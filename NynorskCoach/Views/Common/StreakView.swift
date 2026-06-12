import SwiftUI

struct StreakView: View {
    var manager = StreakManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(manager.isStreakActiveToday ? .orange : .gray)
                .symbolEffect(.pulse, value: manager.isStreakActiveToday)
            
            Text("\(manager.currentStreak)")
                .font(.headline)
                .foregroundStyle(manager.isStreakActiveToday ? .primary : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(manager.isStreakActiveToday ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
        )
    }
}
