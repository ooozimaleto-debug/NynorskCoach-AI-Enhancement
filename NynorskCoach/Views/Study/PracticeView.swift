//
//  PracticeView.swift
//  NynorskCoach
//
//  Week 2 UI — practice screen: a fixed adaptive set from ExerciseGenerator,
//  stepped through one at a time with the shared ExerciseView.
//
//  Unlike the quiz, the set is generated once up front (no per-question network
//  round trips) and difficulty isn't adapted mid-set — it's a calmer drill mode.
//

import SwiftUI

@MainActor
final class PracticeViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var index = 0
    @Published private(set) var correctCount = 0
    @Published private(set) var feedback: ExerciseFeedback?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var source: GenerationSource = .model

    private let provider: PracticeSetProviding
    private let count: Int

    init(provider: PracticeSetProviding, count: Int = 6) {
        self.provider = provider
        self.count = count
    }

    var current: Exercise? {
        exercises.indices.contains(index) ? exercises[index] : nil
    }

    var isFinished: Bool {
        !exercises.isEmpty && index >= exercises.count
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        index = 0
        correctCount = 0
        feedback = nil
        do {
            let set = try await provider.generateAdaptiveSet(count: count)
            exercises = set.exercises
            source = set.source
            if exercises.isEmpty { errorMessage = "Не удалось сгенерировать упражнения." }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Не удалось загрузить упражнения."
        }
        isLoading = false
    }

    func submit(_ answer: String) {
        guard let e = current, feedback == nil else { return }
        let ok = e.isCorrect(answer)
        if ok { correctCount += 1 }
        feedback = ExerciseFeedback(
            wasCorrect: ok,
            acceptedAnswers: e.acceptedAnswers,
            explanation: e.explanation
        )
    }

    func advance() {
        feedback = nil
        index += 1
    }
}

struct PracticeView: View {
    @StateObject private var model: PracticeViewModel
    @State private var loaded = false

    init(model: PracticeViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                if model.isFinished {
                    finishedCard
                } else if let exercise = model.current {
                    progressHeader
                    ExerciseView(
                        exercise: exercise,
                        feedback: model.feedback,
                        onSubmit: model.submit,
                        onContinue: model.advance
                    )
                    .id(exercise.id)
                } else if model.isLoading {
                    loading
                } else if let message = model.errorMessage {
                    errorState(message)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Практика")
        .task {
            guard !loaded else { return }
            loaded = true
            await model.load()
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(model.index + 1) из \(model.exercises.count)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if model.source == .fallback {
                    Text("offline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: Double(model.index), total: Double(max(model.exercises.count, 1)))
                .tint(Theme.accent)
        }
    }

    private var finishedCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Bra jobba!")
                .font(.largeTitle.bold())
            Text("Верно: \(model.correctCount) из \(model.exercises.count)")
                .font(.title3)
                .foregroundStyle(.secondary)
            PrimaryActionButton(title: "Новый набор") {
                Task { await model.load() }
            }
        }
        .card()
    }

    private var loading: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.accent)
            Text("Готовлю упражнения…")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            PrimaryActionButton(title: "Повторить") {
                Task { await model.load() }
            }
            .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PracticeView(model: PracticeViewModel(provider: MockPracticeProvider()))
    }
}
#endif
