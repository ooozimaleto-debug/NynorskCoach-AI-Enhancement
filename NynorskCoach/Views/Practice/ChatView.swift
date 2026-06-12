import SwiftUI
import SwiftData

struct ChatView: View {
    let scenario: PracticeScenario
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    // НАСТРОЙКИ
    @AppStorage("selectedMentor") private var selectedMentorRaw = Mentor.freya.rawValue
    @AppStorage("userRank") private var userRank: VikingRank = .oppdagar
    @AppStorage("userLevel") private var userLevel = "A1"
    @AppStorage("userAvatarData") private var userAvatarData: Data = Data()
    
    // ДОСТУП К СЛОВАРЮ
    @Query var savedItems: [LearningItem]
    @Query(filter: #Predicate<Topic> { $0.isSystem == true }) var systemTopics: [Topic]
    
    // MVVM
    @State private var viewModel = ChatViewModel()
    
    // Текущий ментор
    var mentor: Mentor { Mentor(rawValue: selectedMentorRaw) ?? .freya }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. ХЕДЕР
                    ChatHeader(mentor: mentor, scenarioTitle: scenario.title) {
                        dismiss()
                    }
                    
                    // 2. СПИСОК СООБЩЕНИЙ
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                Text(Date().formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .padding(.top)
                                
                                ForEach(viewModel.messages) { msg in
                                    InteractiveMessageBubble(
                                        message: msg,
                                        mentor: mentor,
                                        userAvatar: userAvatarData,
                                        savedItems: savedItems,
                                        onWordTap: { word in
                                            viewModel.selectedWord = ChatSelectedWord(text: word)
                                        }
                                    )
                                    .id(msg.id)
                                }
                                
                                if viewModel.isLoading {
                                    TypingIndicator(mentor: mentor).id("typing")
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.messages.count) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    
                    // 3. ПОЛЕ ВВОДА
                    InputArea(text: $viewModel.inputText, isLoading: viewModel.isLoading) {
                        viewModel.sendMessage(rank: userRank)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.startChat(
                    scenario: scenario,
                    mentor: mentor,
                    userLevel: userLevel,
                    userRank: userRank
                )
            }
            .sheet(item: $viewModel.selectedWord) { wrapper in
                WordActionSheet(word: wrapper.text, context: context, systemTopic: getSystemTopic())
                    .presentationDetents([.medium])
            }
        }
    }
    
    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = viewModel.messages.last?.id else { return }
        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
    }
    
    // --- ЛОГИКА SYSTEM TOPIC ---
    
    func getSystemTopic() -> Topic {
        if let existing = systemTopics.first { return existing }
        let newTopic = Topic(name: "Mitt Ordbok", emoji: "📖", difficulty: "All", isSystem: true)
        context.insert(newTopic)
        return newTopic
    }
}

// MARK: - ИНТЕРАКТИВНЫЙ ПУЗЫРЬ (PRIVATE)

private struct InteractiveMessageBubble: View {
    let message: ChatMessage
    let mentor: Mentor
    let userAvatar: Data
    let savedItems: [LearningItem]
    let onWordTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 10) {
                if !message.isUser { MentorAvatar(mentor: mentor) }
                
                VStack(alignment: .leading, spacing: 8) {
                    if message.isUser {
                        Text(message.text)
                            .padding(14)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(BubbleShape(isUser: true))
                    } else {
                        ChatFlowLayout(text: message.text, savedItems: savedItems, onWordTap: onWordTap)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(BubbleShape(isUser: false))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    
                    if !message.corrections.isEmpty {
                        CorrectionView(corrections: message.corrections)
                            .padding(.leading, 5)
                    }
                }
                
                if message.isUser { UserAvatar(data: userAvatar) }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

// MARK: - CHAT FLOW LAYOUT (PRIVATE)

private struct ChatFlowLayout: View {
    let text: String
    let savedItems: [LearningItem]
    let onWordTap: (String) -> Void
    
    var body: some View {
        let tokens = tokenize(text)
        
        SimpleFlowLayout(items: tokens, spacing: 4) { token in
            Text(token.text)
                .font(.body)
                .foregroundStyle(textColor(for: token.clean))
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
                .background(bgColor(for: token.clean))
                .cornerRadius(4)
                .onTapGesture {
                    let clean = token.clean.trimmingCharacters(in: .punctuationCharacters)
                    if !clean.isEmpty { onWordTap(clean) }
                }
        }
    }
    
    struct Token: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let clean: String
    }
    
    func tokenize(_ text: String) -> [Token] {
        return text.components(separatedBy: .whitespaces).map { raw in
            let clean = raw.trimmingCharacters(in: .punctuationCharacters)
            return Token(text: raw, clean: clean)
        }
    }
    
    func textColor(for word: String) -> Color {
        guard !word.isEmpty else { return .primary }
        if savedItems.contains(where: { $0.text.localizedCaseInsensitiveCompare(word) == .orderedSame }) {
            return .white
        }
        return .primary
    }
    
    func bgColor(for word: String) -> Color {
        guard !word.isEmpty else { return .clear }
        if let item = savedItems.first(where: { $0.text.localizedCaseInsensitiveCompare(word) == .orderedSame }) {
            switch item.status {
            case .new: return .gray.opacity(0.8)
            case .learning: return .orange.opacity(0.8)
            case .mastered: return .green.opacity(0.8)
            }
        }
        return .clear
    }
}

private struct SimpleFlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { g in
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .padding([.horizontal, .vertical], spacing / 2)
                        .alignmentGuide(.leading, computeValue: { d in
                            if (abs(width - d.width) > g.size.width) {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            if item == items.last { width = 0 } else { width -= d.width }
                            return result
                        })
                        .alignmentGuide(.top, computeValue: { d in
                            let result = height
                            if item == items.last { height = 0 }
                            return result
                        })
                }
            }
            .background(viewHeightReader($totalHeight))
        }
        .frame(height: totalHeight)
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async { binding.wrappedValue = geometry.frame(in: .local).size.height }
            return .clear
        }
    }
}

// MARK: - ОСТАЛЬНЫЕ КОМПОНЕНТЫ (PRIVATE)

private struct ChatHeader: View {
    let mentor: Mentor
    let scenarioTitle: String
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: 15) {
            Button(action: onDismiss) { Image(systemName: "chevron.left").font(.title3).bold().foregroundStyle(.primary).frame(width: 40, height: 40).background(Color(uiColor: .secondarySystemBackground)).clipShape(Circle()) }
            ZStack { Circle().fill(mentorColor.opacity(0.15)); Image(systemName: mentorIcon).foregroundStyle(mentorColor) }.frame(width: 45, height: 45)
            VStack(alignment: .leading, spacing: 2) { Text(scenarioTitle).font(.headline); Text("Наставник: \(mentor.displayName)").font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }.padding().background(Color(uiColor: .systemBackground)).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 5)
    }
    var mentorColor: Color { switch mentor { case .freya: return .green; case .loki: return .purple; case .odin: return .blue } }
    var mentorIcon: String { switch mentor { case .freya: return "leaf.fill"; case .loki: return "flame.fill"; case .odin: return "eye.fill" } }
}

private struct CorrectionView: View {
    let corrections: [ChatCorrection]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(corrections, id: \.original) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.original).strikethrough().foregroundStyle(.secondary).font(.caption)
                        Text(item.corrected).bold().foregroundStyle(.green).font(.subheadline)
                        if !item.explanation.isEmpty { Text(item.explanation).font(.caption2).foregroundStyle(.secondary) }
                    }
                }.padding(10).background(Color.orange.opacity(0.1)).cornerRadius(12)
            }
        }.padding(.top, 4)
    }
}

private struct InputArea: View {
    @Binding var text: String; let isLoading: Bool; let onSend: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            TextField("Сообщение...", text: $text).padding(12).background(Color(uiColor: .secondarySystemBackground)).cornerRadius(20).disabled(isLoading).submitLabel(.send).onSubmit(onSend)
            Button(action: onSend) { Image(systemName: "paperplane.fill").font(.title2).foregroundStyle(text.isEmpty ? .gray : .blue).padding(10).background(Color.blue.opacity(0.1)).clipShape(Circle()) }.disabled(text.isEmpty || isLoading)
        }.padding().background(Color(uiColor: .systemBackground)).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: -5)
    }
}

private struct TypingIndicator: View {
    let mentor: Mentor; @State private var isAnimating = false
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            MentorAvatar(mentor: mentor)
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle().fill(Color.gray).frame(width: 6, height: 6).scaleEffect(isAnimating ? 1.0 : 0.5).opacity(isAnimating ? 1.0 : 0.5).animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: isAnimating)
                }
            }.padding(15).background(Color(uiColor: .secondarySystemBackground)).clipShape(BubbleShape(isUser: false))
        }.frame(maxWidth: .infinity, alignment: .leading).onAppear { isAnimating = true }
    }
}

private struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        var corners: UIRectCorner = [.topLeft, .topRight]
        if isUser { corners.insert(.bottomLeft) } else { corners.insert(.bottomRight) }
        return Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: 16, height: 16)).cgPath)
    }
}

private struct MentorAvatar: View {
    let mentor: Mentor
    var body: some View { ZStack { Circle().fill(Color(uiColor: .secondarySystemBackground)); Image(systemName: icon).foregroundStyle(color) }.frame(width: 32, height: 32) }
    var icon: String { switch mentor { case .freya: return "leaf.fill"; case .loki: return "flame.fill"; case .odin: return "eye.fill" } }
    var color: Color { switch mentor { case .freya: return .green; case .loki: return .purple; case .odin: return .blue } }
}

private struct UserAvatar: View {
    let data: Data
    var body: some View { if let uiImage = UIImage(data: data) { Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 32, height: 32).clipShape(Circle()) } else { Image(systemName: "person.circle.fill").font(.largeTitle).foregroundStyle(.gray) } }
}
