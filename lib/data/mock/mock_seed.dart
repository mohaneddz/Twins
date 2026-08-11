import '../../theme/colors.dart';
import '../models/comment.dart';
import '../models/folder.dart';
import '../models/item.dart';
import '../models/item_type.dart';
import '../models/message.dart';
import '../models/profile.dart';
import '../models/reaction.dart';
import '../models/space.dart';
import '../models/tag.dart';

/// Realistic seeded data so the whole app is explorable before Supabase
/// credentials exist. Mirrors the content shown in the design mockups.
class MockSeed {
  static const spaceId = 'space-1';
  static const meId = 'user-me';
  static const twinId = 'user-twin';

  static final me = Profile(
    id: meId,
    displayName: 'Mohaned',
    username: 'mohaned',
    createdAt: DateTime(2024, 5, 12),
  );

  static final twin = Profile(
    id: twinId,
    displayName: 'Rania',
    username: 'rania',
    createdAt: DateTime(2024, 5, 12),
  );

  static final space = TwinsSpace(
    id: spaceId,
    name: "We're Twins!",
    createdBy: meId,
    createdAt: DateTime(2024, 5, 12),
  );

  static final folders = <TwinsFolder>[
    TwinsFolder(
      id: 'folder-reels',
      spaceId: spaceId,
      name: 'Funny Reels 😂',
      color: TwinsColors.folderMint,
      icon: '😂',
      isPinned: true,
      createdBy: meId,
      createdAt: DateTime(2024, 6, 1),
      updatedAt: DateTime.now(),
      itemCount: 6,
    ),
    TwinsFolder(
      id: 'folder-dates',
      spaceId: spaceId,
      name: 'Date Ideas ✨',
      color: TwinsColors.folderPink,
      icon: '✨',
      createdBy: twinId,
      createdAt: DateTime(2024, 6, 3),
      updatedAt: DateTime.now(),
      itemCount: 12,
    ),
    TwinsFolder(
      id: 'folder-travel',
      spaceId: spaceId,
      name: 'Travel Plans 🌍',
      color: TwinsColors.folderPurple,
      icon: '🌍',
      createdBy: meId,
      createdAt: DateTime(2024, 6, 10),
      updatedAt: DateTime.now(),
      itemCount: 18,
    ),
    TwinsFolder(
      id: 'folder-random',
      spaceId: spaceId,
      name: 'Random Stuff',
      color: TwinsColors.folderBlue,
      icon: '📦',
      createdBy: twinId,
      createdAt: DateTime(2024, 6, 15),
      updatedAt: DateTime.now(),
      itemCount: 37,
    ),
    TwinsFolder(
      id: 'folder-study',
      spaceId: spaceId,
      name: 'Study Stuff',
      color: TwinsColors.folderPeach,
      icon: '📚',
      createdBy: meId,
      createdAt: DateTime(2024, 6, 20),
      updatedAt: DateTime.now(),
      itemCount: 5,
    ),
  ];

  static final tags = <TwinsTag>[
    TwinsTag(id: 'tag-funny', spaceId: spaceId, name: 'funny', color: TwinsColors.mikuLight),
    TwinsTag(id: 'tag-cats', spaceId: spaceId, name: 'cats', color: TwinsColors.sakuraPink),
    TwinsTag(id: 'tag-cozy', spaceId: spaceId, name: 'cozy', color: TwinsColors.folderPeach),
    TwinsTag(id: 'tag-travel', spaceId: spaceId, name: 'travel', color: TwinsColors.skyBlue),
  ];

  static final items = <TwinsItem>[
    TwinsItem(
      id: 'item-1',
      spaceId: spaceId,
      folderId: 'folder-reels',
      createdBy: meId,
      type: ItemType.tiktok,
      platform: ItemPlatform.tiktok,
      sourceUrl: 'https://www.tiktok.com/@user/video/1',
      thumbnailUrl: 'https://images.unsplash.com/photo-1517849845537-4d257902861a?w=600',
      title: 'bro has no filter 😭',
      description: 'this puppy #cozy #books #aesthetic',
      durationMs: 18000,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      commentCount: 3,
      reactionCount: 12,
      tagIds: const ['tag-funny'],
    ),
    TwinsItem(
      id: 'item-2',
      spaceId: spaceId,
      folderId: 'folder-reels',
      createdBy: twinId,
      type: ItemType.tiktok,
      platform: ItemPlatform.tiktok,
      sourceUrl: 'https://www.tiktok.com/@user/video/2',
      thumbnailUrl: 'https://images.unsplash.com/photo-1495360010541-f48722b34f7d?w=600',
      title: 'the acrobat 🐈',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      commentCount: 1,
      reactionCount: 8,
      tagIds: const ['tag-funny', 'tag-cats'],
    ),
    TwinsItem(
      id: 'item-3',
      spaceId: spaceId,
      folderId: 'folder-reels',
      createdBy: meId,
      type: ItemType.tiktok,
      platform: ItemPlatform.tiktok,
      sourceUrl: 'https://www.tiktok.com/@user/video/3',
      thumbnailUrl: 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=600',
      title: 'gotta try this 🙃',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      reactionCount: 15,
    ),
    TwinsItem(
      id: 'item-4',
      spaceId: spaceId,
      folderId: 'folder-reels',
      createdBy: twinId,
      type: ItemType.tiktok,
      platform: ItemPlatform.tiktok,
      sourceUrl: 'https://www.tiktok.com/@user/video/4',
      thumbnailUrl: 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=600',
      title: 'unexpected 😅',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      reactionCount: 6,
    ),
    TwinsItem(
      id: 'item-5',
      spaceId: spaceId,
      folderId: 'folder-reels',
      createdBy: meId,
      type: ItemType.tiktok,
      platform: ItemPlatform.tiktok,
      sourceUrl: 'https://www.tiktok.com/@user/video/5',
      thumbnailUrl: 'https://images.unsplash.com/photo-1583512603866-910c8542d8d3?w=600',
      title: 'the little jump 😳',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      reactionCount: 9,
    ),
    TwinsItem(
      id: 'item-6',
      spaceId: spaceId,
      folderId: 'folder-reels',
      createdBy: twinId,
      type: ItemType.note,
      title: 'Movie night ideas',
      content: '- Interstellar\n- Your Name\n- Into The Wild',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    TwinsItem(
      id: 'item-7',
      spaceId: spaceId,
      folderId: 'folder-travel',
      createdBy: meId,
      type: ItemType.youtube,
      platform: ItemPlatform.youtube,
      sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      thumbnailUrl: 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=600',
      title: 'Big Sur Road Trip',
      description: 'we need to do this next summer',
      durationMs: 762000,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      commentCount: 4,
      reactionCount: 5,
      tagIds: const ['tag-travel'],
    ),
    TwinsItem(
      id: 'item-8',
      spaceId: spaceId,
      folderId: 'folder-random',
      createdBy: twinId,
      type: ItemType.image,
      thumbnailUrl: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
      title: 'aesthetic room inspo 🤍',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
      reactionCount: 3,
    ),
    TwinsItem(
      id: 'item-9',
      spaceId: spaceId,
      folderId: 'folder-random',
      createdBy: meId,
      type: ItemType.image,
      thumbnailUrl: 'https://images.unsplash.com/photo-1524758631624-e2822e304c36?w=600',
      title: 'cozy desk setup',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TwinsItem(
      id: 'item-10',
      spaceId: spaceId,
      folderId: 'folder-random',
      createdBy: twinId,
      type: ItemType.note,
      title: 'room lighting ideas',
      content: '- Warm fairy lights\n- Sunset lamp\n- Candles on the shelf',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    TwinsItem(
      id: 'item-11',
      spaceId: spaceId,
      folderId: 'folder-dates',
      createdBy: meId,
      type: ItemType.link,
      sourceUrl: 'https://www.timeout.com/things-to-do',
      thumbnailUrl: 'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=600',
      title: 'rooftop dinner spots',
      description: 'timeout.com',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  static final comments = <TwinsComment>[
    TwinsComment(
      id: 'c1',
      spaceId: spaceId,
      itemId: 'item-1',
      authorId: twinId,
      body: 'this tiny bookstore vibes ✨',
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
    ),
    TwinsComment(
      id: 'c2',
      spaceId: spaceId,
      itemId: 'item-1',
      authorId: meId,
      body: 'LMFAOOOO 😭',
      mediaTimestampMs: 42000,
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
    ),
    TwinsComment(
      id: 'c3',
      spaceId: spaceId,
      itemId: 'item-1',
      authorId: twinId,
      body: 'saved this to Funny Reels 💚',
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
    ),
  ];

  static final messages = <TwinsMessage>[
    TwinsMessage(
      id: 'm1',
      spaceId: spaceId,
      authorId: meId,
      body: 'I need this cat in my life 🐈',
      createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    TwinsMessage(
      id: 'm2',
      spaceId: spaceId,
      authorId: twinId,
      body: 'same... look at that little face 🥺💜',
      createdAt: DateTime.now().subtract(const Duration(minutes: 39)),
    ),
    TwinsMessage(
      id: 'm3',
      spaceId: spaceId,
      authorId: meId,
      body: 'hahaha twins brain ✨',
      createdAt: DateTime.now().subtract(const Duration(minutes: 38)),
    ),
    TwinsMessage(
      id: 'm4',
      spaceId: spaceId,
      authorId: twinId,
      body: 'already added to Funny Reels 🙂',
      attachedItemId: 'item-2',
      createdAt: DateTime.now().subtract(const Duration(minutes: 37)),
    ),
  ];

  static final reactions = <TwinsReaction>[
    TwinsReaction(
      id: 'r1',
      spaceId: spaceId,
      userId: twinId,
      targetType: ReactionTargetType.message,
      targetId: 'm1',
      emoji: '❤️',
      createdAt: DateTime.now(),
    ),
    TwinsReaction(
      id: 'r2',
      spaceId: spaceId,
      userId: meId,
      targetType: ReactionTargetType.message,
      targetId: 'm4',
      emoji: '❤️',
      createdAt: DateTime.now(),
    ),
  ];
}
