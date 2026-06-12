import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    
    var body: some View {
        if hasCompletedOnboarding {
            // ГЛАВНОЕ ПРИЛОЖЕНИЕ
            TabView(selection: $selectedTab) {
                // Вкладка 1: Учеба
                NavigationStack {
                    AddTopicView() // Твой главный экран учебы
                }
                .tabItem {
                    Label("Учить", systemImage: "book.fill")
                }
                .tag(0)
                
                // Вкладка 2: Практика
                PracticeView()
                    .tabItem {
                        Label("Практика", systemImage: "dumbbell.fill")
                    }
                    .tag(1)
                
                // Вкладка 3: Грамматика
                GrammarView()
                    .tabItem {
                        Label("Правила", systemImage: "text.book.closed.fill")
                    }
                    .tag(2)
                
                // Вкладка 4: Профиль
                ProfileView()
                    .tabItem {
                        Label("Герой", systemImage: "person.crop.circle.fill")
                    }
                    .tag(3)
            }
            .tint(.blue) // Цвет активной вкладки
        } else {
            // ОНБОРДИНГ
            OnboardingView(isOnboardingCompleted: $hasCompletedOnboarding)
                .transition(.opacity.animation(.easeInOut(duration: 0.5)))
        }
    }
}
