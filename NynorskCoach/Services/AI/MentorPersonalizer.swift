import Foundation

// MARK: - AI TASK TYPES

/// Типы задач для ИИ (определяет стиль промпта)
enum AITask {
    case chat(scenario: String)
    case grammar
    case wordGeneration
    case storyGeneration(userKnownWords: [String])
    case podcastGeneration(userKnownWords: [String])
    case exam
    case imageDescription
    case imageDescriptionCheck(userDescription: String)
}

// MARK: - MENTOR PERSONALIZER

/// Генерирует system prompts с учетом наставника и задачи
class MentorPersonalizer {
    
    /// Генерирует system prompt для OpenAI API
    /// - Parameters:
    ///   - mentor: Выбранный наставник (Фрея, Локи, Один)
    ///   - task: Тип задачи
    ///   - userRank: Уровень владения языком пользователя
    ///   - targetLanguage: Родной язык пользователя (для переводов)
    /// - Returns: System prompt для API
    static func getSystemPrompt(
        mentor: Mentor,
        task: AITask,
        userRank: VikingRank,
        targetLanguage: String
    ) -> String {
        
        // Базовая личность наставника
        let personality = mentor.systemInstruction
        
        // Директива по языку в зависимости от уровня
        let languageDirective = getLanguageDirective(rank: userRank, targetLanguage: targetLanguage)
        
        // Специфичный промпт для задачи
        let taskPrompt = getTaskPrompt(task: task, mentor: mentor, targetLanguage: targetLanguage)
        
        return """
        \(personality)
        
        \(languageDirective)
        
        \(taskPrompt)
        """
    }
    
    // MARK: - Private Helpers
    
    /// Определяет, на каком языке должен отвечать ИИ
    private static func getLanguageDirective(rank: VikingRank, targetLanguage: String) -> String {
        switch rank {
        case .oppdagar:  // A0 - новичок
            return "OUTPUT LANGUAGE: \(targetLanguage). Teach beginner. Use simple words."
        case .sjofarar:  // A1-A2 - мореход
            return "OUTPUT LANGUAGE: Mix Nynorsk/\(targetLanguage). Explain in both languages."
        case .krigar:    // B1-B2 - воин
            return "OUTPUT LANGUAGE: Mostly Nynorsk. Explain hard parts in \(targetLanguage)."
        case .jarl:      // C1-C2 - ярл
            return "OUTPUT LANGUAGE: Nynorsk only. No translations."
        }
    }
    
    /// Генерирует промпт для конкретной задачи
    private static func getTaskPrompt(task: AITask, mentor: Mentor, targetLanguage: String) -> String {
        switch task {
            
        // ЧАТ (Симуляции: NAV, магазин, врач и т.д.)
        case .chat(let scenario):
            return """
            TASK: Roleplay Conversation
            SCENARIO: \(scenario)
            YOUR ROLE: Act as a native Norwegian speaker in this situation.
            
            MENTOR STYLE:
            - Freya: Warm, patient, encouraging. Use "Min venn", "Kjære".
            - Loki: Sarcastic, witty, playful teasing.
            - Odin: Harsh, commanding, demanding perfection.
            
            Stay in character. Correct mistakes naturally during conversation.
            JSON FORMAT: { "reply": "...", "corrections": [...] }
            """
            
        // ПРОВЕРКА ГРАММАТИКИ
        case .grammar:
            return """
            TASK: Grammar Check Engine
            ANALYZE: User's Nynorsk text for ALL errors.
            
            CRITICAL INSTRUCTION:
            - EXPLAIN errors in \(targetLanguage) ONLY.
            - Provide examples in Nynorsk.
            - Do NOT explain in Nynorsk. The user needs to understand the mistake in their native language.
            
            TEACHING STYLE: Explain WHY it is wrong clearly.
            
            FEEDBACK STYLE:
            - Freya: Gentle corrections. "Bra jobba! Men her kan du seie..."
            - Loki: Sarcastic roasting. "Åh, du gløymde 'å'? Klassisk!"
            - Odin: Zero tolerance. "DETTE ER FEIL! Rett det NÅ!"
            
            JSON FORMAT: { "reply": "feedback", "corrections": [{"original": "...", "corrected": "...", "explanation": "..."}] }
            """
            
        // ГЕНЕРАЦИЯ СЛОВ
        case .wordGeneration:
            return """
            TASK: Generate Nynorsk vocabulary words
            TARGET LANGUAGE: \(targetLanguage)
            
            REQUIREMENTS:
            - Include gender (masculine/feminine/neuter)
            - Include grammar forms (noun: sg/pl, verb: infinitive/present/past)
            - Include IPA transcription
            - Include example sentence + translation
            
            JSON FORMAT: { "words": [...] }
            """
            
        // ГЕНЕРАЦИЯ ИСТОРИИ (с учетом словаря пользователя)
        case .storyGeneration(let userKnownWords):
            return """
            TASK: Generate a story in Nynorsk
            
            INPUT TOPIC: The user might provide a topic in ANY language (e.g. Polish, Ukrainian, English, Bokmål, Russian).
            ACTION: Understand the topic regardless of input language, but generate the story CONTENT mainly in NYNORSK.
            
            VOCABULARY CONSTRAINT (CRITICAL):
            - User knows these words: \(userKnownWords.prefix(100).joined(separator: ", "))
            - Use MAXIMUM 15% new words (unknown to user)
            - This ensures comprehensible input (i+1 principle by Krashen)
            
            Example: If story has 100 words, max 15 can be new.
            
            MENTOR STYLE:
            - Freya: Warm fairy tales, moral lessons
            - Loki: Trickster stories, plot twists
            - Odin: Epic sagas, battles, wisdom
            
            JSON FORMAT: { "title": "...", "content": "...", "difficulty": "..." }
            """
            
        // ГЕНЕРАЦИЯ ПОДКАСТА (с учетом словаря)
        case .podcastGeneration(let userKnownWords):
            return """
            TASK: Generate a podcast script in Nynorsk
            
            INPUT TOPIC: The user might provide a topic in ANY language (e.g. Polish, Ukrainian, Bokmål, English).
            ACTION: Create a dialogue based on the topic, but generate the dialogue CONTENT strictly in NYNORSK matching the level.
            
            VOCABULARY CONSTRAINT (CRITICAL):
            - User knows these words: \(userKnownWords.prefix(100).joined(separator: ", "))
            - Use MAXIMUM 15% new words
            - Natural spoken language style
            
            MENTOR STYLE:
            - Freya: Calm, educational, storytelling
            - Loki: Entertaining, provocative, humorous
            - Odin: Serious, informative, commanding
            
            JSON FORMAT: { "title": "...", "content": "...", "difficulty": "..." }
            """
            
        // ЭКЗАМЕН
        case .exam:
            return """
            TASK: Evaluate user's knowledge
            
            GRADING STYLE:
            - Freya: Encouraging, focus on progress
            - Loki: Honest but sarcastic feedback
            - Odin: Strict, demanding, no mercy
            
            JSON FORMAT: { "reply": "evaluation", "corrections": [...] }
            """
            
        // ОПИСАНИЕ КАРТИНКИ (распознавание)
        case .imageDescription:
            return """
            TASK: Describe image in Nynorsk
            
            STEPS:
            1. Identify main object/scene
            2. Provide Nynorsk name (with gender)
            3. Short fun description in Nynorsk
            4. Translate to \(targetLanguage)
            
            MENTOR STYLE:
            - Freya: Poetic, detailed descriptions
            - Loki: Witty, unexpected observations
            - Odin: Brief, commanding descriptions
            
            JSON FORMAT: { "reply": "description", "corrections": [] }
            """
            
        // ПРОВЕРКА ОПИСАНИЯ КАРТИНКИ (упражнение)
        case .imageDescriptionCheck(let userDescription):
            return """
            TASK: Image Description Exercise
            USER DESCRIPTION: "\(userDescription)"
            
            STEPS:
            1. Analyze the image - what's in it?
            2. Read user's Nynorsk description
            3. Check grammar, vocabulary, completeness
            4. Give feedback IN CHARACTER
            
            FEEDBACK STYLE:
            - Freya: "Bra jobba, min venn! Du såg katten. Men du gløymde å nemne..."
            - Loki: "Åh, du såg katten? Gratulerer! Men du gløymde heile bordet. Klassisk!"
            - Odin: "DU GLØYMDE HALVPARTEN! Sjå nøye! Beskriv ALT!"
            
            JSON FORMAT: { "reply": "feedback", "corrections": [{"original": "...", "corrected": "...", "explanation": "..."}] }
            """
        }
    }
}
