# ¡Twins!

A private shared digital space for exactly two people. Save reels, TikToks,
YouTube videos, links, notes, images, and files from anywhere on your phone
straight into one shared space with your person — organize it into folders,
react and comment on anything (including at a specific video timestamp), and
keep a lightweight running chat together.

Think: Pinterest + Discord threads + a private scrapbook + a shared drive,
built for exactly two people. Not a social network — no followers, no public
feed, no discovery.

## Architecture

- **App**: Flutter (Dart), Riverpod for state, `go_router` for navigation.
- **Backend**: Supabase (Postgres + Auth + Storage + Realtime).
- **Data layer abstraction** (`lib/data/repositories/twins_repository.dart`):
  every screen talks to a single `TwinsRepository` interface. Two
  implementations exist:
  - `MockTwinsRepository` (`lib/data/mock/`) — in-memory, seeded with
    realistic demo data. Used automatically whenever Supabase credentials
    are absent, so the whole app is explorable with zero setup.
  - `SupabaseTwinsRepository` (`lib/data/supabase/`) — the real backend.
  Which one is active is decided once, in `lib/state/repository_provider.dart`,
  based on whether `.env` has Supabase credentials filled in.
- **Edge Function** (`supabase/functions/resolve-link`): best-effort link
  metadata (title/description/thumbnail) via oEmbed/OpenGraph, with optional
  Groq polish. Runs server-side only.
- **Migrations** (`supabase/migrations/`): full schema + Row Level Security
  policies + the secure `join_space_with_code` RPC.
- **Search** (`supabase/migrations/0009_search.sql`): a weighted `tsvector`
  over title/description/content/URL with a GIN index, a `pg_trgm` index for
  partial and misspelled words, and the `search_items()` RPC that ranks
  results and also matches tag and folder names. Per-user recent searches live
  in `search_history` (your own history only — your twin can't see it).

## Requirements

- Flutter 3.24+ (Dart 3.5+)
- Xcode (iOS) / Android Studio or just the Android SDK (Android)
- A Supabase project (optional — see "Running without Supabase" below)

## Install

```bash
flutter pub get
```

## Running

```bash
flutter run
```

The app works immediately with **no setup** — it starts in mock mode with a
seeded demo space ("Mohaned & Rania") containing sample folders (Funny Reels,
Date Ideas, Travel Plans, Random Stuff, Study Stuff) and items matching the
designs in `design/`.

### Running against real Supabase

1. Fill in `.env` (copy values from `.env.example` if you reset it) — see
   [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) for exactly how to get
   each value.
2. `flutter run` again. The app automatically switches to
   `SupabaseTwinsRepository` the moment `EXPO_PUBLIC_SUPABASE_URL` and
   `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` are non-empty.

### Incoming OS share ("Share to ¡Twins!")

Sharing content **into** ¡Twins! from TikTok/Instagram/YouTube/a browser only
works from a real install on a device/emulator — `flutter run` in debug mode
is enough on Android. It does **not** work in an iOS Simulator without the
share extension target described in the iOS notes below, and it will never
work in a pure web/desktop preview.

To test on Android:

```bash
flutter run
# then, from any other app: Share -> ¡Twins!
```

## Supabase setup

Full step-by-step instructions (create project, run migrations, configure
storage, deploy the Edge Function, set the optional Groq secret) live in
[docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md).

Short version:

```bash
supabase link --project-ref <your-project-ref>
supabase db push                          # applies everything in supabase/migrations
supabase functions deploy resolve-link    # AI/link enrichment (optional)
supabase secrets set --env-file supabase/.env   # sets GROQ_API_KEY (optional)

# optional: load a realistic demo dataset (two paired users + content)
cd supabase && npm install && npm run seed
```

## Environment variables

Two files, split by trust level (see `.env.example` and
[docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md)):

**`.env`** (repo root, bundled into the app, committed):

| Variable | Where it's used | Required? |
|---|---|---|
| `EXPO_PUBLIC_SUPABASE_URL` | Flutter client | No (mock mode without it) |
| `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Flutter client | No (mock mode without it) |
| `EXPO_PUBLIC_APP_SCHEME` | Flutter client (deep link scheme) | No, defaults to `twins` |
| `GROQ_API_KEY` | Flutter client (in-app AI link polish) | No (enables AI; **ships in the bundle** — see below) |

**`supabase/.env`** (git-ignored, never bundled — server-side secrets):

| Variable | Where it's used | Required? |
|---|---|---|
| `SUPABASE_SECRET_KEY` | `seed.ts`, off-device only | Only to run the seed |
| `SUPABASE_DB_PASSWORD` / `*_CONNECTION_STRING` | `psql` / `supabase db push` | Only for direct DB access |

**Never** put `SUPABASE_SECRET_KEY`, the service-role JWT, or the DB password in
the client `.env` — the secret key bypasses Row Level Security and the app
bundle is world-readable. `GROQ_API_KEY` is deliberately client-side so the AI
runs with no server; accept that it can be extracted from the app, or move
enrichment to the `resolve-link` Edge Function to keep the key server-only
(see [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) §7).

## How pairing works

A "Twins space" has a hard cap of exactly two members, enforced **server-side**
(a Postgres trigger on `space_members`, plus the `join_space_with_code` RPC
re-checking the count) — never trust a client-side check for this. After
signing up, a user either:

1. **Creates a space** — generates a 6-character invite code (e.g. `7HG2K9`)
   that expires in 7 days.
2. **Joins with a code** — calls the `join_space_with_code(invite_code)` RPC,
   which validates the code, checks the 2-member cap, and inserts the
   membership row atomically.

Once both people are in, every folder/item/comment/message/reaction is
visible to both and only both, enforced by Row Level Security
(`supabase/migrations/0004_row_level_security.sql`).

## How incoming share works

`lib/sharing/share_intent_service.dart` wraps the `receive_sharing_intent`
plugin. On Android, `android/app/src/main/AndroidManifest.xml` registers an
`ACTION_SEND` intent filter for `text/*`, so any share sheet showing "¡Twins!"
as a target hands off a URL/text string, which gets routed straight into
`/add` pre-filled. If the user isn't logged in yet, the payload is cached via
`SharedPreferences` and replayed the moment they land on the home shell.

## How link metadata works

When a URL is pasted into "Add item", the client immediately guesses the
type (YouTube/TikTok/Instagram/generic link) from the URL shape
(`lib/utils/link_detector.dart`) so the UI can show the right icon right
away, then calls the `resolve-link` Edge Function in the background to fetch
a real title/description/thumbnail. If that call fails or Supabase isn't
configured, the user can still save the raw URL — enrichment is always
best-effort and never blocks saving.

## How Groq enrichment works

Entirely optional. If `GROQ_API_KEY` is set as an Edge Function secret,
`resolve-link` asks Groq (`llama-3.1-8b-instant`) to turn the raw
oEmbed/OpenGraph title+description into a shorter, punchier title, a
one-sentence summary, and 2-4 suggested tags. If the key is missing or the
call fails for any reason, the function silently falls back to the raw
metadata — the app never depends on AI being available.

## Android notes

- Fully supported, including incoming share (`ACTION_SEND`).
- Package: `com.mohaned.twins`.

## iOS notes

- Auth, folders, items, chat, comments, reactions, uploads, and link
  metadata all work identically to Android.
- **Incoming share requires one manual Xcode step** this repo can't
  automate headlessly: add a "Share Extension" target in Xcode
  (File → New → Target → Share Extension), add both the main app target and
  the new extension to the same App Group, and follow the
  `receive_sharing_intent` package's iOS setup guide for wiring the
  extension's `ShareViewController` and `Info.plist` `NSExtensionActivationRule`.
  Until that's done, iOS builds run fully otherwise — you just can't
  "Share → ¡Twins!" from other iOS apps yet.

## Known limitations

- TikTok/Instagram Reels are **not** re-hosted or downloaded — per platform
  ToS, the item detail screen shows the thumbnail/title/metadata and an
  "Open original" button rather than embedding playback. This is a
  deliberate scope boundary, not a missing feature.
- The iOS share extension needs the one-time manual Xcode step above.
- Push notifications are not wired up (no APNs/FCM credentials configured);
  the app relies on Supabase Realtime for in-app live updates instead. The
  architecture (`TwinsRepository` streams) is ready for push to be added
  later without restructuring.
- Profile avatar upload isn't wired to Supabase Storage yet — the schema and
  storage bucket/policies exist (`avatars` bucket in
  `supabase/migrations/0006_storage.sql`), display name/username/bio editing
  works today.
- Import (the other half of Import/Export) is not implemented — Export to
  JSON works from Settings → Our Space.
