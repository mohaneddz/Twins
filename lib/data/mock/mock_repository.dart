import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/comment.dart';
import '../models/folder.dart';
import '../models/item.dart';
import '../models/item_type.dart';
import '../models/message.dart';
import '../models/profile.dart';
import '../models/reaction.dart';
import '../models/space.dart';
import '../models/tag.dart';
import '../models/upload_result.dart';
import '../models/user_settings.dart';
import '../repositories/twins_repository.dart';
import 'mock_seed.dart';

/// In-memory repository that reproduces the shape of the real Supabase
/// backend so every screen is fully explorable without credentials.
/// Streams are broadcast so multiple widgets can subscribe.
class MockTwinsRepository implements TwinsRepository {
  MockTwinsRepository() {
    _folders = List.of(MockSeed.folders);
    _items = List.of(MockSeed.items);
    _tags = List.of(MockSeed.tags);
    _comments = List.of(MockSeed.comments);
    _messages = List.of(MockSeed.messages);
    _reactions = List.of(MockSeed.reactions);
  }

  final _uuid = const Uuid();
  Profile? _authed = MockSeed.me;

  late List<TwinsFolder> _folders;
  late List<TwinsItem> _items;
  late List<TwinsTag> _tags;
  late List<TwinsComment> _comments;
  late List<TwinsMessage> _messages;
  late List<TwinsReaction> _reactions;

  final _authController = StreamController<Profile?>.broadcast();
  final _foldersController = StreamController<void>.broadcast();
  final _itemsController = StreamController<void>.broadcast();
  final _commentsController = StreamController<void>.broadcast();
  final _messagesController = StreamController<void>.broadcast();
  final _reactionsController = StreamController<void>.broadcast();
  final _tagsController = StreamController<void>.broadcast();

  final Map<String, TwinsUserSettings> _settings = {};

  // ---- Auth ----
  @override
  Stream<Profile?> authState() async* {
    yield _authed;
    yield* _authController.stream;
  }

  @override
  Profile? get currentProfile => _authed;

  @override
  Future<Profile> signUp({required String email, required String password, required String displayName}) async {
    await _delay();
    _authed = MockSeed.me.copyWith(displayName: displayName);
    _authController.add(_authed);
    return _authed!;
  }

  @override
  Future<Profile> logIn({required String email, required String password}) async {
    await _delay();
    _authed = MockSeed.me;
    _authController.add(_authed);
    return _authed!;
  }

  @override
  Future<void> logOut() async {
    await _delay();
    _authed = null;
    _authController.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {
    await _delay();
  }

  @override
  Future<Profile> updateProfile({String? displayName, String? username, String? bio, String? avatarUrl}) async {
    await _delay();
    final updated = (_authed ?? MockSeed.me).copyWith(displayName: displayName, username: username, bio: bio, avatarUrl: avatarUrl);
    _authed = updated;
    _authController.add(updated);
    return updated;
  }

  // ---- Space ----
  @override
  Future<TwinsSpace?> currentSpace() async {
    await _delay();
    return MockSeed.space;
  }

  @override
  Future<List<Profile>> spaceMembers(String spaceId) async {
    await _delay();
    return [MockSeed.me, MockSeed.twin];
  }

  @override
  Future<TwinsSpace> createSpace(String name) async {
    await _delay();
    return TwinsSpace(id: _uuid.v4(), name: name, createdBy: MockSeed.meId, createdAt: DateTime.now());
  }

  @override
  Future<SpaceInvite> createInvite(String spaceId) async {
    await _delay();
    final code = _randomCode();
    return SpaceInvite(
      id: _uuid.v4(),
      spaceId: spaceId,
      code: code,
      createdBy: MockSeed.meId,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  @override
  Future<TwinsSpace> joinSpaceWithCode(String code) async {
    await _delay();
    return MockSeed.space;
  }

  @override
  Future<void> leaveSpace(String spaceId) async {
    // Single-device mock mode has only one hardcoded seeded space, so there's
    // nothing meaningful to leave - this is a no-op here and only does
    // something real against Supabase.
    await _delay();
  }

  // ---- Folders ----
  @override
  Future<TwinsFolder?> getFolder(String folderId) async {
    await _delay(ms: 80);
    return _folders.firstWhereOrNull((f) => f.id == folderId);
  }

  @override
  Stream<List<TwinsFolder>> watchFolders(String spaceId, {String? parentId}) async* {
    yield _visibleFolders(parentId);
    await for (final _ in _foldersController.stream) {
      yield _visibleFolders(parentId);
    }
  }

  List<TwinsFolder> _visibleFolders(String? parentId) => _folders
      .where((f) => f.parentId == parentId)
      // Compute item counts live from _items so they stay correct as items are
      // added, deleted, or moved between folders (matches the DB trigger in
      // migration 0008).
      .map((f) => f.copyWith(itemCount: _items.where((i) => i.folderId == f.id).length))
      .toList()
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return a.position.compareTo(b.position);
    });

  @override
  Future<TwinsFolder> createFolder({
    required String spaceId,
    String? parentId,
    required String name,
    required int colorValue,
    required String icon,
  }) async {
    await _delay();
    final folder = TwinsFolder(
      id: _uuid.v4(),
      spaceId: spaceId,
      parentId: parentId,
      name: name,
      color: Color(colorValue),
      icon: icon,
      createdBy: _authed?.id ?? MockSeed.meId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _folders.add(folder);
    _foldersController.add(null);
    return folder;
  }

  @override
  Future<TwinsFolder> updateFolder(TwinsFolder folder) async {
    await _delay();
    final index = _folders.indexWhere((f) => f.id == folder.id);
    if (index != -1) _folders[index] = folder;
    _foldersController.add(null);
    return folder;
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    await _delay();
    _folders.removeWhere((f) => f.id == folderId || f.parentId == folderId);
    _items.removeWhere((i) => i.folderId == folderId);
    _foldersController.add(null);
    _itemsController.add(null);
  }

  // ---- Items ----
  @override
  Stream<List<TwinsItem>> watchItems(String spaceId, {String? folderId, ItemType? type}) async* {
    yield _visibleItems(folderId, type);
    await for (final _ in _itemsController.stream) {
      yield _visibleItems(folderId, type);
    }
  }

  List<TwinsItem> _visibleItems(String? folderId, ItemType? type) {
    var list = _items.where((i) => i.folderId == folderId);
    if (type != null) list = list.where((i) => i.type == type);
    return list.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Stream<List<TwinsItem>> watchAllItems(String spaceId) async* {
    List<TwinsItem> all() => List.of(_items)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield all();
    await for (final _ in _itemsController.stream) {
      yield all();
    }
  }

  @override
  Stream<List<TwinsItem>> watchRecentItems(String spaceId, {int limit = 10}) async* {
    List<TwinsItem> recent() {
      final list = List.of(_items)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    }

    yield recent();
    await for (final _ in _itemsController.stream) {
      yield recent();
    }
  }

  @override
  Future<TwinsItem?> getItem(String itemId) async {
    await _delay();
    try {
      return _items.firstWhere((i) => i.id == itemId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TwinsItem> createItem(TwinsItem draft) async {
    await _delay();
    final item = TwinsItem(
      id: _uuid.v4(),
      spaceId: draft.spaceId,
      folderId: draft.folderId,
      createdBy: _authed?.id ?? MockSeed.meId,
      type: draft.type,
      platform: draft.platform,
      sourceUrl: draft.sourceUrl,
      storagePath: draft.storagePath,
      thumbnailUrl: draft.thumbnailUrl,
      title: draft.title,
      description: draft.description,
      content: draft.content,
      metadata: draft.metadata,
      durationMs: draft.durationMs,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tagIds: draft.tagIds,
    );
    _items.add(item);
    _itemsController.add(null);
    // Folder cards derive their count from _items, so just nudge that stream.
    _foldersController.add(null);
    return item;
  }

  @override
  Future<TwinsItem> updateItem(TwinsItem item) async {
    await _delay();
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) _items[index] = item;
    _itemsController.add(null);
    _foldersController.add(null); // folder_id may have changed (move)
    return item;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _delay();
    _items.removeWhere((i) => i.id == itemId);
    _itemsController.add(null);
    _foldersController.add(null);
  }

  @override
  Future<List<TwinsItem>> searchItems(
    String spaceId,
    String query, {
    ItemType? type,
    int limit = 60,
  }) async {
    await _delay(ms: 150);
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    // Mirrors the field weighting in search_items() (migration 0009) so mock
    // mode ranks results the same way the real backend does.
    final scored = <({TwinsItem item, int score})>[];
    for (final i in _items) {
      if (i.spaceId != spaceId) continue;
      if (type != null && i.type != type) continue;

      final folderName = _folders.firstWhereOrNull((f) => f.id == i.folderId)?.name.toLowerCase() ?? '';
      final tagNames = i.tagIds
          .map((id) => _tags.firstWhereOrNull((t) => t.id == id)?.name.toLowerCase() ?? '')
          .join(' ');

      final title = i.title.toLowerCase();
      var score = 0;
      if (title == q) {
        score = 100;
      } else if (title.startsWith(q)) {
        score = 80;
      } else if (title.contains(q)) {
        score = 60;
      }
      if (score == 0 && (i.description?.toLowerCase().contains(q) ?? false)) score = 40;
      if (score == 0 && (i.content?.toLowerCase().contains(q) ?? false)) score = 30;
      if (score == 0 && tagNames.contains(q)) score = 25;
      if (score == 0 && folderName.contains(q)) score = 20;
      if (score == 0 && (i.sourceUrl?.toLowerCase().contains(q) ?? false)) score = 10;

      if (score > 0) scored.add((item: i, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : b.item.createdAt.compareTo(a.item.createdAt);
    });
    return scored.take(limit).map((e) => e.item).toList();
  }

  // ---- Search history ----
  final _searchHistory = <String, List<String>>{};

  @override
  Future<List<String>> recentSearches(String spaceId, {int limit = 8}) async {
    await _delay(ms: 60);
    return (_searchHistory[spaceId] ?? const <String>[]).take(limit).toList();
  }

  @override
  Future<void> recordSearch(String spaceId, String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = _searchHistory.putIfAbsent(spaceId, () => <String>[]);
    // One entry per distinct query, most recent first.
    list.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    list.insert(0, q);
    if (list.length > 20) list.removeRange(20, list.length);
  }

  @override
  Future<void> clearSearchHistory(String spaceId) async {
    _searchHistory.remove(spaceId);
  }

  // ---- Tags ----
  static const _tagPalette = [
    0xFF7EE7E1, 0xFFF6A5C0, 0xFFFFCC80, 0xFF90CAF9, 0xFFB39DDB, 0xFF80CBC4,
  ];

  @override
  Stream<List<TwinsTag>> watchTags(String spaceId) async* {
    yield List.of(_tags);
    await for (final _ in _tagsController.stream) {
      yield List.of(_tags);
    }
  }

  @override
  Future<TwinsTag> createTag(String spaceId, String name, int colorValue) async {
    await _delay();
    final tag = TwinsTag(id: _uuid.v4(), spaceId: spaceId, name: name.trim().toLowerCase(), color: Color(colorValue));
    _tags.add(tag);
    _tagsController.add(null);
    return tag;
  }

  @override
  Future<void> deleteTag(String tagId) async {
    await _delay();
    _tags.removeWhere((t) => t.id == tagId);
    // Detach from any items.
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].tagIds.contains(tagId)) {
        _items[i] = _items[i].copyWith(tagIds: _items[i].tagIds.where((id) => id != tagId).toList());
      }
    }
    _tagsController.add(null);
    _itemsController.add(null);
  }

  @override
  Future<List<TwinsTag>> ensureTags(String spaceId, List<String> names) async {
    final clean = <String>{
      for (final n in names)
        if (n.trim().isNotEmpty) n.trim().toLowerCase(),
    }.toList();
    final result = <TwinsTag>[];
    var created = false;
    for (final n in clean) {
      var tag = _tags.firstWhereOrNull((t) => t.name.toLowerCase() == n);
      if (tag == null) {
        tag = TwinsTag(id: _uuid.v4(), spaceId: spaceId, name: n, color: Color(_tagPalette[_tags.length % _tagPalette.length]));
        _tags.add(tag);
        created = true;
      }
      result.add(tag);
    }
    if (created) _tagsController.add(null);
    return result;
  }

  @override
  Stream<List<TwinsTag>> watchItemTags(String itemId) async* {
    List<TwinsTag> forItem() {
      final item = _items.firstWhereOrNull((i) => i.id == itemId);
      if (item == null) return const [];
      return [
        for (final id in item.tagIds)
          if (_tags.firstWhereOrNull((t) => t.id == id) != null) _tags.firstWhere((t) => t.id == id),
      ]..sort((a, b) => a.name.compareTo(b.name));
    }

    yield forItem();
    await for (final _ in _itemsController.stream) {
      yield forItem();
    }
  }

  @override
  Future<void> setItemTags({
    required String spaceId,
    required String itemId,
    required List<String> tagNames,
  }) async {
    final tags = await ensureTags(spaceId, tagNames);
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(tagIds: tags.map((t) => t.id).toList());
      _itemsController.add(null);
    }
  }

  // ---- Comments ----
  @override
  Stream<List<TwinsComment>> watchComments(String itemId) async* {
    List<TwinsComment> forItem() =>
        _comments.where((c) => c.itemId == itemId).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    yield forItem();
    await for (final _ in _commentsController.stream) {
      yield forItem();
    }
  }

  @override
  Future<TwinsComment> addComment({
    required String itemId,
    required String body,
    String? parentId,
    int? mediaTimestampMs,
  }) async {
    await _delay(ms: 150);
    final item = await getItem(itemId);
    final comment = TwinsComment(
      id: _uuid.v4(),
      spaceId: item?.spaceId ?? MockSeed.spaceId,
      itemId: itemId,
      authorId: _authed?.id ?? MockSeed.meId,
      parentId: parentId,
      body: body,
      mediaTimestampMs: mediaTimestampMs,
      createdAt: DateTime.now(),
    );
    _comments.add(comment);
    _commentsController.add(null);
    _bumpItemCommentCount(itemId, 1);
    return comment;
  }

  // ---- Messages ----
  @override
  Stream<List<TwinsMessage>> watchMessages(String spaceId) async* {
    List<TwinsMessage> forSpace() =>
        _messages.where((m) => m.spaceId == spaceId).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    yield forSpace();
    await for (final _ in _messagesController.stream) {
      yield forSpace();
    }
  }

  @override
  Future<TwinsMessage> sendMessage({required String spaceId, required String body, String? attachedItemId}) async {
    await _delay(ms: 120);
    final message = TwinsMessage(
      id: _uuid.v4(),
      spaceId: spaceId,
      authorId: _authed?.id ?? MockSeed.meId,
      body: body,
      attachedItemId: attachedItemId,
      createdAt: DateTime.now(),
    );
    _messages.add(message);
    _messagesController.add(null);
    return message;
  }

  // ---- Reactions ----
  @override
  Stream<List<TwinsReaction>> watchReactions(String spaceId, ReactionTargetType type, String targetId) async* {
    List<TwinsReaction> forTarget() =>
        _reactions.where((r) => r.targetType == type && r.targetId == targetId).toList();

    yield forTarget();
    await for (final _ in _reactionsController.stream) {
      yield forTarget();
    }
  }

  @override
  Future<void> toggleReaction({
    required String spaceId,
    required ReactionTargetType targetType,
    required String targetId,
    required String emoji,
  }) async {
    await _delay(ms: 80);
    final userId = _authed?.id ?? MockSeed.meId;
    final existingIndex = _reactions.indexWhere(
      (r) => r.targetType == targetType && r.targetId == targetId && r.userId == userId && r.emoji == emoji,
    );
    if (existingIndex != -1) {
      _reactions.removeAt(existingIndex);
      if (targetType == ReactionTargetType.item) _bumpItemReactionCount(targetId, -1);
    } else {
      _reactions.add(TwinsReaction(
        id: _uuid.v4(),
        spaceId: spaceId,
        userId: userId,
        targetType: targetType,
        targetId: targetId,
        emoji: emoji,
        createdAt: DateTime.now(),
      ));
      if (targetType == ReactionTargetType.item) _bumpItemReactionCount(targetId, 1);
    }
    _reactionsController.add(null);
  }

  void _bumpItemReactionCount(String itemId, int delta) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final item = _items[index];
    _items[index] = item.copyWith(reactionCount: (item.reactionCount + delta).clamp(0, 1 << 30));
    _itemsController.add(null);
  }

  void _bumpItemCommentCount(String itemId, int delta) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final item = _items[index];
    _items[index] = item.copyWith(commentCount: (item.commentCount + delta).clamp(0, 1 << 30));
    _itemsController.add(null);
  }

  // ---- Settings ----
  @override
  Future<TwinsUserSettings> getSettings(String userId) async {
    await _delay(ms: 80);
    return _settings[userId] ?? TwinsUserSettings(userId: userId);
  }

  @override
  Future<TwinsUserSettings> updateSettings(TwinsUserSettings settings) async {
    await _delay(ms: 80);
    _settings[settings.userId] = settings;
    return settings;
  }

  // ---- Export ----
  @override
  Future<Map<String, dynamic>> exportSpace(String spaceId) async {
    await _delay();
    return {
      'space': {'id': MockSeed.space.id, 'name': MockSeed.space.name},
      // fromJson() (used by import) needs id/created_at/updated_at, which
      // toJson() omits since it's shaped for inserts - so folders/items are
      // rebuilt as full rows here, matching what a real Supabase select()
      // returns in SupabaseTwinsRepository.exportSpace.
      'folders': _folders
          .map((f) => {
                ...f.toJson(),
                'id': f.id,
                'created_by': f.createdBy,
                'created_at': f.createdAt.toIso8601String(),
                'updated_at': f.updatedAt.toIso8601String(),
              })
          .toList(),
      'items': _items
          .map((i) => {
                ...i.toJson(),
                'id': i.id,
                'created_by': i.createdBy,
                'created_at': i.createdAt.toIso8601String(),
                'updated_at': i.updatedAt.toIso8601String(),
              })
          .toList(),
      'comments': _comments.map((c) => c.toJson()).toList(),
      'messages': _messages.map((m) => m.toJson()).toList(),
    };
  }

  // ---- Storage ----
  // Single-device mock mode has no real backend to upload to - the local
  // file path itself is both the "storage path" and the "display url".
  // MediaThumbnail/VideoPlayerView know how to render a local file path
  // directly, so this is visually equivalent to a real upload on one device.
  @override
  Future<UploadResult> uploadFile({
    required String spaceId,
    required String localPath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    await _delay(ms: 400);
    onProgress?.call(1);
    return UploadResult(storagePath: localPath, url: localPath);
  }

  @override
  Future<String> uploadAvatar({required String userId, required String localPath}) async {
    await _delay(ms: 300);
    return localPath;
  }

  Future<void> _delay({int ms = 250}) => Future.delayed(Duration(milliseconds: ms));

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
