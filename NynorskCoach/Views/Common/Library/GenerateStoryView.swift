import SwiftUI
import SwiftData

struct GenerateStoryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @ObservedObject var lm = LocalizationManager.shared // Следим за сменой языка
    
    @AppStorage("coins") private var coins = 0
    @State private var topic = ""
    
    // Adaptive cost calculation
    private var generationCost: Int {
        switch selectedDifficulty {
        case "A1", "A2": return 50
        case "B1": return 100
        default: return 200 // B2, C1
        }
    }
    @State private var selectedGenre = "Fairy Tale"
    @State private var selectedDifficulty = "A1"
    @State private var isGenerating = false
    @State private var errorMessage = "" // Added error state
    
    // Ключи для жанров (значения для логики)
    let genres = ["Fairy Tale", "Mystery", "Sci-Fi", "Romance", "History", "Daily Life"]
    let difficulties = ["A1", "A2", "B1", "B2", "C1"]
    
    // FETCH REAL USER DATA
    @Query var learningItems: [LearningItem] // Access all learning items
    @AppStorage("userRank") private var userRank: VikingRank = .oppdagar // Access user rank
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    // СЕКЦИЯ 1: ТЕМА
                    Section {
                        TextField("Например: Тролль, который любил кофе".localized, text: $topic)
                    } header: {
                        Text("О чем будет история?".localized)
                    }
                    
                    // СЕКЦИЯ 2: ПАРАМЕТРЫ
                    Section {
                        // Жанр (с переводом значений)
                        Picker("Жанр".localized, selection: $selectedGenre) {
                            ForEach(genres, id: \.self) { genre in
                                Text(localizeGenre(genre)).tag(genre)
                            }
                        }
                        
                        // Сложность
                        Picker("Сложность".localized, selection: $selectedDifficulty) {
                            ForEach(difficulties, id: \.self) { diff in
                                Text(diff).tag(diff)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Параметры".localized)
                    }
                }
                .scrollContentBackground(.visible) // Серый фон формы
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                // КНОПКА ГЕНЕРАЦИИ
                Button {
                    generateStory()
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text("Сгенерировать (\(generationCost) монет)".localized)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(topic.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(16)
                }
                .disabled(topic.isEmpty || isGenerating)
                .padding()
            }
            .navigationTitle("Новая история".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // ВАЖНО: Своя кнопка "Отмена" вместо системной
                    Button("Отмена".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Симуляция генерации (замените на реальный вызов API, если он у вас был)
    func generateStory() {
        // Проверка баланса с адаптивной ценой
        guard coins >= generationCost else {
            errorMessage = "Недостаточно монет (нужно \(generationCost))!"
            return
        }
        
        // Списание адаптивной цены
        coins -= generationCost
        
        isGenerating = true
        
        Task {
            do {
                // 1. Get known words from SwiftData
                let knownWords = OpenAIService.shared.getUserKnownWords(from: learningItems)
                print("📝 Using \(knownWords.count) known words for story generation")
                
                let result = try await OpenAIService.shared.generateStoryWithVocabulary(
                    topic: topic,
                    difficulty: selectedDifficulty,
                    userKnownWords: knownWords,
                    rank: userRank
                )
                
                await MainActor.run {
                    let newStory = Article(
                        title: result.title,
                        content: result.content, // Now from API
                        difficulty: result.difficulty,
                        topic: nil
                    )
                    context.insert(newStory)
                    isGenerating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Story Gen Error: \(error)")
                    errorMessage = "Ошибка: \(error.localizedDescription)" // Show UI error
                    isGenerating = false
                }
            }
        }
    }
    
    // Хелпер для перевода жанров на лету
    func localizeGenre(_ genre: String) -> String {
        switch genre {
        case "Fairy Tale": return "Сказка".localized
        case "Mystery": return "Детектив".localized
        case "Sci-Fi": return "Фантастика".localized
        case "Romance": return "Романтика".localized
        case "History": return "История".localized
        case "Daily Life": return "Повседневность".localized
        default: return genre
        }
    }
}
