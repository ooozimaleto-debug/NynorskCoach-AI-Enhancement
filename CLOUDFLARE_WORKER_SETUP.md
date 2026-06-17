# Cloudflare Worker Proxy — план миграции API-ключей

> Документ восстановлен после потери оригинала. Зафиксированные решения ниже **не пересматриваются** — только реализация под актуальный код (проверено на коммите `752b515`).

## 0. Почему это критично (не просто "best practice")

Проверка `NynorskCoachApp.swift` / `Secrets.swift` показала:

- Ключи (`openAIKey`, `deepSeekKey`, `googleKey`) читаются из Keychain.
- Keychain заполняется **только** через `Secrets.setTestKeys(...)`, который обёрнут в `#if DEBUG`.
- Этот метод нигде не вызывается автоматически при старте приложения.

**Вывод: в релизной сборке (App Store) у обычного пользователя Keychain пуст — AI-функции (чат, перевод, истории, TTS) не будут работать вообще**, потому что нет механизма доставки реальных ключей на устройство. Cloudflare Worker не просто закрывает дыру безопасности — это единственный способ запустить AI в продакшене без хардкода ключей в бинарник.

## 1. Зафиксированные решения

1. **Провайдер**: Cloudflare Workers (free tier, 100k req/day, без карты).
2. **Auth**: `X-App-Token` (shared secret) + `X-Device-ID` (`identifierForVendor`). Не bulletproof — App Attest в Phase 2.
3. **Rate limit** (Workers KV, per-device per-route):
   - OpenAI chat/vision: 30/min, 500/day
   - DeepSeek: 60/min, 1000/day
   - Google TTS: 30/min, 500/day
4. **Routes** (см. §2 — добавлен 4-й роут, был упущен в исходном плане):
   - `POST /v1/ai/openai` → `api.openai.com/v1/chat/completions`
   - `POST /v1/ai/deepseek` → `api.deepseek.com/v1/chat/completions`
   - `POST /v1/ai/google-tts` → `texttospeech.googleapis.com/v1/text:synthesize`
   - `POST /v1/ai/openai-tts` → `api.openai.com/v1/audio/speech` **(новое, см. ниже)**
5. **Google TTS**: авторизация через header `X-Goog-Api-Key`, не query string.
6. **MVP scope**: без streaming, без кэша, без App Attest, без IAP, без failover.
7. **Единый источник**: URL воркера + app token живут в `Secrets.swift` (gitignored). Старые ключи провайдеров удаляются из `Secrets.swift` и со всех call sites.
8. **Цена**: $0 на старте.

## 2. Расхождения с кодом, которые нашлись при проверке

| # | Было в плане | Реальность в коде | Решение |
|---|---|---|---|
| A | DeepSeek URL: `api.deepseek.com/chat/completions` | `Secrets.swift` default: `.../v1/chat/completions` | Беру `/v1/...` — это реальный endpoint, которым код пользуется сейчас |
| B | 3 роута (openai / deepseek / google-tts) | `OpenAIService.generateSpeech()` дёргает **отдельный** endpoint `api.openai.com/v1/audio/speech` (OpenAI TTS), не chat/completions | Добавляю 4-й роут `/v1/ai/openai-tts`. **Нужно подтверждение лимита** — предлагаю как у google-tts: 30/min, 500/day |
| C | — | `ImageService.swift` использует `Secrets.unsplashKey` напрямую к Unsplash API (вне списка роутов) | Оставляю как есть — вне скоупа этой миграции. Остаточный риск (см. §6), но Unsplash key менее критичен (нет биллинга, есть бесплатный лимит на стороне Unsplash) |
| D | — | `KeychainManager`/`setTestKeys` для openAI/deepSeek/google становятся мёртвым кодом после миграции | Удаляю эти ветки из `Secrets.swift`, `KeychainManager` остаётся для Unsplash |

## 3. Архитектура Worker

```
iOS App
  │  X-App-Token, X-Device-ID, JSON body
  ▼
Cloudflare Worker
  ├─ проверка X-App-Token === env.APP_SHARED_TOKEN  → 401
  ├─ требует X-Device-ID присутствует               → 400
  ├─ rate limit check в KV (per device, per route)   → 429
  └─ proxy запроса на upstream с реальным ключом из env.*_API_KEY
       (ключ никогда не попадает на устройство)
```

### worker.js (draft — создаётся при подтверждении)

```js
const ROUTES = {
  "/v1/ai/openai": {
    upstream: "https://api.openai.com/v1/chat/completions",
    authHeader: (h, env) => h.set("Authorization", `Bearer ${env.OPENAI_API_KEY}`),
    limits: { perMinute: 30, perDay: 500 },
  },
  "/v1/ai/openai-tts": {
    upstream: "https://api.openai.com/v1/audio/speech",
    authHeader: (h, env) => h.set("Authorization", `Bearer ${env.OPENAI_API_KEY}`),
    limits: { perMinute: 30, perDay: 500 }, // TODO: подтвердить с тобой
  },
  "/v1/ai/deepseek": {
    upstream: "https://api.deepseek.com/v1/chat/completions",
    authHeader: (h, env) => h.set("Authorization", `Bearer ${env.DEEPSEEK_API_KEY}`),
    limits: { perMinute: 60, perDay: 1000 },
  },
  "/v1/ai/google-tts": {
    upstream: "https://texttospeech.googleapis.com/v1/text:synthesize",
    authHeader: (h, env) => h.set("X-Goog-Api-Key", env.GOOGLE_API_KEY),
    limits: { perMinute: 30, perDay: 500 },
  },
};

export default {
  async fetch(request, env) {
    if (request.method !== "POST") return new Response("Not found", { status: 404 });

    const url = new URL(request.url);
    const route = ROUTES[url.pathname];
    if (!route) return new Response("Not found", { status: 404 });

    const appToken = request.headers.get("X-App-Token");
    const deviceId = request.headers.get("X-Device-ID");
    if (!appToken || appToken !== env.APP_SHARED_TOKEN) {
      return json({ error: "unauthorized" }, 401);
    }
    if (!deviceId) return json({ error: "missing device id" }, 400);

    const limited = await isRateLimited(env.RATE_LIMIT_KV, deviceId, url.pathname, route.limits);
    if (limited) return json({ error: "rate limit exceeded" }, 429);

    const headers = new Headers({ "Content-Type": "application/json" });
    route.authHeader(headers, env);

    const upstreamResp = await fetch(route.upstream, {
      method: "POST",
      headers,
      body: request.body,
    });

    return new Response(upstreamResp.body, {
      status: upstreamResp.status,
      headers: upstreamResp.headers,
    });
  },
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json" } });
}

async function isRateLimited(kv, deviceId, route, limits) {
  const minuteKey = `${deviceId}:${route}:m`;
  const dayKey = `${deviceId}:${route}:d`;

  const [minuteCount, dayCount] = await Promise.all([
    kv.get(minuteKey).then((v) => parseInt(v || "0", 10)),
    kv.get(dayKey).then((v) => parseInt(v || "0", 10)),
  ]);

  if (minuteCount >= limits.perMinute || dayCount >= limits.perDay) return true;

  await Promise.all([
    kv.put(minuteKey, String(minuteCount + 1), { expirationTtl: 60 }),
    kv.put(dayKey, String(dayCount + 1), { expirationTtl: 86400 }),
  ]);

  return false;
}
```

> Известное ограничение: Workers KV — eventually consistent, при настоящем конкурентном бурсте с одного device ID возможен небольшой over/undercount. Для одного мобильного клиента (запросы последовательны) это не проблема. Точная атомарность через Durable Objects — избыточно для MVP.

### wrangler.toml (draft)

```toml
name = "nynorskcoach-proxy"
main = "worker.js"
compatibility_date = "2025-01-01"

[[kv_namespaces]]
binding = "RATE_LIMIT_KV"
id = "<заполнится после wrangler kv namespace create>"
```

Секреты (`OPENAI_API_KEY`, `DEEPSEEK_API_KEY`, `GOOGLE_API_KEY`, `APP_SHARED_TOKEN`) — через `wrangler secret put`, в `wrangler.toml` не попадают.

## 4. Изменения на iOS-стороне

### Secrets.swift — новая форма

```swift
struct Secrets {
    // Cloudflare Worker proxy
    static let workerBaseURL = "https://nynorskcoach-proxy.<subdomain>.workers.dev"
    static let appToken = "<тот же UUID/токен, что в wrangler secret put APP_SHARED_TOKEN>"

    // Unsplash — вне скоупа этой миграции, остаётся в Keychain
    private static let keychain = KeychainManager.shared
    static let unsplashAccountName = "unsplash_api_key"
    static var unsplashKey: String { keychain.getKey(forAccount: unsplashAccountName) ?? "" }
}
```

Удаляется: `openAIKey`, `deepSeekKey`, `googleKey`, `apiURL`, `deepSeekURL`, `initializeKeys()`, `setTestKeys()`/`clearAllKeys()` для трёх провайдеров.

### Новый helper — DeviceIdentity.swift

```swift
import UIKit

enum DeviceIdentity {
    static var id: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }
}
```

### OpenAIService.swift — точки изменений

- `performNetworkRequest`: выбор `urlString` меняется на `Secrets.workerBaseURL + "/v1/ai/openai"` или `"/v1/ai/deepseek"` по `model.provider`; убирается `guard !apiKey.isEmpty`; вместо `Authorization: Bearer` добавляются `X-App-Token` и `X-Device-ID`.
- `performVisionRequest`: url → `Secrets.workerBaseURL + "/v1/ai/openai"`, те же заголовки.
- `generateSpeech`: url → `Secrets.workerBaseURL + "/v1/ai/openai-tts"` (новый роут), убирается `Secrets.openAIKey` guard, те же заголовки.

### GoogleTTSService.swift — fetchAudio

- url → `Secrets.workerBaseURL + "/v1/ai/google-tts"` (без `?key=` в query).
- убирается guard на `apiKey.contains("ВСТАВИТЬ")`.
- добавляются `X-App-Token`, `X-Device-ID`.
- body (`input`/`voice`/`audioConfig`) не меняется — Worker сам подставит `X-Goog-Api-Key`.

### NynorskCoachApp.swift

- убирается вызов `Secrets.initializeKeys()` (метод удалён вместе с Keychain-веткой для трёх провайдеров).

## 5. Кто что делает

**Я (Claude) делаю автоматически:**
- пишу `worker.js`, `wrangler.toml`
- правки в `Secrets.swift`, `DeviceIdentity.swift` (новый), `OpenAIService.swift`, `GoogleTTSService.swift`, `NynorskCoachApp.swift`
- `npm install -g wrangler` (если не установлен)
- `wrangler kv namespace create RATE_LIMIT_KV` (после твоего логина)
- `wrangler deploy`
- тестовые curl-запросы к роутам после деплоя

**Ты делаешь руками (требует браузер/секреты, не должно идти через меня):**
- `wrangler login` — OAuth в браузере
- `wrangler secret put OPENAI_API_KEY` / `DEEPSEEK_API_KEY` / `GOOGLE_API_KEY` / `APP_SHARED_TOKEN` — 4 интерактивные команды, вводишь реальные значения сам (включая придуманный `APP_SHARED_TOKEN`, например `openssl rand -hex 32`)
- даёшь мне itog: URL воркера (`*.workers.dev`) и сам `APP_SHARED_TOKEN`, чтобы я вписал их в `Secrets.swift`
- финальный билд + ручной тест на устройстве/симуляторе

## 6. Риски

- **App token статичен и шьётся в бинарник** — при экстракции (strings/Frida) злоумышленник получает доступ к Worker без device-специфичных лимитов (может слать много разных `X-Device-ID`). Принятый риск для MVP, закрывается App Attest в Phase 2.
- **KV-лимиты не строго атомарны** — приемлемо для одного устройства, но не защищает от distributed abuse при утечке токена.
- **Unsplash key остаётся клиентским** (вне скоупа) — отдельный остаточный риск, ниже приоритетом, т.к. без биллинга.
- **Один shared secret для всех пользователей** — компрометация требует ручной ротации (`wrangler secret put` + новый билд приложения) для всех клиентов одновременно.
- **Cloudflare free tier условия могут измениться** — на момент написания 100k req/day без карты; стоит перепроверить при регистрации.

## 7. Открытый вопрос для подтверждения

Лимит для нового роута `/v1/ai/openai-tts` — предлагаю 30/min, 500/day (как google-tts). Подтверди или скорректируй.
