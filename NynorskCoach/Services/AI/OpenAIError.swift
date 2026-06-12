import Foundation

// MARK: - OPENAI ERROR HANDLING

/// Типизированные ошибки OpenAI API с понятными сообщениями для пользователя
enum OpenAIError: LocalizedError, Equatable {
    case noInternet
    case apiLimitExceeded
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(Int)
    case parsingError
    case unknown
    
    /// Сообщение для пользователя (на русском)
    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "Нет подключения к интернету"
        case .apiLimitExceeded:
            return "Превышен лимит запросов OpenAI. Попробуй позже."
        case .invalidAPIKey:
            return "Неверный API ключ. Проверь настройки."
        case .rateLimitExceeded:
            return "Слишком много запросов. Подожди минуту."
        case .serverError(let code):
            return "Ошибка сервера (\(code)). Попробуй позже."
        case .parsingError:
            return "Ошибка обработки ответа. Попробуй еще раз."
        case .unknown:
            return "Неизвестная ошибка. Попробуй еще раз."
        }
    }
    
    /// Подсказка для пользователя
    var recoverySuggestion: String? {
        switch self {
        case .noInternet:
            return "Проверь подключение к Wi-Fi или мобильным данным."
        case .apiLimitExceeded:
            return "Подожди несколько минут и попробуй снова."
        case .invalidAPIKey:
            return "Обратись к разработчику приложения."
        case .rateLimitExceeded:
            return "Ты отправляешь слишком много запросов. Сделай паузу."
        case .serverError:
            return "Проблема на стороне сервера OpenAI. Попробуй позже."
        case .parsingError:
            return "Попробуй переформулировать запрос."
        case .unknown:
            return "Перезапусти приложение."
        }
    }
    
    /// Техническая информация для разработчика (логи)
    var developerInfo: String {
        switch self {
        case .noInternet:
            return "URLError: No internet connection"
        case .apiLimitExceeded:
            return "HTTP 402: Payment Required - check OpenAI billing"
        case .invalidAPIKey:
            return "HTTP 401: Unauthorized - invalid API key"
        case .rateLimitExceeded:
            return "HTTP 429: Too Many Requests - rate limit exceeded"
        case .serverError(let code):
            return "HTTP \(code): Server error - check OpenAI status page"
        case .parsingError:
            return "JSON parsing failed - check response format"
        case .unknown:
            return "Unknown error occurred"
        }
    }
    
    /// Создать ошибку из HTTP статус кода
    static func from(statusCode: Int) -> OpenAIError {
        switch statusCode {
        case 401:
            return .invalidAPIKey
        case 402:
            return .apiLimitExceeded
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .serverError(statusCode)
        default:
            return .serverError(statusCode)
        }
    }
}
