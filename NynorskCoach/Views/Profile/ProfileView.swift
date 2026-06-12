import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) var context
    @ObservedObject var lm = LocalizationManager.shared
    
    // Менеджеры
    @ObservedObject var storeManager = StoreManager.shared
    @ObservedObject var bonusManager = DailyBonusManager.shared
    var streakManager = StreakManager.shared
    
    @AppStorage("userName") private var userName = "Viking"
    @AppStorage("userRank") private var userRank: VikingRank = .oppdagar
    
    // НАСТРОЙКИ "МОЗГА"
    @AppStorage("selectedMentor") private var selectedMentorRaw = Mentor.freya.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguage = "Russian"
    @AppStorage("userLevel") private var userLevel = "A1"
    
    // ИНВЕНТАРЬ
    @AppStorage("activeHelmet") private var activeHelmet = "default"
    @AppStorage("activeCardSkin") private var activeCardSkin = "default"
    @AppStorage("purchasedItems") private var purchasedItemsRaw = "default"
    @AppStorage("userAvatarData") private var userAvatarData: Data = Data()
    
    // СТАТИСТИКА
    @Query(sort: \DailyActivity.date, order: .forward) var activities: [DailyActivity]
    @Query var learningItems: [LearningItem]
    
    @State private var animateCharts = false
    @State private var showStore = false
    
    let languages = ["Russian", "English", "Ukrainian", "Polish", "Bokmål"]
    
    var hasIceShield: Bool { storeManager.isPurchased("freeze_1") }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // DAILY BONUS CARD (NEW)
                        if bonusManager.canClaimBonus {
                            DailyBonusCard(bonusManager: bonusManager)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // 1. КАРТОЧКА ГЕРОЯ (Аватар + Статы)
                        CompactHeroCard(
                            rank: userRank,
                            activeHelmetId: activeHelmet,
                            avatarData: userAvatarData,
                            streak: streakManager.currentStreak,
                            totalXP: calculateTotalXP(),
                            purchasedIds: purchasedItemsRaw,
                            activeHelmetBinding: $activeHelmet,
                            activeSkinBinding: $activeCardSkin,
                            hasIceShield: hasIceShield
                        )
                        
                        // 2. ПАНЕЛЬ УПРАВЛЕНИЯ (Язык + Уровень)
                        HStack(spacing: 12) {
                            // Кнопка Языка
                            Menu {
                                ForEach(languages, id: \.self) { lang in
                                    Button {
                                        nativeLanguage = lang
                                        lm.currentLanguage = lang
                                    } label: {
                                        HStack {
                                            Text(lang)
                                            if nativeLanguage == lang { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                SettingsPill(icon: "globe", title: "Родной язык", value: nativeLanguage, color: .blue)
                            }
                            
                            // Кнопка Уровня
                            Menu {
                                ForEach(["A1", "A2", "B1", "B2", "C1"], id: \.self) { level in
                                    Button { userLevel = level } label: {
                                        HStack {
                                            Text(level)
                                            if userLevel == level { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                SettingsPill(icon: "chart.bar.fill", title: "Сложность", value: userLevel, color: .orange)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 3. ВЫБОР МЕНТОРА (HERO CAROUSEL)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Твой Наставник".localized)
                                .font(.title3).bold()
                                .padding(.horizontal)
                            
                            // Полноэкранная карусель (TabView)
                            TabView(selection: $selectedMentorRaw) {
                                ForEach(Mentor.allCases) { mentor in
                                    MentorHeroCard(
                                        mentor: mentor,
                                        isSelected: selectedMentorRaw == mentor.rawValue
                                    )
                                    .tag(mentor.rawValue)
                                    .padding(.horizontal)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .indexViewStyle(.page(backgroundDisplayMode: .always))
                            .frame(height: 240)
                            .onChange(of: selectedMentorRaw) { _, _ in
                                AudioManager.shared.play(.click)
                                HapticManager.shared.impact(style: .medium)
                            }
                        }
                        
                        // 4. СТАТИСТИКА
                        VStack(spacing: 20) {
                            // Активность
                            VStack(alignment: .leading) {
                                NavigationLink(destination: ActivityDetailView()) { // Убедись, что ActivityDetailView существует
                                    HStack {
                                        Text("Боевая активность".localized).font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).bold().foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal)
                                    .foregroundStyle(.primary)
                                }
                                FixedActivityChart(activities: activities, animate: animateCharts)
                            }
                            
                            // Мудрость
                            VStack(alignment: .leading) {
                                NavigationLink(destination: WisdomDetailView()) { // Убедись, что WisdomDetailView существует
                                    HStack {
                                        Text("Твоя мудрость".localized).font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).bold().foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal)
                                    .foregroundStyle(.primary)
                                }
                                VocabularyChart(items: learningItems, animate: animateCharts)
                            }
                        }
                        
                        Spacer().frame(height: 50)
                    }
                    .padding(.top, 10)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStore = true } label: {
                        Image(systemName: "cart").foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(userName).font(.headline).bold()
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: SettingsView()) { // Убедись, что SettingsView существует
                        Image(systemName: "gearshape").foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showStore) { StoreView() }
            .onAppear {
                streakManager.checkStreak()
                bonusManager.checkBonusAvailability()
                withAnimation(.spring(duration: 1.5, bounce: 0.3)) { animateCharts = true }
            }
        }
    }
    
    func calculateTotalXP() -> Int { activities.reduce(0) { $0 + $1.xpEarned } }
}

// MARK: - КОМПОНЕНТЫ UI

// 1. Кнопка настройки (Pill)
struct SettingsPill: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.caption).bold().foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized).font(.caption2).foregroundStyle(.secondary)
                Text(value.localized).font(.subheadline).bold().foregroundStyle(.primary)
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// 2. ИСПРАВЛЕННАЯ ГЕРОЙСКАЯ КАРТОЧКА МЕНТОРА
struct MentorHeroCard: View {
    let mentor: Mentor
    let isSelected: Bool
    
    private var theme: (gradient: LinearGradient, mainColor: Color, icon: String, quote: String) {
        switch mentor {
        case .freya:
            return (LinearGradient(colors: [Color.green.opacity(0.8), Color.teal.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), .green, "leaf.fill", "«Учиться нужно с любовью. Я помогу тебе мягко и терпеливо.»")
        case .loki:
            return (LinearGradient(colors: [Color.purple.opacity(0.8), Color.orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), .purple, "flame.fill", "«Скучно не будет. Немного хаоса полезно для памяти!»")
        case .odin:
            return (LinearGradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), .blue, "eye.fill", "«Дисциплина — путь к силе. Не жди пощады.»")
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.gradient
            
            // Декор
            GeometryReader { geo in
                Circle().fill(.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: geo.size.width - 80, y: -50)
                Circle().fill(.white.opacity(0.05))
                    .frame(width: 150, height: 150)
                    .offset(x: -50, y: geo.size.height - 80)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                // Иконка и статус
                HStack {
                    Image(systemName: theme.icon)
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .shadow(radius: 5)
                    
                    Spacer()
                    
                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Выбран".localized)
                        }
                        .font(.caption2).bold()
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white).clipShape(Capsule())
                        .foregroundStyle(theme.mainColor)
                        .shadow(radius: 5)
                    }
                }
                
                Spacer()
                
                // Текст (поднят выше, чтобы не перекрываться точками)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mentor.displayName)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    
                    Text(mentor.description)
                        .font(.subheadline).bold()
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(2)
                    
                    Text(theme.quote)
                        .font(.caption).italic()
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 2)
                        .lineLimit(2)
                }
                .padding(.bottom, 35) // Запас места для индикатора страниц
            }
            .padding(24)
        }
        .frame(height: 220)
        .mask(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: theme.mainColor.opacity(0.3), radius: 15, x: 0, y: 10)
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.spring(response: 0.4), value: isSelected)
    }
}

// 3. COMPACT HERO CARD (С исправленным шлемом)
struct CompactHeroCard: View {
    let rank: VikingRank
    let activeHelmetId: String
    let avatarData: Data
    let streak: Int
    let totalXP: Int
    let purchasedIds: String
    @Binding var activeHelmetBinding: String
    @Binding var activeSkinBinding: String
    let hasIceShield: Bool
    
    @State private var isFlamePulsing = false
    @State private var isBoltRotating = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 0) {
                // Streak
                ZStack {
                    if hasIceShield {
                        Image(systemName: "shield.fill").resizable().aspectRatio(contentMode: .fit).frame(height: 110).foregroundStyle(LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(Image(systemName: "shield").resizable().aspectRatio(contentMode: .fit).frame(height: 110).foregroundStyle(.cyan.opacity(0.5)).padding(1))
                            .shadow(color: .cyan.opacity(0.3), radius: 10)
                    }
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.title).foregroundStyle(.orange)
                            .scaleEffect(isFlamePulsing ? (hasIceShield ? 1.05 : 1.15) : 1.0)
                            .shadow(color: hasIceShield ? .cyan.opacity(0.5) : .orange.opacity(0.5), radius: hasIceShield ? 10 : 5)
                        Text("\(streak)").font(.title2).bold().fontDesign(.rounded).foregroundStyle(.primary)
                        Text("Стрик".localized.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    }.offset(y: hasIceShield ? -2 : 0)
                }.frame(maxWidth: .infinity).frame(height: 120)
                
                // Avatar
                ZStack {
                    Circle().fill(Color(uiColor: .tertiarySystemGroupedBackground)).frame(width: 110, height: 110)
                        .shadow(color: .black.opacity(0.1), radius: 8)
                    if let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill").resizable().padding(25).foregroundStyle(.gray.opacity(0.5)).frame(width: 100, height: 100)
                    }
                    
                    // ИСПРАВЛЕНИЕ: Отображение шлема
                    if let item = StoreManager.shared.items.first(where: { $0.id == activeHelmetId }), item.type == .equipment {
                        // Используем Image(item.iconName) для ассетов, а не systemName
                        Image(item.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .offset(x: 32, y: -32)
                            .shadow(radius: 3)
                    }
                    
                    VStack { Spacer(); Text(rank.rawValue).font(.system(size: 10, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Color.blue.gradient)).offset(y: 12) }.frame(width: 110, height: 110)
                }.zIndex(1)
                
                // XP
                VStack(spacing: 6) {
                    Image(systemName: "bolt.fill").font(.title2).foregroundStyle(.yellow).rotationEffect(.degrees(isBoltRotating ? 10 : -10))
                    Text("\(totalXP)").font(.title2).bold().fontDesign(.rounded).foregroundStyle(.primary)
                    Text("XP").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).frame(height: 120)
            }
            .padding(.top, 15)
            
            Divider().padding(.horizontal, 40)
            
            InventoryCarousel(purchasedIds: purchasedIds, activeHelmet: $activeHelmetBinding, activeSkin: $activeSkinBinding)
                .padding(.bottom, 10)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(24).padding(.horizontal).shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { isFlamePulsing = true }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { isBoltRotating = true }
        }
    }
}

// MARK: - INVENTORY CAROUSEL
struct InventoryCarousel: View {
    let purchasedIds: String
    @Binding var activeHelmet: String
    @Binding var activeSkin: String
    
    var purchasedItems: [StoreItem] {
        let ids = purchasedIds.components(separatedBy: ",")
        return StoreManager.shared.items.filter { ids.contains($0.id) }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(purchasedItems) { item in
                    InventoryItemCard(
                        icon: item.iconName,
                        isEquipped: isEquipped(item),
                        isTheme: item.type == .theme
                    )
                    .onTapGesture { equipItem(item) }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
    
    func isEquipped(_ item: StoreItem) -> Bool {
        if item.type == .equipment { return activeHelmet == item.id }
        if item.type == .theme { return activeSkin == item.id }
        return false
    }
    
    func equipItem(_ item: StoreItem) {
        if item.type == .equipment { activeHelmet = (activeHelmet == item.id) ? "default" : item.id }
        else if item.type == .theme { activeSkin = (activeSkin == item.id) ? "default" : item.id }
        AudioManager.shared.play(.click)
        HapticManager.shared.impact(style: .light)
    }
}

// 4. ИСПРАВЛЕННАЯ КАРТОЧКА ИНВЕНТАРЯ (Иконки из Assets)
struct InventoryItemCard: View {
    let icon: String
    let isEquipped: Bool
    let isTheme: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isEquipped ? (isTheme ? Color.purple.opacity(0.1) : Color.blue.opacity(0.1)) : Color(uiColor: .tertiarySystemGroupedBackground))
                .frame(width: 65, height: 65)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEquipped ? (isTheme ? Color.purple : Color.blue) : Color.clear, lineWidth: 2)
                )
            
            // ИСПОЛЬЗУЕМ Image(icon) ДЛЯ АССЕТОВ
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
                .shadow(color: .black.opacity(0.1), radius: 2)
            
            if isEquipped {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(isTheme ? .purple : .blue)
                    .background(Circle().fill(.white))
                    .offset(x: 24, y: -24)
            }
        }
    }
}

// MARK: - CHARTS (Без изменений)
struct FixedActivityChart: View {
    let activities: [DailyActivity]; let animate: Bool
    var weekData: [(day: String, xp: Int)] {
        let calendar = Calendar.current; let today = Date(); var result: [(String, Int)] = []; let formatter = DateFormatter(); formatter.locale = Locale(identifier: LocalizationManager.shared.localeIdentifier); formatter.dateFormat = "EE"
        for i in (0..<7).reversed() { if let date = calendar.date(byAdding: .day, value: -i, to: today) { let dayLabel = formatter.string(from: date); let xp = activities.first { calendar.isDate($0.date, inSameDayAs: date) }?.xpEarned ?? 0; result.append((dayLabel, xp)) } }
        return result
    }
    var body: some View {
        Chart { ForEach(weekData, id: \.day) { item in BarMark(x: .value("Day", item.day), y: .value("XP", animate ? item.xp : 0)).foregroundStyle(item.xp > 0 ? LinearGradient(colors: [.blue, .purple], startPoint: .bottom, endPoint: .top) : LinearGradient(colors: [.gray.opacity(0.1), .gray.opacity(0.1)], startPoint: .bottom, endPoint: .top)).cornerRadius(6) } }.chartYAxis { AxisMarks(position: .leading) }.frame(height: 200).padding().background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(24).padding(.horizontal).shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct VocabularyChart: View {
    let items: [LearningItem]; let animate: Bool
    var newCount: Int { items.filter { $0.status == .new }.count }
    var learningCount: Int { items.filter { $0.status == .learning }.count }
    var masteredCount: Int { items.filter { $0.status == .mastered }.count }
    var body: some View {
        HStack(spacing: 20) {
            ZStack { if #available(iOS 17.0, *) { Chart { SectorMark(angle: .value("New", animate ? newCount : 0), innerRadius: .ratio(0.6)).foregroundStyle(Color.gray.opacity(0.3)).cornerRadius(5); SectorMark(angle: .value("Learning", animate ? learningCount : 0), innerRadius: .ratio(0.6)).foregroundStyle(Color.blue).cornerRadius(5); SectorMark(angle: .value("Mastered", animate ? masteredCount : 0), innerRadius: .ratio(0.6)).foregroundStyle(Color.green).cornerRadius(5) }.frame(width: 140, height: 140) }
                VStack { Text("\(items.count)").font(.title).bold(); Text("Слов".localized).font(.caption).foregroundStyle(.secondary) }
            }
            VStack(alignment: .leading, spacing: 12) { LegendRow(color: .green, title: "Выучено".localized, value: masteredCount); LegendRow(color: .blue, title: "В процессе".localized, value: learningCount); LegendRow(color: .gray.opacity(0.5), title: "Новые".localized, value: newCount) }
            Spacer()
        }.padding().background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(24).padding(.horizontal).shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - DAILY BONUS CARD  
struct DailyBonusCard: View {
    @ObservedObject var bonusManager: DailyBonusManager
    @State private var claimed = false
    
    var body: some View {
        Button {
            let amount = bonusManager.claimBonus()
            if amount > 0 {
                withAnimation(.spring()) {
                    claimed = true
                }
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 54, height: 54)
                    Image(systemName: "gift.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ежедневный бонус")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("+\(bonusManager.getBonusAmount()) монет")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !claimed {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8)
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .disabled(claimed)
    }
}

struct LegendRow: View { let color: Color; let title: String; let value: Int; var body: some View { HStack { Circle().fill(color).frame(width: 8, height: 8); Text(title).font(.subheadline).foregroundStyle(.secondary); Spacer(); Text("\(value)").font(.subheadline).bold() } } }
