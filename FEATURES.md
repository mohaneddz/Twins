# ¡Twins! — Remaining work

Audit date: 2026-11-01 (previous: 2026-09-17). Delta between what's claimed (README, state doc) and what's actually in the code.

## ✅ Done (2026-11-01)

- **Self-serve setup from an empty Supabase project** — the setup screen probes the project, installs/updates the schema over a one-time connection string (`lib/data/supabase/project_setup.dart`), and deploys the three edge functions + `GROQ_API_KEY` with a one-time access token. Verified on a real phone against the live project: it applied `0014` and deployed all three functions.
- **Slot-based sign-in** — "Who's this?" lists the project's two twins and creates a missing one with name + password (`0014_twin_slots.sql`). No emails, confirmation mail or invite codes; either twin resets the other's password in Settings → Privacy.
- **Android Direct Share** — "We're Twins!" shows in the system share sheet's top row (verified on a Realme / Android 16; it climbed to first place after two shares).
- **Cold-start shares fixed** — a share that launched the app used to land on home and lose the link (the router was rebuilt on every auth/space change). Now opens Add with the preview. Verified on the phone.
- **Release builds had no INTERNET permission** — every release APK was offline. Fixed.
- **Home greeting is opt-in** — "Hey twins!" is hidden unless turned on in Settings → Greeting on home.
- **Shared links need no editing** — the URL is pulled out of share text, and YouTube links (m., music., youtu.be, share params) are saved as clean www watch links, which also fixed m.youtube previews showing YouTube's generic tagline. Verified on the phone.
- **Tests** — 33 Flutter tests; `supabase/tests/pairing_rls_test.sql` (12 checks) and `supabase/tests/twin_slots_test.sql` (8 checks), both rolled-back and safe on a live project.

## ❌ Blocked on something outside the code

- **Push notifications** (L) — no Firebase/FCM/APNs code. Needs a Firebase project + APNs certs first. Live in-app updates use Realtime.
- **iOS** — out of scope: the app is Android-only for now (no share extension, never built for iOS).

## ⚠️ Still open

- **Second twin's account** — slot 2 is still empty on the live project; create it from the other phone.
- **Redeploy `resolve-link`** — the function source now also canonicalizes YouTube links (for older app builds), but the deployed copy predates that; the app already sends clean links, so nothing is broken.
- **Lint** (S) — ~19 `flutter analyze` infos, no errors.

## 👻 Known, deliberate non-features (not gaps)

- TikTok/Instagram Reels aren't re-hosted/downloaded — thumbnail + "Open original" only, per platform ToS.
- No offline/demo mode — `MockTwinsRepository` is test-only by design.

## Next steps, in order

1. Create twin 2 from the other phone.
2. Lint cleanup.
3. Push notifications — needs a Firebase project first (Android-only, so no APNs).
