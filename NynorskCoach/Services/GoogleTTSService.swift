import Foundation
import SwiftUI

class GoogleTTSService {
    static let shared = GoogleTTSService()
    
    private init() {}
    
    // Структура ответа от Google
    private struct GoogleResponse: Decodable {
        let audioContent: String
    }
    
    // 1. ПУБЛИЧНЫЙ МЕТОД ДЛЯ СЛОВ
    func generateSpeech(text: String, mentor: Mentor? = nil, rate: Double? = nil) async throws -> Data {
        // Определяем наставника (переданный или текущий выбранный)
        let targetMentor: Mentor
        if let mentor = mentor {
            targetMentor = mentor
        } else {
            let savedID = UserDefaults.standard.string(forKey: "selectedMentor") ?? Mentor.freya.rawValue
            targetMentor = Mentor(rawValue: savedID) ?? .freya
        }

        return try await fetchAudio(
            text: text,
            voiceName: targetMentor.googleVoiceName,
            pitch: targetMentor.googlePitch,
            rate: rate
        )
    }
    
    // 2. ПУБЛИЧНЫЙ МЕТОД ДЛЯ ПОДКАСТОВ (PodcastView)
    func enrichDialogue(lines: [DialogueLine]) async throws -> [DialogueLine] {
        var enrichedLines = lines
        
        // Голоса для ролей
        // A - Викинг (Мужской) -> Используем базу Одина/Локи
        // B - Валькирия (Женский) -> Используем базу Фреи
        let voiceA = Mentor.odin.googleVoiceName // Male
        let voiceB = Mentor.freya.googleVoiceName // Female
        
        // Питч для А сделаем чуть ниже, чтобы отличался
        let pitchA = -2.0
        let pitchB = 0.0
        
        print("🎙 Начинаем озвучку диалога (\(lines.count) реплик)...")
        
        for i in 0..<enrichedLines.count {
            let line = enrichedLines[i]
            let isSpeakerA = (line.speaker == "A")
            let voice = isSpeakerA ? voiceA : voiceB
            let pitch = isSpeakerA ? pitchA : pitchB
            
            // Небольшая пауза перед запросом
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 сек
            
            if let audio = try? await fetchAudio(text: line.text, voiceName: voice, pitch: pitch) {
                enrichedLines[i].audioData = audio
            } else {
                print("⚠️ Ошибка озвучки строки: \(line.text)")
            }
        }
        
        return enrichedLines
    }
    
    // 3. ПРИВАТНЫЙ МЕТОД ЗАПРОСА (ЯДРО)
    private func fetchAudio(text: String, voiceName: String, pitch: Double = 0.0, rate: Double? = nil) async throws -> Data {
        let urlString = "\(Secrets.workerBaseURL)/v1/ai/google-tts"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        // Скорость речи: явный override (rate) в приоритете, иначе — из настроек (0.25 - 4.0)
        let savedSpeed = UserDefaults.standard.double(forKey: "speechVelocity")
        let speakingRate = rate ?? ((savedSpeed == 0) ? 1.0 : savedSpeed)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(Secrets.appToken, forHTTPHeaderField: "X-App-Token")
        request.addValue(DeviceIdentity.id, forHTTPHeaderField: "X-Device-ID")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": "nb-NO",
                "name": voiceName
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": speakingRate,
                "pitch": pitch
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let err = String(data: data, encoding: .utf8) { print("Google TTS Error: \(err)") }
            throw URLError(.badServerResponse)
        }
        
        let result = try JSONDecoder().decode(GoogleResponse.self, from: data)
        guard let audioData = Data(base64Encoded: result.audioContent) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return audioData
    }
}
