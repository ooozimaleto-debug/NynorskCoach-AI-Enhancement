import SwiftUI
import SwiftData

struct ImportTextView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @State private var title: String = ""
    @State private var content: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Заголовок".localized)) {
                    TextField("Например: Nyheter...", text: $title)
                }
                
                Section(header: Text("Текст (Nynorsk)".localized)) {
                    TextEditor(text: $content)
                        .frame(height: 300)
                }
                
                Button("Сохранить в библиотеку") {
                    saveArticle()
                }
                .disabled(title.isEmpty || content.isEmpty)
            }
            .navigationTitle("Импорт текста")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
    
    func saveArticle() {
        // Исправлено: Убрали лишние аргументы. Только title и content.
        let newArticle = Article(title: title, content: content)
        
        // Если хочешь добавить сложность, нужно менять DataModel.
        // Пока сохраняем без неё.
        context.insert(newArticle)
        
        dismiss()
    }
}
