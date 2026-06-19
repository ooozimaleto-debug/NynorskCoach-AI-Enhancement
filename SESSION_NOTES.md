# Session Notes — 2026-06-17

## Done this session

### Crash fix — FlashcardSessionView.swift:142
- Out-of-range access on `items[currentIndex]` in `CardStack.body` triggered by race in `endSwipe`'s `DispatchQueue.main.asyncAfter(0.3s)` increment.
- Fix: wrapped top `UniversalCard` (incl. `.gesture` and `.onTapGesture`) in `if currentIndex < items.count { ... }`, matching the back-card preview guard.
- Added `guard currentIndex < items.count else { return }` first line in `endSwipe`.
- Verified through 8 swipe-to-end tests (all 4 directions). No crash.

### TTS root cause discovered
- Google Cloud Text-to-Speech has **zero Nynorsk (nn-NO) voices**. Only Bokmål (nb-NO). The old voice config (`nn-NO-Wavenet-E`/`-D`) was hitting 400 INVALID_ARGUMENT on every call; AVSpeechSynthesizer fallback was masking it.
- All cloud TTS providers (Google, Azure, Polly, ElevenLabs) ship only nb-NO for Norwegian as of June 2026. No Nynorsk roadmap visible.
- Compromise: text stays Nynorsk (correctness preserved), spoken pronunciation uses Bokmål phonetics. Standard workaround in Nynorsk apps.

### Voice migration
- `GoogleTTSService.swift:86` — `languageCode: "nn-NO"` → `"nb-NO"`.
- `DataModels.swift:95-97` — Freya `nb-NO-Wavenet-E` (female), Loki `nb-NO-Wavenet-D` (male), Odin `nb-NO-Wavenet-B` (male, different timbre). Loki and Odin now have distinct voices (previously shared one case).
- Verified: Google Wavenet plays on flashcards and podcasts, dramatic quality jump from system Nora.

### Saved-podcast audio persistence bug — fixed
- **Diagnosis (Claude Code investigation):** `SavedPodcast` model had no audio field at all. Save flow flattened `[DialogueLine]` to `"Speaker: text\n\n..."` string, discarding MP3 bytes. Playback parsed transcript back into local `DisplayLine` and called audio-blind `SpeechService.shared.speak(_ text:)` synchronous overload → straight to AVSpeechSynthesizer Nora, never touching Google or audioData.
- **Fix:**
  - `SavedPodcast` gained `@Attribute(.externalStorage) var linesData: Data?` storing JSON-encoded `[DialogueLine]`.
  - `PodcastGeneratorView.saveAndClose` encodes lines via JSONEncoder, assigns to `newPodcast.linesData` alongside the existing transcript.
  - `SpeechService` gained `func playSingleLine(_ line: DialogueLine) async` — plays `line.audioData` via `playAudioData` if present, else falls through to async `speak(text:rate:language:)` (Google path, not the old synchronous native-only).
  - `PodcastView.parseTranscript` decodes `linesData` when present, falls back to flat-text split for legacy podcasts.
  - `PodcastView.playLine` calls `playSingleLine` instead of `speak(text)`.
- **Verified:** new saved podcasts play with both Wavenet voices, persist across kill+relaunch.
- **Legacy podcasts (saved before this fix):** no `linesData`, fall through to async Google path — single voice (no per-speaker data was captured at save time) but at Google quality, not Nora.

### LearnerContextBuilder — replaced empty `recentVocabulary` stub (commit `05f1559`)
- `IntegrationAdapters.swift`'s `UserLearningProfile.recentVocabulary` was a hardcoded `[]` stub. `ExerciseGenerator` and `StoryGenerator` both consumed it for prompt injection (`.prefix(15)` of nothing → always empty).
- New file `LearnerContextBuilder.swift`: `LearnerVocabularyPool` (file-level struct, not nested in the `@MainActor` `UserContextManager` — per convention, structs used as default-parameter values can't be nested inside actor-isolated types) + `LearnerContextBuilder` enum.
- **Final filter** (`weakVocabularyPool(in:)`): `FetchDescriptor<LearningItem>` with `predicate: $0.interval > 0 && $0.interval <= grayIntervalThreshold` (`grayIntervalThreshold = 7.0`), sorted by `nextReviewDate`, `fetchLimit = 100`, then post-filtered `status != .mastered`.
  - Mirrors `WordOverlayView`'s RED/YELLOW colour convention (RED = `.new`, YELLOW = `.learning`). `.new` items always have `interval == 0` (status flips to `.learning` on first review per `SRSService`), so `interval > 0` already excludes RED.
  - The `<= 7.0` cap additionally excludes words that are still `.learning` but already `SRSColor.gray` (interval 7–30) — those are reinforced fine via the normal flashcard SRS cycle, not via text-generation prompts. Without this cap, `status != .mastered` alone would have been wider than RED+YELLOW.
  - Verified at runtime (not just compile-time) with a standalone SwiftData repro on the same Swift 6.2 toolchain: `#Predicate` capturing the unqualified static `grayIntervalThreshold` fetches identically to an inlined literal. (A *qualified* `Type.member` access inside `#Predicate` does fail — but that's a compile-time error, not the access pattern used here.)
- **Density formula** (`targetVocabularyCount(level:textLength:)`): `targetWordCount = textLength × (1 − coveragePercent)`, coverage by CEFR level per Hu & Nation / Laufer comprehensible-input research: A1→98%, A2→96%, B1→93%, B2→90%.
- `ExerciseGenerator.userPrompt` and `StoryGenerator.userPrompt` both replaced their old `context.recentVocabulary.prefix(15)` with `LearnerContextBuilder.vocabularyToInject(from:level:textLength:)`, and both prompts now explicitly instruct the model not to introduce extra unfamiliar words beyond the injected list.
  - `StoryGenerator` uses the real target word count (`length.wordTarget(for: level)`).
  - `ExerciseGenerator` has no continuous text length, so it uses `plan.count * averageWordsPerExerciseItem` (`averageWordsPerExerciseItem = 12`, an eyeballed estimate, not measured — flagged with a TODO to replace once real generation telemetry exists).
- `LearnerContextBuilder.swift` had to be added to `project.pbxproj` manually (file refs + Sources build phase) since `Services/` is a plain `PBXGroup`, not a filesystem-synchronized group — new files there aren't auto-included.

### SwiftData VersionedSchema — attempted, reverted
- Implemented `SchemaV1: VersionedSchema` (1, 0, 0) + `NynorskCoachMigrationPlan: SchemaMigrationPlan` with `stages: []`, wired into `ModelContainer` in `NynorskCoachApp.swift`.
- Widget required deviation: `UserLearningProfile` (in `UserContextManager.swift`) not in widget target Sources, so widget kept narrower `Schema([LearningItem.self, Topic.self])` with literal `Schema.Version(1, 0, 0)` tag.
- **Regression observed:**
  - Saved podcasts disappeared after kill+relaunch (visible within session, gone after restart).
  - SpringBoard crashed on widget add (likely simulator-only — `-[SBHRippleSimulation clear]`, Apple animation bug, see `SPRINGBOARD_CRASH_2026-06-17.md`).
- **Reverted:** deleted `SchemaV1.swift` and `NynorskCoachMigrationPlan.swift`, restored unversioned `Schema([...])` in app and widget, removed pbxproj entries.
- **Verified after revert:** saved podcasts persist across restart. Widget add still crashes (SpringBoard issue, not our code).

## Confirmed working at session end
- Crash on last-card swipe: fixed.
- TTS via Google Wavenet nb-NO: working for cards, live podcasts, saved podcasts.
- Three distinct mentor voices: Freya female, Loki and Odin different male timbres.
- Saved podcasts persist audio across app restarts.
- Schema is unversioned again (no migration plan).

## Open issues
- **Saved podcasts created during the VersionedSchema window (~30 min) are lost.** Simulator-only impact, no real users yet.
- **Widget crash on home-screen add (SpringBoard SIGSEGV)** — Apple simulator bug, retest on real device.

## Key decisions made
- **TTS provider:** Google Cloud Text-to-Speech via existing Worker proxy.
- **Voice tier:** Wavenet (not Chirp 3 HD). Reason: Chirp 3 HD does NOT support `custom_pronunciations` for nb-NO per Google docs. SSML `<phoneme>` IPA override is essential for Nynorsk-specific words (`eg`, `ikkje`, `kva`, etc.). Wavenet supports full SSML.
- **Mentor differentiation:** three separate Wavenet voices, not pitch-shifted single voice. Aligns with the "characters must be unmistakable" principle.
- **Caching architecture (planned):** L0 device App Group cache + L1/L2 Cloudflare Worker+R2 shared cache + L3 Google TTS on miss. Shared cache for shared vocabulary gives 5-10× cost reduction; first-hit latency 30-100ms via CF edge PoP.
- **Schema versioning:** deferred to dedicated session with proper testing strategy (App Group cross-target, widget compat, kill+relaunch verification, fatalError fallback for production).

## Economics summary (for reference)
- Google Wavenet nb-NO: $4-16 per 1M chars (sources conflict, treat as $16 conservative). Free tier: 1M chars/month forever.
- At 1000 paying users × ~13.5K chars/month/DAU after cache = ~$48/month Google bill = $576/year. <10% of realistic revenue at this scale.
- With Cloudflare Worker+R2 shared cache: estimated 5-10× reduction. Free tier likely covers operations until ~100 active users.

## Pending next session (priority order)

### P0 — blockers for App Store
- **Proper SwiftData migration plan**: must handle App Group + cross-target widget. Must include fatalError fallback (degrade to fresh store, not crash on launch). Test with: kill+relaunch, widget add, schema change roundtrip.

### P1 — high value
- **Step 2: async `loadItems` + move `LearningItem.imageData` out of SwiftData blob storage into App Group file storage.** Not started — separate ticket from the `LearnerContextBuilder` work above, which explicitly left `imageData`/blob logic untouched.
- **Cloudflare Worker + R2 cache**: shifts SHA256 cache from device to shared edge. ~2-3h for Claude Code. Cost reduction + faster cold-start for new users.
- **SSML phoneme overrides** for Nynorsk-specific words: hand-curated list of ~50-100 words with IPA. Wavenet supports full SSML for nb-NO.
- **Slowdown for saved podcasts**: `AVAudioPlayer.rate` (built-in time-stretch). Additive feature.

### P2 — quality
- UI unification: podcast generation dialog vs saved podcast view (visual mismatch).
- Mentor picker in flashcard session (no UI to switch mid-session).
- `DailyActivity` missing `@Attribute(.unique) id` — fix before next schema bump.

### P3 — polish
- Production fatalError fallback in `ModelContainer` creation.

## Backlog (deferred)
- Adaptive playback rate (red/yellow → 0.8x, gray/green → 1.0x).
- Settings slider for "slow" rate (currently hardcoded 0.65).
- Rename `AudioService.swift` → `SpeechService.swift` (filename misleading).
- Revisit 6 unused files (IconGeneratorView, LessonUIKit, TactileCardBackground, ImportTextView, DataSeeder, AppIntents) after submission.

## Lessons learned
- **SwiftData VersionedSchema adoption is not free.** Declaring a baseline V1 on an existing unversioned store can cause silent store recreation per launch. Empty `stages=[]` is not equivalent to "no migration needed". Real fix needs careful App Group + cross-target widget design + tested rollback.
- **Google has zero Nynorsk TTS coverage**, and no other provider does either. This is a permanent constraint on the product — accept Bokmål phonetics or use only AVSpeechSynthesizer offline.
- **Chirp 3 HD's docs disqualify it for nb-NO production use** in any project that needs pronunciation control. The Wavenet/Neural2 tier supporting full SSML is the right choice for Nynorsk-correctness-critical apps.
- **TTS errors had been silent for weeks** — old code's `print()` was the only signal, and console output only reached stdout via `simctl launch --console-pty`, not via Xcode's debug console for previously-launched apps. Production needs structured logging (`os_log` or analytics).
