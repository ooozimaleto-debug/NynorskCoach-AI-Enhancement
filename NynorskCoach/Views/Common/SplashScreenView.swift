import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var isActive = false // Добавили состояние для перехода
    
    var body: some View {
        if isActive {
            EmptyView() // Сюда можно добавить переход, если логика переключения в MainView
        } else {
            ZStack {
                // 1. ФОН
                backgroundGradient
                    .ignoresSafeArea()
                
                // 2. КОНТЕНТ
                VStack(spacing: 20) {
                    Image(systemName: "sailboat.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .white.opacity(0.5), radius: 20, x: 0, y: 0)
                    
                    Text("Nynorsk Coach")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                        .shadow(radius: 5)
                    
                    Text("Lær språket til vikingane")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(50)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
                .scaleEffect(isAnimating ? 1.0 : 0.9)
                .opacity(isAnimating ? 1.0 : 0.0)
            }
            .onAppear {
                withAnimation(.spring(duration: 1.5)) {
                    isAnimating = true
                }
                
                // Таймер для скрытия сплэша (через 2.5 сек)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
    
    // Вынесли градиент отдельно, чтобы упростить body для компилятора
    var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "4A00E0"), // Глубокий синий
                Color(hex: "8E2DE2"), // Фиолетовый
                Color(hex: "00B4DB")  // Ледяной голубой
            ],
            startPoint: isAnimating ? .topLeading : .bottomLeading,
            endPoint: isAnimating ? .bottomTrailing : .topTrailing
        )
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)
    }
}

// Проверяем, что хелпер для Color(hex:) доступен в проекте.
// Если он удален из FlashcardSessionView, он должен быть в Extensions.swift.
// Если ошибки 'Color has no member init(hex:)' НЕТ, значит всё ок.
// Если вдруг появится - скажи, добавим его сюда.
