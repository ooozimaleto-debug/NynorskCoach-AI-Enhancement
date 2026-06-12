import SwiftData
import SwiftUI

@MainActor
class XPManager {
    static let shared = XPManager()
    
    private init() {}
    
    func addXP(_ amount: Int, context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.date == today }
        )
        
        do {
            let results = try context.fetch(descriptor)
            
            if let existingActivity = results.first {
                existingActivity.xpEarned += amount
            } else {
                let newActivity = DailyActivity(date: today, xpEarned: amount, wordsLearned: 0)
                context.insert(newActivity)
            }
            
            // Пытаемся сохранить
            try? context.save()
            print("⚡️ XP добавлен: +\(amount)")
            
        } catch {
            print("Ошибка XP: \(error)")
        }
    }
}
