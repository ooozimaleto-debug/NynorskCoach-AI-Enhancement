import Foundation

/// Result from AI object identification
struct ObjectResult: Codable {
    let object: String       // Nynorsk name, e.g., "ein katt"
    let translation: String  // Native language translation, e.g., "кот"
    let description: String  // Full Nynorsk description
    
    enum CodingKeys: String, CodingKey {
        case object
        case translation
        case description
    }
}

/// Error types for Vision operations
enum VisionError: LocalizedError {
    case noTextFound
    case ocrFailed
    case invalidImage
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "Текст не распознан"
        case .ocrFailed:
            return "Ошибка распознавания текста"
        case .invalidImage:
            return "Некорректное изображение"
        case .apiError(let message):
            return "Ошибка: \(message)"
        }
    }
}
