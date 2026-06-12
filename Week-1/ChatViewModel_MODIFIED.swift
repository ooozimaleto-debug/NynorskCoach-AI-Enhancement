import SwiftUI
import SwiftData
import AVFoundation

@MainActor
@Observable
class ChatViewModel {
    
    // MARK: - State
    var messages: [ChatMessage] = []
    var apiHistory: [OpenAIMessageContent] = []
    
    var inputText = ""
    var isLoading = false
    
    // Sheet state
    var selectedWord: ChatSelectedWord?
    
    // MARK: - NEW: Context Management & User Profiling
    private let contextManager = UserContextManager.shared
    var currentMentor: Mentor = .freya
    var currentScenario: PracticeScenario?
    var sessionStartTime: Date = Date()
    
    // Track corrections for adaptive learning
    var mistakesInSession: [String] = []
    var correctAnswersInSession: Int = 0
    
    // MARK: - Actions
    
    func startChat(scenario: PracticeScenario, mentor: Mentor, userLevel: String, userRank: VikingRank) {
        // Only start if empty to avoid reset on screen rotate/reappear
        if messages.isEmpty {
            self.currentMentor = mentor
            self.currentScenario = scenario
            self.sessionStartTime = Date()
            
            // ENHANCED: Build context-aware system prompt instead of static one
            let contextPrompt = buildContextAwareSystemPrompt(
                scenario: scenario,
                mentor: mentor,
                userLevel: userLevel,
                userRank: userRank
            )
            
            apiHistory.append(OpenAIMessageContent(role: "system", content: contextPrompt))
            
            let introText = scenario.initialMessage
            messages.append(ChatMessage(isUser: false, text: introText))
            apiHistory.append(OpenAIMessageContent(role: "assistant", content: introText))
            
            // Track session start
            contextManager.sessionContext.recordMessage()
        }
    }
    
    func sendMessage(rank: VikingRank) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMsg = ChatMessage(isUser: true, text: text)
        messages.append(userMsg)
        
        inputText = ""
        isLoading = true
        AudioManager.shared.play(.click)
        
        Task {
            do {
                // ENHANCED: Analyze user message before sending
                let analysis = contextManager.analyzeUserMessage(text)
                
                // Track mistakes for session analysis
                if !analysis.isCorrect {
                    mistakesInSession.append(contentsOf: analysis.grammarErrors)
                    contextManager.sessionContext.recordMistake(analysis.grammarErrors.joined(separator: ", "))
                } else {
                    correctAnswersInSession += 1
                    contextManager.sessionContext.recordCorrectAnswer()
                }
                
                let response = try await OpenAIService.shared.chatWithAI(
                    history: apiHistory,
                    newMessage: text,
                    rank: rank
                )
                
                await MainActor.run {
                    apiHistory.append(OpenAIMessageContent(role: "user", content: text))
                    apiHistory.append(OpenAIMessageContent(role: "assistant", content: response.reply))
                    
                    let mentorMsg = ChatMessage(
                        isUser: false,
                        text: response.reply,
                        corrections: response.corrections ?? []
                    )
                    messages.append(mentorMsg)
                    
                    isLoading = false
                    HapticManager.shared.impact(style: .light)
                    
                    // Update session context
                    contextManager.sessionContext.recordMessage()
                }
            } catch {
                await MainActor.run {
                    print("Chat Error: \(error)")
                    // Show actual error for debugging
                    let errorMsg = "Ошибка: \(error.localizedDescription)"
                    messages.append(ChatMessage(isUser: false, text: errorMsg))
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - NEW: Context-Aware System Prompt Builder
    private func buildContextAwareSystemPrompt(
        scenario: PracticeScenario,
        mentor: Mentor,
        userLevel: String,
        userRank: VikingRank
    ) -> String {
        // Use contextManager to build personalized prompt
        let basePrompt = contextManager.buildSystemPrompt(for: mentor)
        
        let scenarioContext = """
        ═══════════════════════════════════════════════════════
        SCENARIO CONTEXT:
        ═══════════════════════════════════════════════════════
        Scenario: \(scenario.title)
        Your Role: \(scenario.role)
        User's Role: Student
        
        INSTRUCTIONS:
        - Act as the Role (\(scenario.role)), but keep the underlying personality traits of the Mentor.
        - If the user makes grammar mistakes, briefly correct them (in character), then continue the roleplay.
        - Stay in character throughout the conversation.
        """
        
        return basePrompt + "\n\n" + scenarioContext
    }
    
    // MARK: - NEW: End Session & Update Profile
    func endSession() {
        let sessionDurationMinutes = Int(Date().timeIntervalSince(sessionStartTime) / 60)
        let totalAnswers = correctAnswersInSession + mistakesInSession.count
        let accuracyRate = totalAnswers > 0 ? Double(correctAnswersInSession) / Double(totalAnswers) : 0.0
        
        let performance = SessionPerformance(
            accuracyRate: accuracyRate,
            mistakeCategories: mistakesInSession,
            xpEarned: Double(correctAnswersInSession * 10),
            durationMinutes: sessionDurationMinutes
        )
        
        contextManager.updateProfileAfterSession(performance: performance)
        
        // Reset session data
        mistakesInSession.removeAll()
        correctAnswersInSession = 0
        sessionStartTime = Date()
    }
    
    // MARK: - NEW: Get User Profile Info
    func getUserProfileSummary() -> String {
        let profile = contextManager.userProfile
        return """
        Level: \(profile.proficiencyLevel)/5
        Streak: \(profile.currentStreak) 🔥
        Hours: \(profile.totalHoursLearned)h
        """
    }
}
