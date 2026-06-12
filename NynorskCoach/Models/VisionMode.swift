import Foundation

/// Vision modes for unified vision view
enum VisionMode: String, CaseIterable, Identifiable {
    case ocr = "Текст"
    case describe = "Описать"
    case identify = "Предмет"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .ocr:
            return "text.viewfinder"
        case .describe:
            return "eye.fill"
        case .identify:
            return "eye.trianglebadge.exclamationmark"
        }
    }
    
    var placeholder: String {
        switch self {
        case .ocr:
            return "Сфотографируй текст, чтобы выделять слова."
        case .describe:
            return "Сфотографируй предмет и опиши его на Nynorsk."
        case .identify:
            return "Сфотографируй предмет, я помогу тебе назвать его."
        }
    }
    
    var title: String {
        switch self {
        case .ocr:
            return "Фото-сканер"
        case .describe:
            return "Опиши картинку"
        case .identify:
            return "Глаз Одина"
        }
    }
}
