import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    enum HapticType {
        case success, warning, error
    }
    
    // Свой enum для силы удара, чтобы не зависеть от UIKit в заголовке функции
    enum ImpactStyle {
        case light, medium, heavy
    }
    
    func notification(type: HapticType) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success: generator.notificationOccurred(.success)
        case .warning: generator.notificationOccurred(.warning)
        case .error: generator.notificationOccurred(.error)
        }
        #endif
    }
    
    // ВОЗВРАЩАЕМ МЕТОД IMPACT
    func impact(style: ImpactStyle) {
        #if canImport(UIKit)
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light: uiStyle = .light
        case .medium: uiStyle = .medium
        case .heavy: uiStyle = .heavy
        }
        let generator = UIImpactFeedbackGenerator(style: uiStyle)
        generator.impactOccurred()
        #endif
    }
}
