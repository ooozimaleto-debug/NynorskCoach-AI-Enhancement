import SwiftUI
import SwiftData
import PhotosUI

struct WordEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @State var item: LearningItem?
    var topic: Topic?
    
    // ПОЛЯ ФОРМЫ
    @State private var text = ""
    @State private var translation = ""
    @State private var selectedGender: GrammaticalGender = .none
    @State private var transcription = ""
    @State private var contextSentence = ""
    @State private var contextTranslation = ""
    
    // ГРАММАТИКА
    @State private var partOfSpeech = "other"
    @State private var forms: [String] = []
    // Новые поля для примеров
    @State private var pastExamples: [String] = []
    @State private var futureExamples: [String] = []
    
    // КАРТИНКА
    @State private var imageData: Data?
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var sfSymbolName: String?
    @State private var isLoadingAI = false
    
    var isEditing: Bool { item != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. МЕДИА
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            if let data = imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 100, height: 100).clipShape(RoundedRectangle(cornerRadius: 15))
                                    .overlay(Button(action: { imageData = nil }) { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }.offset(x: 5, y: -5), alignment: .topTrailing)
                            } else if let symbol = sfSymbolName {
                                // ПОКАЗЫВАЕМ SF SYMBOL ЕСЛИ НЕТ ФОТО
                                Image(systemName: symbol).resizable().scaledToFit().frame(width: 60, height: 60).foregroundStyle(.blue).padding().background(Color.blue.opacity(0.1)).cornerRadius(15)
                            } else {
                                Image(systemName: "photo.badge.plus").font(.system(size: 40)).foregroundStyle(.tertiary)
                            }
                            PhotosPicker(selection: $selectedItem, matching: .images) { Text(imageData == nil ? "Добавить фото" : "Изменить").font(.caption).bold() }
                        }
                        Spacer()
                    }.listRowBackground(Color.clear)
                }
                .onChange(of: selectedItem) {
                    Task { if let data = try? await selectedItem?.loadTransferable(type: Data.self), let ui = UIImage(data: data)?.jpegData(compressionQuality: 0.5) { imageData = ui; sfSymbolName = nil } }
                }
                
                // 2. СЛОВО
                Section("Слово") {
                    TextField("Nynorsk", text: $text).font(.title3)
                    if isLoadingAI {
                        HStack { Text("AI анализирует..."); ProgressView() }
                    } else {
                        Button { generateAIContent() } label: { Label(isEditing ? "Улучшить" : "Заполнить с AI", systemImage: "sparkles").font(.subheadline).bold() }.disabled(text.isEmpty)
                    }
                    TextField("Перевод", text: $translation)
                    TextField("Транскрипция [IPA]", text: $transcription).foregroundStyle(.secondary)
                }
                
                // 3. ГРАММАТИКА
                Section("Грамматика") {
                    Picker("Часть речи", selection: $partOfSpeech) {
                        Text("Существительное").tag("noun")
                        Text("Глагол").tag("verb")
                        Text("Прилагательное").tag("adj")
                        Text("Другое").tag("other")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: partOfSpeech) { updateFormsTemplate() }
                    
                    if partOfSpeech == "noun" {
                        Group {
                            TextField("Entall Ubest.", text: binding(for: 0))
                            TextField("Entall Best.", text: binding(for: 1))
                            TextField("Flertall Ubest.", text: binding(for: 2))
                            TextField("Flertall Best.", text: binding(for: 3))
                        }
                        Picker("Род", selection: $selectedGender) {
                            ForEach(GrammaticalGender.allCases) { g in Text(g.rawValue).tag(g) }
                        }.pickerStyle(.segmented)
                    } else if partOfSpeech == "verb" {
                        Group {
                            TextField("Infinitiv (å)", text: binding(for: 0))
                            TextField("Presens", text: binding(for: 1))
                            TextField("Preteritum", text: binding(for: 2))
                            TextField("Perfektum", text: binding(for: 3))
                        }
                    } else if partOfSpeech == "adj" {
                        Group {
                            TextField("M/F", text: binding(for: 0))
                            TextField("Intetkjønn", text: binding(for: 1))
                            TextField("Flertall", text: binding(for: 2))
                        }
                    }
                }
                
                // 4. КОНТЕКСТ
                Section("Контекст") {
                    TextField("Пример", text: $contextSentence, axis: .vertical)
                    TextField("Перевод примера", text: $contextTranslation, axis: .vertical)
                }
            }
            .navigationTitle(isEditing ? "Редактирование" : "Новое слово")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.disabled(text.isEmpty) }
            }
            .onAppear { loadData() }
        }
    }
    
    // --- HELPER FUNCTIONS ---
    
    func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { forms.indices.contains(index) ? forms[index] : "" },
            set: { val in
                while forms.count <= index { forms.append("") }
                forms[index] = val
            }
        )
    }
    
    func updateFormsTemplate() {
        if forms.isEmpty {
            switch partOfSpeech {
            case "noun", "verb": forms = ["", "", "", ""]
            case "adj": forms = ["", "", ""]
            default: forms = []
            }
        }
    }
    
    func loadData() {
        if let item = item {
            text = item.text; translation = item.translation; selectedGender = item.gender
            transcription = item.transcription ?? ""; contextSentence = item.contextSentence ?? ""
            contextTranslation = item.contextTranslation ?? ""; imageData = item.imageData
            partOfSpeech = item.partOfSpeech ?? "other"; forms = item.forms ?? []
            pastExamples = item.pastExamples ?? []
            futureExamples = item.futureExamples ?? []
        }
    }
    
    func generateAIContent() {
        isLoadingAI = true
        let query = text.isEmpty ? "word" : text
        Task {
            do {
                let result = try await OpenAIService.shared.translateWord(query)
                await MainActor.run {
                    withAnimation {
                        self.text = result.text; self.translation = result.translation
                        self.selectedGender = GrammaticalGender(shortCode: result.gender)
                        self.transcription = result.transcription ?? ""; self.contextSentence = result.context
                        self.contextTranslation = result.contextTranslation
                        self.partOfSpeech = result.partOfSpeech; self.forms = result.forms
                        
                        // ИСПРАВЛЕНИЕ ЗДЕСЬ: Добавлено ?? []
                        self.pastExamples = result.pastExamples ?? []
                        self.futureExamples = result.futureExamples ?? []
                        
                        if self.imageData == nil { self.sfSymbolName = result.imageKeyword }
                    }
                    isLoadingAI = false
                }
            } catch { print("AI Error: \(error)"); await MainActor.run { isLoadingAI = false } }
        }
    }
    
    func save() {
        if imageData == nil, let symbol = sfSymbolName, UIImage(systemName: symbol) != nil {
             let renderer = ImageRenderer(content: Image(systemName: symbol).font(.system(size: 100)).foregroundStyle(.blue))
             renderer.scale = UIScreen.main.scale
             if let rendered = renderer.uiImage { imageData = rendered.pngData() }
        }
        
        if let existingItem = item {
            existingItem.text = text; existingItem.translation = translation; existingItem.gender = selectedGender
            existingItem.transcription = transcription; existingItem.contextSentence = contextSentence
            existingItem.contextTranslation = contextTranslation; existingItem.imageData = imageData
            existingItem.partOfSpeech = partOfSpeech; existingItem.forms = forms
            existingItem.pastExamples = pastExamples; existingItem.futureExamples = futureExamples
        } else if let topic = topic {
            let newItem = LearningItem(text: text, translation: translation, gender: selectedGender, topic: topic)
            newItem.transcription = transcription; newItem.contextSentence = contextSentence
            newItem.contextTranslation = contextTranslation; newItem.imageData = imageData
            newItem.partOfSpeech = partOfSpeech; newItem.forms = forms
            newItem.pastExamples = pastExamples; newItem.futureExamples = futureExamples
            context.insert(newItem)
        }
        dismiss()
    }
}
