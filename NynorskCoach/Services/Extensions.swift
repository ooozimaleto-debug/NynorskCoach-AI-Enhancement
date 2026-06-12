import SwiftUI
import UIKit

// MARK: - String Extensions (Логика текста)
extension String {
    /// Делает первую букву заглавной, удаляя пробелы по краям.
    /// Работает и для слов ("дом" -> "Дом"), и для фраз ("привет мир" -> "Привет мир").
    func capitalizedSentence() -> String {
        let clean = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = clean.first else { return "" }
        return String(first).uppercased() + clean.dropFirst()
    }
}

// MARK: - Color Extensions (Цвета)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Image Extensions (Шум и рендеринг)
extension Image {
    init(size: CGSize, renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {
        let view = Canvas(renderer: renderer)
            .frame(width: size.width, height: size.height)
        
        let imageRenderer = ImageRenderer(content: view)
        imageRenderer.scale = UIScreen.main.scale // Важно для четкости на iPhone
        
        if let uiImage = imageRenderer.uiImage {
            self.init(uiImage: uiImage)
        } else {
            self.init(systemName: "photo")
        }
    }
}

// MARK: - UIImage Extensions (Для камеры и OCR)
extension UIImage {
    /// Исправляет ориентацию фото, чтобы Vision корректно распознавал текст
    func fixedOrientation() -> UIImage? {
        if imageOrientation == .up { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}
