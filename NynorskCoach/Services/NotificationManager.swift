import UserNotifications
import SwiftUI

class NotificationManager {
    static let shared = NotificationManager()
    
    // Ключ для сохранения времени в UserDefaults
    private let kPreferredTimeKey = "userPreferredStudyTime"
    
    private init() {}
    
    // 1. Запрос прав (вызываем при первом запуске)
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("🔔 Уведомления разрешены")
            } else if let error = error {
                print("🚫 Ошибка прав уведомлений: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Установка предпочтительного времени (вызываем из UI)
    func setPreferredTime(_ date: Date) {
        UserDefaults.standard.set(date, forKey: kPreferredTimeKey)
        print("💾 Время обучения сохранено: \(date.formatted(date: .omitted, time: .shortened))")
        // Сразу перепланируем с новым временем
        scheduleReminder()
    }
    
    func getPreferredTime() -> Date {
        return UserDefaults.standard.object(forKey: kPreferredTimeKey) as? Date ?? Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
    }
    
    // 3. Запланировать напоминание
    func scheduleReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "Hei! Время учить Nynorsk 🇳🇴"
        content.body = "Поддержи свой стрик! 5 минут занятий лучше, чем ничего 🔥"
        content.sound = .default
        
        var trigger: UNNotificationTrigger
        
        if let savedDate = UserDefaults.standard.object(forKey: kPreferredTimeKey) as? Date {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: savedDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            print("⏰ Напоминание установлено на \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
        } else {
            var dateComponents = DateComponents()
            dateComponents.hour = 19
            dateComponents.minute = 00
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            print("⏰ Напоминание установлено по умолчанию на 19:00")
        }
        
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка планирования уведомления: \(error)")
            }
        }
    }
    
    // 4. Отменить напоминание (сбросить бейдж)
    func cancelNotifications() {
        UNUserNotificationCenter.current().setBadgeCount(0)
        print("🔕 Бейджи очищены (пользователь онлайн)")
    }
}
