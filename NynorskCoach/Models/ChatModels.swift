import Foundation

// Structure for chat corrections (shared between API and UI)
struct ChatCorrection: Codable {
    let original: String; let corrected: String; let explanation: String
}
// Локальная структура для выбранного слова (чтобы sheet работал надежно)
struct ChatSelectedWord: Identifiable {
    let id = UUID()
    let text: String
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    var corrections: [ChatCorrection] = []
    
    // Custom init if needed, or default memberwise
    init(isUser: Bool, text: String, corrections: [ChatCorrection] = []) {
        self.isUser = isUser
        self.text = text
        self.corrections = corrections
    }
}

// MARK: - EXAM ANALYSIS MODELS

struct ExamMistake: Identifiable {
    let id = UUID()
    let word: String
    let userAnswer: String
    let correctAnswer: String
}

struct MistakeAnalysis: Codable, Identifiable {
    var id: UUID { UUID() }
    let word: String
    let correction: String
    let explanation: String
    let example: String
}

struct AnalysisResponse: Codable {
    let reaction: String
    let corrections: [MistakeAnalysis]
}
