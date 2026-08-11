/**
 * ¡Twins! cloud seed script.
 *
 * Populates the LINKED Supabase project with a realistic, self-contained demo
 * space so you can log in and explore the real backend end-to-end. It uses the
 * admin secret key, so it writes straight past Row Level Security.
 *
 * Prerequisites (see docs/SUPABASE_SETUP.md):
 *   1. Migrations applied:  supabase db push   (or run them in the SQL editor)
 *   2. supabase/.env filled in with SUPABASE_URL + SUPABASE_SECRET_KEY
 *
 * Run:
 *   cd supabase && npm install && npm run seed
 *
 * Idempotent: re-running wipes the two demo users' existing space (cascade)
 * and rebuilds it, so you always end up with a clean, known dataset.
 *
 * After seeding, log into the app with either:
 *   mohaned@twins.app / twinsdemo123      (owner)
 *   rania@twins.app   / twinsdemo123      (twin)
 */
import { createClient, type User } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";

// Load supabase/.env (Node >= 20.12). Falls back to process.env if absent.
try {
  process.loadEnvFile(new URL(".env", import.meta.url));
} catch {
  /* rely on ambient env */
}

const SUPABASE_URL = process.env.SUPABASE_URL ?? process.env.EXPO_PUBLIC_SUPABASE_URL;
const SECRET_KEY =
  process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SECRET_KEY) {
  console.error(
    "Missing SUPABASE_URL or SUPABASE_SECRET_KEY. Fill in supabase/.env first.",
  );
  process.exit(1);
}

const DEMO_PASSWORD = process.env.TWINS_DEMO_PASSWORD ?? "twinsdemo123";

const admin = createClient(SUPABASE_URL, SECRET_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

/** Insert rows and throw on any PostgREST error (supabase-js never throws). */
async function insert(table: string, rows: Record<string, unknown> | Record<string, unknown>[]) {
  const { error } = await admin.from(table).insert(rows as never);
  if (error) {
    throw new Error(
      `Insert into "${table}" failed: ${error.message}` +
        (error.message.includes("schema cache")
          ? "\n\n  → The tables don't exist yet. Apply the migrations first:\n" +
            "      supabase link --project-ref <ref> && supabase db push\n" +
            "    (see docs/SUPABASE_SETUP.md)"
          : ""),
    );
  }
}

/** Find an auth user by email, or create one (email pre-confirmed). */
async function ensureUser(
  email: string,
  displayName: string,
  username: string,
): Promise<User> {
  // paginate through users looking for the email (admin API has no getByEmail)
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw error;
    const found = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
    if (found) {
      await admin.auth.admin.updateUserById(found.id, { password: DEMO_PASSWORD });
      return found;
    }
    if (data.users.length < 200) break;
  }
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: DEMO_PASSWORD,
    email_confirm: true,
    user_metadata: { display_name: displayName, username },
  });
  if (error) throw error;
  return data.user;
}

async function wipeUserSpace(userId: string) {
  // Deleting the space cascades to members, folders, items, tags, comments,
  // messages and reactions (all FK ON DELETE CASCADE).
  const { data: membership } = await admin
    .from("space_members")
    .select("space_id")
    .eq("user_id", userId)
    .maybeSingle();
  if (membership?.space_id) {
    await admin.from("spaces").delete().eq("id", membership.space_id);
  }
  // Belt-and-braces in case a stale membership row outlived its space.
  await admin.from("space_members").delete().eq("user_id", userId);
}

async function main() {
  console.log("Seeding ¡Twins! demo space against", SUPABASE_URL);

  const me = await ensureUser("mohaned@twins.app", "Mohaned", "mohaned");
  const twin = await ensureUser("rania@twins.app", "Rania", "rania");

  // Clean slate for both demo users.
  await wipeUserSpace(me.id);
  await wipeUserSpace(twin.id);

  // Profiles are auto-created by the on_auth_user_created trigger; enrich them.
  const { error: profileErr } = await admin.from("profiles").upsert([
    { id: me.id, display_name: "Mohaned", username: "mohaned", bio: "twin no. 1 ✨" },
    { id: twin.id, display_name: "Rania", username: "rania", bio: "twin no. 2 💜" },
  ]);
  if (profileErr) throw new Error(`Upsert profiles failed: ${profileErr.message}`);

  // Space + membership (owner then member; the 2-member cap trigger allows 2).
  const spaceId = randomUUID();
  await insert("spaces", { id: spaceId, name: "We're Twins!", created_by: me.id });
  await insert("space_members", [
    { space_id: spaceId, user_id: me.id, role: "owner" },
    { space_id: spaceId, user_id: twin.id, role: "member" },
  ]);

  // A live, single-use invite code so the "join space" flow is testable too.
  await insert("space_invites", { space_id: spaceId, created_by: me.id });

  // Folders
  const folders = {
    reels: randomUUID(),
    dates: randomUUID(),
    travel: randomUUID(),
    random: randomUUID(),
    study: randomUUID(),
  };
  await insert("folders", [
    { id: folders.reels, space_id: spaceId, name: "Funny Reels 😂", color: "0xFF8DEBD9", icon: "😂", is_pinned: true, position: 0, created_by: me.id },
    { id: folders.dates, space_id: spaceId, name: "Date Ideas ✨", color: "0xFFF6A5C0", icon: "✨", is_pinned: false, position: 1, created_by: twin.id },
    { id: folders.travel, space_id: spaceId, name: "Travel Plans 🌍", color: "0xFFB39DDB", icon: "🌍", is_pinned: false, position: 2, created_by: me.id },
    { id: folders.random, space_id: spaceId, name: "Random Stuff", color: "0xFF90CAF9", icon: "📦", is_pinned: false, position: 3, created_by: twin.id },
    { id: folders.study, space_id: spaceId, name: "Study Stuff", color: "0xFFFFCC80", icon: "📚", is_pinned: false, position: 4, created_by: me.id },
  ]);

  // Tags: a starter catalog the AI auto-tags from. The first four are wired to
  // seeded items below; the rest round out a realistic catalog to pick from.
  const tags = { funny: randomUUID(), cats: randomUUID(), cozy: randomUUID(), travel: randomUUID() };
  const palette = ["0xFF7EE7E1", "0xFFF6A5C0", "0xFFFFCC80", "0xFF90CAF9", "0xFFB39DDB", "0xFF80CBC4"];
  const extraTags = ["food", "recipes", "aesthetic", "music", "workout", "memes", "outfits", "home", "art", "study"];
  await insert("tags", [
    { id: tags.funny, space_id: spaceId, name: "funny", color: palette[0] },
    { id: tags.cats, space_id: spaceId, name: "cats", color: palette[1] },
    { id: tags.cozy, space_id: spaceId, name: "cozy", color: palette[2] },
    { id: tags.travel, space_id: spaceId, name: "travel", color: palette[3] },
    ...extraTags.map((name, i) => ({ space_id: spaceId, name, color: palette[(i + 4) % palette.length] })),
  ]);

  // Items
  const hoursAgo = (h: number) => new Date(Date.now() - h * 3600_000).toISOString();
  const daysAgo = (d: number) => new Date(Date.now() - d * 86_400_000).toISOString();

  const items = {
    i1: randomUUID(), i2: randomUUID(), i7: randomUUID(), i8: randomUUID(),
    i11: randomUUID(),
  };
  await insert("items", [
    { id: items.i1, space_id: spaceId, folder_id: folders.reels, created_by: me.id, type: "tiktok", platform: "tiktok", source_url: "https://www.tiktok.com/@user/video/1", thumbnail_url: "https://images.unsplash.com/photo-1517849845537-4d257902861a?w=600", title: "bro has no filter 😭", description: "this puppy #cozy #aesthetic", duration_ms: 18000, created_at: hoursAgo(2) },
    { id: items.i2, space_id: spaceId, folder_id: folders.reels, created_by: twin.id, type: "tiktok", platform: "tiktok", source_url: "https://www.tiktok.com/@user/video/2", thumbnail_url: "https://images.unsplash.com/photo-1495360010541-f48722b34f7d?w=600", title: "the acrobat 🐈", created_at: hoursAgo(5) },
    { id: randomUUID(), space_id: spaceId, folder_id: folders.reels, created_by: me.id, type: "tiktok", platform: "tiktok", source_url: "https://www.tiktok.com/@user/video/3", thumbnail_url: "https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=600", title: "gotta try this 🙃", created_at: daysAgo(1) },
    { id: randomUUID(), space_id: spaceId, folder_id: folders.reels, created_by: twin.id, type: "note", platform: "device", title: "Movie night ideas", content: "- Interstellar\n- Your Name\n- Into The Wild", created_at: daysAgo(4) },
    { id: items.i7, space_id: spaceId, folder_id: folders.travel, created_by: me.id, type: "youtube", platform: "youtube", source_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", thumbnail_url: "https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=600", title: "Big Sur Road Trip", description: "we need to do this next summer", duration_ms: 762000, created_at: hoursAgo(3) },
    { id: items.i8, space_id: spaceId, folder_id: folders.random, created_by: twin.id, type: "image", platform: "device", thumbnail_url: "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600", title: "aesthetic room inspo 🤍", created_at: hoursAgo(6) },
    { id: randomUUID(), space_id: spaceId, folder_id: folders.random, created_by: me.id, type: "note", platform: "device", title: "room lighting ideas", content: "- Warm fairy lights\n- Sunset lamp\n- Candles on the shelf", created_at: daysAgo(2) },
    { id: items.i11, space_id: spaceId, folder_id: folders.dates, created_by: me.id, type: "link", platform: "web", source_url: "https://www.timeout.com/things-to-do", thumbnail_url: "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=600", title: "rooftop dinner spots", description: "timeout.com", created_at: daysAgo(5) },
  ]);

  // Item <-> tag links
  await insert("item_tags", [
    { item_id: items.i1, tag_id: tags.funny },
    { item_id: items.i2, tag_id: tags.funny },
    { item_id: items.i2, tag_id: tags.cats },
    { item_id: items.i7, tag_id: tags.travel },
    { item_id: items.i8, tag_id: tags.cozy },
  ]);

  // Comments (comment_count is maintained by a trigger, so don't set it)
  await insert("item_comments", [
    { space_id: spaceId, item_id: items.i1, author_id: twin.id, body: "this tiny bookstore vibes ✨", created_at: hoursAgo(1.9) },
    { space_id: spaceId, item_id: items.i1, author_id: me.id, body: "LMFAOOOO 😭", media_timestamp_ms: 42000, created_at: hoursAgo(1.8) },
    { space_id: spaceId, item_id: items.i1, author_id: twin.id, body: "saved this to Funny Reels 💚", created_at: hoursAgo(1.7) },
    { space_id: spaceId, item_id: items.i7, author_id: twin.id, body: "booking the airbnb 👀", created_at: hoursAgo(2.5) },
  ]);

  // Chat messages (capture ids so reactions can target them)
  const messageIds = [randomUUID(), randomUUID(), randomUUID(), randomUUID()];
  await insert("messages", [
    { id: messageIds[0], space_id: spaceId, author_id: me.id, body: "I need this cat in my life 🐈", created_at: hoursAgo(0.7) },
    { id: messageIds[1], space_id: spaceId, author_id: twin.id, body: "same... look at that little face 🥺💜", created_at: hoursAgo(0.65) },
    { id: messageIds[2], space_id: spaceId, author_id: me.id, body: "hahaha twins brain ✨", created_at: hoursAgo(0.63) },
    { id: messageIds[3], space_id: spaceId, author_id: twin.id, body: "already added to Funny Reels 🙂", attached_item_id: items.i2, created_at: hoursAgo(0.6) },
  ]);

  // Reactions (reaction_count on items is maintained by a trigger)
  await insert("reactions", [
    { space_id: spaceId, user_id: twin.id, target_type: "message", target_id: messageIds[0], emoji: "❤️" },
    { space_id: spaceId, user_id: me.id, target_type: "message", target_id: messageIds[3], emoji: "❤️" },
    { space_id: spaceId, user_id: twin.id, target_type: "item", target_id: items.i1, emoji: "😂" },
    { space_id: spaceId, user_id: me.id, target_type: "item", target_id: items.i1, emoji: "🔥" },
    { space_id: spaceId, user_id: twin.id, target_type: "item", target_id: items.i7, emoji: "😍" },
  ]);

  // Default settings for the owner.
  await admin.from("user_settings").upsert({ user_id: me.id, theme: "system" });

  console.log("\n✅ Seed complete.");
  console.log("   Space:", spaceId);
  console.log("   Log in as  mohaned@twins.app / " + DEMO_PASSWORD + "  (owner)");
  console.log("   or         rania@twins.app   / " + DEMO_PASSWORD + "  (twin)");
}

main().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
