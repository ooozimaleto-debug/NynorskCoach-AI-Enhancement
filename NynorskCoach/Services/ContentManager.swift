import Foundation
import SwiftData
import UIKit

@MainActor
class ContentManager {
    static let shared = ContentManager()
    private init() {}
    
    // MARK: - ЗАГРУЗКА В ПРИЛОЖЕНИЕ
    
    func seedInitialContent(context: ModelContext, userRank: VikingRank) {
        let userLang = LocalizationManager.shared.currentLanguage
        print("🚀 Seeding massive content for rank: \(userRank.rawValue)")
        
        var topicsToLoad: [PresetTopic] = []
        
        // Получаем данные из репозитория
        let allPresets = ContentRepository.allPresets
        
        // Логика добавления (накопительная)
        topicsToLoad.append(contentsOf: allPresets.filter { $0.difficulty == "A0" })
        
        if userRank != .oppdagar {
            topicsToLoad.append(contentsOf: allPresets.filter { $0.difficulty == "A1" || $0.difficulty == "A2" })
        }
        
        if userRank == .krigar || userRank == .jarl {
            topicsToLoad.append(contentsOf: allPresets.filter { $0.difficulty == "B1" || $0.difficulty == "B2" || $0.difficulty == "Grammar" })
        }
        
        for preset in topicsToLoad {
            // Локализация названия
            let localizedTitle = preset.translations[userLang] ?? preset.translations["English"] ?? preset.nynorskTitle
            let displayTitle = localizedTitle
            
            let newTopic = Topic(
                name: displayTitle,
                emoji: preset.emoji,
                difficulty: preset.difficulty,
                themeColor: preset.color
            )
            
            context.insert(newTopic)
            
            for wordData in preset.words {
                // Перевод только на русский (как в данных)
                let trans = wordData.translations[userLang] ?? wordData.translations["Russian"] ?? "?"
                let ctxTrans = wordData.contextTrans[userLang] ?? wordData.contextTrans["Russian"] ?? ""
                
                let item = LearningItem(
                    text: wordData.nynorsk,
                    translation: trans,
                    gender: wordData.gender,
                    topic: newTopic,
                    contextSentence: wordData.context,
                    contextTranslation: ctxTrans
                )
                item.status = .new
                context.insert(item)
            }
        }
        
        try? context.save()
        print("✅ SUCCESS: \(topicsToLoad.count) topics loaded.")
    }
}
