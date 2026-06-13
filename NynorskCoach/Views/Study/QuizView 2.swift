//
//  QuizView.swift
//  NynorskCoach
//
//  Week 2 UI — adaptive quiz screen, bound to AdaptiveQuizEngine.
//
//  Flow: start -> ExerciseView (submit -> feedback) -> advance -> ... -> summary.
//  The engine owns adaptation; this view only renders state and forwards taps.
//

import SwiftUI

struct QuizView: View {
    @StateObject private var engine: AdaptiveQuizEngine
    @State private var started = false

    init(engine: AdaptiveQuizEngine) {
        _engine = StateObject(wrappedValue: engine)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                if engine.isFinished, let summary = engine.summary {
                    SummaryCard(summary: summary) {
                        Task { await engine.start() }
                    }
                } else if let question = engine.currentQuestion {
                    progressHeader
                    ExerciseView(
                        exercise: question,
                        feedback: currentFeedback,
                        onSubmit: { answer in Task { await engine.submit(answer) } },
                        onContinue: { Task { await engine.advance() } }
                    )
                    .id(question.id)
                } else if engine.isLoading {
                    loading
                } else if let message = engine.errorMessage {
                    errorState(message)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Квиз")
        .task {
            guard !started else { return }
            started = true
            await engine.start()
        }
    }

    private var currentFeedback: ExerciseFeedback? {
        engine.lastResult.map {
            ExerciseFeedback(
                wasCorrect: $0.wasCorrect,
                acceptedAnswers: $0.exercise.acceptedAnswers,
                explanation: $0.exercise.explanation
            )
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Вопрос \(min(engine.answered + 1, engine.targetQuestions)) из \(engine.targetQuestions)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Label("\(engine.correctCount)", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.correct)
            }
            ProgressView(value: Double(engine.answered), total: Double(engine.targetQuestions))
                .tint(Theme.accent)
        }
    }

    private var loading: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.accent)
            Text("Подбираю следующий вопрос…")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            PrimaryActionButton(title: "Повторить") {
                Task { await engine.retry() }
            }
            .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

// MARK: - Summary

private struct SummaryCard: View {
    let summary: AdaptiveQuizEngine.Summary
    let onRestart: () -> Void

    private var percent: Int { Int((summary.accuracy * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Готово!")
                .font(.largeTitle.bold())

            HStack(spacing: 24) {
                stat(value: "\(percent)%", caption: "точность")
                stat(value: "\(summary.correct)/\(summary.total)", caption: "верно")
            }

            if summary.suggestedLevelChange != 0 {
                Label(
                    summary.suggestedLevelChange > 0
                        ? "Похоже, можно поднять уровень — задания даются легко."
                        : "Стоит немного снизить уровень и закрепить основы.",
                    systemImage: summary.suggestedLevelChange > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
            }

            Divider()

            Text("По темам")
                .font(.headline)
            ForEach(summary.perSkill, id: \.skill) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.skill.label).font(.subheadline)
                        Spacer()
                        Text("\(Int((item.mastery * 100).rounded()))%")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: item.mastery)
                        .tint(item.mastery >= 0.85 ? Theme.correct : Theme.accent)
                }
            }

            PrimaryActionButton(title: "Ещё раз", action: onRestart)
                .padding(.top, 4)
        }
        .card()
    }

    private func stat(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title.bold()).foregroundStyle(Theme.accent)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        QuizView(engine: AdaptiveQuizEngine(
            provider: MockQuizProvider(),
            context: MockLearnerContext(),
            config: {
                var c = AdaptiveQuizEngine.Config()
                c.maxQuestions = 5
                c.minQuestions = 3
                return c
            }()
        ))
    }
}
#endif
