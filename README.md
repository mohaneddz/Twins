<h1>
  <img src="assets/icon_no_bg.png" alt="¡Twins! icon" width="50" />
  ¡Twins!
</h1>

A private shared space for exactly two people. Share reels, TikToks, YouTube
videos, links, notes and files into it from any app, sort them into folders,
comment and react, chat, and plan things together on a shared calendar. No
followers, no feed: just the two of you, on your own Supabase project.

---

## Tech Used

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-00B3A4?style=for-the-badge)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Deno](https://img.shields.io/badge/Deno-000000?style=for-the-badge&logo=deno&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase_Messaging-DD2C00?style=for-the-badge&logo=firebase&logoColor=white)
![Groq](https://img.shields.io/badge/Groq-F55036?style=for-the-badge)
![Android](https://img.shields.io/badge/Android-34A853?style=for-the-badge&logo=android&logoColor=white)
[![Release](https://img.shields.io/github/v/release/mohaneddz/Twins?style=for-the-badge)](https://github.com/mohaneddz/Twins/releases/latest)

---

## Screenshots

Green is one twin, lavender the other: each picks a colour, and everything
they make shows in it.

| Home | Calendar | Plans in chat | Chat commands |
| --- | --- | --- | --- |
| <img src="docs/screenshots/home.webp" alt="Home: coming-up plans, folders and recently added posts" width="200" /> | <img src="docs/screenshots/calendar.webp" alt="Calendar month view with each twin's plans as coloured dots" width="200" /> | <img src="docs/screenshots/chat_plans.webp" alt="Chat with plan cards, two of them called off" width="200" /> | <img src="docs/screenshots/chat_commands.webp" alt="Typing / in chat lists the calendar commands" width="200" /> |
| Saved post | Everything saved | Profile | Our colours |
| <img src="docs/screenshots/item_detail.webp" alt="A saved TikTok with its AI description" width="200" /> | <img src="docs/screenshots/saved.webp" alt="All saved posts, each with a stripe in the colour of the twin who saved it" width="200" /> | <img src="docs/screenshots/profile.webp" alt="Profile with the twin's card" width="200" /> | <img src="docs/screenshots/settings_colours.webp" alt="Settings: picking a colour for the app" width="200" /> |

The original design mockups are in [design/](design/).

---

## Features

- **Share from anywhere**: "We're Twins!" sits in Android's Direct Share row. Links arrive clean, with a preview, an AI description (Groq, optionally looking at video frames) and suggested tags.
- **Folders and search**: items can live in several folders; long-press to select many; search covers text, tags and folder names.
- **Shared calendar**: plans with times or all-day, notes, a linked saved item and reminders that ring on both phones. Calling one off tells your twin.
- **Chat**: several threads, swipe to reply, plan cards, auto-naming, and commands: `/plan movie night fri 8pm !1h`, `/remind`, `/today`, `/week`, `/next`, `/cancel`, `/help`.
- **Your own colour**: Miku, Sakura, Lavender, Sky or Peach recolours the app and its icon.
- **Push notifications** when your twin saves something, messages or changes a plan.
- **Backup and clear**: export/import a JSON backup; wipe items, folder contents, chats or everything.

## Install

Grab the APK for your phone from the [latest release](https://github.com/mohaneddz/Twins/releases/latest) (`arm64` for almost every phone). Android only.

On first launch:

1. **Connect**: paste your Supabase project URL and publishable key (Project Settings → API Keys).
2. **Set up the database** (empty or outdated projects only): paste the Session pooler connection string; the app installs every migration itself. Used once, never stored.
3. **Server functions** (optional): paste a Supabase access token (and a Groq key for AI) and the app deploys its edge functions.
4. **Invite your twin**: Settings → Invite your twin shares a `twins://join` link. Their phone opens straight on "Who's this?".

"Who's this?" lists the project's two account slots: pick yours, or create it with a name and password. Either twin can reset the other's password in Settings → Privacy.

## Development

```bash
flutter pub get
flutter run
flutter test
```

- `scripts/build_normal.ps1` builds per-CPU release APKs with nothing baked in.
- `scripts/build_special.ps1` bakes your `.env` project URL and key in, skipping step 1.
- To set up a project from a computer instead, see [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md).

Secrets stay out of the app: `supabase/.env` (git-ignored) holds the service key, DB password and `GROQ_API_KEY`, used only by edge functions and scripts.

## How it's built

- **App**: Flutter with Riverpod and `go_router`. Screens only talk to the `TwinsRepository` interface; `SupabaseTwinsRepository` is the real one, `MockTwinsRepository` backs the tests.
- **Database** (`supabase/migrations/`): Postgres with Row Level Security so everything is visible to both twins and nobody else, two account slots per project, weighted full-text and trigram search, and Realtime for live updates.
- **Edge functions** (`supabase/functions/`): `resolve-link` (previews, thumbnails re-hosted to Storage, Groq enrichment), `suggest-tags`, `name-chat`, and `notify`, which pushes to the other twin through one shared relay (`supabase/relay/push-relay`), so every pair uses the same Firebase project without holding its key.
- **Reminders** are alarms set on each phone, so nothing on the server runs on a timer.

## Limitations

- Android only.
- TikTok and Instagram posts aren't downloaded: the app keeps the preview and opens the original.
