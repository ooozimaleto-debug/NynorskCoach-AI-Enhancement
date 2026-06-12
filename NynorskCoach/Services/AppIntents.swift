import AppIntents
import SwiftUI

// 1. Команда "Practice Nynorsk"
struct StartPracticeIntent: AppIntent {
    static var title: LocalizedStringResource = "Practice Nynorsk"
    static var description = IntentDescription("Opens the practice section in Nynorsk Coach.")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "nynorskcoach://practice") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// 2. Команда "Word of the Day"
struct DailyWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Nynorsk Word of the Day"
    static var description = IntentDescription("Shows the word of the day.")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Просто открываем приложение, оно само покажет слово на главной
        // В будущем можно добавить обработку Deep Link: nynorskcoach://word
        return .result()
    }
}

// 3. Провайдер шорткатов
struct NynorskShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPracticeIntent(),
            phrases: [
                "Practice in \(.applicationName)",      // Было: "Practice \(.applicationName)" (ОК)
                "Start \(.applicationName) practice",   // ОК
                "Learn Nynorsk with \(.applicationName)", // ИСПРАВЛЕНО (добавлено имя)
                "Start training in \(.applicationName)"   // ИСПРАВЛЕНО
            ],
            shortTitle: "Practice Nynorsk",
            systemImageName: "dumbbell.fill"
        )
        
        AppShortcut(
            intent: DailyWordIntent(),
            phrases: [
                "Word of the day in \(.applicationName)", // ОК
                "Show word in \(.applicationName)",       // ИСПРАВЛЕНО
                "Open \(.applicationName) daily word"     // ИСПРАВЛЕНО
            ],
            shortTitle: "Word of Day",
            systemImageName: "calendar"
        )
    }
}
