import SwiftUI
import SwiftData

struct WordListView: View {
    @Bindable var topic: Topic
    @Environment(\.modelContext) var context
    
    // Живой запрос к базе данных
    @Query var items: [LearningItem]
    
    // Состояния для навигации
    @State private var showAddWord = false
    @State private var wordToEdit: LearningItem?
    @State private var showStudySession = false
    
    // Инициализатор с фильтрацией слов по имени темы
    init(topic: Topic) {
        self.topic = topic
        let targetTopicName = topic.name
        
        // Сортировка по алфавиту
        _items = Query(
            filter: #Predicate<LearningItem> { item in
                item.topic?.name == targetTopicName
            },
            sort: [SortDescriptor(\LearningItem.text)]
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Кнопка "Начать урок" (только если есть слова)
            if !items.isEmpty {
                Button {
                    showStudySession = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Начать урок".localized)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .padding()
            }
            
            // 2. Список слов
            List {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Нет слов".localized,
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Добавьте слова вручную (+) или импортируйте список.".localized)
                    )
                } else {
                    ForEach(items) { item in
                        Button {
                            wordToEdit = item // Открываем единый редактор
                        } label: {
                            HStack(spacing: 12) {
                                // А. Миниатюра (Фото или Заглушка)
                                if let data = item.imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 42, height: 42)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 42, height: 42)
                                        Text(String(item.text.prefix(1)))
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                // Б. Текст и Перевод
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.text)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(item.translation)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // В. Индикаторы (Род + Статус)
                                VStack(alignment: .trailing, spacing: 4) {
                                    // Род (M/F/N)
                                    if item.gender != .none {
                                        Text(shortGender(item.gender))
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(genderColor(item.gender).opacity(0.15))
                                            .foregroundStyle(genderColor(item.gender))
                                            .clipShape(Capsule())
                                    }
                                    
                                    // Точка статуса SRS
                                    Circle()
                                        .fill(statusColor(item.status))
                                        .frame(width: 8, height: 8)
                                }
                                
                                // Шеврон
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle()) // Чтобы нажималась вся строка
                        }
                        .buttonStyle(.plain) // Убираем стандартное выделение списка
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(topic.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddWord = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        
        // --- НАВИГАЦИЯ ---
        
        // 1. Добавление (Новый WordEditorView)
        .sheet(isPresented: $showAddWord) {
            WordEditorView(topic: topic)
        }
        
        // 2. Редактирование (Новый WordEditorView с переданным item)
        .sheet(item: $wordToEdit) { item in
            WordEditorView(item: item)
        }
        
        // 3. Тренировка (Новый FlashcardSessionView)
        .fullScreenCover(isPresented: $showStudySession) {
            FlashcardSessionView(topic: topic)
        }
    }
    
    // --- ХЕЛПЕРЫ ---
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = items[index]
                context.delete(item)
            }
        }
    }
    
    func shortGender(_ g: GrammaticalGender) -> String {
        switch g {
        case .masculine: return "M"
        case .feminine: return "F"
        case .neuter: return "N"
        default: return ""
        }
    }
    
    func genderColor(_ g: GrammaticalGender) -> Color {
        switch g {
        case .masculine: return .blue
        case .feminine: return .pink
        case .neuter: return .orange
        default: return .gray
        }
    }
    
    func statusColor(_ status: LearningStatus) -> Color {
        switch status {
        case .new: return .blue
        case .learning: return .orange
        case .mastered: return .green
        }
    }
}
