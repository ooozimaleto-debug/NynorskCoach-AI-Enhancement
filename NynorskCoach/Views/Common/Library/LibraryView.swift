import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var lm = LocalizationManager.shared
    
    // Храним порядок секций
    @AppStorage("librarySectionOrder") private var sectionOrder = "decks,news,stories,podcasts,grammar"
    
    // Временная переменная только для работы делегата
    @State private var draggingSection: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 10)

                        let sections = sectionOrder.components(separatedBy: ",")
                        
                        ForEach(sections, id: \.self) { sectionID in
                            sectionView(for: sectionID)
                                // УБРАЛИ ручное управление opacity, чтобы не было залипаний
                                .onDrag {
                                    self.draggingSection = sectionID
                                    return NSItemProvider(object: sectionID as NSString)
                                }
                                .onDrop(of: [.text], delegate: SectionDropDelegate(
                                    item: sectionID,
                                    current: $draggingSection,
                                    moveAction: { from, to in moveSection(from: from, to: to) }
                                ))
                        }
                        
                        // Статичные заглушки
                        LibraryCard(title: "Norskprøve", subtitle: "Гос. экзамен (Скоро)".localized, icon: "doc.text.fill", color: .gray).opacity(0.6).disabled(true)
                        LibraryCard(title: "Культура".localized, subtitle: "Статьи о Норвегии (Скоро)".localized, icon: "map.fill", color: .gray).opacity(0.6).disabled(true)
                    }
                    .padding(.horizontal)
                    // Анимация привязана только к изменению данных в AppStorage
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sectionOrder)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    func sectionView(for id: String) -> some View {
        switch id {
        case "decks":
            NavigationLink(destination: AllDecksView()) {
                LibraryCard(title: "Колоды карт".localized, subtitle: "Мои слова и темы".localized, icon: "rectangle.stack.fill", color: .indigo)
            }
        case "news":
            NavigationLink(destination: NewsFeedView()) {
                LibraryCard(title: "Новости (Live)".localized, subtitle: "NRK Nynorsk", icon: "newspaper.fill", color: .red)
            }
        case "stories":
            NavigationLink(destination: StoriesView()) {
                LibraryCard(title: "Истории".localized, subtitle: "Читаем и слушаем сказки".localized, icon: "book.pages.fill", color: .blue)
            }
        case "podcasts":
            NavigationLink(destination: PodcastView()) {
                LibraryCard(title: "Подкасты".localized, subtitle: "Диалоги и обсуждения".localized, icon: "headphones", color: .purple)
            }
        case "grammar":
            NavigationLink(destination: GrammarView()) {
                LibraryCard(title: "Грамматика".localized, subtitle: "Справочник и проверка".localized, icon: "text.book.closed.fill", color: .orange)
            }
        default: EmptyView()
        }
    }

    func moveSection(from: String, to: String) {
        var sections = sectionOrder.components(separatedBy: ",")
        guard let fromIndex = sections.firstIndex(of: from),
              let toIndex = sections.firstIndex(of: to),
              fromIndex != toIndex else { return }
        
        sections.remove(at: fromIndex)
        sections.insert(from, at: toIndex)
        sectionOrder = sections.joined(separator: ",")
    }
}

// MARK: - Дизайн карточки
struct LibraryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 60, height: 60)
                Image(systemName: icon).font(.title).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3).bold().foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if color != .gray { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Drop Delegate
struct SectionDropDelegate: DropDelegate {
    let item: String
    @Binding var current: String?
    let moveAction: (String, String) -> Void
    
    func dropEntered(info: DropInfo) {
        if let current = current, current != item {
            moveAction(current, item)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        current = nil
        return true
    }
}
