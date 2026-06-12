import Foundation
import CoreGraphics

// Структура распознанного слова
struct RecognizedWord: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect // Координаты Vision (0..1, Y снизу)
}

// Локальная структура для выбранного слова
struct ScannerSelectedWord: Identifiable {
    let id = UUID()
    let text: String
}
