import SwiftUI

struct TactileCardBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "F9F6F0")
            
            GeometryReader { proxy in
                // Используем init(size:renderer:) из Extensions.swift
                Image(size: proxy.size) { context, size in
                    for _ in 0..<Int(size.width * size.height * 0.3) {
                        let x = Double.random(in: 0...size.width)
                        let y = Double.random(in: 0...size.height)
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(.black.opacity(0.03))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.8), location: 0),
                    .init(color: .clear, location: 0.4)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
