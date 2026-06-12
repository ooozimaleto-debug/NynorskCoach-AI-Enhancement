import SwiftUI
import SwiftData
import Combine

struct ExamView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Query var allItems: [LearningItem]
    
    // Настройки
    @AppStorage("selectedMentor") private var selectedMentorRaw = Mentor.freya.rawValue
    @AppStorage("userRank") private var userRank: VikingRank = .oppdagar
    
    // Состояние экзамена
    @State private var questions: [ExamQuestion] = []
    @State private var currentQuestionIndex = 0
    @State private var userAnswers: [UUID: String] = [:]
    @State private var mistakes: [ExamMistake] = []
    
    @State private var isFinished = false
    @State private var score = 0.0
    
    // AI Анализ (ТЕПЕРЬ СТРУКТУРИРОВАННЫЙ)
    @State private var analysisResult: AnalysisResponse? // Храним результат парсинга
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    
    // Таймер
    @State private var timeRemaining: Double = 60.0
    @State private var totalTime: Double = 60.0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var mentor: Mentor { Mentor(rawValue: selectedMentorRaw) ?? .freya }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                if allItems.count < 5 {
                    ContentUnavailableView(
                        "Мало знаний".localized,
                        systemImage: "studentdesk",
                        description: Text("Выучи хотя бы 5 слов для экзамена.".localized)
                    )
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
                } else if isFinished {
                    // ЭКРАН РЕЗУЛЬТАТА
                    ExamResultView(
                        score: score,
                        totalQuestions: questions.count,
                        mistakes: mistakes,
                        mentor: mentor,
                        analysisResult: analysisResult,
                        isAnalyzing: isAnalyzing,
                        analysisError: analysisError,
                        onRequestAnalysis: analyzeMistakes,
                        onClose: { dismiss() }
                    )
                } else if !questions.isEmpty {
                    // ЭКРАН ВОПРОСА
                    VStack(spacing: 20) {
                        HStack {
                            Text("Вопрос".localized + " \(currentQuestionIndex + 1)/\(questions.count)")
                                .font(.caption).bold().foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "stopwatch")
                                Text(timeString(time: timeRemaining)).monospacedDigit()
                            }
                            .font(.caption).bold()
                            .foregroundStyle(timeRemaining < 10 ? .red : .primary)
                        }
                        .padding(.horizontal)
                        
                        ProgressView(value: Double(currentQuestionIndex), total: Double(questions.count))
                            .tint(mentorColor)
                            .padding(.horizontal)
                        
                        let question = questions[currentQuestionIndex]
                        
                        ScrollView {
                            VStack(spacing: 30) {
                                HStack { Spacer(); MentorAvatar(mentor: mentor, size: 60); Spacer() }.padding(.top)
                                Text(question.prompt).font(.title2).bold().multilineTextAlignment(.center)
                                
                                if question.type == .multipleChoice {
                                    MultipleChoiceGrid(options: question.options ?? [], onSelect: { answer in submitAnswer(question, answer: answer) })
                                } else {
                                    TextInputField(
                                        text: Binding(get: { userAnswers[question.id] ?? "" }, set: { userAnswers[question.id] = $0 }),
                                        onSubmit: { if let text = userAnswers[question.id], !text.isEmpty { submitAnswer(question, answer: text) } }
                                    )
                                    Button("Ответить".localized) {
                                        if let text = userAnswers[question.id], !text.isEmpty { submitAnswer(question, answer: text) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(userAnswers[question.id]?.isEmpty ?? true)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top)
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    ProgressView("Подготовка билетов...".localized)
                }
            }
            .navigationTitle("Экзамен".localized)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .onReceive(timer) { _ in
                guard !questions.isEmpty, !isFinished else { return }
                if timeRemaining > 0 { timeRemaining -= 1 } else { finishExam() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Сдаться".localized) { dismiss() } }
            }
        }
        .onAppear { prepareExam() }
    }
    
    // --- ЛОГИКА ---
    
    var mentorColor: Color {
        switch mentor { case .freya: return .green; case .loki: return .purple; case .odin: return .blue }
    }
    
    func timeString(time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func prepareExam() {
        let due = allItems.filter { $0.nextReviewDate <= Date() }
        let learning = allItems.filter { $0.status == .learning }
        var pool = Array(due.prefix(5))
        if pool.count < 10 { pool.append(contentsOf: learning.prefix(10 - pool.count)) }
        if pool.count < 10 { pool.append(contentsOf: allItems.shuffled().prefix(10 - pool.count)) }
        pool = pool.shuffled()
        
        var newQuestions: [ExamQuestion] = []
        let isHardMode = (userRank == .krigar || userRank == .jarl)
        
        for (index, item) in pool.enumerated() {
            let useTextInput = isHardMode ? (index % 2 == 0) : (index % 3 == 0)
            if !useTextInput {
                let distractors = allItems.filter { $0.id != item.id }.shuffled().prefix(3).map { $0.translation }
                let options = (distractors + [item.translation]).shuffled()
                newQuestions.append(ExamQuestion(item: item, type: .multipleChoice, prompt: "Как переводится".localized + " \"\(item.text)\"?", options: options))
            } else {
                newQuestions.append(ExamQuestion(item: item, type: .textInput, prompt: "Напиши перевод для".localized + " \"\(item.translation)\"", options: nil))
            }
        }
        questions = newQuestions
        
        let baseTime = Double(questions.count * 10)
        switch mentor {
        case .freya: totalTime = baseTime * 1.5
        case .loki: totalTime = baseTime * 1.0
        case .odin: totalTime = baseTime * 0.7
        }
        timeRemaining = totalTime
    }
    
    private func submitAnswer(_ question: ExamQuestion, answer: String) {
        userAnswers[question.id] = answer
        AudioManager.shared.play(.click)
        
        let isCorrect: Bool
        if question.type == .multipleChoice {
            isCorrect = (answer == question.item.translation)
        } else {
            isCorrect = (answer.lowercased().trimmingCharacters(in: .whitespaces) == question.item.text.lowercased().trimmingCharacters(in: .whitespaces))
        }
        
        if !isCorrect {
            mistakes.append(ExamMistake(word: question.item.text, userAnswer: answer, correctAnswer: question.type == .multipleChoice ? question.item.translation : question.item.text))
        }
        
        if currentQuestionIndex < questions.count - 1 {
            withAnimation { currentQuestionIndex += 1 }
        } else {
            finishExam()
        }
    }
    
    func finishExam() {
        let correctCount = questions.count - mistakes.count
        score = Double(correctCount) / Double(questions.count)
        isFinished = true
        if score >= 0.8 {
            AudioManager.shared.play(.success)
            QuestManager.shared.progress(.lessonComplete, amount: 1)
        } else {
            AudioManager.shared.play(.error)
        }
    }
    
    // --- АНАЛИЗАТОР (JSON VERSION) ---
    func analyzeMistakes() {
        guard !mistakes.isEmpty else { return }
        isAnalyzing = true
        analysisError = nil
        
        Task {
            do {
                let response = try await OpenAIService.shared.analyzeMistakes(
                    mistakes: mistakes,
                    mentor: mentor,
                    userRank: userRank
                )
                
                await MainActor.run {
                    self.analysisResult = response
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.analysisError = "Не удалось прочитать ответ Одина... (\(error.localizedDescription))"
                    self.isAnalyzing = false
                    print("Analysis Error: \(error)")
                }
            }
        }
    }
}

// --- НОВЫЕ МОДЕЛИ ДЛЯ АНАЛИЗА ---
// MARK: - LOCAL MODELS

private struct ExamQuestion: Identifiable {
    let id = UUID()
    let item: LearningItem
    let type: QuestionType
    let prompt: String
    let options: [String]?
    enum QuestionType { case multipleChoice, textInput }
}

// MARK: - COMPONENTS

private struct MentorAvatar: View {
    let mentor: Mentor
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.1)).frame(width: size, height: size)
            Image(systemName: icon).font(.system(size: size * 0.6)).foregroundStyle(color)
        }
    }
    var icon: String { switch mentor { case .freya: return "leaf.fill"; case .loki: return "flame.fill"; case .odin: return "eye.fill" } }
    var color: Color { switch mentor { case .freya: return .green; case .loki: return .purple; case .odin: return .blue } }
}

private struct MultipleChoiceGrid: View {
    let options: [String]; let onSelect: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
            ForEach(options, id: \.self) { option in
                Button { onSelect(option) } label: {
                    Text(option).font(.headline).multilineTextAlignment(.center).frame(maxWidth: .infinity).frame(height: 80).padding(5).background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 3, y: 2)
                }.buttonStyle(.plain)
            }
        }
    }
}

private struct TextInputField: View {
    @Binding var text: String; var onSubmit: () -> Void
    var body: some View {
        TextField("Введи ответ...".localized, text: $text).font(.title2).padding().background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(12).submitLabel(.done).onSubmit(onSubmit)
    }
}

// MARK: - RESULT SCREEN (ОБНОВЛЕННЫЙ)

private struct ExamResultView: View {
    let score: Double
    let totalQuestions: Int
    let mistakes: [ExamMistake]
    let mentor: Mentor
    
    // Новые данные анализа
    let analysisResult: AnalysisResponse?
    let isAnalyzing: Bool
    let analysisError: String?
    
    let onRequestAnalysis: () -> Void
    let onClose: () -> Void
    
    var passed: Bool { score >= 0.6 }
    var grade: String {
        switch score { case 0.9...1.0: return "A"; case 0.75..<0.9: return "B"; case 0.6..<0.75: return "C"; case 0.4..<0.6: return "D"; default: return "F" }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Spacer().frame(height: 20)
                ZStack {
                    Circle().fill(passed ? Color.green.opacity(0.1) : Color.red.opacity(0.1)).frame(width: 120, height: 120)
                    Text(grade).font(.system(size: 60, weight: .heavy, design: .rounded)).foregroundStyle(passed ? .green : .red)
                }
                Text(passed ? "Экзамен сдан!".localized : "Провал!".localized).font(.largeTitle).bold()
                Text("\(Int(score * 100))%").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(passed ? .green : .red)
                
                if !mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            MentorAvatar(mentor: mentor, size: 40)
                            Text("Вердикт Наставника:".localized).font(.headline)
                        }
                        
                        // 1. Показываем либо кнопку, либо результат
                        if let result = analysisResult {
                            // РЕЗУЛЬТАТ (JSON)
                            Text(result.reaction)
                                .italic()
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(mentorColor.opacity(0.1))
                                .cornerRadius(12)
                            
                            ForEach(result.corrections) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.word).strikethrough().foregroundStyle(.red)
                                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                                        Text(item.correction).bold().foregroundStyle(.green)
                                    }
                                    .font(.headline)
                                    
                                    Text(item.explanation)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    
                                    if !item.example.isEmpty {
                                        Text("Пример: \(item.example)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            
                        } else if isAnalyzing {
                            HStack { ProgressView(); Text("Анализирую...".localized).font(.caption).foregroundStyle(.secondary) }.padding()
                        } else {
                            if let error = analysisError {
                                Text(error).foregroundStyle(.red).font(.caption).padding()
                            }
                            Button { onRequestAnalysis() } label: {
                                Label("Почему я ошибся?".localized, systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                }
                
                Spacer()
                Button("Завершить".localized) { onClose() }.buttonStyle(.borderedProminent).controlSize(.large).padding(.bottom)
            }.padding()
        }
    }
    
    var mentorColor: Color {
        switch mentor { case .freya: return .green; case .loki: return .purple; case .odin: return .blue }
    }
}
