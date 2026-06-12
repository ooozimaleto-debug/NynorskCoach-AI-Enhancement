import Foundation

// MARK: - AI MODEL CONFIGURATION

enum AIProvider {
    case openai
    case deepseek
}

/// Определяет модели OpenAI и их параметры для разных задач
enum AIModel {
    case creative   // DeepSeek V3 для историй/подкастов
    case balanced   // DeepSeek V3 для чата
    case precise    // DeepSeek V3 для грамматики
    case vision     // GPT-4o для Vision (OpenAI)
    
    /// Название модели для API запроса
    var name: String {
        switch self {
        case .creative, .balanced, .precise:
            return "deepseek-chat" // Единая модель для всего текста
        case .vision:
            return "gpt-4o"
        }
    }
    
    var provider: AIProvider {
        switch self {
        case .creative, .balanced, .precise:
            return .deepseek
        case .vision:
            return .openai
        }
    }
    
    /// Температура (креативность) модели
    /// 0.0 = детерминированный, 1.0 = максимально креативный
    var temperature: Double {
        switch self {
        case .creative:
            return 1.3  // DeepSeek любит высокую температуру (до 1.5)
        case .balanced:
            return 1.0
        case .precise:
            return 0.0
        case .vision:
            return 0.5
        }
    }
    
    /// Максимальное количество токенов в ответе
    var maxTokens: Int? {
        switch self {
        case .creative:
            return 8000  // DeepSeek поддерживает огромный контекст
        case .balanced:
            return 4000
        case .precise:
            return 2000
        case .vision:
            return 1000
        }
    }
    
    /// Описание модели для логирования
    var description: String {
        switch self {
        case .creative:
            return "DeepSeek V3 (Creative) - temp: \(temperature)"
        case .balanced:
            return "DeepSeek V3 (Balanced) - temp: \(temperature)"
        case .precise:
            return "DeepSeek V3 (Precise) - temp: \(temperature)"
        case .vision:
            return "GPT-4o (Vision) - temp: \(temperature)"
        }
    }
}
