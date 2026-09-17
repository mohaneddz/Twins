// name-chat: names a chat thread from its first few messages, run
// server-side so GROQ_API_KEY never ships in the client bundle.
//
// Returns null on any failure - the client must treat naming as best-effort
// and leave the chat unnamed (or let the user name it manually).
//
// Deploy: supabase functions deploy name-chat
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
      return new Response(JSON.stringify({ name: null }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { messages } = await req.json();
    const bodies: string[] = Array.isArray(messages) ? messages.filter((m) => typeof m === "string") : [];
    const text = bodies.slice(0, 10).join("\n");
    if (!text.trim()) {
      return new Response(JSON.stringify({ name: null }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

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
              "You name short chat threads between two close friends sharing a private chat app. Given the " +
              "first few messages, respond with a punchy 2 to 4 word title that captures what they are " +
              "talking about. No quotes, no trailing punctuation, no emoji unless it truly fits. " +
              'Respond ONLY with JSON: {"name": string}.',
          },
          { role: "user", content: text },
        ],
        temperature: 0.4,
        response_format: { type: "json_object" },
      }),
    });

    if (!res.ok) {
      return new Response(JSON.stringify({ name: null }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const data = await res.json();
    const raw = data.choices?.[0]?.message?.content;
    const parsed = raw ? JSON.parse(raw) : null;
    const name = typeof parsed?.name === "string" ? parsed.name.trim() : null;

    return new Response(JSON.stringify({ name: name && name.length > 0 && name.length <= 60 ? name : null }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch {
    return new Response(JSON.stringify({ name: null }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
