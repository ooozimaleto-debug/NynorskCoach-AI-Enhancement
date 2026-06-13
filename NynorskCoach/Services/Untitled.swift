//
//  IntegrationAdapters.swift
//  NynorskCoach
//
//  Week 2 Integration
//

import Foundation
import Combine

// MARK: - Conformation: UserLearningProfile -> LearnerContextProviding

extension UserLearningProfile: LearnerContextProviding {
    var nativeLanguageCode: String {
        let langName = UserDefaults.standard.string(forKey: "nativeLanguage") ?? "Russian"
        switch langName.lowercased() {
        case "russian", "русский": return "ru"
        case "ukrainian", "українська": return "uk"
        case "polish", "polski": return "pl"
        case "latvian", "latviešu": return "lv"
        case "english", "английский": return "en"
        case "norwegian", "norsk bokmål": return "nb"
        default: return "ru"
        }
    }
    
    var level: ExerciseDifficulty {
        switch proficiencyLevel {
        case 1: return .a1
        case 2: return .a2
        case 3: return .b1
        case 4, 5: return .b2
        default: return .a1
        }
    }
    
    var weakSkills: [SkillTag] {
        weakAreas.compactMap { name in
            let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
            switch lower {
            case "pronouns", "местоимения": return .pronouns
            case "negation", "ikkje", "отрицание": return .negation
            case "question_words", "вопросы": return .questionWords
            case "noun_gender", "род": return .nounGender
            case "a_verbs", "глаголы a": return .aVerbs
            case "e_verbs", "глаголы e": return .eVerbs
            case "possessives", "притяжательные": return .possessives
            case "numerals", "числа": return .numerals
            case "vocabulary", "лексика": return .vocabulary
            case "syntax", "порядок": return .syntax
            case "prepositions", "предлоги": return .prepositions
            default: return nil
            }
        }
    }
    
    var recentVocabulary: [String] { [] }
}

// MARK: - Conformation: OpenAIService -> AICompletionProviding

extension OpenAIService: AICompletionProviding {
    func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        try await generateSimpleChatResponse(systemPrompt: system, userMessage: user)
    }
}
