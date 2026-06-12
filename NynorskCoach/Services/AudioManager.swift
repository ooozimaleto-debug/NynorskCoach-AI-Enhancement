import SwiftUI
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    @AppStorage("isSoundEnabled") var isSoundEnabled = true
    @AppStorage("isHapticsEnabled") var isHapticsEnabled = true
    
    private init() {}
    
    enum SoundType {
        case success
        case error
        case coin
        case click
        case flip      // Исправляет ошибку 'flip'
        case levelUp   // Исправляет ошибку 'levelUp'
    }
    
    func play(_ type: SoundType) {
        guard isSoundEnabled else { return }
        
        let soundID: SystemSoundID
        
        switch type {
        case .success:      soundID = 1001 // MailSent (мягкий)
        case .error:        soundID = 1053 // SystemError (глухой)
        case .coin:         soundID = 1057 // PIN Key Input (приятный звон)
        case .click:        soundID = 1104 // Tock
        case .flip:         soundID = 1105 // Tock light
        case .levelUp:      soundID = 1016 // Bell Positive
        }
        
        AudioServicesPlaySystemSound(soundID)
    }
    
    func playHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
