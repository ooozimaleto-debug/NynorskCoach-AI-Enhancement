import SwiftUI
import SwiftData
import Charts

struct WisdomDetailView: View {
    @Query var items: [LearningItem]
    
    var mastered: [LearningItem] { items.filter { $0.status == .mastered } }
    var learning: [LearningItem] { items.filter { $0.status == .learning } }
    var new: [LearningItem] { items.filter { $0.status == .new } }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            List {
                // ОБЩАЯ СВОДКА
                Section {
                    HStack(spacing: 20) {
                        StatCircle(value: mastered.count, color: .green, label: "Выучено")
                        StatCircle(value: learning.count, color: .blue, label: "Учим")
                        StatCircle(value: new.count, color: .gray, label: "Новые")
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 10)
                }
                
                // СПИСКИ СЛОВ
                if !mastered.isEmpty {
                    Section("Мастера слова (Выучено)".localized) {
                        ForEach(mastered) { item in WordRow(item: item, color: .green) }
                    }
                }
                
                if !learning.isEmpty {
                    Section("В процессе".localized) {
                        ForEach(learning) { item in WordRow(item: item, color: .blue) }
                    }
                }
                
                if !new.isEmpty {
                    Section("Новые".localized) {
                        ForEach(new) { item in WordRow(item: item, color: .gray) }
                    }
                }
            }
        }
        .navigationTitle("Твоя мудрость".localized)
    }
}

// Компонент кружка с цифрой
struct StatCircle: View {
    let value: Int; let color: Color; let label: String
    var body: some View {
        VStack {
            ZStack {
                Circle().stroke(color.opacity(0.3), lineWidth: 4).frame(width: 60, height: 60)
                Text("\(value)").font(.title3).bold()
            }
            Text(label.localized).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

// Строка слова
struct WordRow: View {
    let item: LearningItem; let color: Color
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(item.text).bold()
            Spacer()
            Text(item.translation).foregroundStyle(.secondary)
        }
    }
}
