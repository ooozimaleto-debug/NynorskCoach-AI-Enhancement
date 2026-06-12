import SwiftUI
import SwiftData

struct DailyWordView: View {
    @Query var items: [LearningItem]
    @State private var dailyWord: LearningItem?
    @State private var showTranslation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.orange)
                Text("Слово дня".localized)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            if let word = dailyWord {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.text)
                            .font(.system(.title2, design: .serif))
                            .bold()
                            .foregroundStyle(.primary)
                        
                        if showTranslation {
                            Text(word.translation)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            Text("Нажми, чтобы узнать".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.7))
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                    
                    Button {
                        SpeechService.shared.speak(word.text)
                    } label: {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue.opacity(0.8))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        showTranslation.toggle()
                        // ИСПРАВЛЕНО: Добавлен лейбл style:
                        HapticManager.shared.impact(style: .medium)
                    }
                }
            } else {
                Text("Добавьте слова в словарь, чтобы увидеть слово дня!".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [.orange.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            pickDailyWord()
        }
    }
    
    func pickDailyWord() {
        guard !items.isEmpty else { return }
        let date = Date()
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = dayOfYear % items.count
        dailyWord = items[index]
    }
}
