# ¡Twins! — Remaining work

Audit date: 2026-11-01 (previous: 2026-09-17). Delta between what's claimed (README, state doc) and what's actually in the code.

## ✅ Done since the last audit

- **Test suite green again (32/32)** — the boot test and dashboard goldens were rendering an empty, unauthenticated shell because the app always builds `SupabaseTwinsRepository` now; they override `repositoryProvider` with `MockTwinsRepository`. Card goldens re-baselined for the fixed-height thumbnail layout.
- **README / `.env.example` corrected** — they still promised a zero-setup mock mode, which went away in `140d51c`. They now describe the first-launch setup screen and the special build. `EXPO_PUBLIC_APP_SCHEME` dropped: nothing read it.
- **Link previews (2026-10-14)** — per-platform extractors in `resolve-link`, author/site/duration kept, thumbnails re-hosted into Storage, "posted by" shown on cards and item detail. Edge functions moved off the retired `llama-3.1-8b-instant` model.
- **A Supabase project now exists** — `.env` points at a live project and migrations `0012`/`0013` were written against it. The September blocker ("no project linked") no longer holds.

## ❓ Unverified — needs one check

- **Backend deployment state** — the project isn't visible to this machine's Supabase CLI/connector (no `supabase/.temp/project-ref`), so it's unconfirmed that `0011`–`0013` are applied and `resolve-link` / `suggest-tags` / `name-chat` are deployed with `GROQ_API_KEY` set. Run `supabase link --project-ref <ref>`, then `supabase migration list` and `supabase functions list`.

## ❌ Blocked on something outside the code — needs your action first

- **Push notifications** (L) — no Firebase/FCM/APNs code anywhere. Needs a Firebase project + APNs certs + device-token storage + an Edge Function trigger. The settings toggle is a placeholder; live in-app updates use Realtime regardless.
- **iOS Share Extension** (S, Xcode GUI only) — no extension target in `ios/`. Needs File → New → Target → Share Extension + an App Group. Android sharing works.

## ⚠️ Still open, not blocked

- **RLS / pairing integration tests** (M) — the two-member cap and `join_space_with_code` live server-side and have no tests. Needs the linked project or a local `supabase start` stack.
- **Lint** (S) — 19 `flutter analyze` infos, no errors: `unnecessary_underscores`, `use_null_aware_elements` in `supabase_repository.dart`, and three `use_build_context_synchronously` in `edit_profile_screen.dart`.

## 👻 Known, deliberate non-features (not gaps)

- TikTok/Instagram Reels aren't re-hosted/downloaded — thumbnail + "Open original" only, per platform ToS.
- No offline/demo mode — `MockTwinsRepository` is test-only by design.

## Next steps, in order

1. Link the project and confirm migrations + edge functions are deployed.
2. RLS/pairing integration tests against it.
3. Lint cleanup.
4. iOS Share Extension, whenever iOS parity matters.
5. Push notifications — Firebase project + APNs certs first.
