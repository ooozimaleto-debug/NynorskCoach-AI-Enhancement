import Foundation
import SwiftUI
import SwiftData
import Combine
// MARK: - User Learning Profile (Persistent with SwiftData)
@Model
final class UserLearningProfile {
    // Basic info
    @Attribute(.unique) var id: UUID = UUID()
    var createdDate: Date = Date()
    
    // Learning characteristics
    var proficiencyLevel: Int = 1  // 1-5 (A1-C1)
    var learningStyleRaw: String = LearningStyle.visual.rawValue
    var preferredPaceRaw: String = LearningPace.medium.rawValue
    var prefersMoralSupport: Bool = true
    var motivationStyleRaw: String = MotivationType.gamification.rawValue
    
    // Progress tracking
    var totalHoursLearned: Int = 0
    var currentStreak: Int = 0
    var lastSessionDate: Date = Date()
    var weakAreas: [String] = []
    var strongAreas: [String] = []
    
    // Preferences
    var selectedMentorRaw: String = Mentor.freya.rawValue
    var darkModePreferred: Bool = false
    
    // Session statistics
    var totalSessionsCompleted: Int = 0
    var averageSessionDurationMinutes: Int = 0
    var totalXPEarned: Int = 0
    
    init() {}
    
    // Computed properties for convenience
    var learningStyle: LearningStyle {
        LearningStyle(rawValue: learningStyleRaw) ?? .visual
    }
    
    var preferredPace: LearningPace {
        LearningPace(rawValue: preferredPaceRaw) ?? .medium
    }
    
    var motivationStyle: MotivationType {
        MotivationType(rawValue: motivationStyleRaw) ?? .gamification
    }
    
    var selectedMentor: Mentor {
        Mentor(rawValue: selectedMentorRaw) ?? .freya
    }
}

enum LearningStyle: String, Codable, CaseIterable {
    case visual = "Visual"
    case auditory = "Auditory"
    case kinesthetic = "Kinesthetic"
    case readingWriting = "Reading/Writing"
}

enum LearningPace: String, Codable, CaseIterable {
    case slow = "Slow"
    case medium = "Medium"
    case fast = "Fast"
}

enum MotivationType: String, Codable, CaseIterable {
    case gamification = "Gamification"
    case progressFocused = "Progress"
    case social = "Social"
    case intrinsic = "Intrinsic"
}

// MARK: - Session Context (Temporary, in-memory)
struct SessionContext {
    var messageCount: Int = 0
    var startTime: Date = Date()
    var topicsDiscussed: [String] = []
    var mistakesMade: [String] = []
    var correctAnswersCount: Int = 0
    
    var elapsedSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }
    
    var elapsedMinutes: Int {
        elapsedSeconds / 60
    }
    
    mutating func recordMessage() {
        messageCount += 1
    }
    
    mutating func recordMistake(_ error: String) {
        mistakesMade.append(error)
    }
    
    mutating func recordCorrectAnswer() {
        correctAnswersCount += 1
    }
}

// MARK: - User Context Manager (Singleton)
@MainActor
class UserContextManager: ObservableObject {
    static let shared = UserContextManager()
    
    @Published var userProfile: UserLearningProfile
    @Published var sessionContext = SessionContext()
    
    private var modelContext: ModelContext?
    
    init() {
        // Will be set up later when we have access to modelContext
        self.userProfile = UserLearningProfile()
    }
    
    // Call this from App initialization with modelContext
    func setupWithModelContext(_ context: ModelContext) {
        self.modelContext = context
        
        // Load existing profile or create new one
        do {
            let descriptor = FetchDescriptor<UserLearningProfile>()
            if let existingProfile = try context.fetch(descriptor).first {
                self.userProfile = existingProfile
            } else {
                self.userProfile = UserLearningProfile()
                context.insert(self.userProfile)
                try context.save()
            }
        } catch {
            print("Error loading user profile: \(error)")
            self.userProfile = UserLearningProfile()
        }
    }
    
    // MARK: - Build Dynamic System Prompt
    func buildSystemPrompt(for mentor: Mentor) -> String {
        let paceInstruction = buildPaceInstruction()
        let styleInstruction = buildStyleInstruction()
        let baseMentorPrompt = mentor.systemInstruction
        
        return """
        \(baseMentorPrompt)
        
        ═══════════════════════════════════════════════════════
        USER PROFILE:
        ═══════════════════════════════════════════════════════
        Level: \(levelString(userProfile.proficiencyLevel))
        Learning Style: \(userProfile.learningStyle.rawValue)
        Pace Preference: \(userProfile.preferredPace.rawValue)
        Current Streak: \(userProfile.currentStreak) 🔥
        Total Study Time: \(userProfile.totalHoursLearned) hours
        Total Sessions: \(userProfile.totalSessionsCompleted)
        XP Earned: \(userProfile.totalXPEarned)
        
        WEAK AREAS TO FOCUS ON:
        \(userProfile.weakAreas.isEmpty ? "None identified yet" : userProfile.weakAreas.joined(separator: ", "))
        
        STRONG AREAS:
        \(userProfile.strongAreas.isEmpty ? "None yet" : userProfile.strongAreas.joined(separator: ", "))
        
        SESSION INFO:
        ═══════════════════════════════════════════════════════
        Current session duration: \(sessionContext.elapsedMinutes) minutes
        Messages in this session: \(sessionContext.messageCount)
        Time of day: \(getCurrentTimeOfDay())
        
        PERSONALIZATION INSTRUCTIONS:
        ═══════════════════════════════════════════════════════
        \(paceInstruction)
        
        \(styleInstruction)
        
        INTERACTION RULES:
        ═══════════════════════════════════════════════════════
        1. Adjust language complexity to \(levelString(userProfile.proficiencyLevel)) level
        2. Reference their streak (\(userProfile.currentStreak) days!) when appropriate
        3. Focus corrections on their WEAK AREAS: \(userProfile.weakAreas.joined(separator: ", "))
        4. Keep responses 2-4 sentences unless they ask complex questions
        5. Always respond ENTIRELY IN NYNORSK (no English unless absolutely necessary)
        6. If they make the same mistake twice in this session, change your teaching approach
        7. Be encouraging but honest about their progress
        """
    }
    
    // MARK: - Helper: Build Pace Instruction
    private func buildPaceInstruction() -> String {
        switch userProfile.preferredPace {
        case .slow:
            return """
            PACE: Break everything into very small steps.
            - Use simple examples
            - Pause between concepts
            - Ask confirmation questions
            - Repeat key points
            """
        case .medium:
            return """
            PACE: Balanced explanations with practical examples.
            - Conversational rhythm
            - Mix new with review
            - One concept at a time
            """
        case .fast:
            return """
            PACE: Be concise and direct.
            - Skip over basics
            - Jump straight to application
            - Use advanced vocabulary
            - Expect quick comprehension
            """
        }
    }
    
    // MARK: - Helper: Build Style Instruction
    private func buildStyleInstruction() -> String {
        switch userProfile.learningStyle {
        case .visual:
            return """
            STYLE: Use visual representations and formatting.
            Example ASCII diagram:
            
            SENTENCE STRUCTURE:
            [Subject] → [Verb] → [Object]
            Eg: Han read boka (He read the book)
            
            Use **bold** for key words, `code format` for examples
            Include emojis for visual reference
            """
        case .auditory:
            return """
            STYLE: Use storytelling and rhythm.
            - Mention pronunciation patterns: "sounds like..."
            - Use rhyme and rhythm when teaching
            - Suggest listening to native speakers
            - Describe how words "sound" in context
            """
        case .kinesthetic:
            return """
            STYLE: Action-oriented exercises.
            - Suggest role-plays and scenarios
            - Use action verbs in explanations
            - Create mini-exercises they can "do"
            - Suggest real-world applications
            """
        case .readingWriting:
            return """
            STYLE: Written explanations and lists.
            - Provide detailed written rules
            - Suggest reading materials
            - Give them rules to write down
            - Use structured, organized format
            """
        }
    }
    
    // MARK: - Analyze User Message
    func analyzeUserMessage(_ text: String) -> MessageAnalysis {
        var analysis = MessageAnalysis(
            isCorrect: true,
            grammarErrors: [],
            confidenceLevel: .medium,
            estimatedLevel: levelString(userProfile.proficiencyLevel)
        )
        
        // Simple local checks (fast, no API needed)
        
        // Check for common grammar patterns
        if text.contains("eg") && !text.contains("eg ") {
            analysis.grammarErrors.append("Missing space after 'eg'")
            analysis.isCorrect = false
        }
        
        // Check for article usage (common issue in Nynorsk)
        if text.contains("ein ") && text.contains("ein ein") {
            analysis.grammarErrors.append("Doubled article 'ein ein'")
            analysis.isCorrect = false
        }
        
        // Estimate confidence based on length and clarity
        if text.count < 5 {
            analysis.confidenceLevel = .low
        } else if text.count > 50 {
            analysis.confidenceLevel = .high
        }
        
        return analysis
    }
    
    // MARK: - Update Profile After Session
    func updateProfileAfterSession(
        performance: SessionPerformance
    ) {
        // Update proficiency if needed
        if performance.accuracyRate > 0.85 && userProfile.proficiencyLevel < 5 {
            userProfile.proficiencyLevel += 1
            userProfile.preferredPaceRaw = LearningPace.fast.rawValue
        } else if performance.accuracyRate < 0.50 && userProfile.proficiencyLevel > 1 {
            userProfile.preferredPaceRaw = LearningPace.slow.rawValue
        }
        
        // Track weak areas
        performance.mistakeCategories.forEach { category in
            if !userProfile.weakAreas.contains(category) {
                userProfile.weakAreas.append(category)
            }
        }
        
        // Update session stats
        userProfile.totalSessionsCompleted += 1
        userProfile.totalHoursLearned += max(1, sessionContext.elapsedMinutes / 60)
        userProfile.totalXPEarned += Int(performance.xpEarned)
        userProfile.lastSessionDate = Date()
        
        // Save to persistent storage
        if let context = modelContext {
            do {
                try context.save()
            } catch {
                print("Error saving profile: \(error)")
            }
        }
        
        // Reset session context
        sessionContext = SessionContext()
    }
    
    // MARK: - Reset Session
    func resetSessionContext() {
        sessionContext = SessionContext()
    }
}

// MARK: - Supporting Structs

struct MessageAnalysis {
    var isCorrect: Bool
    var grammarErrors: [String]
    var confidenceLevel: ConfidenceLevel
    var estimatedLevel: String
}

enum ConfidenceLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct SessionPerformance {
    let accuracyRate: Double  // 0.0 - 1.0
    let mistakeCategories: [String]
    let xpEarned: Double
    let durationMinutes: Int
}

// MARK: - Helper Functions

func levelString(_ level: Int) -> String {
    switch level {
    case 1: return "A1 (Beginner)"
    case 2: return "A2 (Elementary)"
    case 3: return "B1 (Intermediate)"
    case 4: return "B2 (Upper-Intermediate)"
    case 5: return "C1 (Advanced)"
    default: return "Unknown"
    }
}

func getCurrentTimeOfDay() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour < 12 {
        return "morning"
    } else if hour < 17 {
        return "afternoon"
    } else {
        return "evening"
    }
}
