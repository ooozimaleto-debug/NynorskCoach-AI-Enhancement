import SwiftUI
import SwiftData

/// Unified Vision View combining Scanner and Odin's Eye
struct UnifiedVisionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @Query(filter: #Predicate<Topic> { $0.isSystem == true }) var systemTopics: [Topic]
    
    @State private var viewModel: UnifiedVisionViewModel
    
    // Zoom state (UI-specific)
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    init(initialMode: VisionMode = .ocr) {
        _viewModel = State(wrappedValue: UnifiedVisionViewModel())
        viewModel.mode = initialMode
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Picker
                if viewModel.image == nil {
                    Picker("Режим", selection: $viewModel.mode) {
                        ForEach(VisionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
                
                // Main Content
                if let image = viewModel.image {
                    buildResultView(image: image)
                } else {
                    buildPlaceholderView()
                }
            }
            .navigationTitle(viewModel.image == nil ? viewModel.mode.title : "Результат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showCamera) {
                SharedImagePicker(sourceType: .camera) { img in
                    processImage(img)
                }
            }
            .sheet(isPresented: $viewModel.showGallery) {
                SharedImagePicker(sourceType: .photoLibrary) { img in
                    processImage(img)
                }
            }
            .sheet(item: $viewModel.selectedWord) { wrapper in
                WordActionSheet(word: wrapper.text, context: context, systemTopic: getSystemTopic())
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $viewModel.showFeedback) {
                if let feedback = viewModel.aiFeedback {
                    FeedbackSheet(feedback: feedback) {
                        viewModel.showFeedback = false
                    }
                }
            }
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func buildPlaceholderView() -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: viewModel.mode.icon)
                .font(.system(size: 80))
                .foregroundStyle(viewModel.mode == .ocr ? .blue : .purple)
                .symbolEffect(.bounce, value: viewModel.mode)
            
            Text(viewModel.mode.title)
                .font(.largeTitle).bold()
            
            Text(viewModel.mode.placeholder)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            // Camera/Gallery Buttons
            HStack(spacing: 20) {
                Button {
                    viewModel.showCamera = true
                } label: {
                    Label("Камера", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.mode == .ocr ? Color.blue : Color.purple)
                        .foregroundStyle(.white)
                        .cornerRadius(15)
                }
                
                Button {
                    viewModel.showGallery = true
                } label: {
                    Label("Галерея", systemImage: "photo.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.primary)
                        .cornerRadius(15)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
    
    @ViewBuilder
   private func buildResultView(image: UIImage) -> some View {
        VStack {
            switch viewModel.mode {
            case .ocr:
                buildOCRView(image: image)
            case .describe:
                buildDescribeView(image: image)
            case .identify:
                buildIdentifyView(image: image)
            }
        }
    }
    
    @ViewBuilder
    private func buildOCRView(image: UIImage) -> some View {
        GeometryReader { geo in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .overlay(
                            WordOverlayView(
                                words: viewModel.recognizedWords,
                                imageSize: image.size,
                                containerSize: geo.size,
                                onWordTap: { wordText in
                                    if lastOffset == currentOffset {
                                        HapticManager.shared.impact(style: .light)
                                        viewModel.selectedWord = ScannerSelectedWord(text: wordText)
                                    }
                                }
                            )
                        )
                }
                .scaleEffect(currentScale)
                .offset(currentOffset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { v in
                            currentScale = min(max(lastScale * v, 1), 5)
                        }
                        .onEnded { _ in
                            lastScale = currentScale
                            if currentScale < 1 { resetZoom() }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { v in
                            if currentScale > 1 {
                                currentOffset = CGSize(
                                    width: lastOffset.width + v.translation.width,
                                    height: lastOffset.height + v.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            if currentScale > 1 {
                                lastOffset = currentOffset
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation { resetZoom() }
                }
            }
        }
        
        // Bottom toolbar
        HStack {
            Button {
                withAnimation { resetState() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                Text("Переснять")
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
            
            Spacer()
            
            if viewModel.isProcessing {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            } else {
                Text("Нажми на слово").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
    
    @ViewBuilder
    private func buildDescribeView(image: UIImage) -> some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .padding()
            
            VStack(alignment: .leading) {
                Text("Что ты видишь?").font(.headline)
                Text("Опиши картинку на Nynorsk").font(.caption).foregroundStyle(.secondary)
                
                TextField("Например: Ein katt sit på ei matte...", text: $viewModel.userDescription, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            Spacer()
            
            if viewModel.isProcessing {
                ProgressView("Один смотрит...")
            } else {
                Button {
                    hideKeyboard()
                    let mentorID = UserDefaults.standard.string(forKey: "selectedMentor") ?? Mentor.freya.rawValue
                    viewModel.checkUserDescription(mentorID: mentorID)
                } label: {
                    HStack {
                        Image(systemName: "eye")
                        Text("Проверить")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.userDescription.isEmpty ? Color.gray : Color.purple)
                    .foregroundStyle(.white)
                    .cornerRadius(15)
                }
                .disabled(viewModel.userDescription.isEmpty)
                .padding()
            }
            
            Button("Отмена") { resetState() }
                .padding(.bottom)
        }
    }
    
    @ViewBuilder
    private func buildIdentifyView(image: UIImage) -> some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            
            if viewModel.isProcessing {
                VStack {
                    ProgressView().tint(.purple).scaleEffect(1.5)
                    Text("Один всматривается...")
                        .bold()
                        .foregroundStyle(.secondary)
                        .padding(.top)
                }
            } else if let result = viewModel.objectResult {
                ObjectResultCard(result: result) {
                    saveObjectToVocabulary(result: result, image: image)
                }
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
            }
            
            Spacer()
            
            if !viewModel.isProcessing {
                Button("Переснять") {
                    resetState()
                }
                .padding(.bottom)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func processImage(_ img: UIImage) {
        resetZoom()
        viewModel.processImage(img)
    }
    
    private func resetState() {
        resetZoom()
        viewModel.resetState()
    }
    
    private func resetZoom() {
        currentScale = 1.0
        lastScale = 1.0
        currentOffset = .zero
        lastOffset = .zero
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func getSystemTopic() -> Topic {
        if let existing = systemTopics.first {
            return existing
        }
        let newTopic = Topic(name: "Vision", emoji: "👁️", difficulty: "All", isSystem: true)
        context.insert(newTopic)
        return newTopic
    }
    
    private func saveObjectToVocabulary(result: ObjectResult, image: UIImage) {
        let topic = getSystemTopic()
        let item = LearningItem(
            text: result.object,
            translation: result.translation,
            gender: .none,
            topic: topic
        )
        
        if let imgData = image.jpegData(compressionQuality: 0.5) {
            item.imageData = imgData
        }
        
        item.contextSentence = result.description
        context.insert(item)
        
        AudioManager.shared.play(.coin)
        HapticManager.shared.notification(type: .success)
        
        dismiss()
    }
}

// MARK: - Subviews

struct ObjectResultCard: View {
    let result: ObjectResult
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text(result.object)
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(.blue)
            
            Text(result.translation)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(result.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            
            Button {
                onSave()
            } label: {
                Label("Сохранить в словарь", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }
}

struct FeedbackSheet: View {
    let feedback: ChatResponse
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Вердикт Наставника")
                .font(.headline)
                .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Main feedback
                    Text(feedback.reply)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    
                    // Corrections list
                    if let corrections = feedback.corrections, !corrections.isEmpty {
                        Text("Что можно улучшить:")
                            .font(.subheadline).bold()
                            .foregroundStyle(.secondary)
                        
                        ForEach(corrections.indices, id: \.self) { index in
                            let corr = corrections[index]
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    Text(corr.original).strikethrough().foregroundStyle(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text(corr.corrected).bold()
                                }
                                
                                Text(corr.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 24)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            
            Button("Понятно") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding()
        }
    }
}
