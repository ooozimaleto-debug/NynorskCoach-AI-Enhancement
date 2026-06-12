import SwiftUI
import SwiftData
import UniformTypeIdentifiers // Нужно для Drag & Drop

struct TopicListView: View {
    @Environment(\.modelContext) var context
    @AppStorage("nativeLanguage") var nativeLanguage = "Russian"
    @AppStorage("coins") private var coins = 0
    @AppStorage("userName") private var userName = "Viking"
    
    // Списки для фильтрации и сортировки
    @AppStorage("hiddenTopicIDs") private var hiddenTopicIDsString = ""
    @AppStorage("topicOrder") private var topicOrderString = "" // <-- Храним порядок здесь
    
    @Query var topics: [Topic] // Убираем sort: в Query, сортируем вручную
    
    @ObservedObject var questManager = QuestManager.shared
    @ObservedObject var lm = LocalizationManager.shared
    
    @State private var showTopicSelection = false
    @State private var showExam = false
    @State private var showQuiz = false
    @State private var showStore = false
    @State private var topicToEdit: Topic?
    
    // Состояние для Drag & Drop
    @State private var draggingTopic: Topic?
    
    // --- УМНАЯ СОРТИРОВКА ---
    var sortedTopics: [Topic] {
        // 1. Получаем список сохраненных ID
        var orderIds = topicOrderString.components(separatedBy: ",").filter { !$0.isEmpty }
        
        // 2. Если появились новые темы, которых нет в списке порядка -> добавляем их в конец
        let allIds = topics.map { $0.id }
        let newIds = allIds.filter { !orderIds.contains($0) }
        
        if !newIds.isEmpty {
            orderIds.append(contentsOf: newIds)
            // Сохраняем обновленный список, чтобы не вычислять каждый раз
            DispatchQueue.main.async {
                topicOrderString = orderIds.joined(separator: ",")
            }
        }
        
        // 3. Сортируем массив тем на основе индексов в orderIds
        return topics.sorted { t1, t2 in
            let idx1 = orderIds.firstIndex(of: t1.id) ?? Int.max
            let idx2 = orderIds.firstIndex(of: t2.id) ?? Int.max
            return idx1 < idx2
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. ХЕДЕР
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hei, \(userName)!")
                                .font(.title2).bold().foregroundStyle(.primary)
                            Text("Готов к походу?".localized)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        Button { showStore = true } label: {
                            HStack(spacing: 6) {
                                Text("\(coins)").font(.headline).foregroundStyle(.primary)
                                AnimatedCoin()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.ultraThinMaterial).clipShape(Capsule())
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal).padding(.top, 10)
                    
                    // 2. КВЕСТЫ
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Цели дня".localized)
                            .font(.title2).bold()
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(questManager.quests) { quest in
                                    QuestCard(quest: quest)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 15)
                        }
                    }
                    
                    // 3. ТЕМЫ (С DRAG & DROP)
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Темы".localized).font(.title2).bold()
                            Spacer()
                            Button { showTopicSelection = true } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3).fontWeight(.regular).foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 15)], spacing: 15) {
                            ForEach(sortedTopics) { topic in
                                // Показываем только если не скрыто
                                if !hiddenTopicIDsString.contains(topic.id) {
                                    NavigationLink(destination: FlashcardSessionView(topic: topic)) {
                                        NewTopicCard(topic: topic)
                                    }
                                    .contextMenu {
                                        Button {
                                            if hiddenTopicIDsString.isEmpty { hiddenTopicIDsString = topic.id }
                                            else { hiddenTopicIDsString += ",\(topic.id)" }
                                        } label: { Label("Скрыть", systemImage: "eye.slash") }
                                    }
                                    // --- DRAG & DROP МОДИФИКАТОРЫ ---
                                    .onDrag {
                                        self.draggingTopic = topic
                                        return NSItemProvider(object: topic.id as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: DropRelocateDelegate(item: topic, listData: sortedTopics, current: $draggingTopic) { from, to in
                                        moveTopic(from: from, to: to)
                                    })
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(isPresented: $showTopicSelection) { TopicSelectionView() }
            .fullScreenCover(isPresented: $showQuiz) { QuizView() }
            .fullScreenCover(isPresented: $showExam) { ExamView() }
            .sheet(isPresented: $showStore) { StoreView() }
        }
        .onAppear { questManager.checkDailyReset() }
    }
    
    // --- ЛОГИКА ПЕРЕМЕЩЕНИЯ ---
    func moveTopic(from source: Topic, to destination: Topic) {
        // 1. Берем текущий порядок ID
        var orderIds = topicOrderString.components(separatedBy: ",").filter { !$0.isEmpty }
        
        // 2. Если список пуст (первый запуск), заполняем текущим порядком
        if orderIds.isEmpty {
            orderIds = topics.map { $0.id }
        }
        
        // 3. Находим индексы
        guard let fromIndex = orderIds.firstIndex(of: source.id),
              let toIndex = orderIds.firstIndex(of: destination.id) else { return }
        
        // 4. Перемещаем
        withAnimation {
            let movedId = orderIds.remove(at: fromIndex)
            orderIds.insert(movedId, at: toIndex)
            // 5. Сохраняем
            topicOrderString = orderIds.joined(separator: ",")
        }
    }
}

// --- ВСПОМОГАТЕЛЬНЫЙ ДЕЛЕГАТ ДЛЯ ПЕРЕТАСКИВАНИЯ ---
struct DropRelocateDelegate: DropDelegate {
    let item: Topic
    let listData: [Topic]
    @Binding var current: Topic?
    let moveAction: (Topic, Topic) -> Void
    
    func dropEntered(info: DropInfo) {
        guard let current = current, current.id != item.id else { return }
        // Живое перемещение (Live Reorder)
        moveAction(current, item)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        self.current = nil
        return true
    }
}

// MARK: - VISUAL COMPONENTS (Без изменений)
// (Оставляем те же NewTopicCard, QuestCard и AnimatedCoin, что были раньше)

struct AnimatedCoin: View {
    @State private var rotation: Double = 0
    var body: some View {
        Image(systemName: "bitcoinsign.circle.fill")
            .font(.title2)
            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: .orange.opacity(0.4), radius: 2, x: 0, y: 1)
            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
            .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { rotation = 360 } }
    }
}

struct QuestCard: View {
    @ObservedObject var lm = LocalizationManager.shared
    let quest: Quest
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(getStatusColor().opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: getIcon(for: quest.type)).font(.system(size: 16, weight: .bold)).foregroundStyle(getStatusColor())
                }
                Spacer()
                if !quest.isCompleted { Text("\(quest.reward)").font(.caption).bold().foregroundStyle(.secondary).padding(.top, 4) }
            }.padding(.bottom, 12)
            Text(quest.titleKey.localized).font(.subheadline).bold().foregroundStyle(.primary).lineLimit(2).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            ZStack(alignment: .bottomLeading) {
                if quest.isCompleted && !quest.isClaimed {
                    Button("Забрать".localized) { QuestManager.shared.claim(quest) }.buttonStyle(.borderedProminent).tint(.green).controlSize(.mini)
                } else if quest.isClaimed {
                    HStack(spacing: 4) { Image(systemName: "checkmark.circle.fill").font(.caption2); Text("Готово".localized).font(.caption) }.foregroundStyle(.green)
                } else {
                    GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color.gray.opacity(0.2)).frame(height: 6); Capsule().fill(Color.blue).frame(width: geo.size.width * CGFloat(quest.progress), height: 6) } }.frame(height: 6).padding(.top, 8)
                }
            }.frame(height: 25)
        }
        .padding(16).frame(width: 160, height: 160).background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(20).shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    func getStatusColor() -> Color { if quest.isClaimed { return .green }; if quest.isCompleted { return .orange }; return .blue }
    func getIcon(for type: QuestType) -> String { switch type { case .wordPractice: return "book.closed.fill"; case .lessonComplete: return "graduationcap.fill"; case .coinCollector: return "magnifyingglass" } }
}

struct NewTopicCard: View {
    @ObservedObject var lm = LocalizationManager.shared
    let topic: Topic
    
    var learnedCount: Int { topic.items.filter { $0.status == .mastered }.count }
    var totalCount: Int { topic.items.count }
    var progress: Double { totalCount == 0 ? 0 : Double(learnedCount) / Double(totalCount) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ВЕРХ: Иконка и Сложность
            HStack(alignment: .top) {
                // УМНАЯ ИКОНКА
                ZStack {
                    Circle()
                        .fill(topic.color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    // Проверяем: это системная картинка (SF Symbol)?
                    if UIImage(systemName: topic.emoji) != nil {
                        Image(systemName: topic.emoji)
                            .font(.title2)
                            .foregroundStyle(topic.color)
                    } else {
                        // Если нет (это эмодзи пользователя) — рисуем текст
                        Text(topic.emoji)
                            .font(.title)
                    }
                }
                
                Spacer()
                
                // Сложность
                Text(topic.difficulty)
                    .font(.caption2).bold()
                    .foregroundStyle(topic.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(topic.color.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // НАЗВАНИЕ
            Text(LocalizationManager.shared.localizeTopicName(topic.name))
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // ПРОГРЕСС БАР
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2)).frame(height: 4)
                        Capsule().fill(topic.color).frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text("\(learnedCount)/\(totalCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(height: 160)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
