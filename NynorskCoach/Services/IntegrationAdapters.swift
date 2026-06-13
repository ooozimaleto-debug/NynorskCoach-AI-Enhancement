//
//  IntegrationAdapters.swift
//  NynorskCoach
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
            case "negation", "ikkje": return .negation
            case "question_words": return .questionWords
            case "noun_gender": return .nounGender
            case "a_verbs": return .aVerbs
            case "e_verbs": return .eVerbs
            case "possessives": return .possessives
            case "numerals": return .numerals
            case "vocabulary": return .vocabulary
            case "syntax": return .syntax
            case "prepositions": return .prepositions
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
