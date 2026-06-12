import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @Environment(\.modelContext) var context
    
    @AppStorage("userName") private var userName = ""
    @AppStorage("nativeLanguage") private var nativeLanguage = "Russian"
    @AppStorage("userRank") private var userRank: VikingRank = .oppdagar
    @AppStorage("selectedMentor") private var selectedMentorRaw = Mentor.freya.rawValue
    
    @State private var currentStep = 0
    @State private var inputName = ""
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack {
                HStack(spacing: 4) {
                    ForEach(0..<4) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .animation(.default, value: currentStep)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                TabView(selection: $currentStep) {
                    WelcomeStep().tag(0)
                    IdentityStep(name: $inputName, language: $nativeLanguage, rank: $userRank).tag(1)
                    MentorStep(selectedMentor: $selectedMentorRaw).tag(2)
                    FinalStep(onFinish: completeOnboarding).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(), value: currentStep)
                
                Button {
                    nextStep()
                } label: {
                    Text(currentStep == 3 ? "Открыть Врата".localized : "Далее".localized)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isButtonDisabled ? Color.gray : (currentStep == 3 ? Color.green : Color.blue))
                        .cornerRadius(16)
                        .shadow(radius: 5)
                }
                .disabled(isButtonDisabled)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            AudioManager.shared.play(.levelUp)
        }
    }
    
    var isButtonDisabled: Bool {
        if currentStep == 1 && inputName.isEmpty { return true }
        return false
    }
    
    func nextStep() {
        if currentStep < 3 {
            withAnimation { currentStep += 1 }
            HapticManager.shared.impact(style: .light)
            AudioManager.shared.play(.click)
        } else {
            completeOnboarding()
        }
    }
    
    func completeOnboarding() {
        if !inputName.isEmpty { userName = inputName }
        LocalizationManager.shared.currentLanguage = nativeLanguage
        
        Task {
            await MainActor.run {
                ContentManager.shared.seedInitialContent(context: context, userRank: userRank)
            }
        }
        
        AudioManager.shared.play(.success)
        HapticManager.shared.notification(type: .success)
        
        withAnimation {
            isOnboardingCompleted = true
        }
    }
}

// MARK: - ШАГИ (Welcome, Identity - без изменений, сократил для краткости)
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "sailboat.fill")
                .font(.system(size: 100))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("Velkomen!").font(.largeTitle).bold()
            Text("Твой путь к языку фьордов начинается здесь.").foregroundStyle(.secondary)
            Spacer()
        }.padding()
    }
}

struct IdentityStep: View {
    @Binding var name: String
    @Binding var language: String
    @Binding var rank: VikingRank
    let languages = ["Russian", "English", "Ukrainian", "Polish", "Bokmål"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("Кто ты, путник?".localized).font(.largeTitle).bold().padding(.top)
                
                VStack(alignment: .leading) {
                    Text("Твое имя".localized).font(.caption).foregroundStyle(.secondary)
                    TextField("Рагнар Лодброк", text: $name)
                        .padding().background(Color(uiColor: .secondarySystemBackground)).cornerRadius(12)
                }
                
                VStack(alignment: .leading) {
                    Text("Родной язык".localized).font(.caption).foregroundStyle(.secondary)
                    Picker("Язык", selection: $language) {
                        ForEach(languages, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                }
                
                // Ранги
                ForEach(VikingRank.allCases, id: \.self) { r in
                    Button { withAnimation { rank = r } } label: {
                        HStack {
                            Image(systemName: r.emoji).font(.title2).frame(width: 40)
                            VStack(alignment: .leading) {
                                Text(r.rawValue).bold()
                                Text(r.description).font(.caption)
                            }
                            Spacer()
                            if rank == r { Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue) }
                        }
                        .padding()
                        .background(rank == r ? Color.blue.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(rank == r ? Color.blue : Color.clear, lineWidth: 2))
                    }.buttonStyle(.plain)
                }
            }.padding()
        }
    }
}

// MARK: - MENTOR STEP (ИЗМЕНЕН)
struct MentorStep: View {
    @Binding var selectedMentor: String
    
    var body: some View {
        VStack {
            Text("Выбери Наставника".localized).font(.title).bold().padding(.top)
            Text("Кто будет вести тебя к знаниям?".localized).font(.body).foregroundStyle(.secondary)
            
            Spacer()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(Mentor.allCases) { mentor in
                        OnboardingMentorCard(
                            mentor: mentor,
                            isSelected: selectedMentor == mentor.rawValue
                        )
                        .onTapGesture {
                            withAnimation { selectedMentor = mentor.rawValue }
                            HapticManager.shared.impact(style: .medium)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            Spacer()
        }
    }
}

struct OnboardingMentorCard: View {
    let mentor: Mentor
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            // АВАТАР ИЗ ASSETS
            ZStack {
                Image(iconName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: 3))
                    .shadow(radius: isSelected ? 8 : 3)
            }
            
            VStack(spacing: 5) {
                Text(mentor.displayName)
                    .font(.title3).bold()
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(mentor.description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
            }
            
            if isSelected {
                Text("Выбран".localized)
                    .font(.caption).bold().padding(.horizontal, 12).padding(.vertical, 6)
                    .background(color).foregroundStyle(.white).clipShape(Capsule())
            } else {
                Text("Нажать".localized)
                    .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.gray.opacity(0.2)).clipShape(Capsule())
            }
        }
        .padding()
        .frame(width: 220, height: 320)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? color : Color.clear, lineWidth: 3))
        .scaleEffect(isSelected ? 1.05 : 0.95)
        .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 10)
        .animation(.spring(), value: isSelected)
    }
    
    var color: Color {
        switch mentor {
        case .freya: return .green
        case .loki: return .purple
        case .odin: return .blue
        }
    }
    
    // Подставляем имена файлов
    var iconName: String {
        switch mentor {
        case .freya: return "avatar_freya"
        case .loki: return "avatar_loki"
        case .odin: return "avatar_odin"
        }
    }
}

struct FinalStep: View {
    let onFinish: () -> Void
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            if showContent {
                Image(systemName: "door.left.hand.open").font(.system(size: 80)).foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                Text("Врата открыты!".localized).font(.largeTitle).bold().transition(.move(edge: .bottom))
                Text("Удачи в обучении.".localized).foregroundStyle(.secondary).transition(.opacity)
            }
            Spacer()
        }
        .onAppear { withAnimation(.spring(duration: 1.0)) { showContent = true } }
    }
}
