import SwiftUI
import SwiftData
import Combine

struct QuizView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Query var allItems: [LearningItem]
    
    // Игровое состояние
    @State private var currentQuestion: Question?
    @State private var score = 0
    @State private var timeRemaining: Double = 30.0
    @State private var isGameOver = false
    @State private var timeAdded: Double? = nil
    
    // Комбо-система
    @State private var comboCount = 0
    @State private var showComboFire = false
    
    // Анимации
    @State private var shakeOffset: CGFloat = 0
    @State private var scorePopup: Int? = nil // Всплывающие очки
    
    // Таймер
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var isTimerRunning = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if isGameOver {
                GameOverView(score: score, onRestart: restartGame, onClose: { dismiss() })
            } else if allItems.count < 4 {
                ContentUnavailableView("Мало слов".localized, systemImage: "books.vertical.fill", description: Text("Нужно минимум 4 слова для игры.".localized))
                VStack { Spacer(); Button("Закрыть".localized) { dismiss() }.padding() }
            } else {
                VStack(spacing: 20) {
                    // ВЕРХНЯЯ ПАНЕЛЬ
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // СЧЕТ + КОМБО
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack {
                                Text("\(score)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .contentTransition(.numericText())
                                Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(.yellow)
                            }
                            
                            // Индикатор комбо
                            if comboCount > 1 {
                                Text("COMBO x\(min(comboCount, 5))")
                                    .font(.caption).bold()
                                    .foregroundStyle(.orange)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .padding()
                    
                    // ТАЙМЕР
                    ZStack {
                        // Фон таймера
                        Circle()
                            .stroke(lineWidth: 10)
                            .opacity(0.3)
                            .foregroundColor(timeColor)
                        
                        // Прогресс
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(timeRemaining / 30.0, 1.0)))
                            .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                            .foregroundColor(timeColor)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear(duration: 0.1), value: timeRemaining)
                        
                        // Текст времени
                        VStack(spacing: 0) {
                            Text(String(format: "%.0f", max(0, timeRemaining)))
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundStyle(timeColor)
                                .contentTransition(.numericText())
                        }
                        
                        // Всплывающее время (+2s / -5s)
                        if let added = timeAdded {
                            Text(added > 0 ? "+\(Int(added))s" : "\(Int(added))s")
                                .font(.title3).bold()
                                .foregroundStyle(added > 0 ? .green : .red)
                                .offset(y: -60)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Всплывающие очки (+10)
                        if let points = scorePopup {
                            Text("+\(points)")
                                .font(.title).bold()
                                .foregroundStyle(.yellow)
                                .offset(y: 50)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Огонь комбо
                        if showComboFire {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.orange.gradient)
                                .offset(x: 40, y: -40)
                                .transition(.scale)
                        }
                    }
                    .frame(width: 130, height: 130)
                    .padding(.vertical)
                    
                    Spacer()
                    
                    // ВОПРОС
                    if let question = currentQuestion {
                        VStack(spacing: 30) {
                            // Слово
                            Text(question.word)
                                .font(.system(size: 46, weight: .bold))
                                .multilineTextAlignment(.center)
                                .offset(x: shakeOffset)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
                                .padding(.horizontal)
                            
                            // Варианты ответов
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(question.options, id: \.self) { option in
                                    Button {
                                        handleAnswer(option)
                                    } label: {
                                        Text(option)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 80)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                            )
                                            .shadow(color: .black.opacity(0.05), radius: 5, y: 3)
                                    }
                                }
                            }
                        }
                        .padding()
                        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                    }
                    
                    Spacer()
                }
            }
        }
        .onAppear { startGame() }
        .onReceive(timer) { _ in
            guard isTimerRunning, !isGameOver else { return }
            if timeRemaining > 0 {
                timeRemaining -= 0.1
            } else {
                gameOver()
            }
        }
    }
    
    var timeColor: Color {
        if timeRemaining > 10 { return .green }
        if timeRemaining > 5 { return .orange }
        return .red
    }
    
    // --- ЛОГИКА ---
    
    struct Question {
        let id = UUID()
        let word: String
        let correctAnswer: String
        let options: [String]
    }
    
    func startGame() {
        score = 0
        comboCount = 0
        timeRemaining = 30.0
        isGameOver = false
        isTimerRunning = true
        nextQuestion()
    }
    
    func nextQuestion() {
        // УМНЫЙ ВЫБОР СЛОВА
        // 1. Сначала ищем те, что пора повторить (Due)
        let dueItems = allItems.filter { $0.nextReviewDate <= Date() && $0.status != .new }
        
        // 2. Если таких нет, берем те, что "В процессе" (Learning)
        let learningItems = allItems.filter { $0.status == .learning }
        
        // 3. Выбираем пул слов с приоритетом
        let targetItem: LearningItem
        
        // Логика вероятности: 70% взять "горящее", 30% взять любое для разнообразия
        if !dueItems.isEmpty && Bool.random() {
            targetItem = dueItems.randomElement()!
        } else if !learningItems.isEmpty {
            targetItem = learningItems.randomElement()!
        } else {
            // Если все выучено или все новое — берем любое
            guard let random = allItems.randomElement() else { return }
            targetItem = random
        }
        
        // Генерируем варианты (дистракторы)
        let distractors = allItems
            .filter { $0.id != targetItem.id }
            .shuffled()
            .prefix(3)
            .map { $0.translation }
        
        let allOptions = (distractors + [targetItem.translation]).shuffled()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentQuestion = Question(word: targetItem.text, correctAnswer: targetItem.translation, options: allOptions)
        }
    }
    
    func handleAnswer(_ answer: String) {
        guard let current = currentQuestion else { return }
        
        if answer == current.correctAnswer {
            // ПРАВИЛЬНО
            comboCount += 1
            
            // Расчет очков с учетом комбо (макс x5)
            let multiplier = min(comboCount, 5)
            let points = 10 * multiplier
            score += points
            
            // Бонус времени
            let bonus = 2.0
            timeRemaining += bonus
            if timeRemaining > 45 { timeRemaining = 45 } // Кэп времени
            
            // Визуальная обратная связь
            showFloatingText(bonus) // Время
            showScorePopup(points)  // Очки
            
            // Звук зависит от комбо
            if comboCount >= 3 {
                AudioManager.shared.play(.success) // Триумфальный звук
                withAnimation { showComboFire = true }
            } else {
                AudioManager.shared.play(.click)
            }
            
            HapticManager.shared.impact(style: .medium)
            
            nextQuestion()
            
        } else {
            // ОШИБКА
            comboCount = 0
            withAnimation { showComboFire = false }
            
            let penalty = -5.0
            timeRemaining += penalty
            showFloatingText(penalty)
            
            AudioManager.shared.play(.error)
            HapticManager.shared.notification(type: .error)
            
            // Тряска
            withAnimation(.default) { shakeOffset = 10 }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.2).repeatCount(3)) { shakeOffset = 0 }
        }
    }
    
    // Анимация всплывающего текста (Время)
    func showFloatingText(_ value: Double) {
        withAnimation { timeAdded = value }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { timeAdded = nil }
        }
    }
    
    // Анимация всплывающего текста (Очки)
    func showScorePopup(_ value: Int) {
        withAnimation { scorePopup = value }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { scorePopup = nil }
        }
    }
    
    func gameOver() {
        isTimerRunning = false
        isGameOver = true
        AudioManager.shared.play(.levelUp)
        HapticManager.shared.notification(type: .success)
        
        let coinsEarned = score / 10
        if coinsEarned > 0 {
            StoreManager.shared.addCoins(coinsEarned)
            QuestManager.shared.progress(.coinCollector, amount: coinsEarned)
        }
    }
    
    func restartGame() {
        startGame()
    }
}

// --- ЭКРАН GAME OVER (С МОНЕТКАМИ) ---

struct GameOverView: View {
    let score: Int
    let onRestart: () -> Void
    let onClose: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Иконка результата
            Image(systemName: score > 100 ? "crown.fill" : (score > 0 ? "trophy.fill" : "flag.fill"))
                .font(.system(size: 80))
                .foregroundStyle(score > 100 ? .yellow : (score > 0 ? .orange : .gray))
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .shadow(color: .orange.opacity(0.5), radius: 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.5)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear { isAnimating = true }
            
            VStack(spacing: 15) {
                Text("Игра окончена".localized)
                    .font(.largeTitle).bold()
                
                Text("Твой счет:".localized)
                    .font(.title3).foregroundStyle(.secondary)
                
                Text("\(score)")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                
                if score > 0 {
                    HStack {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("+\(score / 10) золота")
                            .bold()
                    }
                    .font(.title3)
                    .padding()
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(16)
                }
            }
            
            Spacer()
            
            VStack(spacing: 15) {
                Button(action: onRestart) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Играть снова".localized)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                }
                
                Button(action: onClose) {
                    Text("Выйти".localized)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

