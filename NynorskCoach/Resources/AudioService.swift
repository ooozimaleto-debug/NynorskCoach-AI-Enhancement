import AVFoundation
import UIKit
import CryptoKit

@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = SpeechService()
    
    // 1. Плееры
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    // 2. Очередь для диалогов
    private var dialogueQueue: [DialogueLine] = []
    private var currentDialogueIndex = 0
    // Колбэк, чтобы сообщить View, какая строка сейчас играет (для подсветки)
    var onDialogueLineStart: ((Int) -> Void)?
    var onDialogueFinished: (() -> Void)?
    
    override private init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    // --- ПРОСТОЕ СЛОВО (КАРТОЧКИ) ---
    func speak(item: LearningItem) {
        stop() // Сброс всего
        if let data = item.audioData {
            playAudioData(data)
        } else {
            speakNative(item.text)
        }
    }
    
    func speak(_ text: String) {
        stop()
        speakNative(text)
    }

    // --- УНИФИЦИРОВАННЫЙ TTS (Google + on-disk cache + offline fallback) ---
    /// Used by flashcards: caches Google TTS audio on disk, falls back to the
    /// on-device synthesizer if the network/Worker call fails.
    func speak(text: String, rate: Float = 1.0, language: String = "nb-NO") async {
        stop()

        let cacheURL = ttsCacheURL(text: text, language: language, rate: rate)
        if let cacheURL, let cached = try? Data(contentsOf: cacheURL) {
            playAudioData(cached)
            return
        }

        do {
            let data = try await GoogleTTSService.shared.generateSpeech(text: text, rate: Double(rate))
            if let cacheURL {
                try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: cacheURL)
            }
            playAudioData(data)
        } catch {
            #if DEBUG
            print("[SpeechService] Google TTS failed: \(error)")
            #endif
            speakOffline(text: text, rate: rate, language: language)
        }
    }

    // --- ОДИНОЧНАЯ РЕПЛИКА ДИАЛОГА (сохранённые подкасты) ---
    /// Plays a single DialogueLine's cached Google TTS audio if present,
    /// otherwise falls back to the modern Google + cache + offline path.
    func playSingleLine(_ line: DialogueLine) async {
        stop()
        if let data = line.audioData {
            playAudioData(data, isSequence: false)
        } else {
            await speak(text: line.text)
        }
    }

    private func ttsCacheURL(text: String, language: String, rate: Float) -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) else { return nil }
        let hash = SHA256.hash(data: Data((text + language).utf8)).map { String(format: "%02x", $0) }.joined()
        let filename = "\(hash)_\(String(format: "%.2f", rate)).mp3"
        return container.appendingPathComponent("Library/Caches/tts", isDirectory: true).appendingPathComponent(filename)
    }

    private func speakOffline(text: String, rate: Float, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = Float(AVSpeechUtteranceDefaultSpeechRate) * rate
        synthesizer.speak(utterance)
    }

    // --- ПОДКАСТЫ (ПЛЕЙЛИСТ) ---
    func playDialogue(lines: [DialogueLine]) {
        stop() // Останавливаем текущее
        
        // Загружаем очередь
        self.dialogueQueue = lines
        self.currentDialogueIndex = 0
        
        // Начинаем с первой
        playNextLine()
    }
    
    private func playNextLine() {
        guard currentDialogueIndex < dialogueQueue.count else {
            // Конец диалога
            onDialogueFinished?()
            return
        }
        
        let line = dialogueQueue[currentDialogueIndex]
        
        // Сообщаем UI, что играем эту строку (можно подсветить)
        onDialogueLineStart?(currentDialogueIndex)
        
        if let data = line.audioData {
            // Играем MP3 от Google
            playAudioData(data, isSequence: true)
        } else {
            // Если аудио нет (вдруг?), читаем роботом
            speakNativeSequence(line)
        }
    }
    
    // --- ПЛЕЕРЫ ---
    
    private func playAudioData(_ data: Data, isSequence: Bool = false) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self // ВАЖНО: Чтобы поймать конец трека
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Audio Player Error: \(error)")
            if isSequence { playNextLine() } // Пропускаем сбойный
        }
    }
    
    private func speakNative(_ text: String) {
        let utterance = createUtterance(text: text)
        synthesizer.speak(utterance)
    }
    
    private func speakNativeSequence(_ line: DialogueLine) {
        let utterance = createUtterance(text: line.text)
        // Настройка голосов для робота (как запасной вариант)
        if line.speaker == "A" {
            utterance.pitchMultiplier = 1.0
        } else {
            utterance.pitchMultiplier = 0.85
        }
        utterance.postUtteranceDelay = 0.5 // Пауза после фразы
        synthesizer.speak(utterance)
    }
    
    // --- УПРАВЛЕНИЕ ---
    
    func stop() {
        dialogueQueue.removeAll()
        currentDialogueIndex = 0
        
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        if let player = audioPlayer, player.isPlaying { player.stop() }
    }
    
    // --- DELEGATE METHODS (АВТО-ПЕРЕКЛЮЧЕНИЕ) ---
    
    // 1. Когда закончился MP3 (Google)
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if SpeechService.shared.dialogueQueue.isEmpty { return }
            
            // Ждем маленькую паузу между репликами для естественности
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 сек
            
            SpeechService.shared.currentDialogueIndex += 1
            SpeechService.shared.playNextLine()
        }
    }
    
    // 2. Когда закончился Native (Robot)
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if SpeechService.shared.dialogueQueue.isEmpty { return }
            
            SpeechService.shared.currentDialogueIndex += 1
            SpeechService.shared.playNextLine()
        }
    }
    
    // --- HELPERS ---
    private func createUtterance(text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        let voice = AVSpeechSynthesisVoice.speechVoices().first { $0.language == "nn-NO" }
                    ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language == "nb-NO" }
                    ?? AVSpeechSynthesisVoice(language: "no-NO")
        utterance.voice = voice
        utterance.rate = 0.45
        return utterance
    }
}
