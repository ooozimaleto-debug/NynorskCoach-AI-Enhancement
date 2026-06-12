import Foundation
import SwiftUI
import Observation

@Observable
class StreakManager {
    static let shared = StreakManager()
    
    var currentStreak: Int = 0
    var isStreakActiveToday: Bool = false
    
    private let kStreakKey = "userStreak"
    private let kLastVisitKey = "lastVisitDate"
    private let kPurchasedItemsKey = "purchasedItems"
    
    // НОВОЕ: Проверяем, есть ли щит в инвентаре (для UI)
    var hasIceShield: Bool {
        let itemsString = UserDefaults.standard.string(forKey: kPurchasedItemsKey) ?? ""
        let items = itemsString.split(separator: ",").map { String($0) }
        return items.contains("freeze_1")
    }
    
    private init() {
        loadStreak()
    }
    
    func checkStreak() {
        let now = Date()
        let calendar = Calendar.current
        
        guard let lastVisit = UserDefaults.standard.object(forKey: kLastVisitKey) as? Date else {
            startNewStreak(date: now)
            return
        }
        
        if calendar.isDateInToday(lastVisit) {
            isStreakActiveToday = true
            return
        }
        
        if calendar.isDateInYesterday(lastVisit) {
            incrementStreak(date: now)
            return
        }
        
        if !calendar.isDateInYesterday(lastVisit) && !calendar.isDateInToday(lastVisit) {
            if tryConsumeFreeze() {
                print("❄️ Стрик спасен заморозкой!")
                // Обновляем дату визита, чтобы стрик не сбросился завтра,
                // но сам стрик не увеличиваем (мы просто сохранили текущий)
                save(date: now, streak: currentStreak)
            } else {
                print("💔 Стрик потерян")
                resetStreak(date: now)
            }
        }
    }
    
    private func tryConsumeFreeze() -> Bool {
        let defaults = UserDefaults.standard
        let itemsString = defaults.string(forKey: kPurchasedItemsKey) ?? ""
        var items = itemsString.split(separator: ",").map { String($0) }
        
        if let index = items.firstIndex(of: "freeze_1") {
            items.remove(at: index)
            let newString = items.joined(separator: ",")
            defaults.set(newString, forKey: kPurchasedItemsKey)
            
            // Уведомляем StoreManager (через AppStorage это произойдет само, так как ключи совпадают)
            return true
        }
        return false
    }
    
    private func startNewStreak(date: Date) { save(date: date, streak: 1) }
    private func incrementStreak(date: Date) { save(date: date, streak: currentStreak + 1) }
    private func resetStreak(date: Date) { save(date: date, streak: 1) }
    
    private func save(date: Date, streak: Int) {
        currentStreak = streak
        isStreakActiveToday = true
        UserDefaults.standard.set(currentStreak, forKey: kStreakKey)
        UserDefaults.standard.set(date, forKey: kLastVisitKey)
        // Синхронизация для старых вьюх, если нужно
        UserDefaults.standard.set(currentStreak, forKey: "streak")
    }
    
    private func loadStreak() {
        self.currentStreak = UserDefaults.standard.integer(forKey: kStreakKey)
        if let lastVisit = UserDefaults.standard.object(forKey: kLastVisitKey) as? Date {
            self.isStreakActiveToday = Calendar.current.isDateInToday(lastVisit)
        }
    }
}
