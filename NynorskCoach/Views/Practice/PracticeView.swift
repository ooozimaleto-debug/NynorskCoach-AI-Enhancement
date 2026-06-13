import SwiftUI
import SwiftData

struct PracticeView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \LearningItem.nextReviewDate, order: .forward) var allItems: [LearningItem]
    @ObservedObject var lm = LocalizationManager.shared
    
    var dueItems: [LearningItem] {
        let now = Date()
        return allItems.filter { item in item.nextReviewDate <= now && item.status != .new }
    }
    
    // Состояния для экранов
    @State private var showQuiz = false
    @State private var showExam = false
    @State private var showVision = false
    @State private var visionMode: VisionMode = .ocr
    
    @State private var selectedScenario: PracticeScenario?
    
    // Для кастомного сценария
    @State private var showCustomChatAlert = false
    @State private var customChatRole = ""
    @State private var customChatContext = ""
    
    @State private var activeAlertTitle = ""
    @State private var activeAlertMessage = ""
    @State private var showFeatureAlert = false
    
    // Сценарии
    var scenarios: [PracticeScenario] {
        [
            PracticeScenario(
                id: "cafe",
                title: "В кафе".localized,
                icon: "cup.and.saucer.fill",
                color: .brown,
                role: "Servitør (Официант)",
                initialMessage: "Hei! Velkomen til oss. Kva vil du ha å drikke?"
            ),
            PracticeScenario(
                id: "nav",
                title: "NAV".localized,
                icon: "building.columns.fill",
                color: .red,
                role: "Saksbehandlar (Сотрудник)",
                initialMessage: "God dag. Du har time hos NAV. Kva gjeld det?"
            ),
            PracticeScenario(
                id: "hospital",
                title: "У врача".localized,
                icon: "cross.case.fill",
                color: .green,
                role: "Lege (Врач)",
                initialMessage: "Kom inn. Kva plagar deg i dag?"
            ),
            PracticeScenario(
                id: "store",
                title: "Магазин".localized,
                icon: "basket.fill",
                color: .orange,
                role: "Butikkmedarbeidar (Кассир)",
                initialMessage: "Hei hei! Var det alt? Treng du pose?"
            ),
            PracticeScenario(
                id: "hms",
                title: "Стройка".localized,
                icon: "hammer.fill",
                color: .gray,
                role: "Byggeleder (Прораб)",
                initialMessage: "Hei! Har du på deg hjelm? Vi må snakke om tryggleik."
            ),
            PracticeScenario(
                id: "office",
                title: "Офис".localized,
                icon: "keyboard",
                color: .purple,
                role: "Kollega (Коллега)",
                initialMessage: "Morn! Har du sett kaffikanna? Eg treng koffein..."
            ),
            PracticeScenario(
                id: "free",
                title: "Болтовня".localized,
                icon: "bubble.left.and.bubble.right.fill",
                color: .blue,
                role: "Venn (Друг)",
                initialMessage: "Heisann! Lenge sidan sist. Kva skjer?"
            )
        ]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Блок "Пора повторить"
                        if !dueItems.isEmpty {
                            SRSStatusCard(count: dueItems.count, status: "Пора повторить".localized)
                        }
                        
                        // СЕКЦИЯ 1: ИСПЫТАНИЯ
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Испытания".localized).font(.title2).bold().padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                // 1. ИИ-Зрение (Унифицированное)
                                PracticeCard(
                                    title: "ИИ-Зрение".localized,
                                    subtitle: "Сканер + Глаз Одина".localized,
                                    icon: "eye.fill",
                                    color: .indigo
                                ) {
                                    visionMode = .ocr
                                    showVision = true
                                }
                                
                                // 2. Quiz
                                PracticeCard(title: "Quiz", subtitle: "Игра".localized, icon: "gamecontroller.fill", color: .orange) {
                                    showQuiz = true
                                }
                                
                                // 3. Экзамен
                                PracticeCard(title: "Экзамен".localized, subtitle: "Тест".localized, icon: "studentdesk", color: .purple) {
                                    showExam = true
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // СЕКЦИЯ 2: СИМУЛЯЦИИ
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Симуляции".localized).font(.title2).bold()
                                Spacer()
                                // Кнопка добавления своего сценария
                                Button {
                                    customChatRole = ""
                                    customChatContext = ""
                                    showCustomChatAlert = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                ForEach(scenarios) { sc in
                                    ChatCard(title: sc.title, icon: sc.icon, color: sc.color) { selectedScenario = sc }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer().frame(height: 50)
                    }
                    .padding(.top, 10)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            
            // --- НАВИГАЦИЯ ---
            .fullScreenCover(isPresented: $showQuiz) { QuizView() }
            .fullScreenCover(isPresented: $showExam) { ExamView() }
            .fullScreenCover(isPresented: $showVision) {
                UnifiedVisionView(initialMode: visionMode)
            }
            .sheet(item: $selectedScenario) { sc in ChatView(scenario: sc) }
            
            // АЛЕРТ ДЛЯ СВОЕГО СЦЕНАРИЯ
            .alert("Свой сценарий".localized, isPresented: $showCustomChatAlert) {
                TextField("Роль (напр. Повар)".localized, text: $customChatRole)
                TextField("Первая фраза (напр. Kva vil du ete?)".localized, text: $customChatContext)
                Button("Отмена".localized, role: .cancel) { }
                Button("Начать".localized) {
                    if !customChatRole.isEmpty {
                        let startMsg = customChatContext.isEmpty ? "Hei! Kva kan eg hjelpe deg med?" : customChatContext
                        selectedScenario = PracticeScenario(
                            id: "custom",
                            title: customChatRole,
                            icon: "person.fill.questionmark",
                            color: .indigo,
                            role: customChatRole,
                            initialMessage: startMsg
                        )
                    }
                }
            }
            .alert(activeAlertTitle, isPresented: $showFeatureAlert) { Button("OK", role: .cancel) { } } message: { Text(activeAlertMessage) }
        }
    }
    
    func triggerFeatureAlert(title: String, msg: String) {
        activeAlertTitle = title; activeAlertMessage = msg; showFeatureAlert = true
    }
}

// UI КОМПОНЕНТЫ

struct ChatCard: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct PracticeScenario: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let role: String          // Кем является AI (Врач, Официант)
    let initialMessage: String // Первая фраза
}

struct SRSStatusCard: View {
    let count: Int; let status: String
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(status).bold().foregroundStyle(.white)
                Text("\(count) \("слов".localized)").font(.caption).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            Image(systemName: "clock.arrow.circlepath").font(.title2).foregroundStyle(.white)
        }
        .padding()
        .background(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(20)
        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct PracticeCard: View {
    let title: String; let subtitle: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle().fill(color.opacity(0.1)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.title3).foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

