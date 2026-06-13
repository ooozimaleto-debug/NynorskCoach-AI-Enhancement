//
//  ExerciseGenerator.swift
//  NynorskCoach
//
//  Week 2 — adaptive Nynorsk exercise generation.
//
//  Sits between UserContextManager (learner state) and the Week 1 API client.
//  Builds a teaching prompt from the learner's context, asks the model for a
//  structured set of exercises, validates the JSON into `Exercise` models, and
//  falls back to a hand-written Nynorsk bank when the network or model fails.
//
//  No UI knowledge, no API key handling — both are injected via protocols.
//

import Foundation

// MARK: - Domain models

/// Pedagogical category of an exercise.
enum ExerciseType: String, Codable, CaseIterable, Sendable {
    case translation        // native language (e.g. Russian) <-> Nynorsk
    case bokmaalToNynorsk   // rewrite a Bokmål sentence in correct Nynorsk
    case fillInBlank        // cloze: one missing word
    case wordOrder          // arrange shuffled tokens into a correct sentence
    case multipleChoice     // grammar / vocabulary, single best answer
    case conjugation        // produce the correct verb or noun form
    case matching           // pair words with meanings

    /// Label shown in the UI (Nynorsk).
    var displayName: String {
        switch self {
        case .translation:      return "Omsetjing"
        case .bokmaalToNynorsk: return "Frå bokmål til nynorsk"
        case .fillInBlank:      return "Fyll ut"
        case .wordOrder:        return "Ordstilling"
        case .multipleChoice:   return "Vel rett svar"
        case .conjugation:      return "Bøying"
        case .matching:         return "Para saman"
        }
    }
}

/// Grammar / vocabulary area an exercise targets — drives spaced repetition.
enum SkillTag: String, Codable, CaseIterable, Sendable {
    case pronouns        // eg, du, han, ho, me/vi, de/dykk, dei
    case nounGender      // hankjønn / hokjønn / inkjekjønn
    case aVerbs          // kasta -> kastar
    case eVerbs          // kjøpe -> kjøper / kjøpte
    case negation        // ikkje
    case questionWords   // kva, korleis, kvifor, kvar, kven
    case possessives     // min, mi, mitt, mine
    case numerals
    case vocabulary
    case syntax
    case prepositions
}

/// CEFR level used both for the learner estimate and per-exercise difficulty.
enum ExerciseDifficulty: String, Codable, CaseIterable, Sendable {
    case a1, a2, b1, b2
}

/// A single self-contained exercise.
struct Exercise: Codable, Identifiable, Sendable {
    let id: UUID
    let type: ExerciseType
    let difficulty: ExerciseDifficulty
    let skill: SkillTag
    /// Instruction or question shown to the learner.
    let prompt: String
    /// Optional sentence/passage the exercise operates on (e.g. the cloze sentence).
    let context: String?
    /// For multipleChoice / wordOrder / matching. Empty otherwise.
    let options: [String]
    /// One or more acceptable answers. Comparison is normalised on check.
    let acceptedAnswers: [String]
    /// The teaching moment, shown after answering. In the learner's native language.
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case id, type, difficulty, skill, prompt, context, options, acceptedAnswers, explanation
    }

    init(
        id: UUID = UUID(),
        type: ExerciseType,
        difficulty: ExerciseDifficulty,
        skill: SkillTag,
        prompt: String,
        context: String? = nil,
        options: [String] = [],
        acceptedAnswers: [String],
        explanation: String
    ) {
        self.id = id
        self.type = type
        self.difficulty = difficulty
        self.skill = skill
        self.prompt = prompt
        self.context = context
        self.options = options
        self.acceptedAnswers = acceptedAnswers
        self.explanation = explanation
    }

    /// Tolerant decoding: the model needn't supply `id`, and arrays default to empty.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        type = try c.decode(ExerciseType.self, forKey: .type)
        difficulty = (try? c.decode(ExerciseDifficulty.self, forKey: .difficulty)) ?? .a1
        skill = (try? c.decode(SkillTag.self, forKey: .skill)) ?? .vocabulary
        prompt = try c.decode(String.self, forKey: .prompt)
        context = try c.decodeIfPresent(String.self, forKey: .context)
        options = (try? c.decode([String].self, forKey: .options)) ?? []
        acceptedAnswers = (try? c.decode([String].self, forKey: .acceptedAnswers)) ?? []
        explanation = (try? c.decode(String.self, forKey: .explanation)) ?? ""
    }
}

extension Exercise {
    /// Case-, whitespace- and trailing-punctuation-insensitive answer check.
    func isCorrect(_ given: String) -> Bool {
        acceptedAnswers.contains { Self.normalise($0) == Self.normalise(given) }
    }

    private static func normalise(_ s: String) -> String {
        let lowered = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = lowered
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:"))
    }
}

/// Where a set of exercises came from — useful for analytics and UI hints.
enum GenerationSource: String, Sendable {
    case model, fallback
}

/// A generated batch of exercises with provenance.
struct ExerciseSet: Identifiable, Sendable {
    let id = UUID()
    let generatedAt: Date
    let exercises: [Exercise]
    let source: GenerationSource
}

// MARK: - Injection boundaries

/// Minimal learner state the generator needs.
/// Conform your existing `UserContextManager` to this in one extension.
protocol LearnerContextProviding: Sendable {
    /// ISO code of the learner's strongest language, used for explanations. e.g. "ru".
    var nativeLanguageCode: String { get }
    /// Current CEFR estimate.
    var level: ExerciseDifficulty { get }
    /// Skills to prioritise (weak areas / due for review).
    var weakSkills: [SkillTag] { get }
    /// Words to reinforce via spaced repetition.
    var recentVocabulary: [String] { get }
}

/// A single-shot text completion. Conform your Week 1 API client to this.
/// It should call the Anthropic Messages endpoint and return the model's text.
protocol AICompletionProviding: Sendable {
    func complete(system: String, user: String, maxTokens: Int) async throws -> String
}

// MARK: - Errors

enum ExerciseGenerationError: LocalizedError {
    case emptyResponse
    case decodingFailed(raw: String)
    case noExercisesProduced

    var errorDescription: String? {
        switch self {
        case .emptyResponse:        return "Модель вернула пустой ответ."
        case .decodingFailed:       return "Не удалось разобрать упражнения из ответа модели."
        case .noExercisesProduced:  return "Не получилось сгенерировать ни одного упражнения."
        }
    }
}

// MARK: - Generator

final class ExerciseGenerator {

    private let ai: AICompletionProviding
    private let context: LearnerContextProviding
    private let model: String

    /// - Parameter model: keep in sync with the model string your API client uses.
    init(
        ai: AICompletionProviding,
        context: LearnerContextProviding,
        model: String = "claude-sonnet-4-6"
    ) {
        self.ai = ai
        self.context = context
        self.model = model
    }

    // MARK: Public entry points

    /// Adaptive mixed set: distribution weighted toward the learner's weak skills.
    func generateAdaptiveSet(count: Int = 6) async throws -> ExerciseSet {
        let plan = buildPlan(count: max(1, count))
        do {
            let exercises = try await requestExercises(plan: plan, difficulty: context.level)
            guard !exercises.isEmpty else { throw ExerciseGenerationError.noExercisesProduced }
            return ExerciseSet(generatedAt: Date(), exercises: exercises, source: .model)
        } catch {
            let fallback = Self.fallbackBank(level: context.level, count: count)
            guard !fallback.isEmpty else { throw error }
            return ExerciseSet(generatedAt: Date(), exercises: fallback, source: .fallback)
        }
    }

    /// Targeted generation of a single exercise type.
    func generate(
        type: ExerciseType,
        count: Int,
        difficulty: ExerciseDifficulty? = nil,
        skill: SkillTag? = nil
    ) async throws -> [Exercise] {
        let level = difficulty ?? context.level
        let plan = Array(repeating: PlanItem(type: type, skill: skill ?? .vocabulary),
                         count: max(1, count))
        return try await requestExercises(plan: plan, difficulty: level)
    }

    // MARK: Planning

    private struct PlanItem { let type: ExerciseType; let skill: SkillTag }

    /// Decide which (type, skill) pairs to request. Weak skills come first,
    /// then variety to keep the set from feeling repetitive.
    private func buildPlan(count: Int) -> [PlanItem] {
        var plan: [PlanItem] = []

        // Map each weak skill to a sensible exercise type.
        for skill in context.weakSkills where plan.count < count {
            plan.append(PlanItem(type: Self.preferredType(for: skill), skill: skill))
        }

        // Fill the rest with a rotating variety of types/skills.
        let varietyTypes: [ExerciseType] = [
            .multipleChoice, .fillInBlank, .bokmaalToNynorsk, .wordOrder, .translation, .conjugation
        ]
        let varietySkills: [SkillTag] = [
            .pronouns, .negation, .questionWords, .nounGender, .aVerbs, .vocabulary
        ]
        var i = 0
        while plan.count < count {
            plan.append(PlanItem(
                type: varietyTypes[i % varietyTypes.count],
                skill: varietySkills[i % varietySkills.count]
            ))
            i += 1
        }
        return plan
    }

    private static func preferredType(for skill: SkillTag) -> ExerciseType {
        switch skill {
        case .pronouns, .possessives, .numerals, .vocabulary: return .multipleChoice
        case .nounGender, .prepositions:                      return .fillInBlank
        case .aVerbs, .eVerbs:                                return .conjugation
        case .negation, .questionWords:                       return .fillInBlank
        case .syntax:                                         return .wordOrder
        }
    }

    // MARK: Model call + parsing

    private func requestExercises(plan: [PlanItem], difficulty: ExerciseDifficulty) async throws -> [Exercise] {
        let raw = try await ai.complete(
            system: Self.systemPrompt(nativeLanguage: context.nativeLanguageCode),
            user: userPrompt(plan: plan, difficulty: difficulty),
            maxTokens: 2048
        )
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExerciseGenerationError.emptyResponse }
        return try Self.decodeExercises(from: trimmed)
    }

    private func userPrompt(plan: [PlanItem], difficulty: ExerciseDifficulty) -> String {
        let requests = plan.enumerated().map { idx, item in
            "\(idx + 1). type=\(item.type.rawValue), skill=\(item.skill.rawValue)"
        }.joined(separator: "\n")

        let vocab = context.recentVocabulary.isEmpty
            ? "(ingen)"
            : context.recentVocabulary.prefix(15).joined(separator: ", ")

        return """
        Lag \(plan.count) øvingar i nynorsk for ein elev på nivå \(difficulty.rawValue.uppercased()).
        Morsmålet til eleven (for forklaringar): \(context.nativeLanguageCode).

        Bruk gjerne desse orda som eleven nyleg har lært, for repetisjon: \(vocab)

        Lag nøyaktig éi øving per linje under, i same rekkjefølgje:
        \(requests)

        Returner BERRE eit JSON-array. Inga innleiing, ingen markdown, ingen kodeblokk.
        Kvart objekt skal ha desse felta:
        {
          "type": "<ein av: translation, bokmaalToNynorsk, fillInBlank, wordOrder, multipleChoice, conjugation, matching>",
          "difficulty": "\(difficulty.rawValue)",
          "skill": "<skill-koden frå lista over>",
          "prompt": "<spørsmål/instruksjon, kort>",
          "context": "<setning eller null>",
          "options": ["..."],            // berre for multipleChoice/wordOrder/matching, elles []
          "acceptedAnswers": ["..."],    // eitt eller fleire rette svar
          "explanation": "<kort forklaring på morsmålet til eleven (\(context.nativeLanguageCode))>"
        }
        """
    }

    private static func systemPrompt(nativeLanguage: String) -> String {
        """
        Du er ein erfaren lærar i nynorsk og lagar korte, presise øvingar.

        Viktige reglar:
        - All målspråk-tekst skal vere KORREKT NYNORSK, aldri bokmål.
          Hugs typiske skilnader: «eg» (ikkje «jeg»), «ikkje» (ikkje «ikke»),
          «kva/korleis/kvifor/kvar/kven» (ikkje «hva/hvordan» osv.),
          «noko» (ikkje «noe»), hokjønnsformer som «jenta», a-verb som «kastar».
        - Tilpass vanskegraden nøye til nivået. På A1/A2: korte setningar, høgfrekvent ordtilfang.
        - Forklaringane («explanation») skal vere på elevens morsmål: \(nativeLanguage).
        - For multipleChoice: 3–4 alternativ, berre eitt rett, distraktorane skal vere truverdige
          (t.d. bokmålsformer eller nære feilformer).
        - Returner alltid gyldig JSON som eit array, utan markdown og utan ekstra tekst.
        """
    }

    /// Strips optional code fences and decodes the first JSON array found.
    static func decodeExercises(from text: String) throws -> [Exercise] {
        var s = text

        // Remove ```json ... ``` fences if present.
        if let fenceStart = s.range(of: "```") {
            s.removeSubrange(s.startIndex..<fenceStart.upperBound)
            if let langNewline = s.firstIndex(of: "\n") { s = String(s[s.index(after: langNewline)...]) }
            if let fenceEnd = s.range(of: "```", options: .backwards) {
                s = String(s[s.startIndex..<fenceEnd.lowerBound])
            }
        }

        // Narrow to the outermost array.
        guard let open = s.firstIndex(of: "["),
              let close = s.lastIndex(of: "]"),
              open < close else {
            throw ExerciseGenerationError.decodingFailed(raw: text)
        }
        let jsonSlice = String(s[open...close])

        guard let data = jsonSlice.data(using: .utf8) else {
            throw ExerciseGenerationError.decodingFailed(raw: text)
        }
        do {
            return try JSONDecoder().decode([Exercise].self, from: data)
        } catch {
            throw ExerciseGenerationError.decodingFailed(raw: text)
        }
    }

    // MARK: Fallback bank (offline / failure resilience)

    /// Hand-written, verified-correct Nynorsk exercises. Returned when the model
    /// is unreachable so the learner never hits an empty screen.
    static func fallbackBank(level: ExerciseDifficulty, count: Int) -> [Exercise] {
        let bank: [Exercise] = [
            Exercise(
                type: .multipleChoice, difficulty: .a1, skill: .pronouns,
                prompt: "Какое слово в нюнорске означает «я»?",
                options: ["eg", "jeg", "jæ", "ek"],
                acceptedAnswers: ["eg"],
                explanation: "В нюнорске «я» — это «eg». «jeg» — это форма букмола."
            ),
            Exercise(
                type: .fillInBlank, difficulty: .a1, skill: .negation,
                prompt: "Вставьте пропущенное слово («не»):",
                context: "Eg snakkar ___ nynorsk enno.",
                acceptedAnswers: ["ikkje"],
                explanation: "Отрицание «не» в нюнорске — «ikkje» (в букмоле — «ikke»)."
            ),
            Exercise(
                type: .multipleChoice, difficulty: .a1, skill: .questionWords,
                prompt: "Как сказать «что» в нюнорске?",
                options: ["kva", "hva", "kvar", "korleis"],
                acceptedAnswers: ["kva"],
                explanation: "«что» — «kva». «kvar» — это «где», «korleis» — «как»."
            ),
            Exercise(
                type: .bokmaalToNynorsk, difficulty: .a2, skill: .syntax,
                prompt: "Перепишите предложение на нюнорске:",
                context: "Jeg vet ikke hva det er.",
                acceptedAnswers: ["Eg veit ikkje kva det er.", "Eg veit ikkje kva det er"],
                explanation: "jeg→eg, vet→veit, ikke→ikkje, hva→kva. Получается «Eg veit ikkje kva det er.»"
            ),
            Exercise(
                type: .conjugation, difficulty: .a2, skill: .aVerbs,
                prompt: "Поставьте глагол «å kasta» в настоящее время: «Eg ___ ballen.»",
                context: "Eg ___ ballen.",
                acceptedAnswers: ["kastar"],
                explanation: "A-глаголы в нюнорске в настоящем времени получают окончание -ar: kasta → kastar."
            ),
            Exercise(
                type: .fillInBlank, difficulty: .a1, skill: .nounGender,
                prompt: "Поставьте существительное «ei jente» в определённую форму: «Eg ser ___.»",
                context: "Eg ser ___. (девочку — определённая форма)",
                acceptedAnswers: ["jenta"],
                explanation: "Существительные женского рода с «ei» в определённой форме получают -a: ei jente → jenta."
            ),
        ]

        let target = level
        // Prefer exercises at/below the learner's level, then top up with the rest.
        let order: [ExerciseDifficulty] = [.a1, .a2, .b1, .b2]
        let cap = order.firstIndex(of: target) ?? 0
        let allowed = Set(order.prefix(cap + 1))

        let primary = bank.filter { allowed.contains($0.difficulty) }
        let rest = bank.filter { !allowed.contains($0.difficulty) }
        return Array((primary + rest).prefix(count))
    }
}
