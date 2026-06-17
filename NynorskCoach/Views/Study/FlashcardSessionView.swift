import SwiftUI
import SwiftData
import AVFoundation
import UIKit

// MARK: - 1. MAIN SCREEN
struct FlashcardSessionView: View {
    let topic: Topic
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var context
    
    @ObservedObject var storeManager = StoreManager.shared
    
    @State private var currentIndex = 0
    @State private var sessionItems: [LearningItem] = []
    @State private var swipeStatus: SRSGrade? = nil
    @State private var showCoinAlert = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 0) {
                // Header
                SessionHeader(
                    current: min(currentIndex + 1, sessionItems.count),
                    total: sessionItems.count,
                    coins: storeManager.coins,
                    onDismiss: { dismiss() }
                ).padding(.bottom, 20)
                
                // Deck Area
                GeometryReader { geo in
                    ZStack {
                        if sessionItems.isEmpty {
                            Text("Слова закончились").font(.headline).foregroundStyle(.secondary)
                        } else if currentIndex < sessionItems.count {
                            CardStack(
                                items: sessionItems,
                                currentIndex: $currentIndex,
                                swipeStatus: $swipeStatus,
                                activeSkin: storeManager.activeCardSkin,
                                cardSize: CGSize(width: geo.size.width - 40, height: geo.size.height - 40),
                                onFinish: { dismiss() },
                                onProcessResult: processResult
                            )
                        } else {
                            FinishView(onFinish: { dismiss() })
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Footer
                SessionFooter(swipeStatus: swipeStatus)
                    .frame(height: 80)
                    .padding(.bottom, 10)
            }
            
            if showCoinAlert { CoinPopup() }
        }
        .navigationBarHidden(true)
        .onAppear { loadItems() }
    }
    
    func loadItems() {
        let items = topic.items.sorted { $0.nextReviewDate < $1.nextReviewDate }
        sessionItems = items.isEmpty ? topic.items.shuffled() : items
    }
    
    func processResult(item: LearningItem, grade: SRSGrade) {
        let now = Date()
        if grade == .good || grade == .easy {
            if Int.random(in: 1...100) <= 15 {
                storeManager.addCoins(1)
                withAnimation { showCoinAlert = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { showCoinAlert = false } }
            }
        }
        
        item.lastReviewDate = now
        item.reviewCount += 1
        
        let q: Double = (grade == .again ? 0 : (grade == .hard ? 3 : (grade == .good ? 4 : 5)))
        let newEF = item.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        item.easeFactor = max(1.3, newEF)
        
        if grade == .again {
            item.status = .learning
            item.interval = 0
            item.nextReviewDate = now.addingTimeInterval(60)
        } else {
            if item.reviewCount == 1 { item.interval = 1 }
            else if item.reviewCount == 2 { item.interval = 6 }
            else { item.interval = round(item.interval * item.easeFactor) }
            
            if grade == .hard { item.interval = max(1, item.interval * 0.5) }
            
            item.nextReviewDate = now.addingTimeInterval(item.interval * 86400)
            item.status = (item.interval > 21) ? .mastered : .learning
        }
        try? context.save()
    }
}

// MARK: - 2. CARD STACK
struct CardStack: View {
    let items: [LearningItem]
    @Binding var currentIndex: Int
    @Binding var swipeStatus: SRSGrade?
    let activeSkin: String
    let cardSize: CGSize
    let onFinish: () -> Void
    let onProcessResult: (LearningItem, SRSGrade) -> Void
    
    @State private var offset: CGSize = .zero // For final animation only
    @GestureState private var gestureTranslation: CGSize = .zero // For interactive drag
    @State private var isFlipped = false

    var computedOffset: CGSize {
        if offset != .zero { return offset } // Animation in progress
        return gestureTranslation // Interactive drag
    }
    
    var body: some View {
        ZStack {
            if currentIndex + 1 < items.count {
                UniversalCard(
                    item: items[currentIndex + 1],
                    isFlipped: false,
                    activeSkin: activeSkin,
                    isTopCard: false,
                    width: cardSize.width,
                    height: cardSize.height,
                    onPlayAudio: {}
                )
                .scaleEffect(0.95).offset(y: 15).opacity(0.6)
            }
            
            if currentIndex < items.count {
                UniversalCard(
                    item: items[currentIndex],
                    isFlipped: isFlipped,
                    activeSkin: activeSkin,
                    isTopCard: true,
                    width: cardSize.width,
                    height: cardSize.height,
                    onPlayAudio: { speak(items[currentIndex].text) }
                )
                .offset(x: computedOffset.width, y: computedOffset.height)
                .rotationEffect(.degrees(Double(computedOffset.width / 15)))
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
                .rotation3DEffect(.degrees(Double(computedOffset.width / 10)), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
                .rotation3DEffect(.degrees(Double(-computedOffset.height / 10)), axis: (x: 1, y: 0, z: 0), perspective: 0.8)

                .gesture(DragGesture()
                    .updating($gestureTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onChanged { val in
                        updateSwipeStatus(translation: val.translation)
                    }
                    .onEnded { val in
                        endSwipe(translation: val.translation)
                    }
                )
                .onTapGesture {
                    let willBeFlipped = !isFlipped
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isFlipped.toggle()
                    }
                    if willBeFlipped { speak(items[currentIndex].text) }
                    AudioManager.shared.play(.click)
                }
            }
        }
    }
    
    func updateSwipeStatus(translation: CGSize) {
        if abs(translation.width) > abs(translation.height) { swipeStatus = translation.width > 0 ? .easy : .again }
        else { swipeStatus = translation.height > 0 ? .good : .hard }
    }
    
    func endSwipe(translation: CGSize) {
        guard currentIndex < items.count else { return }
        let threshold: CGFloat = 80
        if abs(translation.width) > threshold || abs(translation.height) > threshold {
            let status = swipeStatus ?? .good
            onProcessResult(items[currentIndex], status)
            
            // Animate away
            withAnimation(.easeIn(duration: 0.3)) {
                offset = CGSize(width: translation.width > 0 ? 500 : -500, height: translation.height > 0 ? 500 : -500)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentIndex += 1
                offset = .zero
                isFlipped = false
                swipeStatus = nil
            }
        } else {
            // Reset happens automatically via GestureState, but we clear status
            withAnimation(.spring()) {
                swipeStatus = nil
            }
        }
    }
    
    func speak(_ text: String) {
        Task { await SpeechService.shared.speak(text: text) }
    }
}

// MARK: - 3. UNIVERSAL CARD
struct UniversalCard: View {
    let item: LearningItem
    let isFlipped: Bool
    let activeSkin: String
    let isTopCard: Bool
    let width: CGFloat
    let height: CGFloat
    let onPlayAudio: () -> Void
    
    @State private var animatePulse = false
    @State private var activeSheet: SheetType?
    
    enum SheetType: Identifiable {
        case past, grammar, future
        var id: Int { hashValue }
    }
    
    var body: some View {
        ZStack {
            ArtifactBackground(skin: activeSkin, isPulse: animatePulse)
            
            VStack(spacing: 0) {
                // ВЕРХ
                ZStack {
                    if !isFlipped {
                        VStack {
                            HStack {
                                Spacer()
                                AudioButton(skin: activeSkin, action: {
                                    Task { await SpeechService.shared.speak(text: item.text, rate: 1.0) }
                                })
                                SlowAudioButton(skin: activeSkin, action: {
                                    Task { await SpeechService.shared.speak(text: item.text, rate: 0.65) }
                                })
                            }
                            Spacer()
                        }
                        .padding(20)
                    }
                    
                    VStack(spacing: 15) {
                        Spacer()
                        SmartIcon(item: item, size: 140)
                            .transition(.scale.combined(with: .opacity))
                            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                        
                        if isFlipped {
                            Text(item.translation)
                                .font(.system(size: 32, weight: .medium, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(textColor.opacity(0.9))
                                .minimumScaleFactor(0.6)
                                .padding(.horizontal, 20)
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        } else {
                            Text(item.text)
                                .font(.system(size: 44, weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(textColor)
                                .shadow(color: activeSkin == "skin_runes" ? .blue.opacity(0.6) : .clear, radius: 10)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 15)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 10)
                }
                .frame(height: height * 0.65)
                
                ArtifactDivider(skin: activeSkin).frame(height: 2)
                
                // НИЗ
                ZStack {
                    if isFlipped {
                        VStack(spacing: 12) {
                            if let transcription = item.transcription, !transcription.isEmpty {
                                Text("[\(transcription)]")
                                    .font(.system(size: 28, weight: .regular, design: .monospaced))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            if let context = item.contextSentence {
                                Text(context)
                                    .font(.system(size: 16))
                                    .italic()
                                    .foregroundStyle(secondaryTextColor.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        HStack(spacing: 40) {
                            RuneButton(icon: "clock.arrow.circlepath", label: "Fortid", skin: activeSkin) { activeSheet = .past }
                            RuneButton(icon: "tablecells", label: "Former", skin: activeSkin) { activeSheet = .grammar }
                            RuneButton(icon: "arrow.right.circle", label: "Framtid", skin: activeSkin) { activeSheet = .future }
                        }
                        .padding(.bottom, 10)
                    }
                }
                .frame(height: height * 0.35)
            }
        }
        .frame(width: width, height: height)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: shadowColor, radius: isTopCard ? 10 : 2)
        .onAppear { withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { animatePulse = true } }
        .sheet(item: $activeSheet) { type in
            QuickInfoSheet(type: type, item: item)
                .presentationDetents([.fraction(0.5)])
        }
    }
    
    private var textColor: Color { activeSkin == "skin_runes" ? .white : Color(hex: "451A03") }
    private var secondaryTextColor: Color { activeSkin == "skin_runes" ? .white.opacity(0.8) : Color.black.opacity(0.6) }
    private var shadowColor: Color { activeSkin == "skin_runes" ? Color.cyan.opacity(0.4) : Color.black.opacity(0.15) }
}

// MARK: - ВСПОМОГАТЕЛЬНЫЕ КОМПОНЕНТЫ

struct QuickInfoSheet: View {
    let type: UniversalCard.SheetType
    let item: LearningItem
    
    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: iconForType).font(.title).foregroundStyle(.blue)
                    Text(titleForType).font(.title2).bold()
                }
                .padding(.top, 30)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        if type == .grammar {
                            if let forms = item.forms, !forms.isEmpty, let pos = item.partOfSpeech {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Text("Ubestemt").font(.caption).bold().frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Bestemt").font(.caption).bold().frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.bottom, 8)
                                    .foregroundStyle(.secondary)
                                    
                                    if pos == "noun" && forms.count >= 4 {
                                        Text("Entall").font(.caption2).foregroundStyle(.gray).padding(.top, 4)
                                        Divider().padding(.vertical, 4)
                                        HStack { Text(forms[0]).bold().frame(maxWidth: .infinity, alignment: .leading); Text(forms[1]).frame(maxWidth: .infinity, alignment: .leading) }
                                        Text("Flertall").font(.caption2).foregroundStyle(.gray).padding(.top, 12)
                                        Divider().padding(.vertical, 4)
                                        HStack { Text(forms[2]).bold().frame(maxWidth: .infinity, alignment: .leading); Text(forms[3]).frame(maxWidth: .infinity, alignment: .leading) }
                                    } else if pos == "verb" && forms.count >= 4 {
                                        GrammarRow(label: "Infinitiv", value: forms[0].hasPrefix("å ") ? forms[0] : "å \(forms[0])")
                                        GrammarRow(label: "Presens", value: forms[1])
                                        GrammarRow(label: "Preteritum", value: forms[2])
                                        GrammarRow(label: "Perfektum", value: forms[3])
                                    } else if pos == "adj" && forms.count >= 3 {
                                        GrammarRow(label: "M/F", value: forms[0])
                                        GrammarRow(label: "Intetkjønn", value: forms[1])
                                        GrammarRow(label: "Flertall", value: forms[2])
                                    } else {
                                        ForEach(forms, id: \.self) { f in Text("• \(f)").padding(.vertical, 2) }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.6))
                                .cornerRadius(12)
                            } else {
                                ContentUnavailableView("Нет форм", systemImage: "text.book.closed")
                            }
                            
                        } else if type == .past {
                            if let forms = item.forms, forms.count > 2, item.partOfSpeech == "verb" {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(forms[2]).font(.system(size: 40, weight: .bold)).foregroundStyle(.blue).frame(maxWidth: .infinity)
                                    Divider()
                                    Text("Примеры:").font(.caption).bold().foregroundStyle(.secondary)
                                    if let examples = item.pastExamples, !examples.isEmpty {
                                        ForEach(examples, id: \.self) { ex in Text("• \(ex)").italic().padding(.vertical, 2) }
                                    } else { Text("Нет примеров").foregroundStyle(.secondary) }
                                }
                            } else { Text("Нет данных").foregroundStyle(.secondary) }
                        } else {
                            if let forms = item.forms, !forms.isEmpty, item.partOfSpeech == "verb" {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("skal \(forms[0].replacingOccurrences(of: "å ", with: ""))").font(.system(size: 30, weight: .bold)).foregroundStyle(.purple).frame(maxWidth: .infinity)
                                    Divider()
                                    Text("Примеры:").font(.caption).bold().foregroundStyle(.secondary)
                                    if let examples = item.futureExamples, !examples.isEmpty {
                                        ForEach(examples, id: \.self) { ex in Text("• \(ex)").italic().padding(.vertical, 2) }
                                    } else { Text("Нет примеров").foregroundStyle(.secondary) }
                                }
                            } else { Text("Нет данных").foregroundStyle(.secondary) }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    var titleForType: String { type == .past ? "Прошлое" : (type == .grammar ? "Грамматика" : "Будущее") }
    var iconForType: String { type == .past ? "clock.arrow.circlepath" : (type == .grammar ? "tablecells" : "arrow.right.circle") }
}

struct GrammarRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).font(.headline).bold()
        }.padding(.vertical, 4); Divider()
    }
}

// HELPERS
struct RuneButton: View {
    let icon: String; let label: String; let skin: String; let action: () -> Void
    var body: some View { Button(action: action) { VStack { ZStack { Circle().fill(.white.opacity(0.7)).frame(width: 50, height: 50); Image(systemName: icon).font(.system(size: 20)).foregroundStyle(.brown) }; Text(label).font(.caption2).bold().foregroundStyle(.secondary) } } }
}
struct SmartIcon: View {
    let item: LearningItem; let size: CGFloat
    var body: some View { if let data = item.imageData, let ui = UIImage(data: data) { Image(uiImage: ui).resizable().scaledToFill().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 18)) } else { Image(systemName: "sparkles").font(.largeTitle) } }
}
struct AudioButton: View {
    let skin: String; let action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: "speaker.wave.2.fill").font(.title).foregroundStyle(.blue) } }
}
struct SlowAudioButton: View {
    let skin: String; let action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: "tortoise.fill").font(.title).foregroundStyle(.blue) } }
}
struct ArtifactBackground: View {
    let skin: String; let isPulse: Bool
    var body: some View { if skin == "skin_runes" { LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom) } else { Color(hex: "F7F3E8") } }
}
struct ArtifactDivider: View { let skin: String; var body: some View { Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 2) } }
struct SessionHeader: View {
    let current: Int; let total: Int; let coins: Int; let onDismiss: () -> Void
    var body: some View { HStack { Button(action: onDismiss) { Image(systemName: "xmark") }; Spacer(); Text("\(current)/\(total)"); Spacer(); Text("\(coins) 🟡") }.padding() }
}
struct SessionFooter: View {
    let swipeStatus: SRSGrade?
    var body: some View { HStack(spacing: 30) { LegendIcon(icon: "arrow.left", color: .red, label: "Забыл").scaleEffect(swipeStatus == .again ? 1.2 : 1).opacity(swipeStatus == nil || swipeStatus == .again ? 1 : 0.3); LegendIcon(icon: "arrow.up", color: .orange, label: "Трудно").scaleEffect(swipeStatus == .hard ? 1.2 : 1).opacity(swipeStatus == nil || swipeStatus == .hard ? 1 : 0.3); LegendIcon(icon: "arrow.down", color: .blue, label: "Норм").scaleEffect(swipeStatus == .good ? 1.2 : 1).opacity(swipeStatus == nil || swipeStatus == .good ? 1 : 0.3); LegendIcon(icon: "arrow.right", color: .green, label: "Знаю").scaleEffect(swipeStatus == .easy ? 1.2 : 1).opacity(swipeStatus == nil || swipeStatus == .easy ? 1 : 0.3) } }
}
struct LegendIcon: View { let icon: String; let color: Color; let label: String; var body: some View { VStack(spacing: 2) { Image(systemName: icon).foregroundStyle(color); Text(label).font(.caption2).foregroundStyle(.secondary) } } }
struct FinishView: View { let onFinish: () -> Void; var body: some View { Button("Завершить", action: onFinish) } }
struct CoinPopup: View { var body: some View { Text("+1 Золото").padding().background(.white).cornerRadius(10) } }
