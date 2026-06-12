import SwiftUI

struct IconGeneratorView: View {
    var body: some View {
        ZStack {
            // 1. Фон (Тот же фиолетовый, что в LaunchScreen)
            Color(red: 74/255, green: 0/255, blue: 224/255) // Ваш фиолетовый
                .ignoresSafeArea()
            
            // 2. Иконка
            Image(systemName: "sailboat.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .padding(200) // Отступы, чтобы иконка была по центру, но не в край
        }
        // Принудительный размер 1024x1024 (размер иконки App Store)
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    IconGeneratorView()
}
