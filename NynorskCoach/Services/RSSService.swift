import Foundation
import Combine

// ---------------------------------------------------------
// 1. ЧИСТАЯ МОДЕЛЬ (SENDABLE)
// ---------------------------------------------------------
struct RSSItem: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String
    let link: String
    let pubDate: String
    let imageURL: String?
}

// ---------------------------------------------------------
// 2. ИЗОЛИРОВАННЫЙ ПАРСЕР
// ---------------------------------------------------------
struct RSSParser {
    
    static func parse(data: Data) -> [RSSItem] {
        let parser = XMLParser(data: data)
        let delegate = ParserDelegate()
        parser.delegate = delegate
        _ = parser.parse()
        return delegate.resultItems
    }
    
    private final class ParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {
        var resultItems: [RSSItem] = []
        
        private var currentElement = ""
        private var currentTitle = ""
        private var currentDesc = ""
        private var currentLink = ""
        private var currentPubDate = ""
        private var currentImageURL: String? = nil
        
        // Форматтер для дат NRK (RFC 822)
        // Пример: "Tue, 26 Dec 2023 10:00:00 +0100"
        private lazy var inputDateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
            df.locale = Locale(identifier: "en_US_POSIX")
            return df
        }()
        
        private lazy var outputDateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "d MMM HH:mm" // "26 Dec 10:00"
            df.locale = Locale(identifier: "nb_NO") // Норвежский формат
            return df
        }()
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName
            if elementName == "item" {
                currentTitle = ""
                currentDesc = ""
                currentLink = ""
                currentPubDate = ""
                currentImageURL = nil
            }
            if elementName == "enclosure" || elementName == "media:content" {
                if let url = attributeDict["url"] {
                    currentImageURL = url
                }
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            // NRK иногда использует CDATA, но XMLParser обычно справляется
            switch currentElement {
            case "title": currentTitle += string
            case "description": currentDesc += string
            case "link": currentLink += string
            case "pubDate": currentPubDate += string
            default: break
            }
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "item" {
                let item = RSSItem(
                    title: clean(currentTitle),
                    description: clean(currentDesc),
                    link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                    pubDate: formatDate(currentPubDate),
                    imageURL: currentImageURL
                )
                // Фильтруем пустые новости
                if !item.title.isEmpty {
                    resultItems.append(item)
                }
            }
        }
        
        private func clean(_ text: String) -> String {
            var s = text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "NRK", with: "")
            
            // Удаляем HTML теги
            if s.contains("<") {
                s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            }
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        private func formatDate(_ raw: String) -> String {
            // Очищаем строку от лишних пробелов перед парсингом
            let cleanRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let date = inputDateFormatter.date(from: cleanRaw) {
                return outputDateFormatter.string(from: date)
            }
            // Если не вышло распарсить, возвращаем как есть (или заглушку)
            return cleanRaw
        }
    }
}

// ---------------------------------------------------------
// 3. СЕРВИС
// ---------------------------------------------------------
@MainActor
final class RSSService: ObservableObject {
    static let shared = RSSService()
    
    @Published var news: [RSSItem] = []
    @Published var isLoading = false
    
    // ИСПОЛЬЗУЕМ ВЕСТЛАНД (Там больше всего Нюнорска)
    private let feedURL = URL(string: "https://www.nrk.no/vestland/toppsaker.rss")!
    
    private init() {}
    
    func fetchNews() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: feedURL)
                
                // Проверка статуса ответа
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("RSS Error: HTTP \(httpResponse.statusCode)")
                    self.isLoading = false
                    return
                }
                
                let items = await Task.detached(priority: .userInitiated) {
                    return await RSSParser.parse(data: data)
                }.value
                
                self.news = items
                self.isLoading = false
                
            } catch {
                print("RSS Error: \(error)")
                self.isLoading = false
            }
        }
    }
}
