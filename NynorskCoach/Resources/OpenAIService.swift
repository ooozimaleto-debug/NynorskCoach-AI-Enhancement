import Foundation
import SwiftUI

// MARK: - СТРУКТУРЫ ОТВЕТОВ

struct WordResult: Codable {
    let text: String
    let gender: String
    let translation: String
    let transcription: String?
    let context: String
    let contextTranslation: String
    let imageKeyword: String
    // Грамматика
    let partOfSpeech: String // "verb", "noun", "adj", "other"
    let forms: [String]      // Массив форм
    // Доп примеры
    let pastExamples: [String]?
    let futureExamples: [String]?
}

struct BulkWordResult: Codable {
    let words: [WordResult]
}

struct StoryResult: Codable {
    let title: String; let content: String; let difficulty: String
}
struct RetranslateResult: Codable {
    let original: String; let translation: String; let contextTranslation: String
}
struct BulkRetranslateResponse: Codable {
    let items: [RetranslateResult]
}
struct DialogueResult: Codable {
    let title: String; let lines: [DialogueLine]
}

struct ChatResponse: Codable {
    let reply: String; let corrections: [ChatCorrection]?
}
struct SimpleChatResponse: Codable {
    let reply: String
}

struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
}
struct OpenAIChoice: Decodable {
    let message: OpenAIMessageContent
}
struct OpenAIMessageContent: Decodable, Encodable {
    let role: String; let content: String
}

// MARK: - СЕРВИС

class OpenAIService {
    static let shared = OpenAIService()
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        return URLSession(configuration: config)
    }()
    
    private let jsonDecoder = JSONDecoder()
    
    private var targetLanguage: String {
        return UserDefaults.standard.string(forKey: "nativeLanguage") ?? "Russian"
    }
    
    private init() {}
    
    private func cleanJSON(_ text: String) -> String {
        var clean = text
        // 1. Remove markdown markers
        let markers = ["```json", "```"]
        for marker in markers {
            clean = clean.replacingOccurrences(of: marker, with: "")
        }
        
        // 2. Find JSON start and end
        if let firstMeta = clean.firstIndex(of: "{"), let lastMeta = clean.lastIndex(of: "}") {
            let range = firstMeta...lastMeta
            clean = String(clean[range])
        } else if let firstArray = clean.firstIndex(of: "["), let lastArray = clean.lastIndex(of: "]") {
             let range = firstArray...lastArray
             clean = String(clean[range])
        }
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - NETWORK REQUEST (С RETRY ЛОГИКОЙ)
    
    private func performNetworkRequest<T: Decodable>(
        messages: [OpenAIMessageContent],
        model: AIModel = .balanced,
        requireJSON: Bool = true,
        maxRetries: Int = 4 // Increased from 3 to 4
    ) async throws -> T {
        // Выбор API ключа и URL в зависимости от провайдера
        let apiKey: String
        let urlString: String
        
        switch model.provider {
        case .deepseek:
            apiKey = Secrets.deepSeekKey
            urlString = Secrets.deepSeekURL
        case .openai:
            apiKey = Secrets.openAIKey
            urlString = Secrets.apiURL
        }
        
        guard !apiKey.isEmpty else {
            print("❌ ОШИБКА: API ключ для \(model.provider) не настроен")
            throw OpenAIError.invalidAPIKey
        }
        
        guard let url = URL(string: urlString) else {
            throw OpenAIError.unknown
        }
        
        var lastError: Error?
        
        // Retry loop
        for attempt in 1...maxRetries {
            do {
                // Создаем запрос
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Формируем body с параметрами модели
                var body: [String: Any] = [
                    "model": model.name,
                    "messages": messages.map { ["role": $0.role, "content": $0.content] },
                    "temperature": model.temperature
                ]
                
                if requireJSON {
                    body["response_format"] = ["type": "json_object"]
                }
                
                if let maxTokens = model.maxTokens {
                    body["max_tokens"] = maxTokens
                }
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                print("🚀 API Request: \(model.description), Attempt: \(attempt)/\(maxRetries)")
                
                // Выполняем запрос
                let (data, response) = try await session.data(for: request)
                
                // Проверяем HTTP статус
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        let error = OpenAIError.from(statusCode: httpResponse.statusCode)
                        print("❌ \(error.developerInfo)")
                        
                        // Если rate limit - ждем и повторяем
                        if httpResponse.statusCode == 429 && attempt < maxRetries {
                            let waitTime = min(attempt * 4, 30) // 4, 8, 12... макс 30 сек
                            print("⏳ Rate limit. Waiting \(waitTime)s before retry...")
                            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                            continue
                        }
                        
                        throw error
                    }
                }
                
                // Парсим ответ
                do {
                    let apiResponse = try jsonDecoder.decode(OpenAIResponse.self, from: data)
                    let rawContent = apiResponse.choices.first?.message.content ?? "{}"
                    let cleanContent = cleanJSON(rawContent)
                    
                    guard let contentData = cleanContent.data(using: .utf8) else {
                        throw OpenAIError.parsingError
                    }
                    
                    let result = try jsonDecoder.decode(T.self, from: contentData)
                    print("✅ API Success: \(model.description)")
                    return result
                    
                } catch {
                    print("❌ ОШИБКА ПАРСИНГА: \(error)")
                    if let str = String(data: data, encoding: .utf8) {
                        print("📩 RAW RESPONSE: \(str.prefix(500))")
                    }
                    throw OpenAIError.parsingError
                }
                
            } catch let error as OpenAIError {
                lastError = error
                // Если это не rate limit, не повторяем
                if error != .rateLimitExceeded {
                    throw error
                }
            } catch {
                lastError = error
                // Общая ошибка - ждем и повторяем
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 сек
                    continue
                }
            }
        }
        
        // Если все попытки провалились
        throw lastError ?? OpenAIError.unknown
    }
    
    // MARK: - SEND REQUEST (ОБНОВЛЕНО)
    
    private func sendRequest<T: Decodable>(
        systemPrompt: String,
        userPrompt: String,
        model: AIModel = .balanced,
        requireJSON: Bool = true
    ) async throws -> T {
        let messages = [
            OpenAIMessageContent(role: "system", content: systemPrompt),
            OpenAIMessageContent(role: "user", content: userPrompt)
        ]
        return try await performNetworkRequest(
            messages: messages,
            model: model,
            requireJSON: requireJSON
        )
    }
    
    // MARK: - ГЛАЗ ОДИНА (Vision API)
    
    /// Универсальный метод для Vision запросов (внутренний)
    private func performVisionAPIRequest<T: Decodable>(imageData: Data, prompt: String) async throws -> T {
        let base64Image = imageData.base64EncodedString()
        
        let messageContent: [String: Any] = [
            "role": "user",
            "content": [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
            ]
        ]
        
        return try await performVisionRequest(messageContent: messageContent)
    }

    /// Общий анализ изображения (для режима Describe)
    func analyzeImage(imageData: Data) async throws -> ChatResponse {
        let prompt = "Describe this image in detail. Return JSON: { \"reply\": \"...\" }"
        return try await performVisionAPIRequest(imageData: imageData, prompt: prompt)
    }
    
    /// ГЛАЗ ОДИНА: Распознавание предмета
    func identifyImage(imageData: Data) async throws -> ObjectResult {
        let lang = targetLanguage
        let prompt = """
        Identify the main object in this image. 
        Return ONLY valid JSON.
        
        {
            "object": "[Nynorsk name with article, e.g. 'ein katt']",
            "translation": "[\(lang) translation]",
            "description": "[Fun 2-3 sentence description in Nynorsk]"
        }
        """
        return try await performVisionAPIRequest(imageData: imageData, prompt: prompt)
    }
    
    private func performVisionRequest<T: Decodable>(messageContent: [String: Any]) async throws -> T {
        guard let url = URL(string: Secrets.apiURL) else { throw URLError(.badURL) }
        let cleanKey = Secrets.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var lastError: Error?
        let maxRetries = 3
        
        for attempt in 1...maxRetries {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "model": "gpt-4o",
                    "messages": [messageContent],
                    "response_format": ["type": "json_object"],
                    "max_tokens": 500
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                print("🚀 Vision Request attempt \(attempt)/\(maxRetries)")
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        let error = OpenAIError.from(statusCode: httpResponse.statusCode)
                        print("❌ Vision API Error: \(error.developerInfo)")
                        
                        if httpResponse.statusCode == 429 && attempt < maxRetries {
                            try await Task.sleep(nanoseconds: 2_000_000_000)
                            continue
                        }
                        throw error
                    }
                }
                
                let apiResponse = try jsonDecoder.decode(OpenAIResponse.self, from: data)
                let rawContent = apiResponse.choices.first?.message.content ?? "{}"
                let cleanContent = cleanJSON(rawContent)
                
                guard let contentData = cleanContent.data(using: .utf8) else {
                    throw OpenAIError.parsingError
                }
                
                return try jsonDecoder.decode(T.self, from: contentData)
                
            } catch {
                lastError = error
                print("⚠️ Vision retry error: \(error)")
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(attempt))
                    continue
                }
            }
        }
        
        throw lastError ?? OpenAIError.unknown
    }
    
    // MARK: - МЕТОДЫ ГЕНЕРАЦИИ
    
    // 1. ПЕРЕВОД (С ГРАММАТИКОЙ)
    func translateWord(_ input: String) async throws -> WordResult {
        let lang = targetLanguage
        let prompt = """
        Analyze Nynorsk word: "\(input)". Translate to: \(lang).
        Target Language MUST BE: \(lang).
        
        GRAMMAR TASKS:
        1. Determine Gender: EXACTLY "masculine", "feminine", "neuter" or "none".
        2. Determine PartOfSpeech: EXACTLY "noun", "verb", "adj", or "other".
        3. Forms: Clean string array (e.g. ["bil", "bilen", "bilar", "bilane"]).
           - Noun: [Indef.Sg, Def.Sg, Indef.Pl, Def.Pl]
           - Verb: [Infinitive (with 'å'), Presens, Preteritum, Perfektum]
           - Adj: [Masc/Fem, Neuter, Plural]
        
        EXAMPLES TASK:
        - Generate 3 short Nynorsk sentences using the word in PAST tense.
        - Generate 3 short Nynorsk sentences using the word in FUTURE tense.
        
        JSON FORMAT:
        { 
            "text": "normalized_word", 
            "gender": "masculine", 
            "translation": "TRANSLATION", 
            "transcription": "[IPA]", 
            "context": "Main example sentence", 
            "contextTranslation": "Translation of main sentence", 
            "imageKeyword": "sf_symbol_name",
            "partOfSpeech": "noun",
            "forms": ["f1", "f2", "f3", "f4"],
            "pastExamples": ["Past 1", "Past 2", "Past 3"],
            "futureExamples": ["Future 1", "Future 2", "Future 3"]
        }
        """
        return try await sendRequest(systemPrompt: "Dictionary API. Strict JSON.", userPrompt: prompt)
    }
    
    // 2. Волшебная палочка
    func translateToNynorsk(_ input: String) async throws -> String {
        let prompt = "Translate to Nynorsk: \"\(input)\". JSON: { \"reply\": \"TEXT\" }"
        let r: SimpleChatResponse = try await sendRequest(systemPrompt: "Translator.", userPrompt: prompt)
        return r.reply
    }
    
    // 3. Генерация группы слов
    func generateBulkWords(topicName: String, level: String) async throws -> [WordResult] {
        let lang = targetLanguage
        let prompt = "Generate 10 Nynorsk words for topic '\(topicName)'. Level \(level). Target Lang: \(lang). Include grammar forms, gender, and empty examples arrays. JSON: { \"words\": [...] }"
        let res: BulkWordResult = try await sendRequest(systemPrompt: "JSON Generator.", userPrompt: prompt)
        return res.words
    }
    
    // 4. История
    func generateStory(topic: String, level: String) async throws -> StoryResult {
        let prompt = "Story about \(topic) in Nynorsk. Level \(level). JSON: { \"title\": \"...\", \"content\": \"...\", \"difficulty\": \"...\" }"
        return try await sendRequest(systemPrompt: "Writer.", userPrompt: prompt)
    }
    
    // 5. Диалог
    func generateDialogue(topic: String) async throws -> DialogueResult {
        let prompt = "Dialogue (A/B) about \(topic). JSON: { \"title\": \"...\", \"lines\": [...] }"
        return try await sendRequest(systemPrompt: "Writer.", userPrompt: prompt)
    }
    
    // 6. Массовый перевод
    func retranslateBatch(items: [LearningItem]) async throws -> [RetranslateResult] {
        let prompt = "Retranslate items. JSON: { \"items\": [...] }"
        let r: BulkRetranslateResponse = try await sendRequest(systemPrompt: "Translator.", userPrompt: prompt)
        return r.items
    }
    
    // 7. Простой чат
    func generateSimpleChatResponse(systemPrompt: String, userMessage: String) async throws -> String {
        let prompt = "SYS: \(systemPrompt). USER: \(userMessage). JSON: { \"reply\": \"...\" }"
        let r: SimpleChatResponse = try await performNetworkRequest(messages: [OpenAIMessageContent(role: "user", content: prompt)])
        return r.reply
    }
    
    // 8. Умный чат (Наставник) - ОБНОВЛЕНО С MENTOR PERSONALIZER
    func chatWithAI(
        history: [OpenAIMessageContent],
        newMessage: String,
        rank: VikingRank,
        scenario: String = "general",
        contextSize: Int = 20
    ) async throws -> ChatResponse {
        let lang = targetLanguage
        let savedMentorID = UserDefaults.standard.string(forKey: "selectedMentor") ?? Mentor.freya.rawValue
        let mentor = Mentor(rawValue: savedMentorID) ?? .freya
        
        // Используем MentorPersonalizer для генерации промпта
        let systemPrompt = MentorPersonalizer.getSystemPrompt(
            mentor: mentor,
            task: .chat(scenario: scenario),
            userRank: rank,
            targetLanguage: lang
        )
        
        var msgs = [OpenAIMessageContent(role: "system", content: systemPrompt)]
        msgs.append(contentsOf: history.suffix(contextSize))  // Гибкий контекст
        msgs.append(OpenAIMessageContent(role: "user", content: newMessage))
        
        return try await performNetworkRequest(
            messages: msgs,
            model: .balanced  // GPT-4o-mini для чата
        )
    }
    
    // 9. Озвучка (OpenAI TTS)
    func generateSpeech(text: String, mentor: Mentor? = nil) async throws -> Data {
        guard !Secrets.openAIKey.isEmpty else { throw OpenAIError.invalidAPIKey }
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else { throw OpenAIError.unknown }
        
        // Определяем наставника
        let targetMentor: Mentor
        if let mentor = mentor {
            targetMentor = mentor
        } else {
            let savedID = UserDefaults.standard.string(forKey: "selectedMentor") ?? Mentor.freya.rawValue
            targetMentor = Mentor(rawValue: savedID) ?? .freya
        }
        
        // Параметры
        let voice = targetMentor.openAIVoice
        let savedSpeed = UserDefaults.standard.double(forKey: "speechVelocity")
        let speed = (savedSpeed == 0) ? 1.0 : savedSpeed
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let cleanKey = Secrets.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Используем tts-1-hd для лучшего качества
        let body: [String: Any] = [
            "model": "tts-1-hd",
            "input": text,
            "voice": voice,
            "response_format": "mp3",
            "speed": speed
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw OpenAIError.from(statusCode: httpResponse.statusCode)
        }
        
        return data
    }
    
    // 10. Метод для ChatView
    func sendChatHistory(_ dbHistory: [PersistedMessage], for persona: Mentor) async throws -> String {
        let systemMsg = OpenAIMessageContent(role: "system", content: persona.systemInstruction)
        let chatHistory = dbHistory.map { msg in
            OpenAIMessageContent(role: msg.role, content: msg.content)
        }
        var fullHistory = [systemMsg]
        fullHistory.append(contentsOf: chatHistory)
        
        let response: SimpleChatResponse = try await performNetworkRequest(messages: fullHistory)
        return response.reply
    }
    
    // 11. Грамматика - ОБНОВЛЕНО С MENTOR PERSONALIZER
    func checkGrammar(text: String, rank: VikingRank) async throws -> ChatResponse {
        let lang = targetLanguage
        let savedMentorID = UserDefaults.standard.string(forKey: "selectedMentor") ?? Mentor.freya.rawValue
        let mentor = Mentor(rawValue: savedMentorID) ?? .freya
        
        // Используем MentorPersonalizer
        let systemPrompt = MentorPersonalizer.getSystemPrompt(
            mentor: mentor,
            task: .grammar,
            userRank: rank,
            targetLanguage: lang
        )
        
        let userPrompt = "INPUT TEXT: \"\(text)\""
        
        return try await sendRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            model: .precise  // GPT-4o-mini для грамматики
        )
    }
    
    // MARK: - НОВЫЕ МЕТОДЫ (С УЧЕТОМ СЛОВАРЯ ПОЛЬЗОВАТЕЛЯ)
    
    // 12. Генерация истории с учетом словаря (15% новых слов)
    func generateStoryWithVocabulary(
        topic: String,
        difficulty: String,
        userKnownWords: [String],
        mentor: Mentor? = nil,
        rank: VikingRank
    ) async throws -> StoryResult {
        let lang = targetLanguage
        let savedMentorID = UserDefaults.standard.string(forKey: "selectedMentor") ?? Mentor.freya.rawValue
        let actualMentor = mentor ?? (Mentor(rawValue: savedMentorID) ?? .freya)
        
        // Используем MentorPersonalizer
        let systemPrompt = MentorPersonalizer.getSystemPrompt(
            mentor: actualMentor,
            task: .storyGeneration(userKnownWords: userKnownWords),
            userRank: rank,
            targetLanguage: lang
        )
        
        let params = getDifficultyParams(level: difficulty)
        
        let userPrompt = """
        TOPIC: \(topic)
        DIFFICULTY: \(difficulty).
        
        INSTRUCTIONS:
        - Length: \(params.lengthDescription)
        - Complexity: \(params.complexityDescription)
        - Vocabulary: \(params.vocabStyle)
        
        Generate a story following the 15% new words rule.
        Make it engaging and appropriate for the level.
        """
        
        return try await sendRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            model: .creative
        )
    }
    
    // 13. Генерация подкаста с учетом словаря (15% новых слов)
    func generatePodcastWithVocabulary(
        topic: String,
        difficulty: String,
        userKnownWords: [String],
        mentor: Mentor? = nil,
        rank: VikingRank
    ) async throws -> DialogueResult {
        let lang = targetLanguage
        let savedMentorID = UserDefaults.standard.string(forKey: "selectedMentor") ?? Mentor.freya.rawValue
        let actualMentor = mentor ?? (Mentor(rawValue: savedMentorID) ?? .freya)
        
        // Используем MentorPersonalizer
        let systemPrompt = MentorPersonalizer.getSystemPrompt(
            mentor: actualMentor,
            task: .podcastGeneration(userKnownWords: userKnownWords),
            userRank: rank,
            targetLanguage: lang
        )
        
        let params = getDifficultyParams(level: difficulty)
        
        // Explicitly ask for specific JSON structure for DialogueResult
        let userPrompt = """
        TOPIC: \(topic)
        DIFFICULTY: \(difficulty)
        
        INSTRUCTIONS:
        - Length: \(params.lengthDescription)
        - Complexity: \(params.complexityDescription)
        - Vocabulary: \(params.vocabStyle)
        
        Generate a podcast script as a DIALOGUE between Person A (Viking) and Person B (Valkyrie).
        Use natural spoken Nynorsk.
        
        JSON FORMAT: 
        { 
            "title": "Title", 
            "lines": [
                {"speaker": "A", "text": "Hei..."}, 
                {"speaker": "B", "text": "God dag..."}
            ] 
        }
        """
        
        return try await sendRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            model: .creative
        )
    }
    
    // Helper for difficulty params
    private func getDifficultyParams(level: String) -> (lengthDescription: String, complexityDescription: String, vocabStyle: String) {
        switch level.uppercased() {
        case "A1":
            return (
                "Short (approx 4 paragraphs).",
                "Simple sentences. Basic grammar.",
                "High frequency words only."
            )
        case "A2":
            return (
                "Medium length (approx 200-250 words).",
                "Simple but cohesive story. Introduction of past tense.",
                "Core vocabulary with some variety."
            )
        case "B1":
            return (
                "Longer (approx 350-400 words).",
                "More complex sentences (subordinate clauses).",
                "Use synonyms for known words. Express opinions."
            )
        case "B2":
            return (
                "Long (approx 500 words).",
                "Complex flow. Nuanced arguments.",
                "Idiomatic expressions. Rich descriptions."
            )
        case "C1", "C2":
            return (
                "Very long (600+ words).",
                "Sophisticated structure.",
                "Advanced, academic or literary vocabulary."
            )
        default: // Fallback like A2
            return (
                "Medium length.",
                "Standard storytelling.",
                "Balanced vocabulary."
            )
        }
    }
    
    // 14. Проверка описания картинки (упражнение "Опиши картинку")
    func checkImageDescription(
        imageData: Data,
        userDescription: String,
        mentor: Mentor? = nil,
        rank: VikingRank
    ) async throws -> ChatResponse {
        let lang = targetLanguage
        let savedMentorID = UserDefaults.standard.string(forKey: "selectedMentor") ?? Mentor.freya.rawValue
        let actualMentor = mentor ?? (Mentor(rawValue: savedMentorID) ?? .freya)
        
        // Используем MentorPersonalizer
        let systemPrompt = MentorPersonalizer.getSystemPrompt(
            mentor: actualMentor,
            task: .imageDescriptionCheck(userDescription: userDescription),
            userRank: rank,
            targetLanguage: lang
        )
        
        return try await performVisionAPIRequest(imageData: imageData, prompt: systemPrompt)
    }
    
    // 15. Получить список известных слов пользователя (helper)
    func getUserKnownWords(from items: [LearningItem], maxWords: Int = 200) -> [String] {
        // Берем слова с interval > 0 (хотя бы раз повторенные)
        return items
            .filter { $0.interval > 0 }
            .sorted { $0.interval > $1.interval }  // Сначала самые знакомые
            .prefix(maxWords)
            .map { $0.text.lowercased() }
    }

    // 16. Анализ ошибок экзамена (НОВОЕ)
    func analyzeMistakes(mistakes: [ExamMistake], mentor: Mentor, userRank: VikingRank) async throws -> AnalysisResponse {
        let lang = targetLanguage
        
        let mistakesText = mistakes.map { "- \($0.word) (User wrote: \($0.userAnswer), Correct: \($0.correctAnswer))" }.joined(separator: "\n")
        
        let systemPrompt = """
        SYSTEM ROLE: You are an expert Nynorsk tutor playing the persona of \(mentor.displayName).
        USER LEVEL: \(userRank.rawValue).
        LANGUAGE: Explain in \(lang).
        
        TASK: Analyze exams mistakes and return a JSON object.
        
        MISTAKES:
        \(mistakesText)
        
        NEGATIVE CONSTRAINT: DO NOT USE BOKMÅL. EXAMPLES MUST BE NYNORSK.
        
        INSTRUCTIONS:
        1. "reaction": A short, emotional comment from the Mentor (Odin=Angry/Strict, Loki=Sarcastic, Freya=Supportive).
        2. "corrections": An array of objects, one for EACH mistake.
           - "word": The word in question.
           - "correction": The correct form.
           - "explanation": Detailed explanation WHY it's wrong (mention grammar rules like V2, Gender, Definite forms).
           - "example": A simple example sentence using the word correctly.
        
        REQUIRED JSON FORMAT:
        {
            "reaction": "String",
            "corrections": [
                {
                    "word": "String",
                    "correction": "String",
                    "explanation": "String",
                    "example": "String"
                }
            ]
        }
        """
        
        let userPrompt = "Analyze these mistakes. Output strict JSON."
        
        // Используем gpt-4o-mini (balanced) с JSON mode
        return try await sendRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            model: .balanced,
            requireJSON: true
        )
    }
}

