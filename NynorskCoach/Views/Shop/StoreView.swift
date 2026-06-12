
import SwiftUI

struct StoreView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var storeManager = StoreManager.shared
    @State private var showingAlert = false
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 25) {
                        // Баланс
                        HStack {
                            Text("Твой кошель:".localized).font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 6) {
                                Text("\(storeManager.coins)").font(.system(size: 24, weight: .heavy, design: .rounded))
                                Image(systemName: "bitcoinsign.circle.fill").font(.title2).foregroundStyle(.yellow)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color(uiColor: .secondarySystemBackground)).clipShape(Capsule())
                        }
                        .padding(.horizontal).padding(.top)
                        
                        // Секции
                        StoreSection(title: "Магия и Защита".localized, items: storeManager.consumables)
                        StoreSection(title: "Снаряжение Героя".localized, items: storeManager.equipment)
                        StoreSection(title: "Свитки и Темы".localized, items: storeManager.themes)
                        
                        Spacer().frame(height: 50)
                    }
                }
            }
            .navigationTitle("Лавка Ярла".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть".localized) { dismiss() } }
            }
            .alert("Не хватает золота!".localized, isPresented: $showingAlert) {
                Button("Ок", role: .cancel) { }
            } message: {
                Text("Учись усерднее, чтобы заработать больше.".localized)
            }
        }
    }
    
    @ViewBuilder
    func StoreSection(title: String, items: [StoreItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.title2).bold().padding(.horizontal)
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(items) { item in
                        StoreItemCard(item: item) { buyItem(item) }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    func buyItem(_ item: StoreItem) {
        // Если куплено и не расходник - не покупаем
        if storeManager.isPurchased(item.id) && item.type != .consumable { return }
        
        if storeManager.buy(item: item) {
            AudioManager.shared.play(.coin)
            HapticManager.shared.notification(type: .success)
        } else {
            AudioManager.shared.play(.error)
            showingAlert = true
        }
    }
}

struct StoreItemCard: View {
    let item: StoreItem
    let action: () -> Void
    @ObservedObject var storeManager = StoreManager.shared
    
    var isPurchased: Bool { storeManager.isPurchased(item.id) }
    var isActive: Bool {
        if item.type == .theme { return storeManager.activeCardSkin == item.id }
        if item.type == .equipment { return storeManager.activeHelmet == item.id }
        return false
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    // ЛОГИКА ОТОБРАЖЕНИЯ ИКОНКИ (Fix)
                    // Сначала пробуем загрузить из Assets, если нет - SF Symbol
                    if UIImage(named: item.iconName) != nil {
                        Image(item.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 65, height: 65)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else {
                        Image(systemName: item.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                    
                    Spacer()
                    
                    if isPurchased && item.type != .consumable {
                        Image(systemName: isActive ? "checkmark.seal.fill" : "checkmark.circle.fill")
                            .font(.title2).foregroundStyle(isActive ? .blue : .green)
                    } else {
                        HStack(spacing: 2) {
                            Text("\(item.price)").font(.headline)
                            Image(systemName: "bitcoinsign.circle.fill").font(.caption).foregroundStyle(.yellow)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemBackground)).cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name.localized).font(.headline).foregroundStyle(.primary).lineLimit(1)
                    Text(item.description.localized).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isActive ? Color.blue : Color.clear, lineWidth: 2))
            .opacity(isPurchased && item.type != .consumable && !isActive ? 0.6 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
