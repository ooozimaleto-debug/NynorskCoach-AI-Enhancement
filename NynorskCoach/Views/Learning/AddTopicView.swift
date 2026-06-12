import SwiftUI
import SwiftData

struct AddTopicView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @ObservedObject var lm = LocalizationManager.shared
    
    @State private var topicName = ""
    @State private var selectedLevel = "A1"
    @State private var isLoading = false
    @State private var loadingStatus = ""
    @State private var progress: Double = 0.0
    @State private var generatedWords: [WordResult] = []
    @State private var generatedAudio: [String: Data] = [:]
    @State private var topicEmoji = "✨"
    
    let levels = ["A1", "A2", "B1", "B2", "C1"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 25) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("О чем хочешь узнать?".localized).font(.headline).foregroundStyle(.secondary)
                            
                            HStack {
                                TextField("Например: Рыбалка".localized, text: $topicName)
                                    .font(.title3).padding().background(.ultraThinMaterial).cornerRadius(15)
                                Button { topicEmoji = randomEmoji() } label: {
                                    Text(topicEmoji).font(.title).padding().background(.ultraThinMaterial).clipShape(Circle())
                                }
                            }
                            
                            Picker("Уровень сложности".localized, selection: $selectedLevel) {
                                ForEach(levels, id: \.self) { level in Text(level).tag(level) }
                            }.pickerStyle(.segmented).padding(.top, 5)
                        }.padding(.horizontal)
                        
                        Button { generateContent() } label: {
                            HStack {
                                if isLoading { ProgressView().tint(.white) } else {
                                    Image(systemName: "sparkles")
                                    Text("Сгенерировать (AI)".localized)
                                }
                            }
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding()
                            .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(20).shadow(radius: 5, y: 3)
                        }
                        .disabled(topicName.isEmpty || isLoading)
                        .padding(.horizontal)
                        
                        if isLoading {
                            VStack(spacing: 8) {
                                Text(loadingStatus).font(.caption).bold().foregroundStyle(.secondary)
                                ProgressView(value: progress, total: 1.0).tint(.blue)
                            }
                            .padding(.horizontal)
                        }
                        
                        if !generatedWords.isEmpty && !isLoading {
                            VStack(alignment: .leading) {
                                Text("Готово! (\(generatedWords.count) слов)").font(.headline).padding(.leading)
                                
                                ForEach(generatedWords, id: \.text) { word in
                                    HStack {
                                        Image(systemName: word.imageKeyword).foregroundStyle(.blue).frame(width: 30)
                                        VStack(alignment: .leading) {
                                            Text(word.text).bold()
                                            Text(word.translation).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if generatedAudio[word.text] != nil { Image(systemName: "waveform").foregroundStyle(.green).font(.caption) }
                                        Text(word.gender).font(.caption2).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4)
                                    }
                                    .padding().background(.ultraThinMaterial).cornerRadius(12).padding(.horizontal)
                                }
                                
                                Button { saveTopic() } label: {
                                    Text("Сохранить Тему".localized)
                                        .font(.title3).bold().foregroundStyle(.white).frame(maxWidth: .infinity).padding()
                                        .background(Color.green.gradient).cornerRadius(20).shadow(radius: 5)
                                }
                                .padding()
                            }
                        }
                    }.padding(.top)
                }
            }
            .navigationTitle("Добавить тему".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена".localized) { dismiss() } } }
        }
    }
    
    func generateContent() {
        hideKeyboard()
        isLoading = true
        progress = 0.1
        loadingStatus = "AI..."
        generatedWords = []
        generatedAudio = [:]
        
        // ИСПРАВЛЕНИЕ: Явный приоритет задачи, чтобы убрать ошибку Ambiguous use
        Task(priority: .userInitiated) {
            do {
                let words = try await OpenAIService.shared.generateBulkWords(topicName: topicName, level: selectedLevel)
                await MainActor.run {
                    self.generatedWords = words
                    self.progress = 0.3
                    self.loadingStatus = "Озвучка..."
                }
                
                let total = Double(words.count)
                for word in words {
                    // Используем GoogleTTSService для слов (быстрее и дешевле)
                    // Использует голос текущего выбранного наставника
                    let audioData = try await GoogleTTSService.shared.generateSpeech(text: word.text)
                    await MainActor.run {
                        self.generatedAudio[word.text] = audioData
                        self.progress += 0.7 / total
                    }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                await MainActor.run {
                    self.isLoading = false
                    self.loadingStatus = "Готово"
                    AudioManager.shared.play(.success)
                }
            } catch {
                await MainActor.run {
                    print("Err: \(error)")
                    self.isLoading = false
                    self.loadingStatus = "Ошибка"
                    AudioManager.shared.play(.error)
                }
            }
        }
    }
    
    func saveTopic() {
        let newTopic = Topic(name: topicName, emoji: topicEmoji, difficulty: selectedLevel)
        context.insert(newTopic)
        for word in generatedWords {
            let item = LearningItem(text: word.text, translation: word.translation, gender: GrammaticalGender(shortCode: word.gender), topic: newTopic)
            item.contextSentence = word.context
            item.contextTranslation = word.contextTranslation
            if let uiImage = UIImage(systemName: word.imageKeyword)?.withTintColor(.black, renderingMode: .alwaysOriginal) {
                item.imageData = uiImage.pngData()
            }
            if let audio = generatedAudio[word.text] { item.audioData = audio }
            context.insert(item)
        }
        AudioManager.shared.play(.coin)
        dismiss()
    }
    
    func randomEmoji() -> String {
        ["✈️", "🍔", "⚽️", "🎸", "💻", "🌲", "🏠", "🚗", "🎨", "📚"].randomElement() ?? "✨"
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
