import SwiftUI
import SwiftData
import PhotosUI
import SafariServices

struct GrammarView: View {
    @State private var selectedTab = 0
    @ObservedObject var lm = LocalizationManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ПЕРЕКЛЮЧАТЕЛЬ
                Picker("Режим", selection: $selectedTab) {
                    Text("Справочник".localized).tag(0)
                    Text("AI Проверка".localized).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // КОНТЕНТ
                if selectedTab == 0 {
                    ReferenceListView()
                } else {
                    GrammarCheckerView()
                }
            }
            .navigationTitle("Грамматика".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 1. СПРАВОЧНИК
struct ReferenceListView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \GrammarNote.dateCreated, order: .reverse) var notes: [GrammarNote]
    @State private var showAddSheet = false
    @State private var showSafari = false
    @State private var selectedURL: URL?
    
    let resources = [
        ExternalResource(name: "Grammatikk.com", desc: "Таблицы правил (PDF)", urlString: "http://grammatikk.com/pdf/Nynorsk.pdf", icon: "doc.text.fill"),
        ExternalResource(name: "Ordbøkene.no", desc: "Официальный словарь", urlString: "https://ordbokene.no/nn", icon: "book.closed.fill"),
        ExternalResource(name: "Språkrådet", desc: "Языковой совет (Правила)", urlString: "https://www.sprakradet.no/Sprakhjelp/Skriveregler/", icon: "building.columns.fill")
    ]
    
    var body: some View {
        List {
            Section("Мой справочник".localized) {
                if notes.isEmpty {
                    ContentUnavailableView { Label("Пока пусто".localized, systemImage: "note.text") } description: { Text("Добавь свои правила или фото таблиц.".localized) }
                } else {
                    ForEach(notes) { note in
                        NavigationLink(destination: NoteDetailView(note: note)) { NoteRow(note: note) }
                    }.onDelete(perform: deleteNotes)
                }
            }
            Section("Ресурсы".localized) {
                ForEach(resources) { res in
                    Button { if let url = URL(string: res.urlString) { selectedURL = url; showSafari = true } } label: {
                        HStack {
                            Image(systemName: res.icon).foregroundStyle(.orange)
                            VStack(alignment: .leading) { Text(res.name).bold(); Text(res.desc.localized).font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showAddSheet = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAddSheet) { AddNoteView() }
        .sheet(isPresented: $showSafari) { if let url = selectedURL { SafariView(url: url) } }
    }
    
    func deleteNotes(at offsets: IndexSet) { for index in offsets { context.delete(notes[index]) } }
}

struct NoteRow: View {
    let note: GrammarNote
    var body: some View {
        HStack {
            if let data = note.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "text.book.closed").foregroundStyle(.blue)
            }
            Text(note.title)
        }
    }
}

// MARK: - 2. AI ПРОВЕРКА (С МЕНТОРОМ)
struct GrammarCheckerView: View {
    @AppStorage("userRank") private var userRank: VikingRank = .oppdagar
    @AppStorage("selectedMentor") private var selectedMentorRaw = Mentor.freya.rawValue
    
    @State private var inputText = ""
    @State private var resultText = ""
    @State private var corrections: [ChatCorrection] = []
    @State private var isAnalyzing = false
    
    var mentor: Mentor { Mentor(rawValue: selectedMentorRaw) ?? .freya }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Ввод
                VStack(alignment: .leading) {
                    Text("Текст для проверки".localized).font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $inputText)
                        .frame(height: 150).padding(8).background(Color(uiColor: .secondarySystemBackground)).cornerRadius(12)
                }
                
                // Кнопка
                Button { checkGrammar() } label: {
                    if isAnalyzing { ProgressView().tint(.white) } else {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Проверить".localized)
                        }
                    }
                }
                .frame(maxWidth: .infinity).padding().background(inputText.isEmpty ? Color.gray : Color.blue).foregroundStyle(.white).cornerRadius(12)
                .disabled(inputText.isEmpty || isAnalyzing)
                
                // Результат
                if !corrections.isEmpty || !resultText.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        
                        // Заголовок от Ментора
                        HStack {
                            Image(systemName: mentorIcon).foregroundStyle(mentorColor).font(.title2)
                            Text(mentor.displayName).font(.headline)
                            Spacer()
                        }
                        .padding(.bottom, 5)
                        
                        // Основной вердикт
                        if !resultText.isEmpty {
                            Text(resultText)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(mentorColor.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(mentorColor.opacity(0.3), lineWidth: 1))
                        }
                        
                        // Список ошибок
                        ForEach(corrections, id: \.original) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).padding(.top, 4)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.original).strikethrough().foregroundStyle(.secondary)
                                    HStack {
                                        Image(systemName: "arrow.right").font(.caption)
                                        Text(item.corrected).bold().foregroundStyle(.green)
                                    }
                                    Text(item.explanation).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                                }
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .transition(.opacity)
                }
            }.padding()
        }
        .onTapGesture { hideKeyboard() }
    }
    
    var mentorColor: Color {
        switch mentor { case .freya: return .green; case .loki: return .purple; case .odin: return .blue }
    }
    var mentorIcon: String {
        switch mentor { case .freya: return "leaf.fill"; case .loki: return "flame.fill"; case .odin: return "eye.fill" }
    }
    
    // Внутри struct GrammarCheckerView
        
        func checkGrammar() {
            isAnalyzing = true
            // Промпт теперь формируется внутри сервиса, нам нужен только текст
            let textToCheck = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !textToCheck.isEmpty else {
                isAnalyzing = false
                return
            }
            
            Task {
                do {
          // ВЫЗЫВАЕМ НОВЫЙ СПЕЦИАЛЬНЫЙ МЕТОД
            let response = try await OpenAIService.shared.checkGrammar(text: textToCheck, rank: userRank)
                    
                    await MainActor.run {
                        withAnimation {
                            // Чистим текст от случайных кавычек в начале и конце, если AI их добавил
                            self.resultText = response.reply.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            self.corrections = response.corrections ?? []
                            self.isAnalyzing = false
                        }
                        AudioManager.shared.play(.success)
                        StoreManager.shared.addCoins(1) // Награда за старание
                    }
                } catch {
                    await MainActor.run {
                        self.resultText = "Ошибка анализа: \(error.localizedDescription)"
                        self.isAnalyzing = false
                        AudioManager.shared.play(.error)
                    }
                }
            }
        }
    
    func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
}

// MARK: - ВСПОМОГАТЕЛЬНЫЕ КОМПОНЕНТЫ
struct AddNoteView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Заголовок", text: $title)
                Button(selectedImage == nil ? "Добавить фото" : "Изменить фото") { showImagePicker = true }
                if let img = selectedImage { Image(uiImage: img).resizable().scaledToFit().frame(height: 150) }
                TextEditor(text: $content).frame(height: 150)
            }
            .navigationTitle("Новая заметка")
            .toolbar {
                Button("Сохранить") {
                    let note = GrammarNote(title: title, content: content, imageData: selectedImage?.jpegData(compressionQuality: 0.7))
                    context.insert(note)
                    dismiss()
                }.disabled(title.isEmpty)
            }
            .sheet(isPresented: $showImagePicker) { GrammarImagePicker { img in selectedImage = img } }
        }
    }
}

struct NoteDetailView: View {
    let note: GrammarNote
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(note.title).font(.largeTitle).bold()
                if let data = note.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFit().cornerRadius(12)
                }
                Text(note.content).padding()
            }.padding()
        }
    }
}

struct ExternalResource: Identifiable { let id = UUID(); let name, desc, urlString, icon: String }

struct GrammarImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: GrammarImagePicker; init(_ p: GrammarImagePicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImagePicked(img) }
            picker.dismiss(animated: true)
        }
    }
}

// !!! SAFARI VIEW УДАЛЕН, ЧТОБЫ ИЗБЕЖАТЬ КОНФЛИКТА С ReaderView.swift
