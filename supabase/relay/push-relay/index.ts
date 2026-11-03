// push-relay: the one place that talks to Firebase Cloud Messaging.
//
// Every pair of twins runs ¡Twins! on their own Supabase project, but the
// Android app has a single Firebase project. Its service-account key must not
// be copied into every pair's project, so it lives here only (one Supabase
// project run by the app's maintainer), and each pair's `notify` function
// asks this relay to deliver.
//
// Not part of a pair's project: deployed separately with verify_jwt = false,
// secrets FIREBASE_SERVICE_ACCOUNT_B64 (base64 service-account JSON) and
// TWINS_RELAY_KEY (shared with the app, checked on every call).
//
// Nothing is stored in Firebase: tokens live in each pair's own database.
// Messages expire after a day if undelivered, and a `collapse` key makes a
// newer notification replace an older one of the same kind on the phone.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

type PushRequest = {
  tokens: string[];
  title: string;
  body: string;
  // Where tapping the notification should go in the app, e.g. "/chat/<id>".
  route?: string;
  // Notifications sharing a key replace each other (one per chat, say).
  collapse?: string;
  // Extra string fields for the app, e.g. a plan's time so the phone can set
  // its own reminder alarm without opening the app.
  data?: Record<string, string>;
};

const MAX_TOKENS = 10;
const FCM_TTL = "86400s";

let cachedToken: { value: string; expiresAt: number } | null = null;

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_B64");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT_B64 is not set");
  return JSON.parse(atob(raw));
}

function base64Url(bytes: Uint8Array | string): string {
  const binary = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(account: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)),
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${base64Url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`Google token exchange failed: ${res.status}`);
  const data = await res.json();
  cachedToken = { value: data.access_token, expiresAt: Date.now() + data.expires_in * 1000 };
  return cachedToken.value;
}

function messageData(payload: PushRequest): Record<string, string> {
  const data: Record<string, string> = {};
  if (payload.data && typeof payload.data === "object") {
    for (const [key, value] of Object.entries(payload.data).slice(0, 12)) {
      if (typeof value === "string") data[key.slice(0, 40)] = value.slice(0, 500);
    }
  }
  if (payload.route) data.route = payload.route;
  return data;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const relayKey = Deno.env.get("TWINS_RELAY_KEY");
  if (!relayKey || req.headers.get("x-twins-relay-key") !== relayKey) return json({ error: "Unauthorized" }, 401);

  let payload: PushRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  const tokens = Array.isArray(payload.tokens) ? payload.tokens.filter((t) => typeof t === "string" && t.length > 0) : [];
  if (tokens.length === 0 || tokens.length > MAX_TOKENS || typeof payload.title !== "string" || typeof payload.body !== "string") {
    return json({ error: "Expected 1-10 tokens, a title and a body" }, 400);
  }

  const account = serviceAccount();
  const bearer = await accessToken(account);
  const endpoint = `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  // Tokens Firebase no longer knows (app uninstalled, data cleared): the
  // caller deletes them so nothing keeps trying to reach a dead phone.
  const invalid: string[] = [];
  const errors: string[] = [];
  let sent = 0;
  await Promise.all(tokens.map(async (token) => {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${bearer}` },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: payload.title.slice(0, 120), body: payload.body.slice(0, 400) },
          data: messageData(payload),
          android: {
            ttl: FCM_TTL,
            priority: "high",
            ...(payload.collapse ? { collapse_key: payload.collapse.slice(0, 64) } : {}),
            notification: payload.collapse ? { tag: payload.collapse.slice(0, 64) } : {},
          },
        },
      }),
    });
    if (res.ok) {
      sent++;
      return;
    }
    const error = await res.json().catch(() => null);
    const code = error?.error?.details?.find((d: { errorCode?: string }) => d.errorCode)?.errorCode ?? error?.error?.status;
    if (code === "UNREGISTERED" || code === "INVALID_ARGUMENT" || res.status === 404) {
      invalid.push(token);
    } else {
      errors.push(`${res.status} ${code ?? ""}`.trim());
    }
  }));

  return json({ sent, invalid, errors });
});
