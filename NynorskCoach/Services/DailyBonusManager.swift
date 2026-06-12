import SwiftUI
import Combine

/// Manages daily login bonuses and rewards
class DailyBonusManager: ObservableObject {
    static let shared = DailyBonusManager()
    
    private let defaults = UserDefaults.standard
    private let bonusKey = "lastDailyBonusDate"
    private let bonusAmount = 50
    
    @Published var canClaimBonus: Bool = false
    @Published var daysStreak: Int = 0
    
    private init() {
        checkBonusAvailability()
    }
    
    /// Check if daily bonus is available
    func checkBonusAvailability() {
        let lastBonusTimestamp = defaults.double(forKey: bonusKey)
        let lastBonusDate = Date(timeIntervalSince1970: lastBonusTimestamp)
        let calendar = Calendar.current
        
        // Check if it's a new day
        if !calendar.isDate(lastBonusDate, inSameDayAs: Date()) {
            canClaimBonus = true
        } else {
            canClaimBonus = false
        }
    }
    
    /// Claim daily bonus
    func claimBonus() -> Int {
        guard canClaimBonus else { return 0 }
        
        // Update last claim date
        defaults.set(Date().timeIntervalSince1970, forKey: bonusKey)
        canClaimBonus = false
        
        // Add coins
        StoreManager.shared.addCoins(bonusAmount)
        
        // Play effects
        AudioManager.shared.play(.coin)
        HapticManager.shared.notification(type: .success)
        
        print("💰 Daily bonus claimed: +\(bonusAmount) монет")
        
        return bonusAmount
    }
    
    /// Get bonus amount for display
    func getBonusAmount() -> Int {
        return bonusAmount
    }
}
