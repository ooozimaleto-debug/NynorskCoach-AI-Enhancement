# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# List schemes
xcodebuild -project NynorskCoach.xcodeproj -list

# Build for simulator (use scheme "Nynorsk Coach 2.0")
xcodebuild -project NynorskCoach.xcodeproj \
  -scheme "Nynorsk Coach 2.0" \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -configuration Debug build

# Find available simulators
xcrun simctl list devices available | grep -i iphone
```

There are no automated tests in this project. Verification is manual (build + run on device or simulator).

## Architecture

**MVVM + SwiftUI + SwiftData.** No third-party dependencies — pure Apple stack.

### Data Layer

All persistent models are `@Model` classes in `NynorskCoach/Models/DataModels.swift`:
- `Topic` / `LearningItem` — vocabulary deck + SRS card
- `ChatSession` / `PersistedMessage` — mentor chat history
- `SavedPodcast` — offline podcast audio
- `DailyActivity` / `GrammarNote` — activity tracking
- `UserLearningProfile` — AI-driven user profile (see `UserContextManager.swift`)

The `ModelContainer` is created in `NynorskCoachApp.swift` and stored in the **App Group** (`group.ooo.zimaleto.NynorskCoach`) so the widget shares the same SQLite file. If the App Group container is unavailable the app will hit an `assertionFailure`.

### AI / Networking Layer

All AI calls go through a **Cloudflare Worker proxy** — no API keys on the device.

```
iOS → Cloudflare Worker (nynorskcoach-proxy.ooo-zimaleto.workers.dev)
        ├─ POST /v1/ai/openai      → api.openai.com/v1/chat/completions  (gpt-4o vision)
        ├─ POST /v1/ai/deepseek    → api.deepseek.com/v1/chat/completions (text tasks)
        ├─ POST /v1/ai/openai-tts  → api.openai.com/v1/audio/speech
        └─ POST /v1/ai/google-tts  → texttospeech.googleapis.com/v1/text:synthesize
```

Every request carries two headers added by the client:
- `X-App-Token` — shared secret from `Secrets.appToken`
- `X-Device-ID` — `UIDevice.current.identifierForVendor` via `DeviceIdentity.id`

The Worker enforces per-device rate limits via Cloudflare KV (worker source in `cloudflare-worker/`).

**Key service files:**
- `NynorskCoach/Resources/OpenAIService.swift` — all text + vision + OpenAI TTS calls; single `performNetworkRequest` method routes to openai vs deepseek based on `AIModel.provider`
- `NynorskCoach/Services/GoogleTTSService.swift` — Google Neural2 TTS, used for word/podcast audio
- `NynorskCoach/Services/AI/AIModel.swift` — `AIModel` enum (`.creative`/`.balanced`/`.precise` → DeepSeek; `.vision` → GPT-4o)
- `NynorskCoach/Services/AI/MentorPersonalizer.swift` — builds system prompts by combining mentor persona + user rank + task type
- `NynorskCoach/Services/UserContextManager.swift` — tracks session performance and injects user context into prompts

**Unsplash** is the only API still using a client-side key (`Secrets.unsplashKey` from Keychain). All other provider keys were removed in the Worker migration.

### Secrets

`NynorskCoach/Resources/Secrets.swift` is **gitignored**. It contains:
```swift
static let workerBaseURL = "https://nynorskcoach-proxy.ooo-zimaleto.workers.dev"
static let appToken      = "<hex token>"
```
If the file is missing, create it from the template in `CLOUDFLARE_WORKER_SETUP.md §4`.

### Mentor System

Three mentor personas live in `DataModels.swift` (`Mentor` enum): `freya`, `loki`, `odin`. Each has distinct TTS voice (`googleVoiceName`, `openAIVoice`), pitch, and `systemInstruction`. `MentorPersonalizer.getSystemPrompt(mentor:task:userRank:targetLanguage:)` is the single entry point for all system prompts — add new task types via the `AITask` enum in `MentorPersonalizer.swift`.

### SRS / Adaptive Quiz

- `SRSService` applies SM-2 scheduling to `LearningItem` (updates `interval`, `easeFactor`, `dueDate`)
- `AdaptiveQuizEngine` (Week 2) wraps `ExerciseGenerator` for dynamic exercise selection
- `ExerciseGenerator` / `StoryGenerator` are Week 2 additions; `LessonUIKit.swift` depends on both

### Widget

`NynorskWidget/NynorskWidget.swift` reads `LearningItem` and streak directly from the shared App Group SQLite — it cannot import `OpenAIService` or any AI services. Widget schema is limited to `[LearningItem.self, Topic.self]`.

### Localization

UI strings are in `NynorskCoach/Resources/Localizable.xcstrings`. A `.localized` extension is used throughout views (see `Extensions.swift`). Native language for AI explanations is stored in `UserDefaults` key `"nativeLanguage"`.

## Important Conventions

- **Never add a new AI endpoint** without a matching route in `cloudflare-worker/worker.js` and `wrangler.toml`; the Worker will return 404 otherwise.
- **`response_format: json_object`** is required for all non-chat AI calls; `cleanJSON()` in `OpenAIService` strips markdown fences before decoding.
- **App Group ID** (`group.ooo.zimaleto.NynorskCoach`) must match in both `NynorskCoach.entitlements`, `NynorskWidgetExtension.entitlements`, and `Constants.appGroupIdentifier`.
- **TTS choice**: Google TTS (`GoogleTTSService`) is used for words and podcasts; OpenAI TTS (`generateSpeech`) is used in `AudioService` for the mentor voice in chat. The split is intentional — Google Neural2 voices sound more natural for Nynorsk.
