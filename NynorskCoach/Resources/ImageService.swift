import Foundation
import SwiftUI
import Combine

struct UnsplashResult: Decodable {
    let results: [UnsplashPhoto]
}
struct UnsplashPhoto: Decodable {
    let urls: UnsplashURLs
}
struct UnsplashURLs: Decodable {
    let regular: String
    let small: String
}

class ImageService: ObservableObject {
    static let shared = ImageService()
    
    private let accessKey = Secrets.unsplashAccessKey
    
    // Возвращает массив картинок (Data)
    func searchImages(query: String, count: Int = 5) async throws -> [Data] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.unsplash.com/search/photos?page=1&query=\(encodedQuery)&client_id=\(accessKey)&per_page=\(count)"
        
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("Unsplash Error: \(httpResponse.statusCode)")
            return []
        }
        
        let result = try JSONDecoder().decode(UnsplashResult.self, from: data)
        
        // Скачиваем все найденные картинки параллельно
        var imagesData: [Data] = []
        
        // Берем первые 'count' URL
        let urlsToLoad = result.results.prefix(count).compactMap { URL(string: $0.urls.small) }
        
        for imgUrl in urlsToLoad {
            if let (imgData, _) = try? await URLSession.shared.data(from: imgUrl) {
                imagesData.append(imgData)
            }
        }
        
        return imagesData
    }
}
