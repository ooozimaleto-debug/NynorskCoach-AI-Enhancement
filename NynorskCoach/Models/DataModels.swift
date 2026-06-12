import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum GrammaticalGender: String, Codable, CaseIterable, Identifiable {
    case masculine = "Hankjønn"
    case feminine = "Hokjønn"
    case neuter = "Inkjekjønn"
    case none = "Ingen"
    var id: String { self.rawValue }
    init(shortCode: String) {
        switch shortCode.lowercased() {
        case "m", "masculine", "hankjønn": self = .masculine
        case "f", "feminine", "hokjønn": self = .feminine
        case "n", "neuter", "inkjekjønn": self = .neuter
        default: self = .none
        }
    }
}

enum LearningStatus: String, Codable, CaseIterable {
    case new = "Ny"
    case learning = "Læring"
    case mastered = "Lært"
}

enum SRSGrade { case again, hard, good, easy }

enum Mentor: String, Codable, CaseIterable, Identifiable {
    case freya = "Freya"
    case loki = "Loki"
    case odin = "Odin"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .freya: return "Фрея 🌸"
        case .loki: return "Локи 😏"
        case .odin: return "Один ⚔️"
        }
    }
    
    var description: String {
        switch self {
        case .freya: return "Мудрая и терпеливая. Мягко хвалит и поддерживает."
        case .loki: return "Хитрый трикстер. Подкалывает и иронизирует."
        case .odin: return "Суровый генерал. Требует дисциплины."
        }
    }
    
    var voiceGender: String {
        switch self {
        case .freya: return "female"
        default: return "male"
        }
    }
    
    var systemInstruction: String {
        switch self {
        case .freya:
            return """
            [MENTOR PERSONA: FREYA]
            You are Freya, a loving, patient goddess.
            - Tone: Warm, soft, motherly. Use "Min venn", "Kjære".
            - Emojis: 🥰, 🌸, ✨, ❤️.
            - On Mistake: Use the "Sandwich Method" (Praise -> Gentle Correction -> Praise). Never scold.
            """
        case .loki:
            return """
            [MENTOR PERSONA: LOKI]
            You are Loki, a sarcastic trickster friend.
            - Tone: Ironic, witty, provocative, playful.
            - Emojis: 😏, 🙄, 🤡, 😂.
            - On Mistake: Roast the user playfully. Make fun of the error before fixing it.
            """
        case .odin:
            return """
            [MENTOR PERSONA: ODIN]
            You are Odin (General Harald), a strict Viking commander.
            - Tone: Harsh, commanding, loud (use CAPS LOCK often). No "please".
            - Emojis: 🤬, 🫵, 📢, ⚔️.
            - On Mistake: Zero tolerance. Treat errors as weakness. Demand repetition.
            """
        }
    }
    
    // MARK: - TTS Configuration
    
    /// Имя голоса для Google TTS
    var googleVoiceName: String {
        switch self {
        case .freya: return "nn-NO-Wavenet-E" // Женский (Валькирия)
        case .loki, .odin: return "nn-NO-Wavenet-D" // Мужской (Викинг)
        }
    }
    
    /// Высота тона для Google TTS (0.0 = норма)
    var googlePitch: Double {
        switch self {
        case .freya: return 0.0
        case .loki: return 0.0
        case .odin: return -4.0 // Один говорит низким басом
        }
    }
    
    /// Имя модели для OpenAI TTS
    var openAIVoice: String {
        switch self {
        case .freya: return "nova"  // Энергичный женский
        case .loki: return "fable"  // Ироничный мужской
        case .odin: return "onyx"   // Глубокий мужской
        }
    }
}

enum VikingRank: String, Codable, CaseIterable {
    case oppdagar = "Oppdagar", sjofarar = "Sjøfarar", krigar = "Krigar", jarl = "Jarl"
    var description: String {
        switch self {
        case .oppdagar: return "Новичок (A0)"
        case .sjofarar: return "Мореход (A1-A2)"
        case .krigar: return "Воин (B1-B2)"
        case .jarl: return "Ярл (C1-C2)"
        }
    }
    var emoji: String {
        switch self {
        case .oppdagar: return "sailboat"
        case .sjofarar: return "safari"
        case .krigar: return "shield"
        case .jarl: return "crown"
        }
    }
}

// MARK: - Store Models

enum StoreItemType: String, Codable {
    case consumable // Расходники (заморозка, зелья)
    case equipment  // Одежда
    case theme      // Темы карт
}

struct StoreItem: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let price: Int
    let type: StoreItemType
}

// MARK: - Dialogue Models

struct DialogueLine: Codable, Identifiable {
    var id: UUID = UUID()
    let speaker: String
    let text: String
    var audioData: Data?
    
    private enum CodingKeys: String, CodingKey { case speaker, text, audioData }
    
    init(speaker: String, text: String, audioData: Data? = nil) {
        self.speaker = speaker
        self.text = text
        self.audioData = audioData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.speaker = try container.decode(String.self, forKey: .speaker)
        self.text = try container.decode(String.self, forKey: .text)
        self.audioData = try container.decodeIfPresent(Data.self, forKey: .audioData)
        self.id = UUID()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(speaker, forKey: .speaker)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(audioData, forKey: .audioData)
    }
}

// MARK: - SwiftData Models

@Model
class Topic: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var emoji: String
    var difficulty: String
    var isSystem: Bool
    var themeColor: String
    
    @Relationship(deleteRule: .cascade, inverse: \LearningItem.topic)
    var items: [LearningItem] = []
    
    init(id: String = UUID().uuidString, name: String, emoji: String = "📚", difficulty: String = "A1", isSystem: Bool = false, themeColor: String = "blue") {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.difficulty = difficulty
        self.isSystem = isSystem
        self.themeColor = themeColor
    }
    
    var color: Color {
        switch themeColor {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        default: return .blue
        }
    }
}

@Model
class LearningItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var text: String
    var translation: String
    var gender: GrammaticalGender
    
    var transcription: String?
    var contextSentence: String?
    var contextTranslation: String?
    var imageFilename: String?
    
    // --- ГРАММАТИКА И ФОРМЫ ---
    var partOfSpeech: String? // "noun", "verb", "adj", "other"
    var forms: [String]?      // Массив основных форм
    
    // НОВЫЕ ПОЛЯ: Примеры для времен
    var pastExamples: [String]?   // ["Eg gjekk heim.", "Det var kaldt."]
    var futureExamples: [String]? // ["Eg skal gå.", "Det blir bra."]
    
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var audioData: Data?
    
    var status: LearningStatus
    var nextReviewDate: Date
    var lastReviewDate: Date?
    var interval: Double
    var easeFactor: Double
    var reviewCount: Int
    var dateAdded: Date
    
    var topic: Topic?
    
    init(text: String, translation: String, gender: GrammaticalGender = .none, topic: Topic? = nil, contextSentence: String? = nil, contextTranslation: String? = nil) {
        self.id = UUID()
        self.text = text
        self.translation = translation
        self.gender = gender
        self.topic = topic
        self.contextSentence = contextSentence
        self.contextTranslation = contextTranslation
        self.dateAdded = Date.now
        self.status = .new
        self.nextReviewDate = Date.now
        self.interval = 0
        self.easeFactor = 2.5
        self.reviewCount = 0
        
        self.partOfSpeech = "other"
        self.forms = []
        self.pastExamples = []
        self.futureExamples = []
    }
}

// MARK: - SRS COLOR EXTENSION

extension LearningItem {
    /// Цветовой код для подсветки слов в текстах
    enum SRSColor: String {
        case red = "red"       // Не знаю (interval = 0)
        case orange = "orange" // Трудно (interval < 2)
        case green = "green"   // Легко (interval 2-7)
        case gray = "gray"     // Знаю (interval > 7)
    }
    
    /// Определяет цвет на основе интервала повторения
    var srsColor: SRSColor {
        switch interval {
        case 0:
            return .red
        case 0..<2:
            return .orange
        case 2..<7:
            return .green
        default:
            return .gray
        }
    }
    
    /// Цвет фона для подсветки слова в тексте
    var backgroundColor: Color {
        switch srsColor {
        case .red:
            return Color.red.opacity(0.3)
        case .orange:
            return Color.orange.opacity(0.2)
        case .green:
            return Color.green.opacity(0.15)
        case .gray:
            return Color.gray.opacity(0.1)
        }
    }
    
    /// Эмодзи для визуализации статуса
    var statusEmoji: String {
        switch srsColor {
        case .red: return "🔴"
        case .orange: return "🟠"
        case .green: return "🟢"
        case .gray: return "⚪"
        }
    }
}


@Model
class Article: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String; var content: String; var translation: String?
    var dateCreated: Date; var isRead: Bool; var difficulty: String?; var topic: Topic?
    init(title: String, content: String, translation: String? = nil, difficulty: String? = nil, topic: Topic? = nil) {
        self.id = UUID(); self.title = title; self.content = content; self.translation = translation; self.difficulty = difficulty; self.dateCreated = Date.now; self.isRead = false; self.topic = topic
    }
}

@Model
class ChatSession {
    @Attribute(.unique) var id: UUID; var date: Date; var topicName: String
    @Relationship(deleteRule: .cascade) var messages: [PersistedMessage] = []
    init(topicName: String) { self.id = UUID(); self.date = Date.now; self.topicName = topicName }
}

@Model
class PersistedMessage {
    @Attribute(.unique) var id: UUID; var content: String; var role: String; var timestamp: Date
    init(content: String, role: String) { self.id = UUID(); self.content = content; self.role = role; self.timestamp = Date.now }
}

@Model
class SavedPodcast {
    @Attribute(.unique) var id: UUID; var title: String; var transcript: String; var dateSaved: Date
    init(title: String, transcript: String) { self.id = UUID(); self.title = title; self.transcript = transcript; self.dateSaved = Date.now }
}

@Model
class DailyActivity {
    var date: Date; var xpEarned: Int; var wordsLearned: Int
    init(date: Date, xpEarned: Int, wordsLearned: Int) { self.date = date; self.xpEarned = xpEarned; self.wordsLearned = wordsLearned }
}

@Model
class GrammarNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    @Attribute(.externalStorage) var imageData: Data?
    var dateCreated: Date
    
    init(title: String, content: String, imageData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.imageData = imageData
        self.dateCreated = Date.now
    }
}
