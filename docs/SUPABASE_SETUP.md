# Supabase setup for ¡Twins!

Follow these steps in order. Everything after step 5 requires the
[Supabase CLI](https://supabase.com/docs/guides/cli) installed and logged in
(`supabase login`).

## 1. Create a project

Go to [supabase.com/dashboard](https://supabase.com/dashboard) → **New
project**. Pick any name/region/password (the DB password isn't used by the
app directly).

## 2. Copy the project URL

**Project Settings → API → Project URL**, e.g. `https://xxxxxxxx.supabase.co`.

## 3. Copy the publishable ("anon") key

Same page, **Project Settings → API → Project API keys → anon / public**.
This key is safe to ship in the client — Row Level Security is what actually
protects the data, not secrecy of this key.

## 4. Populate the env files

There are **two** env files, split by trust level:

- **`.env`** (repo root) — bundled into the app and committed. **Public values
  only**: the project URL and publishable/anon key. Never put a secret here;
  everything in it ships to every device.
- **`supabase/.env`** — git-ignored, never bundled. Server-side secrets used by
  the seed script and `supabase secrets set`.

Client (`.env` in repo root):

```
EXPO_PUBLIC_SUPABASE_URL=https://xxxxxxxx.supabase.co
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...   # or anon eyJhbGciOi...
```

Server (`supabase/.env`, git-ignored):

```
SUPABASE_URL=https://xxxxxxxx.supabase.co
SUPABASE_SECRET_KEY=sb_secret_...            # Project Settings → API → secret keys
SUPABASE_DIRECT_CONNECTION_STRING=postgresql://postgres:YOUR-DB-PASSWORD@db.xxxxxxxx.supabase.co:5432/postgres
GROQ_API_KEY=gsk_...                          # optional, enables AI polish
```

> The `sb_secret_*` key bypasses Row Level Security — treat it like a root
> password. It is only ever used off-device (seed script, function secrets).

## 5. Run migrations

From the repo root, link the CLI to your project and push every file in
`supabase/migrations/` in order:

```bash
supabase link --project-ref xxxxxxxx
supabase db push
```

This creates all tables, indexes, the two-member cap trigger, every Row
Level Security policy, and the `join_space_with_code` RPC.

If you'd rather apply them by hand (e.g. via the SQL editor in the
dashboard), run the files in `supabase/migrations/` **in filename order**
(`0001_...` through `0006_...`) — later files depend on tables/functions
created earlier.

## 6. Configure storage

Storage buckets and their policies are created by migration
`0006_storage.sql` (part of `supabase db push` above) — no manual dashboard
steps needed. It creates:

- `avatars` (public read, owner-only write) for profile pictures, keyed by
  `{userId}/...`.
- `spaces` (members-only read/write) for uploaded item media. Inside the
  bucket the object key starts with the space id: `{spaceId}/items/...`. The
  RLS policy checks the first path segment is a space you belong to, so that
  leading segment **must** be the space id (not a literal folder name).

## 7. Link enrichment + AI (baked into the app)

By default the app enriches pasted links **on-device** — no Edge Function
needed. `lib/data/supabase/link_metadata_service.dart` detects the platform,
pulls oEmbed/OpenGraph metadata, and (if `GROQ_API_KEY` is set in the bundled
`.env`) calls Groq directly to polish the title, write a one-sentence summary,
and suggest 2–4 tags. Get a key at [console.groq.com](https://console.groq.com).

> **Security tradeoff:** a key in the bundled `.env` ships inside the app and
> can be extracted. That's the accepted cost of running AI with no server. To
> lock it down instead, use the optional Edge Function below and remove
> `GROQ_API_KEY` from `.env`.

### Optional: server-side enrichment (locks the Groq key away)

The same logic exists as an Edge Function (`supabase/functions/resolve-link`)
so the Groq key never ships in the client:

```bash
supabase functions deploy resolve-link
supabase secrets set --env-file supabase/.env   # sets GROQ_API_KEY server-side
```

If you go this route, point `resolveLinkMetadata` at the function instead of
the on-device path. Either way the app always lets you save the raw link if
enrichment fails.

## 8b. Seed a demo space (optional but recommended)

Populate the project with a realistic, known dataset (two paired users,
folders, items, tags, comments, chat, reactions) so you can log in and see the
real backend immediately:

```bash
cd supabase
npm install
npm run seed
```

The script uses `SUPABASE_SECRET_KEY` from `supabase/.env` to write past RLS.
It is idempotent — re-running wipes the two demo users' space and rebuilds it.
Afterwards log in with:

- `mohaned@twins.app` / `twinsdemo123` (owner)
- `rania@twins.app` / `twinsdemo123` (twin)

> Requires migrations (step 5) to be applied first — the seed fails loudly with
> a "tables don't exist" hint otherwise.

## 9. Test with two accounts

1. Sign up as account A → **Create our space** → note the invite code.
2. Sign up as account B (a different email, or a second device/simulator) →
   **Join with a code** → enter A's code.
3. Confirm both accounts land in the same space, folders, and chat.
4. Try a third account joining the same code — it should be rejected
   ("This Twins space already has two members.") — this proves the
   server-side cap (not just client UI) is working.

## 10. Test realtime

With both accounts logged in on two devices/simulators simultaneously:

1. Open the Chat tab on both.
2. Send a message from account A.
3. Confirm it appears on account B's screen without a manual refresh.
4. Repeat by adding an item from account A and watching it appear in account
   B's folder view / dashboard "Recently added".
