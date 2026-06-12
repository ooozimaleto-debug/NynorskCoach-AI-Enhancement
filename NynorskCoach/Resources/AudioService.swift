import AVFoundation
import UIKit

@MainActor
class SpeechService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
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
