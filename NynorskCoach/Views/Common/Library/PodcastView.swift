import SwiftUI
import SwiftData

struct PodcastView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \SavedPodcast.dateSaved, order: .reverse) var savedPodcasts: [SavedPodcast]
    @ObservedObject var lm = LocalizationManager.shared
    @State private var showGenerator = false
    
    var body: some View {
        List {
            if savedPodcasts.isEmpty {
                ContentUnavailableView {
                    Label("Пока пусто".localized, systemImage: "headphones")
                } description: {
                    Text("Сгенерируй свой первый подкаст на Nynorsk.".localized)
                }
            } else {
                ForEach(savedPodcasts) { podcast in
                    NavigationLink(destination: SavedPodcastDetailView(podcast: podcast)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(podcast.title).font(.headline)
                            HStack {
                                Text("AI Audio").font(.caption2).bold().padding(4).background(Color.purple.opacity(0.1)).cornerRadius(4)
                                Text(podcast.dateSaved.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }
                }
                .onDelete { idx in idx.forEach { context.delete(savedPodcasts[$0]) } }
            }
        }
        .navigationTitle("Подкасты".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showGenerator = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showGenerator) { PodcastGeneratorView() }
    }
}

// --- ИНТЕРАКТИВНЫЙ ПРОСМОТРЩИК ПОДКАСТА (ЧАТ-СТИЛЬ) ---

struct SavedPodcastDetailView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss // Для закрытия
    
    let podcast: SavedPodcast
    
    // Для подсветки сохраненных слов
    @Query var savedItems: [LearningItem]
    @Query(filter: #Predicate<Topic> { $0.name == "Mimers Brønn" }) var dictionaryTopics: [Topic]
    
    @State private var selectedWordToken: WordToken?
    @State private var parsedLines: [DisplayLine] = [] // State cache
    
    @State private var playingLineId: UUID? = nil // Restored
    @State private var isCompleted = false       // Restored
    
    // Структура для отображения одной строки
    struct DisplayLine: Identifiable {
        let id = UUID()
        let speaker: String // "A" или "B"
        let text: String
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(podcast.title).font(.largeTitle).bold().padding(.horizontal)
                
                // Рендерим как диалог
                LazyVStack(spacing: 16) {
                    ForEach(parsedLines) { line in
                        HStack(alignment: .top, spacing: 12) {
                            // ЛЕВЫЙ СПИКЕР (A)
                            if line.speaker == "A" {
                                speakerButton(for: line, icon: "person.wave.2.fill", color: .blue)
                                chatBubble(for: line, color: .blue.opacity(0.1))
                                Spacer(minLength: 40)
                            } else {
                                // ПРАВЫЙ СПИКЕР (B)
                                Spacer(minLength: 40)
                                chatBubble(for: line, color: .purple.opacity(0.1))
                                speakerButton(for: line, icon: "person.2.wave.2.fill", color: .purple)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider().padding(.vertical)
                
                // КНОПКА ЗАВЕРШЕНИЯ (НОВОЕ)
                Button {
                    completeLesson()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Завершить урок".localized)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isCompleted ? Color.gray : Color.blue)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                }
                .disabled(isCompleted)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        // ОСТАНОВКА ПРИ ВЫХОДЕ
        .onDisappear {
            SpeechService.shared.stop()
        }
        .onAppear {
            parseTranscript()
        }
        .sheet(item: $selectedWordToken) { token in
            WordActionSheet(word: token.cleanText, context: context, systemTopic: getDictionaryTopic())
                .presentationDetents([.medium])
        }
    }
    
    func parseTranscript() {
        guard parsedLines.isEmpty else { return }
        let rawLines = podcast.transcript.components(separatedBy: .newlines)
        self.parsedLines = rawLines.compactMap { rawLine -> DisplayLine? in
            guard rawLine.contains(":") else { return nil }
            let parts = rawLine.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            let speaker = parts[0].trimmingCharacters(in: .whitespaces)
            let text = parts[1].trimmingCharacters(in: .whitespaces)
            if text.isEmpty { return nil }
            return DisplayLine(speaker: speaker, text: text)
        }
    }
    func completeLesson() {
        guard !isCompleted else { return }
        isCompleted = true
        
        AudioManager.shared.play(.success)
        HapticManager.shared.notification(type: .success)
        
        // Двигаем прогресс "Complete Lessons"
        QuestManager.shared.progress(.lessonComplete, amount: 1)
        StoreManager.shared.addCoins(10)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    // --- UI КОМПОНЕНТЫ (Без изменений) ---
    
    func speakerButton(for line: DisplayLine, icon: String, color: Color) -> some View {
        Button {
            HapticManager.shared.impact(style: .light)
            playLine(line.text, id: line.id)
        } label: {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: playingLineId == line.id ? "speaker.wave.3.fill" : icon)
                    .foregroundStyle(color).font(.system(size: 20))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                    .symbolEffect(.bounce, value: playingLineId == line.id)
            }
        }
        .buttonStyle(.plain)
    }
    
    func chatBubble(for line: DisplayLine, color: Color) -> some View {
        VStack(alignment: line.speaker == "A" ? .leading : .trailing) {
            Text(line.speaker == "A" ? "Викинг".localized : "Валькирия".localized)
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            renderParagraph(line.text, alignment: line.speaker == "A" ? .leading : .trailing)
                .padding(12).background(color).cornerRadius(16)
        }
    }
    
    // --- ЛОГИКА (Без изменений) ---
    
    // --- ЛОГИКА (Без изменений) ---
    
    // parsedLines moved to State and parseTranscript function
    
    func playLine(_ text: String, id: UUID) {
        SpeechService.shared.stop()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { self.playingLineId = id }
        SpeechService.shared.speak(text)
        let estimatedDuration = Double(text.count) * 0.08 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) {
            if self.playingLineId == id { withAnimation { self.playingLineId = nil } }
        }
    }
    
    @ViewBuilder
    func renderParagraph(_ text: String, alignment: HorizontalAlignment) -> some View {
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
            if cleanForSearch.isEmpty { return WordToken(text: rawWord, cleanText: "", displayPart: rawWord, punctuation: "") }
            return WordToken(text: rawWord, cleanText: cleanForSearch, displayPart: t, punctuation: suffix)
        }
    }
    
    func getStatus(for token: WordToken) -> LearningStatus? {
        guard !token.cleanText.isEmpty else { return nil }
        if let item = savedItems.first(where: { $0.text.localizedCaseInsensitiveCompare(token.cleanText) == .orderedSame }) { return item.status }
        return nil
    }
    
    func handleWordTap(_ token: WordToken) {
        if !token.cleanText.isEmpty {
            HapticManager.shared.impact(style: .light)
            selectedWordToken = token
        }
    }
    
    func getDictionaryTopic() -> Topic {
        if let existing = dictionaryTopics.first { return existing }
        let newTopic = Topic(name: "Mimers Brønn", emoji: "🧿", difficulty: "All", isSystem: true)
        context.insert(newTopic)
        return newTopic
    }
}
