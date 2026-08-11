// resolve-link: best-effort URL metadata enrichment for the Add Item flow.
//
// - Detects platform (YouTube / TikTok / Instagram / generic web).
// - Tries oEmbed first (YouTube, TikTok - no auth required), then falls
//   back to scraping OpenGraph/HTML <meta> tags for everything else.
// - If GROQ_API_KEY is set as a Supabase Edge Function secret, optionally
//   polishes the title into a short caption-style title, a 1-sentence
//   summary, and 2-4 suggested tags. Groq is entirely optional: on any
//   failure (missing key, network error, bad response) this simply skips
//   the polish step and returns the raw metadata.
// - Never throws for a "couldn't enrich" case - the client must always be
//   able to save the raw URL even if this returns partial/empty data.
//
// Deploy: supabase functions deploy resolve-link
// Secrets: supabase secrets set GROQ_API_KEY=...   (optional)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type Metadata = {
  title: string | null;
  description: string | null;
  thumbnail_url: string | null;
  platform: "youtube" | "tiktok" | "instagram" | "web";
  // AI-suggested topic tags (Groq). Empty unless GROQ_API_KEY is set and the
  // polish step succeeds.
  tags: string[];
};

function detectPlatform(url: URL): Metadata["platform"] {
  const host = url.hostname.replace(/^www\./, "");
  if (host === "youtu.be" || host.endsWith("youtube.com")) return "youtube";
  if (host.endsWith("tiktok.com")) return "tiktok";
  if (host.endsWith("instagram.com")) return "instagram";
  return "web";
}

async function fetchJson(url: string): Promise<any | null> {
  try {
    const res = await fetch(url, { headers: { "User-Agent": "TwinsApp/1.0" } });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

async function fetchOEmbed(platform: Metadata["platform"], url: string): Promise<Partial<Metadata> | null> {
  if (platform === "youtube") {
    const data = await fetchJson(`https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`);
    if (!data) return null;
    return { title: data.title ?? null, thumbnail_url: data.thumbnail_url ?? null };
  }
  if (platform === "tiktok") {
    const data = await fetchJson(`https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`);
    if (!data) return null;
    return { title: data.title ?? null, thumbnail_url: data.thumbnail_url ?? null };
  }
  return null;
}

function extractMeta(html: string, property: string): string | null {
  const patterns = [
    new RegExp(`<meta[^>]+property=["']${property}["'][^>]+content=["']([^"']*)["']`, "i"),
    new RegExp(`<meta[^>]+content=["']([^"']*)["'][^>]+property=["']${property}["']`, "i"),
    new RegExp(`<meta[^>]+name=["']${property}["'][^>]+content=["']([^"']*)["']`, "i"),
  ];
  for (const re of patterns) {
    const match = html.match(re);
    if (match) return match[1];
  }
  return null;
}

async function fetchOpenGraph(url: string): Promise<Partial<Metadata> | null> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; TwinsBot/1.0; +https://example.com)" },
      redirect: "follow",
    });
    if (!res.ok) return null;
    const html = await res.text();
    return {
      title: extractMeta(html, "og:title") ?? extractMeta(html, "twitter:title"),
      description: extractMeta(html, "og:description") ?? extractMeta(html, "description"),
      thumbnail_url: extractMeta(html, "og:image") ?? extractMeta(html, "twitter:image"),
    };
  } catch {
    return null;
  }
}

async function polishWithGroq(meta: Metadata): Promise<Metadata> {
  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey || !meta.title) return meta;

  try {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "llama-3.1-8b-instant",
        messages: [
          {
            role: "system",
            content:
              "You clean up social-media video/link titles for a private bookmarking app. " +
              'Given a raw title and description, respond ONLY with JSON: {"title": string, "summary": string, "tags": string[]}. ' +
              "title: a short punchy version of the original title (keep it under 60 chars, keep emoji if present). " +
              "summary: one short sentence describing the content. " +
              "tags: 2-4 lowercase single-word topic tags, no hashtags.",
          },
          {
            role: "user",
            content: `Title: ${meta.title}\nDescription: ${meta.description ?? ""}`,
          },
        ],
        temperature: 0.4,
        response_format: { type: "json_object" },
      }),
    });
    if (!res.ok) return meta;
    const data = await res.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) return meta;
    const parsed = JSON.parse(content);
    const tags = Array.isArray(parsed.tags)
      ? parsed.tags
          .filter((t: unknown): t is string => typeof t === "string")
          .map((t: string) => t.trim().toLowerCase().replace(/^#/, ""))
          .filter((t: string) => t.length > 0 && t.length <= 24)
          .slice(0, 4)
      : [];
    return {
      ...meta,
      title: typeof parsed.title === "string" && parsed.title.trim() ? parsed.title.trim() : meta.title,
      description: typeof parsed.summary === "string" && parsed.summary.trim() ? parsed.summary.trim() : meta.description,
      tags,
    };
  } catch {
    return meta;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { url } = await req.json();
    if (typeof url !== "string" || url.trim().length === 0) {
      return new Response(JSON.stringify({ error: "Missing url" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let parsed: URL;
    try {
      parsed = new URL(url);
    } catch {
      return new Response(JSON.stringify({ error: "Invalid url" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return new Response(JSON.stringify({ error: "Unsupported url scheme" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const platform = detectPlatform(parsed);

    let partial = await fetchOEmbed(platform, url);
    if (!partial || !partial.title) {
      partial = { ...partial, ...(await fetchOpenGraph(url)) };
    }

    let metadata: Metadata = {
      title: partial?.title ?? null,
      description: partial?.description ?? null,
      thumbnail_url: partial?.thumbnail_url ?? null,
      platform,
      tags: [],
    };

    metadata = await polishWithGroq(metadata);

    return new Response(JSON.stringify(metadata), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    // Enrichment failing must never block saving the raw URL client-side.
    return new Response(JSON.stringify({ title: null, description: null, thumbnail_url: null, platform: "web", tags: [] }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
