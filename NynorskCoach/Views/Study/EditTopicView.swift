import SwiftUI
import SwiftData

struct EditTopicView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Bindable var topic: Topic
    
    // Состояния для добавления
    @State private var isAddingWord = false
    @State private var nativeInput = ""
    @State private var nynorskInput = ""
    @State private var isTranslating = false
    
    // Состояния для редактирования
    @State private var wordToEdit: LearningItem?
    @State private var editNative = ""
    @State private var editNynorsk = ""
    
    // Цвета
    let colors: [String] = [
        "blue", "cyan", "teal", "mint", "green", "yellow", "orange", "red", "pink", "purple", "indigo", "brown", "gray"
    ]
    
    // СОВРЕМЕННЫЕ ИКОНКИ (SF Symbols)
    // Оставляем их, так как они нужны для современных слов (ноутбук, машина и т.д.)
    let icons: [String] = [
        "book.closed.fill", "graduationcap.fill", "pencil.circle.fill", "briefcase.fill", "laptopcomputer",
        "fork.knife", "cup.and.saucer.fill", "carrot.fill", "fish.fill", "birthday.cake.fill",
        "airplane", "car.fill", "tram.fill", "map.fill", "tent.fill", "sailboat.fill",
        "figure.run", "dumbbell.fill", "soccerball", "trophy.fill", "music.note",
        "leaf.fill", "tree.fill", "mountain.2.fill", "sun.max.fill", "snowflake", "flame.fill", "drop.fill",
        "house.fill", "key.fill", "cart.fill", "creditcard.fill", "bed.double.fill",
        "heart.fill", "star.fill", "lightbulb.fill", "bubble.left.and.bubble.right.fill", "crown.fill", "gift.fill"
    ]
    
    let difficulties = ["A1", "A2", "B1", "B2", "C1", "C2"]
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. НАСТРОЙКИ
                Section("О теме".localized) {
                    TextField("Название темы".localized, text: $topic.name)
                    Picker("Уровень".localized, selection: $topic.difficulty) {
                        ForEach(difficulties, id: \.self) { level in Text(level).tag(level) }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 2. ЦВЕТ ТЕМЫ
                Section("Цвет оформления".localized) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 10) {
                        ForEach(colors, id: \.self) { colorName in
                            Circle()
                                .fill(colorFromString(colorName))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(Color.primary, lineWidth: topic.themeColor == colorName ? 3 : 0)
                                )
                                .onTapGesture {
                                    withAnimation { topic.themeColor = colorName }
                                }
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                // 3. ИКОНКА
                Section("Иконка".localized) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 45))], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(topic.emoji == icon ? topic.color.opacity(0.2) : Color(uiColor: .secondarySystemBackground))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(topic.emoji == icon ? topic.color : .gray)
                            }
                            .onTapGesture {
                                withAnimation { topic.emoji = icon }
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                // 4. СЛОВА
                Section("\("Слова".localized) (\(topic.items.count))") {
                    if topic.items.isEmpty {
                        Text("Нет слов. Добавьте первое!".localized).foregroundStyle(.secondary)
                    } else {
                        List {
                            ForEach(topic.items) { item in
                                Button {
                                    startEditing(item)
                                } label: {
                                    HStack {
                                        Text(item.text).bold().foregroundStyle(.primary)
                                        Spacer()
                                        Text(item.translation).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .onDelete(perform: deleteWords)
                        }
                    }
                    
                    Button {
                        nativeInput = ""
                        nynorskInput = ""
                        isAddingWord = true
                    } label: {
                        Label("Добавить слово".localized, systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Редактирование".localized)
            .toolbar { Button("Готово".localized) { dismiss() } }
            
            // АЛЕРТ ДОБАВЛЕНИЯ
            .sheet(isPresented: $isAddingWord) {
                NavigationStack {
                    Form {
                        Section("Добавление слова".localized) {
                            TextField("На родном (напр. Племянница)".localized, text: $nativeInput)
                            
                            HStack {
                                TextField("Nynorsk", text: $nynorskInput) // Исправленный плейсхолдер
                                
                                Button {
                                    translateToNynorsk()
                                } label: {
                                    if isTranslating {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                            .foregroundStyle(.purple)
                                            .font(.title2)
                                            .symbolEffect(.bounce, value: isTranslating)
                                    }
                                }
                                .disabled(nativeInput.isEmpty || isTranslating)
                            }
                        }
                        
                        Section {
                            Button("Сохранить".localized) { addWord(); isAddingWord = false }
                                .disabled(nynorskInput.isEmpty || nativeInput.isEmpty)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .navigationTitle("Новое слово".localized)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена".localized) { isAddingWord = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            
            // АЛЕРТ РЕДАКТИРОВАНИЯ
            .alert("Изменить слово".localized, isPresented: Binding(get: { wordToEdit != nil }, set: { _ in wordToEdit = nil })) {
                TextField("Nynorsk", text: $editNynorsk)
                TextField("Перевод".localized, text: $editNative)
                Button("Отмена".localized, role: .cancel) { wordToEdit = nil }
                Button("Сохранить".localized) { saveWordChanges() }
            }
        }
    }
    
    // --- ЛОГИКА ---
    
    func colorFromString(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        default: return .blue
        }
    }
    
    func translateToNynorsk() {
        guard !nativeInput.isEmpty else { return }
        isTranslating = true
        
        Task {
            do {
                let translatedText = try await OpenAIService.shared.translateToNynorsk(nativeInput)
                await MainActor.run {
                    nynorskInput = translatedText
                    isTranslating = false
                }
            } catch {
                print("Translation error: \(error)")
                await MainActor.run { isTranslating = false }
            }
        }
    }
    
    func deleteWords(at offsets: IndexSet) {
        for index in offsets {
            let item = topic.items[index]
            context.delete(item)
        }
        try? context.save()
    }
    
    func addWord() {
        guard !nynorskInput.isEmpty, !nativeInput.isEmpty else { return }
        let newItem = LearningItem(
            text: nynorskInput,
            translation: nativeInput,
            gender: .masculine,
            topic: topic
        )
        context.insert(newItem)
        topic.items.append(newItem)
        try? context.save()
        nativeInput = ""
        nynorskInput = ""
    }
    
    func startEditing(_ item: LearningItem) {
        wordToEdit = item
        editNynorsk = item.text
        editNative = item.translation
    }
    
    func saveWordChanges() {
        guard let item = wordToEdit else { return }
        item.text = editNynorsk
        item.translation = editNative
        try? context.save()
        wordToEdit = nil
    }
}
