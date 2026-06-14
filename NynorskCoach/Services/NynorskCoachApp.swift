import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct NynorskCoachApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var activeDeepLink: DeepLinkData?
    @State private var selectedTab: Int = 0
    @State private var showSplash = true
    
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var contextManager = UserContextManager.shared
    
    // Setting up the SwiftData database
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LearningItem.self, Topic.self, Article.self, ChatSession.self,
            PersistedMessage.self, SavedPodcast.self, DailyActivity.self, GrammarNote.self,
            UserLearningProfile.self
        ])
        
        let modelConfiguration: ModelConfiguration
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.abzac.NynorskCoach") {
            let dbURL = containerURL.appendingPathComponent("NynorskCoach.store")
            modelConfiguration = ModelConfiguration(url: dbURL)
        } else {
            modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
        }

        do { return try ModelContainer(for: schema, configurations: [modelConfiguration]) }
        catch { fatalError("Could not create ModelContainer: \(error)") }
    }()
    init() {
        Secrets.initializeKeys()
    }
    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if hasCompletedOnboarding {
                        // Main menu with correct tabs
                        MainTabView(selectedTab: $selectedTab)
                            .onAppear { NotificationManager.shared.requestAuthorization() }
                    } else {
                        OnboardingView(isOnboardingCompleted: $hasCompletedOnboarding)
                    }
                }
                .opacity(showSplash ? 0 : 1)
                
                if showSplash {
                    SplashScreenView().transition(.opacity).zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
                }
                // Initialize UserContextManager with modelContext
                contextManager.setupWithModelContext(sharedModelContainer.mainContext)
            }
            .onOpenURL { url in handleDeepLink(url) }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    let word = id.replacingOccurrences(of: "nynorsk_word_", with: "")
                    self.activeDeepLink = DeepLinkData(word: word)
                }
            }
            .sheet(item: $activeDeepLink) { data in
                DeepLinkResolverView(word: data.word)
            }
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(contextManager)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { NotificationManager.shared.cancelNotifications() }
            if newPhase == .background { NotificationManager.shared.scheduleReminder() }
        }
    }
    
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "nynorskcoach" else { return }
        switch url.host {
        case "word":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            if let text = components?.queryItems?.first(where: { $0.name == "text" })?.value {
                self.activeDeepLink = DeepLinkData(word: text)
            }
        case "practice": selectedTab = 1
        case "library": selectedTab = 2
        default: break
        }
    }
}

// MARK: - Helper Structures

struct DeepLinkData: Identifiable { let id = UUID(); let word: String }

struct DeepLinkResolverView: View {
    let word: String
    @Environment(\.modelContext) var context
    @Query(filter: #Predicate<Topic> { $0.isSystem == true }) var systemTopics: [Topic]
    
    var body: some View {
        // Changed name here to avoid conflict
        DeepLinkWordSheet(word: word, context: context, systemTopic: getSystemTopic())
            .presentationDetents([.medium])
    }
    
    func getSystemTopic() -> Topic {
        if let existing = systemTopics.first { return existing }
        let newTopic = Topic(name: "Mitt Ordbok", emoji: "📖", difficulty: "All", isSystem: true)
        context.insert(newTopic)
        return newTopic
    }
}

// MARK: - Renamed Action Sheet to avoid 'Redeclaration' error
struct DeepLinkWordSheet: View {
    let word: String
    let context: ModelContext
    let systemTopic: Topic
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Новое слово")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(word)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
            
            Button {
                let newItem = LearningItem(text: word, translation: "", topic: systemTopic)
                context.insert(newItem)
                try? context.save()
                dismiss()
            } label: {
                Label("Сохранить в словарь", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            
            Button("Отмена", role: .cancel) {
                dismiss()
            }
        }
        .padding()
        .presentationDetents([.fraction(0.3)])
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Binding var selectedTab: Int
    @ObservedObject var lm = LocalizationManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            TopicListView()
                .tabItem { Label("Учить".localized, systemImage: "book.closed.fill") }
                .tag(0)
            
            PracticeView()
                .tabItem { Label("Практика".localized, systemImage: "dumbbell.fill") }
                .tag(1)
            
            LibraryView()
                .tabItem { Label("Библиотека".localized, systemImage: "books.vertical.fill") }
                .tag(2)
            
            ProfileView()
                .tabItem { Label("Профиль".localized, systemImage: "person.crop.circle.fill") }
                .tag(3)
        }
        .tint(.blue)
    }
}

