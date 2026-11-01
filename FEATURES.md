# ¡Twins! — Remaining work

Audit date: 2026-11-01 (previous: 2026-09-17). Delta between what's claimed (README, state doc) and what's actually in the code.

## ✅ Done since the last audit

- **Test suite green again (32/32)** — the boot test and dashboard goldens were rendering an empty, unauthenticated shell because the app always builds `SupabaseTwinsRepository` now; they override `repositoryProvider` with `MockTwinsRepository`. Card goldens re-baselined for the fixed-height thumbnail layout.
- **README / `.env.example` corrected** — they still promised a zero-setup mock mode, which went away in `140d51c`. They now describe the first-launch setup screen and the special build. `EXPO_PUBLIC_APP_SCHEME` dropped: nothing read it.
- **Link previews (2026-10-14)** — per-platform extractors in `resolve-link`, author/site/duration kept, thumbnails re-hosted into Storage, "posted by" shown on cards and item detail. Edge functions moved off the retired `llama-3.1-8b-instant` model.
- **Live database verified** — all 13 migrations (`0001`–`0013`) are applied on the live project (`supabase migration list --db-url`).
- **Pairing / RLS tests** — `supabase/tests/pairing_rls_test.sql`, 12 checks (two-member cap, single-use/expired/unknown invites, cross-space reads and writes), all passing against the live project inside a rolled-back transaction.
- **Android Direct Share** — the app publishes a long-lived sharing shortcut for the space so it can appear in the system share sheet's top row. Builds; **not yet tried on a device**.

## ❌ Blocked on something outside the code — needs your action first

- **Edge functions are NOT deployed** (S) — `resolve-link`, `suggest-tags` and `name-chat` all return `NOT_FOUND` on the live project, so link previews, AI tags and chat auto-naming are broken in the real app. This machine's Supabase CLI is logged into a different account, so deploying needs `supabase login` with the account that owns the Twins project, then:
  `supabase functions deploy resolve-link --project-ref incxcgnwtnalzxmztatq` (same for `suggest-tags`, `name-chat`) and `supabase secrets set --env-file supabase/.env --project-ref incxcgnwtnalzxmztatq`.

- **Push notifications** (L) — no Firebase/FCM/APNs code anywhere. Needs a Firebase project + APNs certs + device-token storage + an Edge Function trigger. The settings toggle is a placeholder; live in-app updates use Realtime regardless.
- **iOS Share Extension** (S, Xcode GUI only) — no extension target in `ios/`. Needs File → New → Target → Share Extension + an App Group. Android sharing works.

## ⚠️ Still open, not blocked

- **Direct Share on a real phone** (S) — install, pair, share a reel from Chrome/YouTube and check "¡Twins!" shows in the top row. Android ranks it by use, so it can take a couple of shares to climb.
- **Lint** (S) — 19 `flutter analyze` infos, no errors: `unnecessary_underscores`, `use_null_aware_elements` in `supabase_repository.dart`, and three `use_build_context_synchronously` in `edit_profile_screen.dart`.

## 👻 Known, deliberate non-features (not gaps)

- TikTok/Instagram Reels aren't re-hosted/downloaded — thumbnail + "Open original" only, per platform ToS.
- No offline/demo mode — `MockTwinsRepository` is test-only by design.

## Next steps, in order

1. `supabase login` (right account) → deploy the three edge functions + secrets.
2. Try Direct Share on a phone.
3. Lint cleanup.
4. iOS Share Extension, whenever iOS parity matters.
5. Push notifications — Firebase project + APNs certs first.
