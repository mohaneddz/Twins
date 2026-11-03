# ¡Twins! — Remaining work

Audit date: 2026-11-01 (previous: 2026-09-17). Delta between what's claimed (README, state doc) and what's actually in the code.

## ✅ Done (2026-11-03)

- **Shared calendar** (`0018`) — the second tab is now Calendar: a month grid (dots green for your plans, pink for your twin's), the picked day's plans and what's coming up. Plans have a time or all-day, an optional end, notes, a linked saved item (item details → Plan it) and a reminder (none / at the time / 10 min … 1 day; default in Settings → Calendar). Editing, sending to a chat and calling off live on the plan's page (`/event/:id`). Home shows the next three under "Coming up". Verified on the phone.
- **Reminders on both phones** — each phone sets its own alarm from the calendar (`lib/notifications/plan_reminders.dart`, alarm-clock mode because realme batched plain exact alarms by up to an hour); the twin's phone sets its alarm straight from the "X planned something" push, even with the app closed. Verified the alarm is set exactly on the phone; the actual ring and the twin's side are untested.
- **Chat replies** — swipe a message right (or long-press → Reply); the bubble quotes the original and tapping the quote scrolls to it. Long-press also has reactions, Copy text and Make it a plan. Verified on the phone.
- **Slash commands** — `/plan movie night fri 8pm !1h`, `/remind`, `/today`, `/tomorrow`, `/week`, `/next`, `/cancel`, `/help`. Suggestions show as you type `/`, and a live line above the composer says exactly what the plan will be before sending. The plan parser (`lib/utils/when_parser.dart`) handles weekdays, dates (day first), 12/24h and 20h30 times, ranges and "in 2 hours"; 12 tests. Verified on the phone.
- **Saved page** (`/saved`, Everything → See all) — every saved thing with kind filters, Not in a folder, and multi-select. Folders stay at Folders → See all.
- **Settings → Clear data** (`0019`) — clear all saved items (files included), empty all folders, clear all chats, or clear everything; each asks first.
- **Message times** showed UTC; fixed.

## ✅ Done (2026-11-01)

- **Self-serve setup from an empty Supabase project** — the setup screen probes the project, installs/updates the schema over a one-time connection string (`lib/data/supabase/project_setup.dart`), and deploys the three edge functions + `GROQ_API_KEY` with a one-time access token. Verified on a real phone against the live project: it applied `0014` and deployed all three functions.
- **Slot-based sign-in** — "Who's this?" lists the project's two twins and creates a missing one with name + password (`0014_twin_slots.sql`). No emails, confirmation mail or invite codes; either twin resets the other's password in Settings → Privacy.
- **Android Direct Share** — "We're Twins!" shows in the system share sheet's top row (verified on a Realme / Android 16; it climbed to first place after two shares).
- **Cold-start shares fixed** — a share that launched the app used to land on home and lose the link (the router was rebuilt on every auth/space change). Now opens Add with the preview. Verified on the phone.
- **Release builds had no INTERNET permission** — every release APK was offline. Fixed.
- **Home greeting is opt-in** — "Hey twins!" is hidden unless turned on in Settings → Greeting on home.
- **Shared links need no editing** — the URL is pulled out of share text, and YouTube links (m., music., youtu.be, share params) are saved as clean www watch links, which also fixed m.youtube previews showing YouTube's generic tagline. Verified on the phone.
- **Multi-folder items** (`0015`) — "Move to folder" is now "Add to folder": a checkbox sheet (dash when only some selected items are in a folder), shared by item details and multi-select; folders can also be picked on the add screen, with a New folder chip.
- **Long-press multi-select** on home and in folders — Add to folder / Remove from this folder / Delete.
- **Home "Everything" grid** under Recently added, with a Not in a folder filter.
- **Unread badge on the bell** — counts what the other twin added or sent since Activity was last opened on this phone; message rows open their chat.
- **Profile edits show instantly** (both twins' profiles stream over Realtime) and the profile page has pull-to-refresh.
- **Chat**: keyboard no longer squeezes messages under the composer; chats get their first name after N messages (default 1) and a fresh one every Y messages (default 20, or Never) from the latest messages — typed names are never replaced (`0016`); the list shows each chat's latest message.
- **AI vision** (Settings → AI looks at) — Groq's `qwen/qwen3.8-27b` sees up to 3 images (YouTube start/middle/end frames and/or the thumbnail) and writes a description of what's actually in the video; falls back to the text model on failure. Settings → Update server functions redeploys the edge functions from the phone.
- **Schema upgrades on app update** — setup stores the schema version it confirmed; an update needing a newer one reconnects automatically and only asks for the connection string if the DB is behind.
- **Invite link** — Settings → Invite your twin (or the profile's twin card) shares `twins://join?u=…&k=…`; opening it on a fresh install, or pasting it on the setup screen, connects without a second setup. Not yet tried on a device.
- **Profile** shows your own name, @username and bio plus a card with your twin's (invite button while their slot is empty). Selection borders draw above thumbnails. Not yet tried on a device.
- **Tests** — 37 Flutter tests; `supabase/tests/pairing_rls_test.sql` (12 checks) and `supabase/tests/twin_slots_test.sql` (8 checks), both rolled-back and safe on a live project.

## ❌ Blocked on something outside the code

- **Push notifications — built, not yet seen on a phone.** One shared Firebase project (`twins-6e30c`, `google-services.json` in the app), a `push-relay` function on the maintainer's Supabase (the only holder of the Firebase key — verified against FCM: auth works, dead tokens are reported), and per-pair `device_tokens` (`0017`) + `notify`, which setup deploys and wires to the relay. Remaining: install the new build on both phones and send something.
- **iOS** — out of scope: the app is Android-only for now (no share extension, never built for iOS).

## ⚠️ Still open

- **Second twin's account** — slot 2 is still empty on the live project; create it from the other phone.
- **In-app "Update server functions" didn't reach Supabase** (2026-11-02) — the functions stayed at the setup-time version; the sheet now reports every failure and the deployed version numbers. Deployed v3 of all three functions directly via the Management API; AI vision confirmed live (3 images, ~1s extra).
- **Lint** (S) — ~19 `flutter analyze` infos, no errors.

## 👻 Known, deliberate non-features (not gaps)

- TikTok/Instagram Reels aren't re-hosted/downloaded — thumbnail + "Open original" only, per platform ToS.
- No offline/demo mode — `MockTwinsRepository` is test-only by design.

## Next steps, in order

1. Create twin 2 from the other phone.
2. Lint cleanup.
3. Test push on two phones.
