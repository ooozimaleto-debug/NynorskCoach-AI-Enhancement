import Foundation

enum Constants {
    // ВАЖНО: должен совпадать с com.apple.security.application-groups
    // в NynorskCoach.entitlements и NynorskWidgetExtension.entitlements
    static let appGroupIdentifier = "group.ooo.zimaleto.NynorskCoach"
    
    // Ключи для UserDefaults (AppStorage)
    enum Keys {
        static let userCoins = "userCoins"
        static let streak = "userStreak"
        static let lastVisitDate = "lastVisitDate"
        static let purchasedItems = "purchasedItems"
        static let activeHelmet = "activeHelmet"
        static let activeCardSkin = "activeCardSkin"
        
        static let nativeLanguage = "nativeLanguage"
        static let selectedPersona = "selectedPersona"
        static let userLevel = "userLevel"
        static let userName = "userName"
        
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        
        static let isSoundEnabled = "isSoundEnabled"
        static let isHapticsEnabled = "isHapticsEnabled"
    }
    
    // Ссылки (если понадобятся)
    enum URLs {
        static let privacyPolicy = "https://nynorskcoach.com/privacy"
        static let supportEmail = "ooo.zimaleto@gmail.com"
    }
}
