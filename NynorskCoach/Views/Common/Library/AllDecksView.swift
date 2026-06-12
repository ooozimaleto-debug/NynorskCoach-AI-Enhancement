import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AllDecksView: View {
    @Environment(\.modelContext) var context
    // Загружаем все темы, сортируем по имени
    @Query(sort: \Topic.name) var topics: [Topic]
    
    // Состояния для управления окнами
    @State private var showAddManual = false
    @State private var showFileImporter = false
    @State private var showOptions = false
    
    // Сообщения об ошибках или успехе
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        List {
            if topics.isEmpty {
                ContentUnavailableView("Нет колод", systemImage: "tray.fill", description: Text("Создайте новую тему или загрузите контент."))
            } else {
                ForEach(topics) { topic in
                    NavigationLink(destination: WordListView(topic: topic)) {
                        HStack(spacing: 15) {
                            // Иконка
                            ZStack {
                                Circle()
                                    .fill(topic.color.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: topic.emoji)
                                    .foregroundStyle(topic.color)
                            }
                            
                            // Текст
                            VStack(alignment: .leading) {
                                Text(topic.name)
                                    .font(.headline)
                                Text("\(topic.items.count) слов")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Уровень
                            Text(topic.difficulty)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(6)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteTopic)
            }
        }
        .navigationTitle("Все колоды")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showOptions = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                }
            }
        }
        // МЕНЮ ВЫБОРА
        .confirmationDialog("Добавить колоду", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Создать вручную") { showAddManual = true }
            Button("Залить файлом (CSV)") { showFileImporter = true }
            Button("Отмена", role: .cancel) {}
        }
        // РУЧНОЕ СОЗДАНИЕ
        .sheet(isPresented: $showAddManual) {
            AddTopicView()
        }
        // ИМПОРТ ФАЙЛА
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText, .commaSeparatedText], // Разрешаем .txt и .csv
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        // АЛЕРТ РЕЗУЛЬТАТА
        .alert("Импорт", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func deleteTopic(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                context.delete(topics[index])
            }
        }
    }
    
    // MARK: - ЛОГИКА ИМПОРТА CSV
    private func handleImport(result: Result<[URL], Error>) {
        do {
            // 1. Получаем доступ к файлу
            guard let selectedFile: URL = try result.get().first else { return }
            
            // Важно для доступа к файлам вне песочницы
            if selectedFile.startAccessingSecurityScopedResource() {
                defer { selectedFile.stopAccessingSecurityScopedResource() }
                
                // 2. Читаем содержимое
                let fileData = try String(contentsOf: selectedFile, encoding: .utf8)
                let fileName = selectedFile.deletingPathExtension().lastPathComponent
                
                // 3. Парсим и сохраняем
                parseAndSaveCSV(data: fileData, topicName: fileName)
            }
        } catch {
            alertMessage = "Ошибка чтения файла: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func parseAndSaveCSV(data: String, topicName: String) {
        // Разбиваем на строки
        let rows = data.components(separatedBy: .newlines)
        guard !rows.isEmpty else {
            alertMessage = "Файл пуст"
            showAlert = true
            return
        }
        
        // 1. Создаем новую тему
        // Имя темы берем из названия файла
        let newTopic = Topic(name: topicName, emoji: "📂", difficulty: "A1")
        context.insert(newTopic)
        
        var count = 0
        
        // 2. Бежим по строкам
        for row in rows {
            // Пропускаем пустые строки
            if row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            // Разбиваем по точке с запятой (;)
            let columns = row.components(separatedBy: ";")
            
            // Проверяем, что есть хотя бы Слово и Перевод (минимум 2 колонки)
            if columns.count >= 2 {
                let text = columns[0].trimmingCharacters(in: .whitespaces)
                let translation = columns[1].trimmingCharacters(in: .whitespaces)
                
                // Пропускаем заголовок (если есть слово "Слово" или "Word" в первой строке)
                if text.lowercased() == "слово" || text.lowercased() == "word" { continue }
                
                // Парсим род (3-я колонка)
                var gender: GrammaticalGender = .none
                if columns.count > 2 {
                    let genderStr = columns[2].trimmingCharacters(in: .whitespaces)
                    gender = GrammaticalGender(shortCode: genderStr) // Используем твой инит из DataModels
                }
                
                // Парсим контекст (4-я и 5-я колонки)
                var contextSent: String? = nil
                var contextTrans: String? = nil
                
                if columns.count > 3 {
                    contextSent = columns[3].trimmingCharacters(in: .whitespaces)
                }
                if columns.count > 4 {
                    contextTrans = columns[4].trimmingCharacters(in: .whitespaces)
                }
                
                // 3. Создаем слово
                let item = LearningItem(
                    text: text.capitalizedSentence(), // Твое расширение для красоты
                    translation: translation.capitalizedSentence(),
                    gender: gender,
                    topic: newTopic,
                    contextSentence: contextSent?.capitalizedSentence(),
                    contextTranslation: contextTrans?.capitalizedSentence()
                )
                context.insert(item)
                count += 1
            }
        }
        
        // 4. Показываем результат
        if count > 0 {
            alertMessage = "Успешно добавлена тема \"\(topicName)\" с \(count) словами."
            AudioManager.shared.play(.success) // Твой звук успеха
        } else {
            // Если ничего не добавилось, удаляем пустую тему
            context.delete(newTopic)
            alertMessage = "Не удалось найти слова. Проверьте формат: Слово;Перевод"
        }
        showAlert = true
    }
}
