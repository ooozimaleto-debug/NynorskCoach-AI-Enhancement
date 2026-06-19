//
//  LearnerContextBuilder.swift
//  NynorskCoach
//
//  Builds the learner's "weak vocabulary" pool for AI prompt injection
//  (replaces the empty `recentVocabulary` stub in IntegrationAdapters.swift)
//  and computes how many of those words a generated text should target,
//  based on comprehensible-input research (Hu & Nation / Laufer).
//

import Foundation
import SwiftData

/// Snapshot of a learner's in-progress vocabulary pool.
///
/// File-level by design: per project convention, structs used as default
/// parameter values must not be nested inside @MainActor-isolated classes,
/// since callers outside that actor context couldn't reference the type.
struct LearnerVocabularyPool: Sendable {
    let words: [String]
}

enum LearnerContextBuilder {

    /// Defensive ceiling so a learner with thousands of in-progress cards
    /// never blows up the prompt payload.
    static let maxPoolSize = 100

    /// Upper bound on `interval` (days) for a word to still count as YELLOW.
    /// Mirrors the `SRSColor.gray` threshold in `DataModels.swift`
    /// (`interval > 7`): past this point a word is well-practised and
    /// reinforced fine through the normal flashcard SRS cycle — it doesn't
    /// need to be force-fed into generated text anymore, even though
    /// `LearningStatus` itself doesn't flip to `.mastered` until `interval > 30`.
    private static let grayIntervalThreshold = 7.0

    /// Fetches the RED + YELLOW vocabulary pool for prompt injection.
    ///
    /// Colour mapping mirrors `WordOverlayView`: RED == `.new`, YELLOW ==
    /// `.learning`, `.mastered` is excluded entirely. `SRSService` flips
    /// `status` from `.new` to `.learning` on the very first review and
    /// `.new` items are always created with `interval == 0`, so filtering
    /// on `interval > 0` already excludes RED. The extra `interval <=
    /// grayIntervalThreshold` cap additionally excludes words that are
    /// technically still `.learning` but already `SRSColor.gray` (interval
    /// 7–30) — those are reinforced by the flashcard cycle, not by
    /// text-generation prompts.
    static func weakVocabularyPool(in context: ModelContext) -> LearnerVocabularyPool {
        var descriptor = FetchDescriptor<LearningItem>(
            predicate: #Predicate { $0.interval > 0 && $0.interval <= grayIntervalThreshold }
        )
        descriptor.sortBy = [SortDescriptor(\.nextReviewDate)]
        descriptor.fetchLimit = maxPoolSize

        let items = (try? context.fetch(descriptor)) ?? []
        let words = items
            .filter { $0.status != .mastered }
            .map(\.text)
        return LearnerVocabularyPool(words: words)
    }

    /// Target share of *already-known* vocabulary for comprehensible input,
    /// by CEFR level. Below ~90% known coverage, comprehension breaks down
    /// statistically (Hu & Nation 2000; Laufer 1989).
    private static let knownCoverageByLevel: [ExerciseDifficulty: Double] = [
        .a1: 0.98,
        .a2: 0.96,
        .b1: 0.93,
        .b2: 0.90
    ]

    /// How many *unfamiliar* (RED/YELLOW pool) words to deliberately seed
    /// into a generated text of `textLength` words, given the learner's
    /// level's target coverage of already-known vocabulary.
    ///
    /// targetWordCount = textLength × (1 − coveragePercent)
    static func targetVocabularyCount(level: ExerciseDifficulty, textLength: Int) -> Int {
        let coverage = knownCoverageByLevel[level] ?? 0.93
        let raw = Double(textLength) * (1 - coverage)
        return max(0, Int(raw.rounded()))
    }

    /// Convenience: words to actually inject into a prompt for a given
    /// level/text length, sliced from the pool to the computed target count.
    static func vocabularyToInject(
        from pool: LearnerVocabularyPool,
        level: ExerciseDifficulty,
        textLength: Int
    ) -> [String] {
        let count = targetVocabularyCount(level: level, textLength: textLength)
        guard count > 0 else { return [] }
        return Array(pool.words.prefix(count))
    }
}
