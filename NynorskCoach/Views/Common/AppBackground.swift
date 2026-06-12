import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        ZStack {
            if scheme == .dark {
                // --- ТЕМНАЯ ТЕМА (Северная Ночь) ---
                LinearGradient(
                    colors: [
                        Color(hex: "0F2027"), // Глубокий черный/синий
                        Color(hex: "203A43"), // Темная сталь
                        Color(hex: "2C5364")  // Холодный синий
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Декоративные пятна (Сияние)
                GeometryReader { proxy in
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 300)
                        .position(x: proxy.size.width, y: 0)
                        .blur(radius: 60)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 250)
                        .position(x: 0, y: proxy.size.height * 0.5)
                        .blur(radius: 60)
                }
            } else {
                // --- СВЕТЛАЯ ТЕМА (Чистый Снег) ---
                // Используем системные цвета, чтобы не было "грязи"
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground), // Чистый белый
                        Color(uiColor: .secondarySystemBackground) // Легкий серый (едва заметный)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    VStack {
        Text("Light Mode")
        AppBackground()
    }
}
