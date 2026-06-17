import WidgetKit
import SwiftUI
import SwiftData

// --- 1. МОДЕЛЬ ДАННЫХ ДЛЯ ВИДЖЕТА ---
// В реальном проекте файлы DataModels.swift должны быть включены в Target виджета.
// Если нет - код не скомпилируется.
// Предполагаем, что LearningItem доступен.

struct SimpleEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let word: String
    let translation: String
    let gender: String?
}

// --- 2. ПРОВАЙДЕР ---
// --- 2. ПРОВАЙДЕР ---
struct Provider: TimelineProvider {
    // APP GROUP ID
    let appGroup = "group.com.abzac.NynorskCoach"
    
    // ModelContainer (Non-isolated for background thread safety)
    func getSharedContainer() -> ModelContainer? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        let dbURL = containerURL.appendingPathComponent("NynorskCoach.store")
        
        let schema = Schema([LearningItem.self, Topic.self])
        
        // Use simpler init without label if needed, or specific label.
        // If 'url:' is extraneous, try init(_ url: URL) or just init(url)
        let config = ModelConfiguration(url: dbURL)
        return try? ModelContainer(for: schema, configurations: [config])
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), streak: 5, word: "Nynorsk", translation: "Норвежский", gender: "none")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date(), streak: 10, word: "Kjærleik", translation: "Любовь", gender: "masculine")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        var word = "Velkommen"
        var trans = "Добро пожаловать"
        var gender: String? = nil
        
        // 1. Пытаемся достать слово из SwiftData
        if let container = getSharedContainer() {
            let context = ModelContext(container)
            // Fetch ALL (safest for macro issues) and filter in memory
            let descriptor = FetchDescriptor<LearningItem>()
            
            if let items = try? context.fetch(descriptor) {
                // Filter where status != mastered. 
                // Assuming .mastered works if file is imported correctly.
                let activeItems = items.filter { $0.status != .mastered }
                
                if let randomItem = activeItems.randomElement() {
                    word = randomItem.text
                    trans = randomItem.translation
                    gender = randomItem.gender.rawValue
                }
            }
        }
        
        // 2. Достаем стрик из UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: appGroup)
        let streak = defaults?.integer(forKey: "streak") ?? 0
        
        let entry = SimpleEntry(date: Date(), streak: streak, word: word, translation: trans, gender: gender)
        
        // Обновляем раз в час
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// --- 3. ЛОКАЛИЗАЦИЯ (Простая) ---
func localizedLabel(_ key: String) -> String {
    let lang = Locale.current.language.languageCode?.identifier ?? "en"
    switch key {
    case "streak":
        if lang == "ru" { return "Стрик" }
        if lang == "uk" { return "Стрік" }
        if lang == "pl" { return "Seria" }
        return "Streak"
    case "word_of_day":
        if lang == "ru" { return "СЛОВО ДНЯ" }
        if lang == "uk" { return "СЛОВО ДНЯ" }
        if lang == "pl" { return "SŁOWO DNIA" }
        return "WORD OF DAY"
    default: return key
    }
}

// --- 4. VIEW ВИДЖЕТА ---
struct NynorskWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall, .systemMedium:
            MainWidgetView(entry: entry, isMedium: family == .systemMedium)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            MainWidgetView(entry: entry, isMedium: false)
        }
    }
}

struct MainWidgetView: View {
    let entry: SimpleEntry
    let isMedium: Bool
    
    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(LinearGradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "sailboat.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if entry.streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").font(.caption).foregroundStyle(.orange)
                            Text("\(entry.streak)").font(.caption).bold().foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial).clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedLabel("word_of_day"))
                        .font(.caption2).fontWeight(.black).foregroundStyle(.white.opacity(0.6))
                    
                    HStack(alignment: .lastTextBaseline) {
                        Text(entry.word)
                            .font(.title).bold().foregroundStyle(.white)
                            .minimumScaleFactor(0.8).lineLimit(1)
                        
                        if let gender = entry.gender, gender != "none" {
                            Text(gender == "masculine" ? "m" : (gender == "feminine" ? "f" : "n"))
                                .font(.caption).italic().foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    
                    Text(entry.translation)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.9)).lineLimit(2)
                }
            }
            .padding()
        }
        .widgetURL(URL(string: "nynorskcoach://word?text=\(entry.word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
    }
}

struct CircularWidgetView: View {
    let entry: SimpleEntry
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.3), lineWidth: 4)
            Circle().trim(from: 0, to: min(CGFloat(entry.streak) / 30.0, 1.0))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 0) {
                Image(systemName: "flame.fill").font(.caption2)
                Text("\(entry.streak)").font(.caption).bold()
            }
        }
    }
}

struct InlineWidgetView: View {
    let entry: SimpleEntry
    var body: some View {
        Text("🇳🇴 \(entry.word) - \(entry.translation)")
    }
}

struct RectangularWidgetView: View {
    let entry: SimpleEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(localizedLabel("word_of_day")).font(.caption2).foregroundStyle(.secondary)
                Text(entry.word).font(.headline).bold()
                Text(entry.translation).font(.caption)
            }
            Spacer()
        }
    }
}

// --- 5. КОНФИГУРАЦИЯ ---
@main
struct NynorskWidget: Widget {
    let kind: String = "NynorskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                NynorskWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                NynorskWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Nynorsk Coach")
        .description("Слово дня и твой прогресс")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

