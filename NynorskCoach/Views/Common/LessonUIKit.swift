//
//  LessonUIKit.swift
//  NynorskCoach
//
//  Week 2 UI — shared foundations for the lesson screens.
//
//  Holds the visual theme, the decoupled `ExerciseFeedback` value used by the
//  reusable ExerciseView, the source protocols the screen ViewModels depend on
//  (with zero-code conformances for the Week 2 generators), Russian labels for
//  skills, and DEBUG-only mocks so every screen has a working Xcode preview.
//
//  REQUIRES: ExerciseGenerator.swift, StoryGenerator.swift, AdaptiveQuizEngine.swift
//  in the same target.
//

import SwiftUI

// MARK: - Theme

enum Theme {
    /// Fjord teal — calm Nordic accent, not a default system blue.
    static let accent  = Color(red: 0.13, green: 0.45, blue: 0.55)
    static let correct = Color(red: 0.20, green: 0.55, blue: 0.36)
    static let wrong   = Color(red: 0.80, green: 0.32, blue: 0.30)

    static let corner: CGFloat = 16
    static let spacing: CGFloat = 16

    static var surface: Color { Color(uiColor: .secondarySystemBackground) }
    static var subtle: Color  { Color(uiColor: .tertiarySystemBackground) }
}

/// Card surface used across the lesson screens.
private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// Filled accent button used for primary actions.
struct PrimaryActionButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .background(enabled ? Theme.accent : Color.gray.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .disabled(!enabled)
    }
}

// MARK: - Feedback (decoupled from any engine)

/// Result of grading an answer, built by whichever screen owns the exercise.
struct ExerciseFeedback {
    let wasCorrect: Bool
    let acceptedAnswers: [String]
    let explanation: String
}

// MARK: - Source protocols (let ViewModels stay testable / previewable)

protocol PracticeSetProviding {
    func generateAdaptiveSet(count: Int) async throws -> ExerciseSet
}

protocol StoryProviding {
    func generateStory(theme: String?, length: StoryLength, questionCount: Int) async throws -> Story
}

// Zero-code conformances: the Week 2 generators already have these methods.
extension ExerciseGenerator: PracticeSetProviding {}
extension StoryGenerator: StoryProviding {}

// MARK: - Skill labels (Russian, for the learner-facing summary)

extension SkillTag {
    var label: String {
        switch self {
        case .pronouns:      return "Местоимения"
        case .nounGender:    return "Род существительных"
        case .aVerbs:        return "Глаголы на -a"
        case .eVerbs:        return "Глаголы на -e"
        case .negation:      return "Отрицание (ikkje)"
        case .questionWords: return "Вопросительные слова"
        case .possessives:   return "Притяжательные"
        case .numerals:      return "Числительные"
        case .vocabulary:    return "Лексика"
        case .syntax:        return "Порядок слов"
        case .prepositions:  return "Предлоги"
        }
    }
}

// MARK: - DEBUG mocks for previews

#if DEBUG
extension Exercise {
    static func sampleMultipleChoice(
        skill: SkillTag = .questionWords,
        difficulty: ExerciseDifficulty = .a2
    ) -> Exercise {
        Exercise(
            type: .multipleChoice, difficulty: difficulty, skill: skill,
            prompt: "Kva tyder ordet «kva»?",
            options: ["что", "где", "как", "почему"],
            acceptedAnswers: ["что"],
            explanation: "«kva» означает «что». «kvar» — где, «korleis» — как."
        )
    }

    static func sampleFill(difficulty: ExerciseDifficulty = .a1) -> Exercise {
        Exercise(
            type: .fillInBlank, difficulty: difficulty, skill: .negation,
            prompt: "Вставьте пропущенное слово («не»):",
            context: "Eg snakkar ___ nynorsk enno.",
            acceptedAnswers: ["ikkje"],
            explanation: "Отрицание в нюнорске — «ikkje» (в букмоле «ikke»)."
        )
    }

    static func sampleWordOrder(difficulty: ExerciseDifficulty = .a2) -> Exercise {
        Exercise(
            type: .wordOrder, difficulty: difficulty, skill: .syntax,
            prompt: "Соберите предложение: «Я люблю рыбачить».",
            options: ["Eg", "likar", "å", "fiska"],
            acceptedAnswers: ["Eg likar å fiska"],
            explanation: "Порядок: подлежащее + глагол + инфинитивная группа «å fiska»."
        )
    }
}

extension Story {
    static var sample: Story { StoryGenerator.fallbackStory(level: .a2) }
}

struct MockLearnerContext: LearnerContextProviding {
    var nativeLanguageCode = "ru"
    var level: ExerciseDifficulty = .a2
    var weakSkills: [SkillTag] = [.negation, .questionWords]
    var recentVocabulary: [String] = ["fjord", "makrell", "kaia"]
}

struct MockQuizProvider: QuizItemProviding {
    func quizItem(skill: SkillTag, difficulty: ExerciseDifficulty) async throws -> Exercise {
        [Exercise.sampleMultipleChoice(skill: skill, difficulty: difficulty),
         .sampleFill(difficulty: difficulty),
         .sampleWordOrder(difficulty: difficulty)].randomElement()!
    }
}

struct MockPracticeProvider: PracticeSetProviding {
    func generateAdaptiveSet(count: Int) async throws -> ExerciseSet {
        ExerciseSet(
            generatedAt: Date(),
            exercises: [.sampleMultipleChoice(), .sampleFill(), .sampleWordOrder()],
            source: .fallback
        )
    }
}

struct MockStoryProvider: StoryProviding {
    func generateStory(theme: String?, length: StoryLength, questionCount: Int) async throws -> Story {
        .sample
    }
}
#endif
