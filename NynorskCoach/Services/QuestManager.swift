import SwiftUI
import Combine

// Типы заданий
enum QuestType: String, Codable, CaseIterable {
    case wordPractice = "word_practice"
    case lessonComplete = "lesson_complete"
    case coinCollector = "coin_collector"
}

// Модель квеста
struct Quest: Identifiable, Codable {
    var id: String
    var type: QuestType
    var titleKey: String
    var target: Int
    var current: Int
    var reward: Int
    var isClaimed: Bool
    
    var isCompleted: Bool { current >= target }
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return Double(current) / Double(target)
    }
}

// Менеджер квестов
class QuestManager: ObservableObject {
    static let shared = QuestManager()
    private let defaults = UserDefaults.standard
    
    @Published var quests: [Quest] = []
    
    init() {
        loadQuests()
        checkDailyReset()
    }
    
    func checkDailyReset() {
        let lastDate = Date(timeIntervalSince1970: defaults.double(forKey: "lastQuestDate"))
        let calendar = Calendar.current
        
        if !calendar.isDate(lastDate, inSameDayAs: Date()) {
            generateNewQuests()
            defaults.set(Date().timeIntervalSince1970, forKey: "lastQuestDate")
        }
    }
    
    func generateNewQuests() {
        var newQuests: [Quest] = []
        
        // 1. Слова (Логика из v1 - ваша настройка баланса)
        let wordsTarget = Int.random(in: 1...3) * 5
        newQuests.append(Quest(
            id: UUID().uuidString,
            type: .wordPractice,
            titleKey: "quest_words",
            target: wordsTarget,
            current: 0,
            reward: wordsTarget * 3, // Increased from x2 to x3
            isClaimed: false
        ))
        
        // 2. Уроки (Логика из v1)
        let lessonsTarget = Int.random(in: 1...2)
        newQuests.append(Quest(
            id: UUID().uuidString,
            type: .lessonComplete,
            titleKey: "quest_lesson",
            target: lessonsTarget,
            current: 0,
            reward: lessonsTarget * 100, // Increased from x50 to x100
            isClaimed: false
        ))
        
        // 3. Монеты (Логика из v1)
        let coinsTarget = Int.random(in: 2...5)
        newQuests.append(Quest(
            id: UUID().uuidString,
            type: .coinCollector,
            titleKey: "quest_coins",
            target: coinsTarget,
            current: 0,
            reward: 50, // Increased from 30 to 50
            isClaimed: false
        ))
        
        quests = newQuests
        saveQuests()
    }
    
    func progress(_ type: QuestType, amount: Int = 1) {
        if let index = quests.firstIndex(where: { $0.type == type && !$0.isCompleted }) {
            quests[index].current += amount
            saveQuests()
            
            if quests[index].isCompleted {
                DispatchQueue.main.async {
                    AudioManager.shared.play(.success)
                }
            }
        }
    }
    
    func claim(_ quest: Quest) {
        if let index = quests.firstIndex(where: { $0.id == quest.id }), quest.isCompleted, !quest.isClaimed {
            quests[index].isClaimed = true
            
            // ВАЖНОЕ ИСПРАВЛЕНИЕ: Используем StoreManager (как в новой версии)
            StoreManager.shared.addCoins(quest.reward)
            
            DispatchQueue.main.async {
                AudioManager.shared.play(.coin)
                AudioManager.shared.playHaptic(.success)
            }
            saveQuests()
        }
    }
    
    private func saveQuests() {
        if let data = try? JSONEncoder().encode(quests), let str = String(data: data, encoding: .utf8) {
            defaults.set(str, forKey: "dailyQuestsJSON")
        }
    }
    
    private func loadQuests() {
        let json = defaults.string(forKey: "dailyQuestsJSON") ?? ""
        if let data = json.data(using: .utf8), let decoded = try? JSONDecoder().decode([Quest].self, from: data) {
            quests = decoded
        } else {
            generateNewQuests()
        }
    }
    
    func debugReset() {
        generateNewQuests()
    }
}
