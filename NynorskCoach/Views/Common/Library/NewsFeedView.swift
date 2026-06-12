import SwiftUI

struct NewsFeedView: View {
    @StateObject private var rss = RSSService.shared
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if rss.isLoading && rss.news.isEmpty {
                ProgressView("Загрузка новостей...".localized)
            } else if rss.news.isEmpty {
                ContentUnavailableView(
                    "Нет новостей".localized,
                    systemImage: "wifi.slash",
                    description: Text("Проверьте интернет или попробуйте позже.".localized)
                )
                Button("Обновить".localized) { rss.fetchNews() }
            } else {
                List {
                    ForEach(rss.news) { item in
                        NavigationLink(destination: ReaderView(
                            articleTitle: item.title,
                            articleContent: item.description,
                            originalURL: item.link
                        )) {
                            NewsRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    rss.fetchNews()
                }
            }
        }
        // Локализация заголовка
        .navigationTitle("Новости (NRK)".localized)
        .onAppear {
            if rss.news.isEmpty {
                rss.fetchNews()
            }
        }
    }
}

struct NewsRow: View {
    let item: RSSItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Картинка (если есть)
            if let urlString = item.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Color.gray.opacity(0.2)
                    } else {
                        ProgressView()
                    }
                }
                .frame(height: 180)
                .clipped()
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                
                Text(item.pubDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(item.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.vertical, 4)
    }
}
