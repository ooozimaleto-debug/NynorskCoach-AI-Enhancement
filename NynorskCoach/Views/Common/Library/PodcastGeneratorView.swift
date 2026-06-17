import SwiftUI
import SwiftData

struct PodcastGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @ObservedObject var lm = LocalizationManager.shared
    @AppStorage("coins") private var coins = 0
    
    @State private var topic = ""
    @State private var selectedTone = "Повседневный"
    @State private var selectedLevel = "A1"
    
    @State private var isGenerating = false
    @State private var errorMessage = ""
    @State private var loadingStatus = ""
    
    @State private var lines: [DialogueLine] = []
    @State private var podcastTitle = ""
    @State private var isFinished = false
    @State private var currentPlayingIndex: Int? = nil
    
    // Тона (ключи)
    let tones = ["Повседневный", "Деловой", "Юмористический", "Романтический", "Спор"]
    let levels = ["A1", "A2", "B1", "B2", "C1"]
    
    // Adaptive cost calculation
    private var generationCost: Int {
        switch selectedLevel {
        case "A1", "A2": return 50
        case "B1": return 100
        default: return 200 // B2, C1
        }
    }
    
    var body: some View {
        NavigationStack {
            if isFinished {
                PodcastPlayerResultView(lines: lines, title: podcastTitle, onSave: saveAndClose, onDiscard: { isFinished = false })
            } else {
                Form {
                    Section("О чем будет подкаст?".localized) {
                        TextField("Например: Викинги обсуждают биткойн".localized, text: $topic)
                    }
                    
                    Section("Параметры".localized) {
                        Picker("Тон беседы".localized, selection: $selectedTone) {
                            ForEach(tones, id: \.self) { tone in
                                Text(tone.localized).tag(tone)
                            }
                        }
                        Picker("Уровень сложности".localized, selection: $selectedLevel) {
                            ForEach(levels, id: \.self) { level in Text(level).tag(level) }
                        }.pickerStyle(.segmented)
                    }
                    
                    Section {
                        Button { generate() } label: {
                            if isGenerating {
                                HStack {
                                    ProgressView()
                                    // Локализация статуса
                                    Text(loadingStatus.isEmpty ? "Создание...".localized : loadingStatus.localized)
                                }
                            } else {
                                HStack { Image(systemName: "waveform"); Text("Сгенерировать (\(generationCost) монет)".localized) }.bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(isGenerating ? Color.gray.opacity(0.1) : Color.blue)
                        .foregroundStyle(isGenerating ? Color.primary : Color.white)
                        .disabled(topic.isEmpty || isGenerating)
                    }
                    
                    if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red).font(.caption) } }
                }
                .navigationTitle("Новый подкаст".localized)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена".localized) { dismiss() } } }
            }
        }
        .onDisappear {
            SpeechService.shared.stop()
            SpeechService.shared.onDialogueLineStart = nil
            SpeechService.shared.onDialogueFinished = nil
        }
    }
    
    func generate() {
        // Проверка баланса с адаптивной ценой
        guard coins >= generationCost else {
            errorMessage = "Недостаточно монет (нужно \(generationCost))!"
            return
        }
        
        // Списание адаптивной цены
        coins -= generationCost
        
        isGenerating = true
        errorMessage = ""
        loadingStatus = "ИИ пишет сценарий..." // Будет локализовано через .localized в View
        _ = "\(topic) (Тон: \(selectedTone), Уровень: \(selectedLevel))" // Removed promptContext assignment
        
        Task {
            do {
                // TODO: Inject real known words
                let knownWords: [String] = []  
                
                let dialogueResult = try await OpenAIService.shared.generatePodcastWithVocabulary(
                    topic: "\(topic) (Tone: \(selectedTone))", // Pass tone in topic
                    difficulty: selectedLevel,
                    userKnownWords: knownWords,
                    rank: VikingRank.oppdagar // Default
                )

                await MainActor.run {
                    self.podcastTitle = dialogueResult.title
                    self.loadingStatus = "Google TTS..."
                }
                let audioLines = try await GoogleTTSService.shared.enrichDialogue(lines: dialogueResult.lines)
                await MainActor.run {
                    self.lines = audioLines
                    self.isGenerating = false
                    self.isFinished = true
                    playPodcast()
                }
            } catch {
                await MainActor.run { errorMessage = "Error: \(error.localizedDescription)"; isGenerating = false }
            }
        }
    }
    
    func playPodcast() {
        SpeechService.shared.onDialogueLineStart = { index in withAnimation { currentPlayingIndex = index } }
        SpeechService.shared.onDialogueFinished = { withAnimation { currentPlayingIndex = nil } }
        SpeechService.shared.playDialogue(lines: lines)
    }
    
    func saveAndClose() {
        let fullText = lines.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n\n")
        let newPodcast = SavedPodcast(title: podcastTitle, transcript: fullText)
        newPodcast.linesData = try? JSONEncoder().encode(lines)
        context.insert(newPodcast)
        XPManager.shared.addXP(50, context: context)
        AudioManager.shared.play(.success)
        dismiss()
    }
}

struct PodcastPlayerResultView: View {
    let lines: [DialogueLine]; let title: String; let onSave: () -> Void; let onDiscard: () -> Void
    @State private var currentPlayingIndex: Int? = nil
    
    var body: some View {
        VStack {
            Text(title).font(.headline).padding()
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top) {
                            Text(line.speaker == "A" ? "👨‍🦰" : "👩‍🦰")
                            VStack(alignment: .leading) {
                                Text(line.speaker == "A" ? "Викинг".localized : "Валькирия".localized)
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(line.text).foregroundStyle(currentPlayingIndex == index ? Color.green : Color.primary)
                            }
                        }
                        .id(index)
                    }
                }
                .onChange(of: currentPlayingIndex) { _, newIndex in if let i = newIndex { withAnimation { proxy.scrollTo(i, anchor: .center) } } }
            }
            HStack {
                Button("Удалить".localized, role: .destructive, action: onDiscard)
                Spacer()
                Button("Сохранить".localized, action: onSave).buttonStyle(.borderedProminent)
            }.padding()
        }
        .onAppear {
            SpeechService.shared.onDialogueLineStart = { idx in withAnimation { currentPlayingIndex = idx } }
            SpeechService.shared.onDialogueFinished = { withAnimation { currentPlayingIndex = nil } }
        }
    }
}
