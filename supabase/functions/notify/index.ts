// notify: tell the other twin's phones that something new arrived.
//
// Called by the app right after it saves an item or sends a message, with the
// caller's own JWT. Everything is re-read here with the service role, so a
// client can only trigger a push about something it actually authored, and
// only to its own twin. Delivery goes through the shared push relay (see
// supabase/relay/push-relay), configured by the TWINS_RELAY_URL and
// TWINS_RELAY_KEY secrets that setup sets on every project.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

async function rest(path: string, init: RequestInit = {}): Promise<unknown> {
  const res = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json", ...init.headers },
  });
  if (!res.ok) throw new Error(`${path}: ${res.status}`);
  return res.status === 204 ? null : res.json();
}

async function first<T>(path: string): Promise<T | null> {
  const rows = (await rest(path)) as T[];
  return rows[0] ?? null;
}

type EventRow = {
  space_id: string;
  title: string;
  starts_at: string;
  all_day: boolean;
  remind_minutes: number | null;
  cancelled_at: string | null;
};

const EVENT_KINDS = ["event", "event_update", "event_cancel"];

// The plan's time in the sender's clock; the twins share a timezone, and the
// server's own is UTC.
function formatWhen(event: EventRow, tzOffsetMinutes: number): string {
  const local = new Date(new Date(event.starts_at).getTime() + tzOffsetMinutes * 60_000);
  const day = local.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short", timeZone: "UTC" });
  if (event.all_day) return day;
  const time = local.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", timeZone: "UTC" });
  return `${day}, ${time}`;
}

function truncate(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const relayUrl = Deno.env.get("TWINS_RELAY_URL");
  const relayKey = Deno.env.get("TWINS_RELAY_KEY");
  if (!relayUrl || !relayKey) return json({ skipped: "push not configured" });

  try {
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const userRes = await fetch(`${supabaseUrl}/auth/v1/user`, { headers: { apikey: serviceKey, Authorization: `Bearer ${jwt}` } });
    if (!userRes.ok) return json({ error: "Unauthorized" }, 401);
    const senderId = (await userRes.json()).id as string;

    const { kind, id, tzOffsetMinutes } = await req.json();
    if ((kind !== "item" && kind !== "message" && !EVENT_KINDS.includes(kind)) || typeof id !== "string") {
      return json({ error: "Expected kind and id" }, 400);
    }
    const offset = typeof tzOffsetMinutes === "number" && Math.abs(tzOffsetMinutes) <= 14 * 60 ? tzOffsetMinutes : 0;

    let spaceId: string;
    let body: string;
    let route: string;
    let collapse: string;
    let titleSuffix = "";
    let data: Record<string, string> | undefined;
    if (EVENT_KINDS.includes(kind)) {
      const event = await first<EventRow>(
        `events?id=eq.${encodeURIComponent(id)}&select=space_id,title,starts_at,all_day,remind_minutes,cancelled_at`,
      );
      if (!event) return json({ error: "No such plan" }, 404);
      const member = await first<{ user_id: string }>(
        `space_members?space_id=eq.${event.space_id}&user_id=eq.${senderId}&select=user_id`,
      );
      if (!member) return json({ error: "Not your plan" }, 403);
      spaceId = event.space_id;
      body = `${truncate(event.title, 100)} · ${formatWhen(event, offset)}`;
      route = `/event/${id}`;
      collapse = `event-${id}`;
      titleSuffix = kind === "event" ? " planned something" : kind === "event_update" ? " changed a plan" : " called off a plan";
      // Lets the twin's phone set (or drop) its reminder straight away.
      data = {
        kind: "event",
        event_id: id,
        title: event.title,
        starts_at: event.starts_at,
        all_day: String(event.all_day),
        remind_minutes: event.remind_minutes === null ? "" : String(event.remind_minutes),
        cancelled: String(event.cancelled_at !== null),
      };
    } else if (kind === "item") {
      const item = await first<{ space_id: string; created_by: string; title: string }>(
        `items?id=eq.${encodeURIComponent(id)}&select=space_id,created_by,title`,
      );
      if (!item || item.created_by !== senderId) return json({ error: "Not your item" }, 403);
      spaceId = item.space_id;
      body = truncate(item.title, 140);
      route = `/item/${id}`;
      collapse = "new-items";
      titleSuffix = " saved something";
    } else {
      const message = await first<{ space_id: string; author_id: string; chat_id: string; body: string | null; attached_event_id: string | null }>(
        `messages?id=eq.${encodeURIComponent(id)}&select=space_id,author_id,chat_id,body,attached_event_id`,
      );
      if (!message || message.author_id !== senderId) return json({ error: "Not your message" }, 403);
      // A plan card: the plan's own notification already went out.
      if (message.attached_event_id && !message.body) return json({ sent: 0, skipped: "plan card" });
      spaceId = message.space_id;
      body = message.body ? truncate(message.body, 200) : "Shared an item";
      route = `/chat/${message.chat_id}`;
      // One notification per chat, replaced by the newest message.
      collapse = `chat-${message.chat_id}`;
    }

    const members = (await rest(`space_members?space_id=eq.${spaceId}&select=user_id`)) as { user_id: string }[];
    const recipient = members.map((m) => m.user_id).find((u) => u !== senderId);
    if (!recipient) return json({ sent: 0 });

    const settings = await first<{ notifications_enabled: boolean }>(
      `user_settings?user_id=eq.${recipient}&select=notifications_enabled`,
    );
    if (settings && !settings.notifications_enabled) return json({ sent: 0, muted: true });

    const tokens = ((await rest(`device_tokens?user_id=eq.${recipient}&select=token`)) as { token: string }[]).map((t) => t.token);
    if (tokens.length === 0) return json({ sent: 0 });

    const sender = await first<{ display_name: string }>(`profiles?id=eq.${senderId}&select=display_name`);
    const relayRes = await fetch(relayUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-twins-relay-key": relayKey },
      body: JSON.stringify({ tokens: tokens.slice(0, 10), title: `${sender?.display_name ?? "Your twin"}${titleSuffix}`, body, route, collapse, data }),
    });
    if (!relayRes.ok) return json({ error: `relay ${relayRes.status}` }, 502);
    const result = await relayRes.json() as { sent: number; invalid: string[] };

    if (result.invalid?.length) {
      const list = result.invalid.map((t) => `"${t.replace(/"/g, "")}"`).join(",");
      await rest(`device_tokens?token=in.(${list})`, { method: "DELETE" });
    }
    return json({ sent: result.sent, removed: result.invalid?.length ?? 0 });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
