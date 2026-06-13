//
//  AdaptiveQuizEngine.swift
//  NynorskCoach
//
//  Week 2 — adaptive quiz.
//
//  Adapts on two axes at once:
//   1. Difficulty — rises on correct streaks, falls on errors, clamped to a band
//      around the learner's level (so a B2 learner is never dropped to A1).
//   2. Skill selection — weighted toward weak skills, drilling each until mastered,
//      while capping consecutive repeats so the session stays varied.
//
//  The question SOURCE is intentionally pluggable via `QuizItemProviding`.
//  Today it is wired to ExerciseGenerator; a story-based or composite provider
//  can be added later without touching the engine.
//
//  REQUIRES: ExerciseGenerator.swift in the same target (reuses `Exercise`,
//  `ExerciseType`, `ExerciseDifficulty`, `SkillTag`, `ExerciseGenerationError`,
//  `LearnerContextProviding`).
//

import Foundation
import Combine

// MARK: - Difficulty ordering helpers

extension ExerciseDifficulty {
    var rank: Int {
        switch self {
        case .a1: return 0
        case .a2: return 1
        case .b1: return 2
        case .b2: return 3
        }
    }

    static func fromRank(_ r: Int) -> ExerciseDifficulty {
        let levels: [ExerciseDifficulty] = [.a1, .a2, .b1, .b2]
        return levels[min(levels.count - 1, max(0, r))]
    }
}

// MARK: - Difficulty controller (within-session)

/// Moves the working difficulty up after a correct streak and down on a miss,
/// bounded by a band around the learner's level.
struct DifficultyController {
    let floor: ExerciseDifficulty
    let ceiling: ExerciseDifficulty
    let promoteAfter: Int
    private(set) var current: ExerciseDifficulty
    private var streakCorrect = 0

    init(level: ExerciseDifficulty, band: Int, promoteAfter: Int) {
        self.floor = .fromRank(level.rank - band)
        self.ceiling = .fromRank(level.rank + band)
        self.promoteAfter = max(1, promoteAfter)
        self.current = level
    }

    mutating func record(correct: Bool) {
        if correct {
            streakCorrect += 1
            if streakCorrect >= promoteAfter {
                current = .fromRank(min(ceiling.rank, current.rank + 1))
                streakCorrect = 0
            }
        } else {
            streakCorrect = 0
            current = .fromRank(max(floor.rank, current.rank - 1))
        }
    }

    var atCeiling: Bool { current.rank >= ceiling.rank }
    var atFloor: Bool { current.rank <= floor.rank }
}

// MARK: - Mastery tracking (skill selection)

struct SkillMastery: Sendable {
    var score: Double     // 0...1
    var attempts: Int = 0
    var correct: Int = 0
}

/// Tracks per-skill mastery and chooses what to drill next.
struct MasteryTracker {
    private(set) var skills: [SkillTag: SkillMastery]
    let learningRate: Double
    let masteryThreshold: Double
    let minAttempts: Int

    init(pool: [SkillTag], weak: Set<SkillTag>, learningRate: Double, masteryThreshold: Double, minAttempts: Int) {
        var seed: [SkillTag: SkillMastery] = [:]
        for s in pool {
            // Weak skills start low so they're prioritised; others start mid.
            seed[s] = SkillMastery(score: weak.contains(s) ? 0.10 : 0.50)
        }
        self.skills = seed
        self.learningRate = learningRate
        self.masteryThreshold = masteryThreshold
        self.minAttempts = max(1, minAttempts)
    }

    mutating func record(_ skill: SkillTag, correct: Bool) {
        var m = skills[skill] ?? SkillMastery(score: 0.30)
        m.attempts += 1
        if correct {
            m.correct += 1
            m.score += learningRate * (1 - m.score)        // toward 1
        } else {
            m.score *= (1 - learningRate)                  // toward 0
        }
        skills[skill] = m
    }

    func isMastered(_ skill: SkillTag) -> Bool {
        guard let m = skills[skill] else { return false }
        return m.attempts >= minAttempts && m.score >= masteryThreshold
    }

    var allMastered: Bool { !skills.isEmpty && skills.keys.allSatisfy { isMastered($0) } }

    /// Weighted pick favouring low-mastery skills; skips mastered ones and the
    /// `avoid` skill when there's an alternative.
    func nextSkill(avoid: SkillTag?) -> SkillTag? {
        let unmastered = skills.keys.filter { !isMastered($0) }
        let base = unmastered.isEmpty ? Array(skills.keys) : unmastered
        let candidates = (avoid != nil && base.count > 1) ? base.filter { $0 != avoid } : base
        guard !candidates.isEmpty else { return base.first }

        let weights = candidates.map { max(0.05, 1 - (skills[$0]?.score ?? 0.5)) }
        let total = weights.reduce(0, +)
        var r = Double.random(in: 0..<max(total, 0.0001))
        for (i, s) in candidates.enumerated() {
            r -= weights[i]
            if r <= 0 { return s }
        }
        return candidates.last
    }
}

// MARK: - Question source (pluggable)

/// The engine's only dependency on where questions come from.
/// Conform any generator/store to this; the engine doesn't care which.
protocol QuizItemProviding {
    func quizItem(skill: SkillTag, difficulty: ExerciseDifficulty) async throws -> Exercise
}

/// Today's wiring: questions come from the LLM-backed ExerciseGenerator.
extension ExerciseGenerator: QuizItemProviding {
    func quizItem(skill: SkillTag, difficulty: ExerciseDifficulty) async throws -> Exercise {
        let items = try await generate(
            type: Self.quizType(for: skill),
            count: 1,
            difficulty: difficulty,
            skill: skill
        )
        guard let q = items.first else { throw ExerciseGenerationError.noExercisesProduced }
        return q
    }

    /// Quiz questions favour fast, auto-gradable formats.
    private static func quizType(for skill: SkillTag) -> ExerciseType {
        switch skill {
        case .aVerbs, .eVerbs:
            return .conjugation
        case .nounGender, .negation, .questionWords, .prepositions:
            return .fillInBlank
        default:
            return .multipleChoice
        }
    }
}

// MARK: - Engine

@MainActor
final class AdaptiveQuizEngine: ObservableObject {

    struct Config {
        var maxQuestions = 12
        var minQuestions = 6
        var masteryThreshold = 0.85
        var minAttemptsPerSkill = 3
        var difficultyBand = 1            // ± steps around the learner's level
        var promoteAfter = 2              // correct-in-a-row to bump difficulty up
        var learningRate = 0.35
        var maxConsecutiveSameSkill = 2

        init() {}
    }

    struct AnswerResult: Sendable {
        let wasCorrect: Bool
        let exercise: Exercise
        let given: String
    }

    struct Summary: Sendable {
        let total: Int
        let correct: Int
        let accuracy: Double
        /// Skills sorted weakest-first, with final mastery scores.
        let perSkill: [(skill: SkillTag, mastery: Double)]
        /// -1 / 0 / +1 hint for UserContextManager to adjust the stored level.
        let suggestedLevelChange: Int
    }

    // Published state for the SwiftUI view.
    @Published private(set) var currentQuestion: Exercise?
    @Published private(set) var lastResult: AnswerResult?
    @Published private(set) var answered = 0
    @Published private(set) var correctCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isFinished = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var summary: Summary?

    let targetQuestions: Int

    private let provider: QuizItemProviding
    private let config: Config
    private var tracker: MasteryTracker
    private var difficulty: DifficultyController
    private var lastSkill: SkillTag?
    private var consecutiveSameSkill = 0

    private static let defaultPool: [SkillTag] =
        [.pronouns, .negation, .questionWords, .nounGender, .aVerbs, .vocabulary]

    init(provider: QuizItemProviding, context: LearnerContextProviding, config: Config = Config()) {
        self.provider = provider
        self.config = config
        self.targetQuestions = config.maxQuestions

        // Build the skill pool: weak skills first, topped up for variety so the
        // session never has to hammer a single skill.
        var pool = context.weakSkills
        if pool.count < 3 {
            for s in Self.defaultPool where !pool.contains(s) && pool.count < 4 {
                pool.append(s)
            }
        }

        self.tracker = MasteryTracker(
            pool: pool,
            weak: Set(context.weakSkills),
            learningRate: config.learningRate,
            masteryThreshold: config.masteryThreshold,
            minAttempts: config.minAttemptsPerSkill
        )
        self.difficulty = DifficultyController(
            level: context.level,
            band: config.difficultyBand,
            promoteAfter: config.promoteAfter
        )
    }

    // MARK: Lifecycle

    /// Begin a fresh session and load the first question.
    func start() async {
        answered = 0
        correctCount = 0
        isFinished = false
        summary = nil
        lastResult = nil
        errorMessage = nil
        await loadNext()
    }

    /// Grade the current question, update adaptation state, and show feedback.
    /// Does NOT auto-advance — the view shows the explanation, then calls `advance()`.
    func submit(_ answer: String) async {
        guard let q = currentQuestion, !isFinished else { return }
        let correct = q.isCorrect(answer)

        answered += 1
        if correct { correctCount += 1 }
        tracker.record(q.skill, correct: correct)
        difficulty.record(correct: correct)
        lastResult = AnswerResult(wasCorrect: correct, exercise: q, given: answer)
    }

    /// Move past the feedback step: finish if done, otherwise load the next question.
    func advance() async {
        guard !isFinished else { return }
        let reachedMax = answered >= config.maxQuestions
        let masteredEarly = answered >= config.minQuestions && tracker.allMastered
        if reachedMax || masteredEarly {
            finish()
        } else {
            await loadNext()
        }
    }

    /// Retry after a load error.
    func retry() async {
        await loadNext()
    }

    // MARK: Internals

    private func loadNext() async {
        isLoading = true
        errorMessage = nil

        let avoid = consecutiveSameSkill >= config.maxConsecutiveSameSkill ? lastSkill : nil
        let skill = tracker.nextSkill(avoid: avoid) ?? .vocabulary
        let diff = difficulty.current

        do {
            let q = try await provider.quizItem(skill: skill, difficulty: diff)
            currentQuestion = q
            lastResult = nil
            consecutiveSameSkill = (skill == lastSkill) ? consecutiveSameSkill + 1 : 1
            lastSkill = skill
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Не удалось загрузить вопрос. Проверьте подключение и повторите."
        }
        isLoading = false
    }

    private func finish() {
        let accuracy = answered > 0 ? Double(correctCount) / Double(answered) : 0

        var levelChange = 0
        if difficulty.atCeiling && accuracy >= 0.80 {
            levelChange = 1
        } else if difficulty.atFloor && accuracy < 0.40 {
            levelChange = -1
        }

        let perSkill = tracker.skills
            .map { (skill: $0.key, mastery: $0.value.score) }
            .sorted { $0.mastery < $1.mastery }

        summary = Summary(
            total: answered,
            correct: correctCount,
            accuracy: accuracy,
            perSkill: perSkill,
            suggestedLevelChange: levelChange
        )
        currentQuestion = nil
        isFinished = true
    }
}
