import SwiftUI
import Combine

class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // Хранение монет и покупок
    @AppStorage("coins") var coins = 300
    @AppStorage("purchasedItems") var purchasedItemsString = "default"
    @AppStorage("activeHelmet") var activeHelmet = "default"
    @AppStorage("activeCardSkin") var activeCardSkin = "default"
    
    // MARK: - КАТАЛОГ ТОВАРОВ
    // Исправлен порядок аргументов: id -> name -> description -> iconName -> price -> type
    let items: [StoreItem] = [
        // --- РАСХОДНИКИ (CONSUMABLES) ---
        StoreItem(
            id: "freeze_1",
            name: "Ледяной Щит",
            description: "Защищает стрик на один день.",
            iconName: "snowflake", // Используем SF Symbol или имя ассета
            price: 200,
            type: .consumable // БЫЛО: .freeze
        ),
        
        // --- ТЕМЫ (Скины карточек) ---
        StoreItem(
            id: "skin_wood",
            name: "Драккар (Дерево)",
            description: "Уютная текстура корабельного дерева.",
            iconName: "sailboat.fill",
            price: 150,
            type: .theme
        ),
        StoreItem(
            id: "skin_runes",
            name: "Камень Рун",
            description: "Древняя магия на твоих карточках.",
            iconName: "text.book.closed.fill",
            price: 300,
            type: .theme
        ),
        StoreItem(
            id: "skin_gold",
            name: "Сокровище Ярла",
            description: "Золотой блеск для настоящих богачей.",
            iconName: "crown.fill",
            price: 1000,
            type: .theme
        ),
        
        // --- ЭКИПИРОВКА ---
        StoreItem(
            id: "helmet_iron",
            name: "Железный Шлем",
            description: "Классика для начала пути.",
            iconName: "shield.fill",
            price: 100,
            type: .equipment
        ),
        StoreItem(
            id: "helmet_horns",
            name: "Рогатый Шлем",
            description: "Исторически неверно, но выглядит эпично!",
            iconName: "trophy.fill",
            price: 500,
            type: .equipment
        ),
        StoreItem(
            id: "mask_loki",
            name: "Маска Локи",
            description: "Для тех, кто любит хитрость.",
            iconName: "theatermasks.fill",
            price: 800,
            type: .equipment
        ),
        StoreItem(
            id: "crown_odin",
            name: "Корона Всеотца",
            description: "Только для достойных.",
            iconName: "sun.max.fill",
            price: 2000,
            type: .equipment
        )
    ]
    
    // Хелперы для View (фильтрация по новому типу)
    var consumables: [StoreItem] { items.filter { $0.type == .consumable } }
    var themes: [StoreItem] { items.filter { $0.type == .theme } }
    var equipment: [StoreItem] { items.filter { $0.type == .equipment } }
    
    private init() {}
    
    // MARK: - ЛОГИКА
    
    func addCoins(_ amount: Int) {
        coins += amount
    }
    
    func isPurchased(_ itemId: String) -> Bool {
        if itemId == "default" { return true }
        let list = purchasedItemsString.split(separator: ",").map { String($0) }
        return list.contains(itemId)
    }
    
    // Переименовал в buyItem для соответствия вызову в StoreView,
    // но если там buy(item:), можно оставить buy.
    // Здесь используем buyItem, так как в StoreView.swift (который я видел ранее) вызывается storeManager.buy(item:)
    // Но чтобы совпадало с StoreView, я оставжу имя метода buy, но обновлю логику внутри.
    
    func buy(item: StoreItem) -> Bool {
        // Проверяем .consumable вместо .freeze
        if isPurchased(item.id) && item.type != .consumable {
            return true
        }
        
        if coins >= item.price {
            coins -= item.price
            addItemToInventory(item.id)
            
            if item.type == .consumable {
                print("❄️ Расходник куплен/активирован!")
                // Тут можно дернуть StreakManager
            }
            // Если купили скин, сразу применяем его (опционально)
            if item.type == .theme {
                activeCardSkin = item.id
            }
            // Если купили шлем
            if item.type == .equipment {
                activeHelmet = item.id
            }
            return true
        }
        return false
    }
    
    // Добавил этот метод для совместимости, если где-то вызывается buyItem
    func buyItem(_ item: StoreItem) -> Bool {
        return buy(item: item)
    }
    
    // Добавил метод активации, который используется в StoreView
    func activateItem(_ item: StoreItem) {
        switch item.type {
        case .theme:
            activeCardSkin = item.id
        case .equipment:
            activeHelmet = item.id
        case .consumable:
            print("Расходник использован")
        }
    }
    
    private func addItemToInventory(_ id: String) {
        let list = purchasedItemsString.split(separator: ",").map { String($0) }
        if !list.contains(id) {
            if purchasedItemsString.isEmpty {
                purchasedItemsString = id
            } else {
                purchasedItemsString += ",\(id)"
            }
        }
    }
    
    func getItemColor(_ type: StoreItemType) -> Color {
        switch type {
        case .consumable: return .cyan // Было .freeze
        case .theme: return .purple
        case .equipment: return .orange
        }
    }
}
