// suggest-tags: AI tag suggestion for the Add Item flow, run server-side so
// GROQ_API_KEY never ships in the client bundle.
//
// Given an item's text and the space's existing tag catalog, picks 1-4 tags
// that best describe the item, strongly preferring to reuse catalog tags.
// Returns an empty list on any failure (missing key, network error, bad
// response) - the client must always let the user save without tags.
//
// Deploy: supabase functions deploy suggest-tags
// Secrets: supabase secrets set GROQ_API_KEY=...   (required for this one)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("GROQ_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ tags: [] }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { title, description, content, url, platform, catalog, max } = await req.json();
    const cap = typeof max === "number" && max > 0 ? max : 4;

    const text = [
      title && String(title).trim() ? `Title: ${title}` : null,
      description && String(description).trim() ? `Description: ${description}` : null,
      content && String(content).trim() ? `Content: ${String(content).slice(0, 500)}` : null,
      platform && platform !== "device" ? `Platform: ${platform}` : null,
      url && String(url).trim() ? `URL: ${url}` : null,
    ]
      .filter(Boolean)
      .join("\n");

    if (!text.trim()) {
      return new Response(JSON.stringify({ tags: [] }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const catalogList: string[] = Array.isArray(catalog) ? catalog.filter((t) => typeof t === "string") : [];

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
              "You tag saved items (videos, links, notes, images) for a private bookmarking app shared by two friends. " +
              `You are given an item and the existing tag catalog. Choose 1 to ${cap} tags that best describe the item. ` +
              "STRONGLY prefer reusing tags from the catalog; only invent a NEW tag when nothing in the catalog fits. " +
              'Respond ONLY with JSON: {"tags": string[]}. Each tag: lowercase, one or two words, no "#", no emoji.',
          },
          {
            role: "user",
            content: `Catalog: ${catalogList.length ? catalogList.join(", ") : "(empty)"}\n\nItem:\n${text}`,
          },
        ],
        temperature: 0.3,
        response_format: { type: "json_object" },
      }),
    });

    if (!res.ok) {
      return new Response(JSON.stringify({ tags: [] }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const data = await res.json();
    const raw = data.choices?.[0]?.message?.content;
    const parsed = raw ? JSON.parse(raw) : null;
    const tags = Array.isArray(parsed?.tags)
      ? [
          ...new Set(
            parsed.tags
              .filter((t: unknown): t is string => typeof t === "string")
              .map((t: string) => t.trim().toLowerCase().replace(/^#/, ""))
              .filter((t: string) => t.length > 0 && t.length <= 24),
          ),
        ].slice(0, cap)
      : [];

    return new Response(JSON.stringify({ tags }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch {
    return new Response(JSON.stringify({ tags: [] }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
