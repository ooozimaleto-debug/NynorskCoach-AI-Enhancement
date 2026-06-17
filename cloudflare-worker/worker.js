// NynorskCoach API proxy
// Скрывает реальные ключи OpenAI/DeepSeek/Google от клиента.
// Auth: X-App-Token (shared secret) + X-Device-ID (rate-limit key).
// См. CLOUDFLARE_WORKER_SETUP.md в корне основного репо за полным планом.

const ROUTES = {
  "/v1/ai/openai": {
    upstream: "https://api.openai.com/v1/chat/completions",
    authHeader: (h, env) => h.set("Authorization", `Bearer ${env.OPENAI_API_KEY}`),
    limits: { perMinute: 30, perDay: 500 },
  },
  "/v1/ai/openai-tts": {
    upstream: "https://api.openai.com/v1/audio/speech",
    authHeader: (h, env) => h.set("Authorization", `Bearer ${env.OPENAI_API_KEY}`),
    limits: { perMinute: 30, perDay: 500 },
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
    if (request.method !== "POST") {
      return new Response("Not found", { status: 404 });
    }

    const url = new URL(request.url);
    const route = ROUTES[url.pathname];
    if (!route) {
      return new Response("Not found", { status: 404 });
    }

    const appToken = request.headers.get("X-App-Token");
    const deviceId = request.headers.get("X-Device-ID");

    if (!appToken || appToken !== env.APP_SHARED_TOKEN) {
      return json({ error: "unauthorized" }, 401);
    }
    if (!deviceId) {
      return json({ error: "missing device id" }, 400);
    }

    const limited = await isRateLimited(env.RATE_LIMIT_KV, deviceId, url.pathname, route.limits);
    if (limited) {
      return json({ error: "rate limit exceeded" }, 429);
    }

    const headers = new Headers({ "Content-Type": "application/json" });
    route.authHeader(headers, env);

    const upstreamResp = await fetch(route.upstream, {
      method: "POST",
      headers,
      body: request.body,
    });

    // Прозрачный passthrough (включая бинарный mp3 от TTS-эндпоинтов).
    return new Response(upstreamResp.body, {
      status: upstreamResp.status,
      headers: upstreamResp.headers,
    });
  },
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function isRateLimited(kv, deviceId, route, limits) {
  const minuteKey = `${deviceId}:${route}:m`;
  const dayKey = `${deviceId}:${route}:d`;

  const [minuteCount, dayCount] = await Promise.all([
    kv.get(minuteKey).then((v) => parseInt(v || "0", 10)),
    kv.get(dayKey).then((v) => parseInt(v || "0", 10)),
  ]);

  if (minuteCount >= limits.perMinute || dayCount >= limits.perDay) {
    return true;
  }

  await Promise.all([
    kv.put(minuteKey, String(minuteCount + 1), { expirationTtl: 60 }),
    kv.put(dayKey, String(dayCount + 1), { expirationTtl: 86400 }),
  ]);

  return false;
}
