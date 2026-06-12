import SwiftData
import SwiftUI

class DataSeeder {
    static let shared = DataSeeder()
    
    @MainActor
    func seed(context: ModelContext) {
        print("🌱 Seeder: Проверка...")
        
        // Проверяем, есть ли уже темы в базе
        let descriptor = FetchDescriptor<Topic>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        
        if count == 0 {
            print("📭 База пуста. Запускаем ContentManager...")
            // Делегируем загрузку менеджеру контента
            ContentManager.shared.seedInitialContent(context: context, userRank: .oppdagar)
        } else {
            print("✅ Контент уже есть. Пропуск.")
        }
    }
}
