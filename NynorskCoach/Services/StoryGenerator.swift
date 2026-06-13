//
//  StoryGenerator.swift
//  NynorskCoach
//
//  Week 2 — graded Nynorsk reader generation.
//
//  Mirror of ExerciseGenerator: same injection boundaries, same Nynorsk-correctness
//  discipline, same offline fallback strategy. Produces a short story adapted to the
//  learner's level, with a native-language glossary and comprehension questions
//  expressed as `Exercise` values so the UI and answer-checking stay uniform.
//
//  REQUIRES: ExerciseGenerator.swift in the same target. This file reuses
//  `Exercise`, `ExerciseType`, `ExerciseDifficulty`, `SkillTag`, `GenerationSource`,
//  `AICompletionProviding` and `LearnerContextProviding` from there.
//

import Foundation

// MARK: - Domain models

/// A glossary item linking a Nynorsk term to a native-language translation.
struct GlossaryEntry: Codable, Identifiable, Sendable {
    var id: String { term }
    let term: String          // Nynorsk word/phrase
    let translation: String   // in the learner's native language
    let note: String?         // optional: gender, part of speech, Bokmål contrast

    enum CodingKeys: String, CodingKey { case term, translation, note }

    init(term: String, translation: String, note: String? = nil) {
        self.term = term
        self.translation = translation
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decode(String.self, forKey: .term)
        translation = (try? c.decode(String.self, forKey: .translation)) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

/// Approximate length target. Actual word count scales with the learner's level.
enum StoryLength: String, Codable, CaseIterable, Sendable {
    case short, medium, long

    /// Rough word target for a given level — kept gentle at A1/A2.
    func wordTarget(for level: ExerciseDifficulty) -> Int {
        let base: Int
        switch self {
        case .short:  base = 60
        case .medium: base = 120
        case .long:   base = 220
        }
        let multiplier: Double
        switch level {
        case .a1: multiplier = 0.8
        case .a2: multiplier = 1.0
        case .b1: multiplier = 1.4
        case .b2: multiplier = 1.8
        }
        return Int((Double(base) * multiplier).rounded())
    }
}

/// A generated graded reader.
struct Story: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let level: ExerciseDifficulty
    let paragraphs: [String]          // Nynorsk body, one entry per paragraph
    let glossary: [GlossaryEntry]
    let questions: [Exercise]         // comprehension, reusing the Exercise model
    var source: GenerationSource = .model

    var wordCount: Int {
        paragraphs.reduce(0) { $0 + $1.split(whereSeparator: { $0.isWhitespace }).count }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, level, paragraphs, glossary, questions
    }

    init(
        id: UUID = UUID(),
        title: String,
        level: ExerciseDifficulty,
        paragraphs: [String],
        glossary: [GlossaryEntry],
        questions: [Exercise],
        source: GenerationSource = .model
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.paragraphs = paragraphs
        self.glossary = glossary
        self.questions = questions
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? "Forteljing"
        level = (try? c.decode(ExerciseDifficulty.self, forKey: .level)) ?? .a1
        paragraphs = (try? c.decode([String].self, forKey: .paragraphs)) ?? []
        glossary = (try? c.decode([GlossaryEntry].self, forKey: .glossary)) ?? []
        questions = (try? c.decode([Exercise].self, forKey: .questions)) ?? []
        source = .model
    }
}

// MARK: - Errors

enum StoryGenerationError: LocalizedError {
    case emptyResponse
    case decodingFailed(raw: String)
    case emptyStory

    var errorDescription: String? {
        switch self {
        case .emptyResponse:  return "Модель вернула пустой ответ."
        case .decodingFailed: return "Не удалось разобрать историю из ответа модели."
        case .emptyStory:     return "История получилась пустой."
        }
    }
}

// MARK: - Generator

final class StoryGenerator {

    private let ai: AICompletionProviding
    private let context: LearnerContextProviding
    private let model: String

    init(
        ai: AICompletionProviding,
        context: LearnerContextProviding,
        model: String = "claude-sonnet-4-6"
    ) {
        self.ai = ai
        self.context = context
        self.model = model
    }

    // MARK: Public entry point

    /// Generate a graded reader. Falls back to a verified local story on failure.
    /// - Parameters:
    ///   - theme: optional topic; if nil, a level-appropriate everyday theme is used.
    ///   - length: target length, scaled internally by the learner's level.
    ///   - questionCount: number of comprehension questions to attach.
    func generateStory(
        theme: String? = nil,
        length: StoryLength = .short,
        questionCount: Int = 3
    ) async throws -> Story {
        do {
            let raw = try await ai.complete(
                system: Self.systemPrompt(nativeLanguage: context.nativeLanguageCode),
                user: userPrompt(theme: theme, length: length, questionCount: questionCount),
                maxTokens: 2048
            )
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw StoryGenerationError.emptyResponse }
            let story = try Self.decodeStory(from: trimmed)
            guard !story.paragraphs.isEmpty else { throw StoryGenerationError.emptyStory }
            return story
        } catch {
            return Self.fallbackStory(level: context.level)
        }
    }

    // MARK: Prompt building

    private func userPrompt(theme: String?, length: StoryLength, questionCount: Int) -> String {
        let level = context.level
        let words = length.wordTarget(for: level)
        let topic = theme ?? Self.defaultTheme(for: level)
        let vocab = context.recentVocabulary.isEmpty
            ? "(ingen)"
            : context.recentVocabulary.prefix(15).joined(separator: ", ")

        return """
        Skriv ei kort forteljing på nynorsk for ein elev på nivå \(level.rawValue.uppercased()).
        Tema: \(topic).
        Lengd: om lag \(words) ord, fordelt på korte avsnitt.
        Morsmålet til eleven (for ordliste og forklaringar): \(context.nativeLanguageCode).

        Prøv å flette inn nokre av desse orda eleven nyleg har lært: \(vocab)

        Returner BERRE eit JSON-objekt. Inga innleiing, ingen markdown, ingen kodeblokk.
        Strukturen skal vere:
        {
          "title": "<kort tittel på nynorsk>",
          "level": "\(level.rawValue)",
          "paragraphs": ["<avsnitt 1>", "<avsnitt 2>", "..."],
          "glossary": [
            { "term": "<nynorsk ord>", "translation": "<omsetjing på \(context.nativeLanguageCode)>", "note": "<kjønn/ordklasse eller bokmål-kontrast, valfritt>" }
          ],
          "questions": [
            {
              "type": "multipleChoice",
              "difficulty": "\(level.rawValue)",
              "skill": "vocabulary",
              "prompt": "<spørsmål om innhaldet, på nynorsk>",
              "context": null,
              "options": ["...", "...", "..."],
              "acceptedAnswers": ["<rett alternativ>"],
              "explanation": "<kort forklaring på \(context.nativeLanguageCode)>"
            }
          ]
        }

        Lag \(questionCount) forståingsspørsmål. Ordlista skal ha 5–8 ord som er nye eller nyttige for nivået.
        """
    }

    private static func defaultTheme(for level: ExerciseDifficulty) -> String {
        switch level {
        case .a1: return "ein vanleg dag (heim, mat, vêr)"
        case .a2: return "ein tur ut i naturen eller i byen"
        case .b1: return "ei lita hending med ein liten konflikt som blir løyst"
        case .b2: return "ei forteljing med eit val og ein refleksjon"
        }
    }

    private static func systemPrompt(nativeLanguage: String) -> String {
        """
        Du er ein erfaren lærar i nynorsk og skriv korte graderte lesetekstar (graded readers).

        Viktige reglar:
        - All forteljingstekst skal vere KORREKT NYNORSK, aldri bokmål.
          Hugs typiske skilnader: «eg», «ikkje», «kva/korleis/kvifor/kvar/kven»,
          «noko», hokjønnsformer som «jenta/sola/kaia», a-verb som «kastar», «heim», «veit».
        - Tilpass språket nøye til nivået. På A1/A2: korte hovudsetningar, presens,
          høgfrekvent ordtilfang, lite biografi og lite passiv.
        - Ordlista («glossary») og forklaringane skal vere på elevens morsmål: \(nativeLanguage).
        - Forståingsspørsmåla skal kunne svarast ut frå teksten åleine.
        - Returner alltid gyldig JSON som eit enkelt objekt, utan markdown og utan ekstra tekst.
        """
    }

    // MARK: Parsing

    /// Strips optional code fences and decodes the first JSON object found.
    static func decodeStory(from text: String) throws -> Story {
        var s = text

        if let fenceStart = s.range(of: "```") {
            s.removeSubrange(s.startIndex..<fenceStart.upperBound)
            if let langNewline = s.firstIndex(of: "\n") { s = String(s[s.index(after: langNewline)...]) }
            if let fenceEnd = s.range(of: "```", options: .backwards) {
                s = String(s[s.startIndex..<fenceEnd.lowerBound])
            }
        }

        guard let open = s.firstIndex(of: "{"),
              let close = s.lastIndex(of: "}"),
              open < close else {
            throw StoryGenerationError.decodingFailed(raw: text)
        }
        let jsonSlice = String(s[open...close])

        guard let data = jsonSlice.data(using: .utf8) else {
            throw StoryGenerationError.decodingFailed(raw: text)
        }
        do {
            return try JSONDecoder().decode(Story.self, from: data)
        } catch {
            throw StoryGenerationError.decodingFailed(raw: text)
        }
    }

    // MARK: Fallback (offline / failure resilience)

    /// A hand-written, verified-correct A1/A2 Nynorsk story so the reader screen
    /// is never empty when the model is unreachable.
    static func fallbackStory(level: ExerciseDifficulty) -> Story {
        Story(
            title: "Ein dag ved fjorden",
            level: level == .a1 ? .a1 : .a2,
            paragraphs: [
                "Per bur i ein liten by ved fjorden. Han likar å fiska.",
                "Tidleg om morgonen går han ned til kaia. Han har med seg fiskestonga si.",
                "Vatnet er stilt og sola skin. Per ventar lenge, men til slutt får han ein stor makrell.",
                "Han smiler og går heim. I kveld skal familien eta fersk fisk."
            ],
            glossary: [
                GlossaryEntry(term: "fjorden", translation: "фьорд", note: "сущ., м. р., опр. форма"),
                GlossaryEntry(term: "bur", translation: "живёт", note: "от «å bu»; букмол «bor»"),
                GlossaryEntry(term: "å fiska", translation: "ловить рыбу, рыбачить", note: "a-глагол"),
                GlossaryEntry(term: "kaia", translation: "причал, пристань", note: "ж. р.: ei kai → kaia"),
                GlossaryEntry(term: "fiskestonga", translation: "удочка", note: "ж. р.: ei fiskestong → fiskestonga"),
                GlossaryEntry(term: "makrell", translation: "макрель, скумбрия", note: "м. р."),
                GlossaryEntry(term: "heim", translation: "домой", note: "нюнорск; букмол «hjem»"),
                GlossaryEntry(term: "eta", translation: "есть, кушать", note: "инфинитив; букмол «spise»")
            ],
            questions: [
                Exercise(
                    type: .multipleChoice, difficulty: .a1, skill: .vocabulary,
                    prompt: "Kvar bur Per?",
                    options: ["ved fjorden", "i ein stor by", "på fjellet", "ved havet"],
                    acceptedAnswers: ["ved fjorden"],
                    explanation: "В первом абзаце: «Per bur i ein liten by ved fjorden» — у фьорда."
                ),
                Exercise(
                    type: .multipleChoice, difficulty: .a1, skill: .vocabulary,
                    prompt: "Kva får Per til slutt?",
                    options: ["ein stor makrell", "ein laks", "ein torsk", "ingenting"],
                    acceptedAnswers: ["ein stor makrell"],
                    explanation: "«til slutt får han ein stor makrell» — он ловит большую скумбрию."
                ),
                Exercise(
                    type: .multipleChoice, difficulty: .a2, skill: .questionWords,
                    prompt: "Kva tid på dagen går Per til kaia?",
                    options: ["tidleg om morgonen", "om kvelden", "midt på dagen", "om natta"],
                    acceptedAnswers: ["tidleg om morgonen"],
                    explanation: "«Tidleg om morgonen går han ned til kaia» — рано утром."
                )
            ],
            source: .fallback
        )
    }
}
