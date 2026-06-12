import SwiftUI
import SwiftData
import SafariServices

// MARK: - Models
struct WordToken: Identifiable {
    let id = UUID()
    let text: String
    let cleanText: String
    let displayPart: String
    let punctuation: String
}

// MARK: - Reader View
struct ReaderView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lm = LocalizationManager.shared // Следим за языком
    
    let articleTitle: String
    let articleContent: String
    var originalURL: String? = nil
    
    @Query var savedItems: [LearningItem]
    @Query(filter: #Predicate<Topic> { $0.isSystem == true }) var systemTopics: [Topic]
    
    @State private var selectedWordToken: WordToken?
    @State private var showBrowser = false
    @State private var isCompleted = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Заголовок
                    Text(articleTitle)
                        .font(.largeTitle)
                        .bold()
                        .padding(.bottom, 5)
                    
                    // Текст статьи
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(paragraphs, id: \.self) { paragraph in
                            if !paragraph.trimmingCharacters(in: .whitespaces).isEmpty {
                                renderParagraph(paragraph)
                            }
                        }
                    }
                    
                    Divider().padding(.top, 20)
                    
                    // КНОПКА ЗАВЕРШЕНИЯ
                    Button {
                        completeLesson()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Завершить чтение".localized)
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCompleted ? Color.gray : Color.green)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                    }
                    .disabled(isCompleted)
                    .padding(.bottom, 10)
                    
                    // Кнопка "Читать в оригинале"
                    if let urlString = originalURL, let url = URL(string: urlString) {
                        Button {
                            showBrowser = true
                        } label: {
                            HStack {
                                Image(systemName: "safari")
                                Text("Читать полностью (NRK.no)".localized)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .padding()
                        }
                        .frame(maxWidth: .infinity)
                        .sheet(isPresented: $showBrowser) {
                            SafariView(url: url)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 50)
            }
        }
        .navigationTitle("Чтение".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWordToken) { token in
            WordActionSheet(word: token.cleanText, context: context, systemTopic: getSystemTopic())
                .presentationDetents([.medium])
        }
    }
    
    // --- ЛОГИКА ---
    func completeLesson() {
        guard !isCompleted else { return }
        isCompleted = true
        
        AudioManager.shared.play(.success)
        HapticManager.shared.notification(type: .success)
        
        QuestManager.shared.progress(.lessonComplete, amount: 1)
        StoreManager.shared.addCoins(10)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    // --- Helpers ---
    var paragraphs: [String] {
        let parts = articleContent.components(separatedBy: "\n\n")
        if parts.count > 1 { return parts }
        return articleContent.components(separatedBy: "\n")
    }
    
    @ViewBuilder
    func renderParagraph(_ text: String) -> some View {
        let tokens = tokenize(text)
        FlowLayout(items: tokens, hSpacing: 4, vSpacing: 6) { token in
            WordView(token: token, status: getStatus(for: token))
                .onTapGesture { handleWordTap(token) }
        }
    }
    
    func tokenize(_ text: String) -> [WordToken] {
        let components = text.components(separatedBy: .whitespaces)
        return components.compactMap { rawWord -> WordToken? in
            guard !rawWord.isEmpty else { return nil }
            var t = rawWord
            var suffix = ""
            while let last = t.last, String(last).rangeOfCharacter(from: .punctuationCharacters) != nil {
                suffix.insert(last, at: suffix.startIndex)
                t.removeLast()
            }
            let cleanForSearch = t.trimmingCharacters(in: .punctuationCharacters)
            if cleanForSearch.isEmpty {
                return WordToken(text: rawWord, cleanText: "", displayPart: rawWord, punctuation: "")
            }
            return WordToken(text: rawWord, cleanText: cleanForSearch, displayPart: t, punctuation: suffix)
        }
    }
    
    func getStatus(for token: WordToken) -> LearningStatus? {
        guard !token.cleanText.isEmpty else { return nil }
        if let item = savedItems.first(where: { $0.text.localizedCaseInsensitiveCompare(token.cleanText) == .orderedSame }) {
            return item.status
        }
        return nil
    }
    
    func handleWordTap(_ token: WordToken) {
        if !token.cleanText.isEmpty {
            HapticManager.shared.impact(style: .light)
            selectedWordToken = token
        }
    }
    
    func getSystemTopic() -> Topic {
        if let existing = systemTopics.first(where: { $0.isSystem == true }) { return existing }
        // Исправлено: название топика тоже локализуем через LocalizationManager при отображении,
        // но в базу пишем системное имя.
        let newTopic = Topic(name: "Mitt Ordbok", emoji: "📖", difficulty: "All", isSystem: true)
        context.insert(newTopic)
        return newTopic
    }
}

// MARK: - Word View Component
struct WordView: View {
    let token: WordToken
    let status: LearningStatus?
    
    var body: some View {
        HStack(spacing: 0) {
            Text(token.displayPart)
                .font(.body)
                .fontWeight(status != nil ? .semibold : .regular)
                .foregroundStyle(status != nil ? .white : .primary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(bgColor)
                .cornerRadius(6)
            
            if !token.punctuation.isEmpty {
                Text(token.punctuation)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
    }
    
    var bgColor: Color {
        switch status {
        case .new: return .red.opacity(0.8)
        case .learning: return .orange.opacity(0.8)
        case .mastered: return .green.opacity(0.8)
        case nil: return .clear
        }
    }
}

// MARK: - Word Action Sheet (Меню слова)
struct WordActionSheet: View {
    let word: String
    let context: ModelContext
    let systemTopic: Topic
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lm = LocalizationManager.shared // Локализация
    
    @State private var translation: String = ""
    @State private var gender: GrammaticalGender = .none
    @State private var isLoading = false
    
    @Query var existingItems: [LearningItem]
    
    init(word: String, context: ModelContext, systemTopic: Topic) {
        self.word = word
        self.context = context
        self.systemTopic = systemTopic
        let cleanWord = word
        self._existingItems = Query(filter: #Predicate<LearningItem> { item in
            item.text == cleanWord
        })
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("AI ищет перевод...".localized)
                } else {
                    Text(word)
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    if let existing = existingItems.first {
                        // УЖЕ ЕСТЬ В БАЗЕ
                        VStack(spacing: 10) {
                            Text("Слово уже сохранено".localized) // БЫЛО: "Allerede lagret"
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text(existing.translation)
                                .font(.title)
                                .foregroundStyle(.blue)
                            
                            HStack {
                                Text(existing.gender.rawValue)
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Text("Статус".localized + ": \(existing.status.rawValue)")
                                    .font(.caption)
                                    .padding(6)
                                    .background(statusColor(existing.status).opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(15)
                        
                    } else if !translation.isEmpty {
                        // ПЕРЕВОД НАЙДЕН
                        VStack(spacing: 15) {
                            Text(translation)
                                .font(.title2)
                                .foregroundStyle(.primary)
                            
                            Picker("Род".localized, selection: $gender) {
                                ForEach(GrammaticalGender.allCases) { g in
                                    Text(g.rawValue).tag(g)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Button {
                                saveWord()
                            } label: {
                                Text("\("Сохранить в".localized) \(systemTopic.name)")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                        
                    } else {
                        // НАЧАЛЬНОЕ СОСТОЯНИЕ
                        Button {
                            translate()
                        } label: {
                            Label("Перевести (AI)".localized, systemImage: "sparkles")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple.opacity(0.1))
                                .foregroundStyle(.purple)
                                .cornerRadius(12)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Слово".localized) // БЫЛО: "Ord"
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть".localized) { dismiss() } // БЫЛО: "Lukk"
                }
            }
        }
        .onAppear {
            if existingItems.isEmpty {
                translate()
            }
        }
    }
    
    func translate() {
        isLoading = true
        Task {
            do {
                let result = try await OpenAIService.shared.translateWord(word)
                await MainActor.run {
                    self.translation = result.translation
                    self.gender = GrammaticalGender(shortCode: result.gender)
                    self.isLoading = false
                    AudioManager.shared.play(.click)
                }
            } catch {
                await MainActor.run {
                    self.translation = "Ошибка перевода".localized
                    self.isLoading = false
                    AudioManager.shared.play(.error)
                }
            }
        }
    }
    
    func saveWord() {
        AudioManager.shared.play(.coin)
        HapticManager.shared.notification(type: .success)
        
        let newItem = LearningItem(
            text: word,
            translation: translation,
            gender: gender,
            topic: systemTopic
        )
        context.insert(newItem)
        QuestManager.shared.progress(.wordPractice, amount: 1)
        dismiss()
    }
    
    func statusColor(_ status: LearningStatus) -> Color {
        switch status {
        case .new: return .blue
        case .learning: return .orange
        case .mastered: return .green
        }
    }
}
