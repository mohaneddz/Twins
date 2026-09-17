# ¡Twins! — Remaining work

Audit date: 2026-09-17. Delta between what's claimed (README, state doc) and what's actually in the code.

## ✅ Done since the audit

- **GROQ_API_KEY server-side move** — link polish, tag suggestion, and chat auto-naming all now go through Edge Functions (`resolve-link`, new `suggest-tags`, new `name-chat`). Nothing calls Groq directly from the Flutter client anymore; `flutter_dotenv` dependency dropped.
- **Stale README claims fixed** — avatar upload and import-from-backup were already implemented; the README no longer says otherwise.
- **Tests added** — `SpaceInvite.isValid` (expiry/used-once logic), `shouldAttemptAutoName` (chat auto-name trigger, extracted out of `ChatScreen` into a pure function), and `ShareIntentService` pending-share stash/replay.

## ❌ Blocked on something outside the code — needs your action first

- **Push notifications** (M) — no Firebase/FCM/APNs code anywhere in `lib/`. Needs a Firebase project + APNs certs + device-token storage before any client code is worth writing. Can't proceed without those credentials.
- **iOS Share Extension** (S, but Xcode GUI only) — needs a manual Xcode step (File → New → Target → Share Extension + App Group) that can't be scripted headlessly. Android sharing already works.
- **Migration `0011_chats.sql` not applied** — no Twins Supabase project is linked in this environment (`supabase projects list` shows none under this account). Needs `supabase link --project-ref <ref>` with your project's ref, then `supabase db push`, before chat threads can be tested against a real backend. Also blocks deploying the two new Edge Functions (`suggest-tags`, `name-chat`) and re-deploying `resolve-link`.

## ⚠️ Still open, not blocked

- **RLS-backed repository flow tests and the two-member pairing cap** — these live entirely server-side (Postgres trigger + `join_space_with_code` RPC), not in client code, so they need a linked Supabase project (or a local `supabase start` stack) to test against for real. Not written yet.

## 👻 Known, deliberate non-features (not gaps)

- TikTok/Instagram Reels aren't re-hosted/downloaded — thumbnail + "Open original" only, per platform ToS. Documented as intentional in the README.

## Next steps, in order

1. Link a Supabase project (`supabase link --project-ref <ref>`) and `supabase db push` — unblocks migration `0011` and deploying `resolve-link`/`suggest-tags`/`name-chat`.
2. iOS Share Extension — one manual Xcode step, whenever iOS parity matters.
3. Push notifications — needs a Firebase project + APNs certs first; biggest remaining effort.
4. RLS/pairing integration tests — once a project is linked, worth adding.
