//
//  ExerciseView.swift
//  NynorskCoach
//
//  Week 2 UI — the one reusable exercise renderer.
//
//  Renders any `Exercise` by its `type`, collects the learner's answer, and once
//  the owner supplies an `ExerciseFeedback`, switches to a result + "Далее" state.
//  Decoupled from any engine: the parent grades the answer and passes feedback in.
//
//  Apply `.id(exercise.id)` at the call site so input state resets per question.
//

import SwiftUI
import Combine

struct ExerciseView: View {
    let exercise: Exercise
    /// nil while the learner is answering; set after submit to show the result.
    let feedback: ExerciseFeedback?
    let onSubmit: (String) -> Void
    let onContinue: () -> Void

    @State private var selected: String?       // multipleChoice
    @State private var textAnswer = ""         // text-based types
    @State private var placed: [String] = []   // wordOrder — assembled
    @State private var pool: [String] = []     // wordOrder — remaining tokens

    private var answering: Bool { feedback == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            header

            if let context = exercise.context, !context.isEmpty {
                Text(context)
                    .font(.title3.weight(.medium))
                    .padding(.vertical, 4)
            }

            Text(exercise.prompt)
                .font(.body)
                .foregroundStyle(.secondary)

            inputArea

            if let feedback {
                feedbackArea(feedback)
            } else {
                PrimaryActionButton(title: "Проверить", enabled: canSubmit) {
                    onSubmit(currentAnswer)
                }
            }
        }
        .card()
        .animation(.easeInOut(duration: 0.2), value: feedback != nil)
        .onAppear(perform: resetState)
        .onChange(of: exercise.id) { resetState() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(exercise.type.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Theme.accent.opacity(0.12))
                .foregroundStyle(Theme.accent)
                .clipShape(Capsule())
            Spacer()
            Text(exercise.difficulty.rawValue.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Input area per type

    @ViewBuilder
    private var inputArea: some View {
        switch exercise.type {
        case .multipleChoice:
            choiceList
        case .wordOrder:
            wordOrderArea
        default: // fillInBlank, conjugation, translation, bokmaalToNynorsk, matching
            textField
        }
    }

    private var choiceList: some View {
        VStack(spacing: 10) {
            ForEach(exercise.options, id: \.self) { option in
                Button {
                    if answering { selected = option }
                } label: {
                    HStack {
                        Text(option).font(.body)
                        Spacer()
                        if selected == option && answering {
                            Image(systemName: "largecircle.fill.circle")
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(optionForeground(option))
                .background(optionBackground(option))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(optionBorder(option), lineWidth: 1.5)
                )
                .disabled(!answering)
            }
        }
    }

    private var textField: some View {
        TextField("Ваш ответ на нюнорске", text: $textAnswer)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.title3)
            .padding(14)
            .background(Theme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(!answering)
    }

    private var wordOrderArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Assembled sentence
            FlowChips(items: placed.isEmpty ? ["…"] : placed,
                      style: .placed,
                      enabled: answering) { token in
                guard let idx = placed.firstIndex(of: token) else { return }
                placed.remove(at: idx)
                pool.append(token)
            }
            .frame(minHeight: 44)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Remaining tokens
            FlowChips(items: pool, style: .pool, enabled: answering) { token in
                guard let idx = pool.firstIndex(of: token) else { return }
                pool.remove(at: idx)
                placed.append(token)
            }
        }
    }

    // MARK: Feedback

    private func feedbackArea(_ f: ExerciseFeedback) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: f.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(f.wasCorrect ? "Riktig!" : "Ikkje heilt")
                    .font(.headline)
            }
            .foregroundStyle(f.wasCorrect ? Theme.correct : Theme.wrong)

            if !f.wasCorrect, let answer = f.acceptedAnswers.first {
                Text("Правильно: \(answer)")
                    .font(.subheadline.weight(.medium))
            }

            if !f.explanation.isEmpty {
                Text(f.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            PrimaryActionButton(title: "Далее", action: onContinue)
        }
        .padding(.top, 4)
    }

    // MARK: Answer assembly + validation

    private var currentAnswer: String {
        switch exercise.type {
        case .multipleChoice: return selected ?? ""
        case .wordOrder:      return placed.joined(separator: " ")
        default:              return textAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var canSubmit: Bool {
        switch exercise.type {
        case .multipleChoice: return selected != nil
        case .wordOrder:      return !placed.isEmpty
        default:              return !currentAnswer.isEmpty
        }
    }

    private func resetState() {
        selected = nil
        textAnswer = ""
        placed = []
        pool = exercise.options.shuffled()
    }

    // MARK: Option styling (also reflects correctness after feedback)

    private func optionIsCorrect(_ option: String) -> Bool {
        exercise.acceptedAnswers.contains { $0.caseInsensitiveCompare(option) == .orderedSame }
    }

    private func optionForeground(_ option: String) -> Color {
        guard feedback != nil else { return .primary }
        if optionIsCorrect(option) { return Theme.correct }
        if option == selected { return Theme.wrong }
        return .secondary
    }

    private func optionBackground(_ option: String) -> Color {
        if answering { return selected == option ? Theme.accent.opacity(0.10) : Theme.subtle }
        if optionIsCorrect(option) { return Theme.correct.opacity(0.10) }
        if option == selected { return Theme.wrong.opacity(0.10) }
        return Theme.subtle
    }

    private func optionBorder(_ option: String) -> Color {
        if answering { return selected == option ? Theme.accent : .clear }
        if optionIsCorrect(option) { return Theme.correct }
        if option == selected { return Theme.wrong }
        return .clear
    }
}

// MARK: - Simple wrapping chip row for wordOrder

private struct FlowChips: View {
    enum Style { case placed, pool }
    let items: [String]
    let style: Style
    let enabled: Bool
    let onTap: (String) -> Void

    var body: some View {
        // Lightweight wrap using a flexible HStack grid.
        FlexibleWrap(items: items) { token in
            Button { if enabled, token != "…" { onTap(token) } } label: {
                Text(token)
                    .font(.body)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(style == .pool ? Theme.accent.opacity(0.12) : Theme.surface)
                    .foregroundStyle(token == "…" ? Color.secondary : Color.primary)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .disabled(!enabled || token == "…")
        }
    }
}

/// Minimal flow layout that wraps chips onto multiple lines.
private struct FlexibleWrap<Content: View>: View {
    let items: [String]
    @ViewBuilder let content: (String) -> Content
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            self.generate(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generate(in geo: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                content(item)
                    .padding(4)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0; height -= d.height
                        }
                        let result = width
                        if item == items.last { width = 0 } else { width -= d.width }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last { height = 0 }
                        return result
                    }
            }
        }
        .background(heightReader)
    }

    private var heightReader: some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async { totalHeight = geo.size.height }
            return .clear
        }
    }
}

#if DEBUG
#Preview("Multiple choice") {
    StatefulPreview(exercise: .sampleMultipleChoice())
        .padding()
}

#Preview("Word order") {
    StatefulPreview(exercise: .sampleWordOrder())
        .padding()
}

/// Tiny harness that grades locally so the preview is interactive.
private struct StatefulPreview: View {
    let exercise: Exercise
    @State private var feedback: ExerciseFeedback?

    var body: some View {
        ExerciseView(
            exercise: exercise,
            feedback: feedback,
            onSubmit: { answer in
                feedback = ExerciseFeedback(
                    wasCorrect: exercise.isCorrect(answer),
                    acceptedAnswers: exercise.acceptedAnswers,
                    explanation: exercise.explanation
                )
            },
            onContinue: { feedback = nil }
        )
    }
}
#endif

