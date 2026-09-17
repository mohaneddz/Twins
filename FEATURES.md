# ¡Twins! — Remaining work

Audit date: 2026-09-17. Delta between what's claimed (README, state doc) and what's actually in the code.

## ❌ Missing / not started

- **Push notifications** (M) — no Firebase/FCM/APNs code anywhere in `lib/`. Settings toggle exists as UI only; live updates rely entirely on Supabase Realtime. Needs a Firebase project + APNs certs + device-token storage + a Supabase Edge Function trigger before any client code is worth writing.
- **iOS Share Extension** (S, but requires Xcode GUI, not headless) — `receive_sharing_intent` plugin is wired for Android (`ACTION_SEND` in `AndroidManifest.xml`), but iOS has no Share Extension target/App Group. iOS builds work otherwise; "Share → ¡Twins!" from other apps doesn't exist on iOS yet.
- **GROQ_API_KEY server-side move** (S) — key currently ships in the client bundle for in-app AI polish even though `resolve-link` Edge Function already supports it server-side. Security cleanup, not a missing feature.
- **Automated tests for core flows** (M) — `test/` only has golden/widget tests for cards/theme and one `search_test.dart`. No tests for pairing, RLS-backed repository flows, chat auto-naming, or share-intent replay.

## ⚠️ Shell / needs backend action

- **Migration `0011_chats.sql`** (chat threads) — written but per the state doc not yet applied to a live Supabase project (no Twins project currently linked in this environment). Needs `supabase link` + `supabase db push` before testing threads against a real backend.

## ✅ Confirmed built (README is stale here — don't trust it)

- Profile avatar upload — `edit_profile_screen.dart` calls `repo.uploadAvatar(...)`, wired to Supabase Storage's `avatars` bucket. README still says "not wired yet" — that line is outdated.
- Import from backup — `settings_screen.dart` has the "Import from a backup" flow (folders/items re-created with remapped ids). README still says only Export exists — outdated.

## 👻 Known, deliberate non-features (not gaps)

- TikTok/Instagram Reels aren't re-hosted/downloaded — thumbnail + "Open original" only, per platform ToS. Documented as intentional in the README.

## Recommended order

1. Link a Supabase project and push migration `0011` — blocks testing chat threads at all against real data.
2. iOS Share Extension — if iOS parity matters, this is the one manual step blocking it.
3. Move `GROQ_API_KEY` server-side — quick security win, low effort.
4. Push notifications — biggest effort, needs external account setup (Firebase/APNs) before any code.
5. Test coverage for pairing/RLS/chat-naming/share-replay — polish, do opportunistically.

*(README.md has two stale "not implemented" claims — see readme-upkeep skill to fix these once convenient.)*
