// resolve-link: best-effort URL metadata enrichment for the Add Item flow.
//
// - Detects platform (YouTube / TikTok / Instagram / generic web).
// - Each platform has its own extractor, because each one hides its data
//   differently: YouTube has oEmbed plus the watch page, TikTok's oEmbed is
//   rate-limited so its page's rehydration JSON is the fallback, Instagram
//   only serves OpenGraph to link-preview crawlers, and plain articles often
//   have no og:image/description at all, so we fall back to the page body.
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

const BROWSER_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";
// Instagram (and TikTok's share-card fallback) only render OpenGraph tags for
// known link-preview crawlers; a browser UA gets an empty JS shell.
const CRAWLER_UA = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)";

type Platform = "youtube" | "tiktok" | "instagram" | "web";

type Metadata = {
  title: string | null;
  description: string | null;
  thumbnail_url: string | null;
  platform: Platform;
  author: string | null;
  site_name: string | null;
  favicon_url: string | null;
  duration_ms: number | null;
  // AI-suggested topic tags (Groq). Empty unless GROQ_API_KEY is set and the
  // polish step succeeds.
  tags: string[];
};

function emptyMetadata(platform: Platform): Metadata {
  return {
    title: null,
    description: null,
    thumbnail_url: null,
    platform,
    author: null,
    site_name: null,
    favicon_url: null,
    duration_ms: null,
    tags: [],
  };
}

function detectPlatform(url: URL): Platform {
  const host = url.hostname.replace(/^www\./, "");
  if (host === "youtu.be" || host.endsWith("youtube.com")) return "youtube";
  if (host.endsWith("tiktok.com")) return "tiktok";
  if (host.endsWith("instagram.com")) return "instagram";
  return "web";
}

// ---------------------------------------------------------------------------
// HTML helpers
// ---------------------------------------------------------------------------

const NAMED_ENTITIES: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
  ndash: "–", mdash: "—", hellip: "…", lsquo: "‘", rsquo: "’", ldquo: "“", rdquo: "”",
  copy: "©", reg: "®", trade: "™", middot: "·", bull: "•",
};

// Some CMSes double-encode (`&amp;amp;`), so decode until it stops changing.
function decodeEntities(text: string): string {
  let previous = "";
  let current = text;
  for (let i = 0; i < 3 && current !== previous; i++) {
    previous = current;
    current = current.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (match, code: string) => {
      if (code[0] === "#") {
        const n = code[1].toLowerCase() === "x" ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
        return Number.isFinite(n) ? String.fromCodePoint(n) : match;
      }
      return NAMED_ENTITIES[code.toLowerCase()] ?? match;
    });
  }
  return current;
}

function clean(text: string | null | undefined): string | null {
  if (!text) return null;
  const collapsed = decodeEntities(text).replace(/\s+/g, " ").trim();
  return collapsed.length > 0 ? collapsed : null;
}

function stripTags(html: string): string {
  return html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, " ").replace(/<[^>]+>/g, " ");
}

// Attribute order and quoting vary wildly between sites, so parse each tag's
// attributes properly instead of matching one fixed `property=... content=...`
// shape (which also broke on apostrophes inside double-quoted content).
function parseAttributes(tag: string): Record<string, string> {
  const attrs: Record<string, string> = {};
  const re = /([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(tag)) !== null) {
    attrs[m[1].toLowerCase()] = m[2] ?? m[3] ?? m[4] ?? "";
  }
  return attrs;
}

type Page = { html: string; url: string; meta: Map<string, string> };

function parseMetaTags(html: string): Map<string, string> {
  const meta = new Map<string, string>();
  for (const tag of html.match(/<meta\b[^>]*>/gi) ?? []) {
    const attrs = parseAttributes(tag);
    const key = (attrs.property ?? attrs.name ?? attrs.itemprop)?.toLowerCase();
    if (key && attrs.content !== undefined && !meta.has(key)) meta.set(key, attrs.content);
  }
  return meta;
}

function metaOf(page: Page, ...keys: string[]): string | null {
  for (const key of keys) {
    const value = clean(page.meta.get(key));
    if (value) return value;
  }
  return null;
}

function absolutize(src: string | null, base: string): string | null {
  if (!src) return null;
  try {
    const resolved = new URL(decodeEntities(src.trim()), base);
    return resolved.protocol === "http:" || resolved.protocol === "https:" ? resolved.toString() : null;
  } catch {
    return null;
  }
}

async function fetchPage(url: string, userAgent: string): Promise<Page | null> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": userAgent, "Accept-Language": "en-US,en;q=0.9", Accept: "text/html,*/*;q=0.8" },
      redirect: "follow",
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    const contentType = res.headers.get("content-type") ?? "";
    if (contentType && !contentType.includes("html")) return null;
    const html = await res.text();
    return { html, url: res.url || url, meta: parseMetaTags(html) };
  } catch {
    return null;
  }
}

async function fetchJson(url: string): Promise<any | null> {
  try {
    const res = await fetch(url, { headers: { "User-Agent": BROWSER_UA }, signal: AbortSignal.timeout(6000) });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

/** The main content region, so hero images/paragraphs win over nav chrome. */
function mainRegion(html: string): string {
  for (const tag of ["<article", "<main", 'role="main"']) {
    const at = html.indexOf(tag);
    if (at >= 0) return html.slice(at);
  }
  const body = html.search(/<body\b/i);
  return body >= 0 ? html.slice(body) : html;
}

function firstContentImage(page: Page): string | null {
  for (const tag of mainRegion(page.html).match(/<img\b[^>]*>/gi) ?? []) {
    const attrs = parseAttributes(tag);
    const src = attrs.src ?? attrs["data-src"] ?? attrs["data-lazy-src"];
    if (!src || src.startsWith("data:")) continue;
    const hint = `${src} ${attrs.alt ?? ""} ${attrs.class ?? ""} ${attrs.style ?? ""}`.toLowerCase();
    if (/display:\s*none|logo|icon|avatar|sprite|pixel|spacer|\.svg/.test(hint)) continue;
    const width = parseInt(attrs.width ?? "", 10);
    if (Number.isFinite(width) && width < 120) continue;
    const resolved = absolutize(src, page.url);
    if (resolved) return resolved;
  }
  return null;
}

function firstParagraph(page: Page): string | null {
  for (const match of mainRegion(page.html).matchAll(/<p\b[^>]*>([\s\S]*?)<\/p>/gi)) {
    const text = clean(stripTags(match[1]));
    if (!text || text.length < 80 || text.split(" ").length < 12) continue;
    if (!/[.!?](\s|$)/.test(text)) continue;
    return text;
  }
  return null;
}

function documentTitle(page: Page): string | null {
  const m = page.html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  return clean(m?.[1]);
}

function favicon(page: Page): string | null {
  let best: { href: string; score: number } | null = null;
  for (const tag of page.html.match(/<link\b[^>]*>/gi) ?? []) {
    const attrs = parseAttributes(tag);
    const rel = (attrs.rel ?? "").toLowerCase();
    if (!rel.includes("icon") || !attrs.href) continue;
    // Bigger icons look better on cards: apple-touch-icon > sized icon > rest.
    const size = parseInt((attrs.sizes ?? "").split("x")[0], 10);
    const score = rel.includes("apple-touch-icon") ? 1000 : Number.isFinite(size) ? size : 16;
    if (!best || score > best.score) best = { href: attrs.href, score };
  }
  return absolutize(best?.href ?? "/favicon.ico", page.url);
}

/** "Article title - Site Name" → ["Article title", "Site Name"]. */
function splitTitleSuffix(title: string, siteName: string | null): [string, string | null] {
  const parts = title.split(/\s+[-–—|·]\s+/);
  if (parts.length < 2) return [title, null];
  const suffix = parts[parts.length - 1];
  const head = parts.slice(0, -1).join(" - ");
  if (siteName && suffix.toLowerCase() === siteName.toLowerCase()) return [head, suffix];
  if (!siteName && suffix.length <= 40 && head.length >= 12) return [head, suffix];
  return [title, null];
}

function truncate(text: string | null, max: number): string | null {
  if (!text || text.length <= max) return text;
  const cut = text.slice(0, max);
  const lastSpace = cut.lastIndexOf(" ");
  return `${cut.slice(0, lastSpace > max * 0.6 ? lastSpace : max).trimEnd()}…`;
}

/** A caption's first line, minus trailing hashtags, as a card title. */
function captionTitle(caption: string | null): string | null {
  if (!caption) return null;
  const firstLine = caption.split(/\n/)[0];
  const withoutTags = firstLine.replace(/(\s*#[\p{L}\p{N}_]+)+\s*$/u, "").trim();
  return truncate(clean(withoutTags || firstLine), 90);
}

// ---------------------------------------------------------------------------
// Platform extractors
// ---------------------------------------------------------------------------

function youtubeId(url: URL): string | null {
  if (url.hostname === "youtu.be") return url.pathname.slice(1).split("/")[0] || null;
  const v = url.searchParams.get("v");
  if (v) return v;
  const m = url.pathname.match(/\/(?:shorts|embed|live)\/([\w-]{6,})/);
  return m?.[1] ?? null;
}

async function resolveYouTube(url: URL): Promise<Metadata> {
  const meta = emptyMetadata("youtube");
  meta.site_name = "YouTube";
  meta.favicon_url = "https://www.youtube.com/favicon.ico";

  const [oembed, page] = await Promise.all([
    fetchJson(`https://www.youtube.com/oembed?url=${encodeURIComponent(url.toString())}&format=json`),
    fetchPage(url.toString(), BROWSER_UA),
  ]);

  meta.title = clean(oembed?.title) ?? (page ? metaOf(page, "og:title", "title") : null);
  meta.author = clean(oembed?.author_name);

  if (page) {
    const shortDescription = page.html.match(/"shortDescription":"((?:[^"\\]|\\.)*)"/)?.[1];
    let fullDescription: string | null = null;
    if (shortDescription) {
      try {
        fullDescription = JSON.parse(`"${shortDescription}"`);
      } catch {
        fullDescription = null;
      }
    }
    meta.description = truncate(clean(fullDescription) ?? metaOf(page, "og:description", "description"), 400);
    const seconds = parseInt(page.html.match(/"lengthSeconds":"(\d+)"/)?.[1] ?? "", 10);
    if (Number.isFinite(seconds) && seconds > 0) meta.duration_ms = seconds * 1000;
    meta.author ??= clean(page.html.match(/"ownerChannelName":"((?:[^"\\]|\\.)*)"/)?.[1]);
  }

  // og:image is the maxres frame when one exists; oEmbed only ever offers the
  // letterboxed 480x360 "hqdefault".
  const id = youtubeId(url);
  meta.thumbnail_url = (page ? metaOf(page, "og:image") : null) ??
    (id ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : clean(oembed?.thumbnail_url));
  return meta;
}

async function resolveTikTok(url: URL): Promise<Metadata> {
  const meta = emptyMetadata("tiktok");
  meta.site_name = "TikTok";
  meta.favicon_url = "https://www.tiktok.com/favicon.ico";

  const oembed = await fetchJson(`https://www.tiktok.com/oembed?url=${encodeURIComponent(url.toString())}`);
  if (oembed?.title !== undefined) {
    meta.description = clean(oembed.title);
    meta.title = captionTitle(oembed.title);
    meta.author = oembed.author_unique_id ? `@${oembed.author_unique_id}` : clean(oembed.author_name);
    meta.thumbnail_url = clean(oembed.thumbnail_url);
  }

  // oEmbed regularly answers "overload-protect triggered" instead of JSON, so
  // the web page's rehydration blob is the reliable source. It also has the
  // duration, which oEmbed never returns.
  const page = await fetchPage(url.toString(), BROWSER_UA);
  const blob = page?.html.match(/<script[^>]*id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>([\s\S]*?)<\/script>/)?.[1];
  if (blob) {
    try {
      const item = JSON.parse(blob)?.__DEFAULT_SCOPE__?.["webapp.video-detail"]?.itemInfo?.itemStruct;
      if (item) {
        meta.description ??= clean(item.desc);
        meta.title ??= captionTitle(item.desc);
        meta.author ??= item.author?.uniqueId ? `@${item.author.uniqueId}` : clean(item.author?.nickname);
        meta.thumbnail_url ??= clean(item.video?.originCover) ?? clean(item.video?.cover);
        const seconds = Number(item.video?.duration);
        if (Number.isFinite(seconds) && seconds > 0) meta.duration_ms = seconds * 1000;
      }
    } catch {
      // Malformed blob: fall through to the crawler share card below.
    }
  }

  if (!meta.thumbnail_url || !meta.title) {
    const card = await fetchPage(url.toString(), CRAWLER_UA);
    if (card) {
      meta.thumbnail_url ??= absolutize(metaOf(card, "og:image", "twitter:image"), card.url);
      meta.title ??= metaOf(card, "og:title");
    }
  }
  meta.title ??= meta.author ? `TikTok by ${meta.author}` : null;
  return meta;
}

async function resolveInstagram(url: URL): Promise<Metadata> {
  const meta = emptyMetadata("instagram");
  meta.site_name = "Instagram";
  meta.favicon_url = "https://www.instagram.com/favicon.ico";

  const page = await fetchPage(url.toString(), CRAWLER_UA);
  if (!page) return meta;

  // og:title:       `Display Name on Instagram: "the caption"`
  // og:description: `username on October 13, 2026: "the caption". `
  // og:url:         https://www.instagram.com/username/reel/<code>/
  const ogTitle = metaOf(page, "og:title");
  const ogDescription = metaOf(page, "og:description");
  const caption =
    ogTitle?.match(/on Instagram:\s*"([\s\S]*)"\s*$/)?.[1] ??
    ogDescription?.match(/:\s*"([\s\S]*)"\.?\s*$/)?.[1] ??
    null;
  const username =
    metaOf(page, "og:url")?.match(/instagram\.com\/([\w.]+)\/(?:reel|p|tv)\//)?.[1] ??
    ogDescription?.match(/^([\w.]+) on /)?.[1] ??
    null;

  meta.author = username ? `@${username}` : clean(ogTitle?.split(" on Instagram")[0]);
  meta.description = clean(caption);
  meta.title = captionTitle(caption) ?? (meta.author ? `Reel by ${meta.author}` : ogTitle);
  meta.thumbnail_url = absolutize(metaOf(page, "og:image", "twitter:image"), page.url);
  const seconds = parseFloat(page.html.match(/"video_duration":([\d.]+)/)?.[1] ?? "");
  if (Number.isFinite(seconds) && seconds > 0) meta.duration_ms = Math.round(seconds * 1000);
  return meta;
}

async function resolveWeb(url: URL): Promise<Metadata> {
  const meta = emptyMetadata("web");
  const page = await fetchPage(url.toString(), BROWSER_UA) ?? await fetchPage(url.toString(), CRAWLER_UA);
  meta.site_name = url.hostname.replace(/^www\./, "");
  if (!page) return meta;

  const declaredSite = metaOf(page, "og:site_name", "application-name", "apple-mobile-web-app-title");
  const rawTitle = metaOf(page, "og:title", "twitter:title") ?? documentTitle(page);
  if (rawTitle) {
    const [title, suffix] = splitTitleSuffix(rawTitle, declaredSite);
    meta.title = title;
    meta.site_name = declaredSite ?? suffix ?? meta.site_name;
  } else if (declaredSite) {
    meta.site_name = declaredSite;
  }

  meta.description = truncate(
    metaOf(page, "og:description", "twitter:description", "description") ?? firstParagraph(page),
    400,
  );
  meta.author = metaOf(page, "author", "article:author", "twitter:creator");
  if (meta.author?.startsWith("http")) meta.author = null;

  const linkImage = page.html.match(/<link\b[^>]*rel=["']image_src["'][^>]*>/i)?.[0];
  meta.thumbnail_url =
    absolutize(metaOf(page, "og:image", "og:image:url", "og:image:secure_url", "twitter:image", "twitter:image:src"), page.url) ??
    absolutize(linkImage ? parseAttributes(linkImage).href ?? null : null, page.url) ??
    firstContentImage(page);
  meta.favicon_url = favicon(page);
  return meta;
}

// ---------------------------------------------------------------------------
// Optional AI polish
// ---------------------------------------------------------------------------

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
        model: "openai/gpt-oss-20b",
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
      signal: AbortSignal.timeout(8000),
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
    // The creator's own words win: only shorten titles too long for a card,
    // and only summarise when the source had no description at all.
    const aiTitle = typeof parsed.title === "string" ? parsed.title.trim() : "";
    const aiSummary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
    return {
      ...meta,
      title: aiTitle && meta.title.length > 70 ? aiTitle : meta.title,
      description: meta.description ?? (aiSummary || null),
      tags,
    };
  } catch {
    return meta;
  }
}

async function resolve(url: URL): Promise<Metadata> {
  switch (detectPlatform(url)) {
    case "youtube":
      return resolveYouTube(url);
    case "tiktok":
      return resolveTikTok(url);
    case "instagram":
      return resolveInstagram(url);
    default:
      return resolveWeb(url);
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let platform: Platform = "web";
  try {
    const { url } = await req.json();
    if (typeof url !== "string" || url.trim().length === 0) return json({ error: "Missing url" }, 400);

    let parsed: URL;
    try {
      parsed = new URL(url.trim());
    } catch {
      return json({ error: "Invalid url" }, 400);
    }
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return json({ error: "Unsupported url scheme" }, 400);
    }

    platform = detectPlatform(parsed);
    return json(await polishWithGroq(await resolve(parsed)));
  } catch {
    // Enrichment failing must never block saving the raw URL client-side.
    return json(emptyMetadata(platform));
  }
});
