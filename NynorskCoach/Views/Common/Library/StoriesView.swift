import SwiftUI
import SwiftData

struct StoriesView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \Article.dateCreated, order: .reverse) var articles: [Article]
    
    @State private var showGenerateSheet = false
    
    var body: some View {
        List {
            if articles.isEmpty {
                ContentUnavailableView {
                    Label("Пока пусто".localized, systemImage: "books.vertical")
                } description: {
                    Text("Сгенерируй свою первую историю на Nynorsk.".localized)
                }
            } else {
                ForEach(articles) { article in
                    NavigationLink(destination: ReaderView(articleTitle: article.title, articleContent: article.content)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.title)
                                .font(.headline)
                            
                            HStack {
                                Text(article.difficulty ?? "A1")
                                    .font(.caption2).bold()
                                    .padding(4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Text(article.dateCreated.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteArticles)
            }
        }
        .navigationTitle("Истории".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showGenerateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showGenerateSheet) {
            GenerateStoryView()
        }
    }
    
    func deleteArticles(at offsets: IndexSet) {
        for index in offsets {
            let article = articles[index]
            context.delete(article)
        }
    }
}
