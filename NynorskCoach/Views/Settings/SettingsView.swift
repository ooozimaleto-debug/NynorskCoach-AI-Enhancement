import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @ObservedObject var lm = LocalizationManager.shared
    
    // ОСНОВНЫЕ НАСТРОЙКИ
    @AppStorage("userName") private var userName = "Viking"
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes = 15
    
    // СИНХРОНИЗИРОВАНО С PROFILE VIEW
    @AppStorage("userLevel") private var userLevel = "A1"
    @AppStorage("nativeLanguage") private var nativeLanguage = "Russian"
    
    // СИСТЕМНЫЕ
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("reminderTime") private var reminderTime = 19.0
    @AppStorage("isSoundEnabled") private var isSoundEnabled = true
    // voiceGender удалено, так как привязано к наставнику
    @AppStorage("speechVelocity") private var speechSpeed = 1.0
    @AppStorage("appFontSize") private var appFontSize = "Medium"
    
    @AppStorage("isOfflineMode") private var isOfflineMode = false
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true
    @AppStorage("userSubscription") private var userSubscription = "Free"
    
    // ДЕМО ДАННЫЕ
    @AppStorage("coins") private var coins = 0
    @AppStorage("streak") private var streak = 0
    
    // АЛЕРТЫ
    @State private var showResetAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showEditNameAlert = false
    @State private var tempName = ""
    @State private var ragnarokInput = ""
    @State private var cacheSize = "12 MB"
    
    let languages = ["Russian", "English", "Ukrainian", "Polish", "Bokmål"]
    let goals = [5, 10, 15, 30, 60]
    let fontSizes = ["Small", "Medium", "Large"]
    
    var body: some View {
        NavigationStack {
            List {
                // --- ГРУППА 1: АККАУНТ И ОБУЧЕНИЕ ---
                Section {
                    HStack(spacing: 15) {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.1)).frame(width: 60, height: 60)
                            Image(systemName: "person.fill").font(.title).foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName).font(.headline)
                            Text(userSubscription == "Pro" ? "Ярл (Pro)".localized : "Новичок (Free)".localized)
                                .font(.caption)
                                .foregroundStyle(userSubscription == "Pro" ? Color.purple : Color.secondary)
                        }
                        Spacer()
                        Button("Изм.".localized) {
                            tempName = userName
                            showEditNameAlert = true
                        }
                        .font(.subheadline).buttonStyle(.bordered).controlSize(.small)
                    }
                    .padding(.vertical, 8)
                    
                    // ЯЗЫК (Дублируем здесь, так как пользователи ищут его в настройках)
                    Picker(selection: $nativeLanguage) {
                        ForEach(languages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    } label: {
                        Label("Родной язык".localized, systemImage: "globe")
                    }
                    .onChange(of: nativeLanguage) { _, newVal in
                        lm.currentLanguage = newVal // Обновляем локализацию приложения
                    }
                    
                    // УРОВЕНЬ
                    Picker(selection: $userLevel) {
                        Text("A1 (Новичок)").tag("A1")
                        Text("A2 (Базовый)").tag("A2")
                        Text("B1 (Средний)").tag("B1")
                        Text("B2 (Продвинутый)").tag("B2")
                        Text("C1 (Ярл)").tag("C1")
                    } label: {
                        Label("Сложность".localized, systemImage: "chart.bar.doc.horizontal")
                    }
                    
                    Picker(selection: $dailyGoalMinutes) {
                        ForEach(goals, id: \.self) { min in
                            Text("\(min) \("мин/день".localized)").tag(min)
                        }
                    } label: {
                        Label("Цель дня".localized, systemImage: "target")
                    }
                    
                    // МЕНТОР УБРАН ОТСЮДА -> ОН ТЕПЕРЬ КРАСИВЫЙ В ПРОФИЛЕ
                    
                } header: {
                    Text("Профиль".localized)
                }
                
                // --- ГРУППА 2: АТМОСФЕРА ---
                Section {
                    Toggle(isOn: $dailyReminderEnabled) {
                        Label("Напоминания".localized, systemImage: "bell.fill")
                    }
                    .onChange(of: dailyReminderEnabled) { _, val in handleNotificationToggle(val) }
                    
                    if dailyReminderEnabled {
                        HStack {
                            Label("Время".localized, systemImage: "clock")
                            Spacer()
                            Text("\(Int(reminderTime)):00").bold().foregroundStyle(.blue)
                        }
                        Slider(value: $reminderTime, in: 6...23, step: 1) { _ in NotificationManager.shared.scheduleReminder() }
                    }
                    
                    Toggle(isOn: $isSoundEnabled) {
                        Label("Эффекты (SFX)".localized, systemImage: "speaker.wave.2.fill")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Скорость речи".localized, systemImage: "hare.fill")
                        HStack {
                            Text("0.5x").font(.caption).foregroundStyle(.secondary)
                            Slider(value: $speechSpeed, in: 0.5...1.5, step: 0.1)
                            Text("1.5x").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Голос озвучки зависит от выбранного Наставника.".localized)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    
                    Picker("Размер шрифта".localized, selection: $appFontSize) {
                        ForEach(fontSizes, id: \.self) { size in Text(size).tag(size) }
                    }
                } header: {
                    Text("Настройки приложения".localized)
                }
                
                // --- ГРУППА 3: ДАННЫЕ ---
                Section {
                    HStack {
                        Label("Статус подписки".localized, systemImage: "crown.fill")
                        Spacer()
                        Text(userSubscription)
                            .foregroundStyle(userSubscription == "Free" ? Color.secondary : Color.purple).bold()
                    }
                    
                    Toggle(isOn: $isOfflineMode) {
                        Label("Офлайн режим".localized, systemImage: "wifi.slash")
                    }
                    
                    HStack {
                        Label("Кэш уроков".localized, systemImage: "internaldrive")
                        Spacer()
                        Text(cacheSize).foregroundStyle(.secondary)
                    }
                    
                    Button("Очистить кэш".localized) {
                        cacheSize = "0 MB"
                        AudioManager.shared.play(.click)
                    }
                    .foregroundStyle(.red).font(.subheadline)
                    
                    Toggle(isOn: $analyticsEnabled) {
                        Label("Отправлять аналитику".localized, systemImage: "chart.bar")
                    }
                } header: {
                    Text("Данные и Хранилище".localized)
                }
                
                // --- ГРУППА 4: ПОДДЕРЖКА ---
                Section {
                    Button(action: openMail) {
                        Label("Сообщить о баге".localized, systemImage: "ladybug.fill")
                    }
                    Link(destination: URL(string: "https://google.com")!) {
                        Label("Условия и Политика".localized, systemImage: "doc.text")
                    }
                    
                    Button("Сброс прогресса (RAGNAROK)".localized, role: .destructive) {
                        ragnarokInput = ""
                        showResetAlert = true
                    }
                    
                    Button("Удалить аккаунт".localized, role: .destructive) {
                        ragnarokInput = ""
                        showDeleteAccountAlert = true
                    }
                    
                    // ДЕМО КНОПКА
                    Button {
                        populateDemoData()
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("DEMO MODE")
                        }
                        .foregroundStyle(.green).bold()
                    }
                } header: {
                    Text("Опасная зона".localized)
                } footer: {
                    Text("Версия 1.0.2 (Build 45)").frame(maxWidth: .infinity, alignment: .center).padding(.top)
                }
            }
            .navigationTitle("Настройки".localized)
            .navigationBarTitleDisplayMode(.inline)
            
            // --- АЛЕРТЫ ---
            .alert("Твое имя".localized, isPresented: $showEditNameAlert) {
                TextField("Имя".localized, text: $tempName)
                Button("OK") { if !tempName.isEmpty { userName = tempName } }
                Button("Отмена".localized, role: .cancel) { }
            }
            
            .alert("Рагнарёк (Сброс)".localized, isPresented: $showResetAlert) {
                TextField("Напиши Ragnarok", text: $ragnarokInput).textInputAutocapitalization(.never)
                Button("Отмена".localized, role: .cancel) { }
                Button("Сжечь всё".localized, role: .destructive) {
                    if ragnarokInput.lowercased() == "ragnarok" { performRagnarok() }
                }
            } message: {
                Text("Это удалит весь прогресс безвозвратно.".localized)
            }
            
            .alert("Удаление аккаунта".localized, isPresented: $showDeleteAccountAlert) {
                TextField("Напиши Ragnarok", text: $ragnarokInput).textInputAutocapitalization(.never)
                Button("Отмена".localized, role: .cancel) { }
                Button("Удалить".localized, role: .destructive) {
                    if ragnarokInput.lowercased() == "ragnarok" { performRagnarok() }
                }
            }
        }
    }
    
    // --- ФУНКЦИИ ---
    func populateDemoData() {
        coins = 1250
        streak = 5
        userSubscription = "Pro"
        // Генерация активности
        let calendar = Calendar.current
        let today = Date()
        let minutes = [45, 20, 60, 15, 30, 50, 10]
        for (index, mins) in minutes.enumerated() {
            if let date = calendar.date(byAdding: .day, value: -index, to: today) {
                let activity = DailyActivity(date: date, xpEarned: mins, wordsLearned: Int.random(in: 3...10))
                context.insert(activity)
            }
        }
        HapticManager.shared.notification(type: .success)
        AudioManager.shared.play(.success)
    }

    func handleNotificationToggle(_ enabled: Bool) {
        if enabled { NotificationManager.shared.requestAuthorization(); NotificationManager.shared.scheduleReminder() }
        else { NotificationManager.shared.cancelNotifications() }
    }
    func openMail() {
        if let url = URL(string: "mailto:support@nynorskcoach.com?subject=Bug%20Report"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    func performRagnarok() {
        try? context.delete(model: LearningItem.self)
        try? context.delete(model: Topic.self)
        try? context.delete(model: SavedPodcast.self)
        try? context.delete(model: DailyActivity.self)
        try? context.delete(model: ChatSession.self)
        try? context.delete(model: Article.self)
        if let bundleID = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: bundleID) }
        AudioManager.shared.play(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
    }
}
