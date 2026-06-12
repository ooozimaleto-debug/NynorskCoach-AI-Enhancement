import SwiftUI
import SwiftData

struct TopicSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Topic.name) var topics: [Topic]
    
    // Мы будем хранить ID скрытых тем в UserDefaults, чтобы не менять базу данных
    @AppStorage("hiddenTopicIDs") private var hiddenTopicIDsString = ""
    
    var body: some View {
        NavigationStack {
            List {
                if topics.isEmpty {
                    ContentUnavailableView("Нет тем", systemImage: "tray")
                } else {
                    ForEach(topics) { topic in
                        HStack {
                            // Иконка и имя
                            ZStack {
                                Circle().fill(topic.color.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: topic.emoji).foregroundStyle(topic.color)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(topic.name).font(.headline)
                                Text("\(topic.items.count) слов").font(.caption).foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Переключатель
                            Toggle("", isOn: Binding(
                                get: { !isHidden(topic) },
                                set: { show in
                                    if show { unhide(topic) } else { hide(topic) }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
            .navigationTitle("Что учим?")
            .toolbar {
                Button("Готово") { dismiss() }
            }
        }
    }
    
    // --- ЛОГИКА СКРЫТИЯ ---
    
    func isHidden(_ topic: Topic) -> Bool {
        hiddenTopicIDsString.contains(topic.id)
    }
    
    func hide(_ topic: Topic) {
        if !isHidden(topic) {
            hiddenTopicIDsString += (hiddenTopicIDsString.isEmpty ? "" : ",") + topic.id
        }
    }
    
    func unhide(_ topic: Topic) {
        var ids = hiddenTopicIDsString.components(separatedBy: ",").filter { !$0.isEmpty }
        if let index = ids.firstIndex(of: topic.id) {
            ids.remove(at: index)
        }
        hiddenTopicIDsString = ids.joined(separator: ",")
    }
}
