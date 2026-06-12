import Foundation

// Оценки, которые ставит пользователь


// Результат обработки (инструкция для View)
struct SRSResult {
    let coinsReward: Int       // Сколько монет добавить (или снять, если < 0)
    let shouldVibrate: Bool    // Нужно ли вибрировать (ошибка)
    let isMastered: Bool       // Выучено ли слово
}

final class SRSService {
    static let shared = SRSService()
    
    private init() {}
    
    // Метод теперь возвращает SRSResult и ничего сам не меняет в UI
    func processReview(item: LearningItem, grade: SRSGrade) -> SRSResult {
        
        // 1. Смена статуса (если слово новое -> учим)
        if item.status == .new { item.status = .learning }
        
        var reward = 0
        var shouldVibrateError = false
        
        // 2. Алгоритм интервалов (SM-2 модифицированный)
        switch grade {
        case .again:
            item.interval = 0
            item.easeFactor = max(1.3, item.easeFactor - 0.2)
            item.status = .learning
            
            // Штраф (был -2 монеты)
            reward = -2
            shouldVibrateError = true
            
        case .hard:
            item.interval = (item.interval == 0 ? 1 : item.interval * 1.2)
            item.easeFactor = max(1.3, item.easeFactor - 0.15)
            // Нет награды, но и нет штрафа
            
        case .good:
            item.interval = (item.interval == 0 ? 1 : item.interval * item.easeFactor)
            reward = 1
            
        case .easy:
            item.interval = (item.interval == 0 ? 4 : item.interval * item.easeFactor * 1.3)
            item.easeFactor += 0.15
            reward = 1
        }
        
        // 3. Бонус за наличие контекста (если не ошибся)
        if item.contextSentence != nil && grade != .again && grade != .hard {
            reward += 1
        }
        
        // 4. Обновление дат
        item.reviewCount += 1
        item.lastReviewDate = Date.now
        
        // Вычисляем следующую дату (минимум 12 часов = 0.5 дня)
        let secondsToAdd = max(item.interval, 0.5) * 86400
        item.nextReviewDate = Date.now.addingTimeInterval(secondsToAdd)
        
        // 5. Проверка: стало ли слово "Mastered"
        var mastered = false
        if item.interval > 30 {
            item.status = .mastered
            mastered = true
        }
        
        // Возвращаем результат во View
        return SRSResult(
            coinsReward: reward,
            shouldVibrate: shouldVibrateError,
            isMastered: mastered
        )
    }
}
