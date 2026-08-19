import 'dart:async';
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/chat.dart';
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
import 'supabase_client_provider.dart';

/// Real backend implementation. Every method maps 1:1 onto the schema in
/// supabase/migrations. RLS on the server is the actual security boundary -
/// this class does not attempt to re-implement authorization client-side.
class SupabaseTwinsRepository implements TwinsRepository {
  final _authController = StreamController<Profile?>.broadcast();
  Profile? _cachedProfile;

  SupabaseTwinsRepository() {
    supa.auth.onAuthStateChange.listen((event) async {
      final user = event.session?.user;
      if (user == null) {
        _cachedProfile = null;
        _authController.add(null);
        return;
      }
      final profile = await _fetchOrCreateProfile(user.id);
      _cachedProfile = profile;
      _authController.add(profile);
    });
  }

  Future<Profile> _fetchOrCreateProfile(String userId) async {
    final row = await supa.from('profiles').select().eq('id', userId).maybeSingle();
    if (row != null) return Profile.fromJson(row);
    final email = supa.auth.currentUser?.email ?? 'twin';
    final inserted = await supa
        .from('profiles')
        .insert({'id': userId, 'display_name': email.split('@').first, 'username': email.split('@').first})
        .select()
        .single();
    return Profile.fromJson(inserted);
  }

  @override
  Stream<Profile?> authState() async* {
    // Emit the current session state immediately so the router's redirect
    // resolves on the first frame instead of hanging on the splash: the
    // broadcast controller above only replays events that fire AFTER a
    // listener subscribes, and onAuthStateChange's initial event can be missed.
    final user = supa.auth.currentUser;
    if (user == null) {
      yield null;
    } else {
      try {
        yield _cachedProfile ??= await _fetchOrCreateProfile(user.id);
      } catch (_) {
        yield null;
      }
    }
    yield* _authController.stream;
  }

  @override
  Profile? get currentProfile => _cachedProfile;

  @override
  Future<Profile> signUp({required String email, required String password, required String displayName}) async {
    final res = await supa.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) throw Exception('Sign up failed');
    final inserted = await supa
        .from('profiles')
        .upsert({'id': user.id, 'display_name': displayName, 'username': email.split('@').first})
        .select()
        .single();
    final profile = Profile.fromJson(inserted);
    _cachedProfile = profile;
    return profile;
  }

  @override
  Future<Profile> logIn({required String email, required String password}) async {
    final res = await supa.auth.signInWithPassword(email: email, password: password);
    final user = res.user;
    if (user == null) throw Exception('Login failed');
    final profile = await _fetchOrCreateProfile(user.id);
    _cachedProfile = profile;
    return profile;
  }

  @override
  Future<void> logOut() => supa.auth.signOut();

  @override
  Future<void> resetPassword(String email) => supa.auth.resetPasswordForEmail(email);

  @override
  Future<Profile> updateProfile({String? displayName, String? username, String? bio, String? avatarUrl}) async {
    final userId = supa.auth.currentUser!.id;
    final payload = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_path': avatarUrl,
    };
    if (payload.isEmpty) return _cachedProfile!;
    final row = await supa.from('profiles').update(payload).eq('id', userId).select().single();
    final profile = Profile.fromJson(row);
    _cachedProfile = profile;
    return profile;
  }

  // ---- Space ----
  @override
  Future<TwinsSpace?> currentSpace() async {
    final userId = supa.auth.currentUser?.id;
    if (userId == null) return null;
    final membership = await supa.from('space_members').select('space_id').eq('user_id', userId).maybeSingle();
    if (membership == null) return null;
    final spaceId = membership['space_id'] as String;
    final row = await supa.from('spaces').select().eq('id', spaceId).single();
    return TwinsSpace.fromJson(row);
  }

  @override
  Future<List<Profile>> spaceMembers(String spaceId) async {
    final rows = await supa
        .from('space_members')
        .select('profiles(*)')
        .eq('space_id', spaceId) as List;
    return rows.map((r) => Profile.fromJson((r as Map)['profiles'] as Map<String, dynamic>)).toList();
  }

  /// Starter tag catalog every new space begins with, so AI auto-tagging has
  /// something to reuse from day one. The pair edits this under Manage tags.
  static const defaultTagNames = [
    'funny', 'aesthetic', 'food', 'recipes', 'travel', 'music',
    'workout', 'cozy', 'outfits', 'memes', 'art', 'study',
  ];

  @override
  Future<TwinsSpace> createSpace(String name) async {
    final userId = supa.auth.currentUser!.id;
    final row = await supa.from('spaces').insert({'name': name, 'created_by': userId}).select().single();
    await supa.from('space_members').insert({'space_id': row['id'], 'user_id': userId, 'role': 'owner'});
    // Seed the starter tag catalog (best-effort; pairing still works if it fails).
    try {
      await supa.from('tags').insert([
        for (var i = 0; i < defaultTagNames.length; i++)
          {
            'space_id': row['id'],
            'name': defaultTagNames[i],
            'color': '0x${_tagPalette[i % _tagPalette.length].toRadixString(16).padLeft(8, '0').toUpperCase()}',
          },
      ]);
    } catch (_) {}
    return TwinsSpace.fromJson(row);
  }

  @override
  Future<SpaceInvite> createInvite(String spaceId) async {
    final userId = supa.auth.currentUser!.id;
    final row = await supa
        .from('space_invites')
        .insert({
          'space_id': spaceId,
          'created_by': userId,
          'code': null, // generated server-side by default expression
          'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        })
        .select()
        .single();
    return SpaceInvite.fromJson(row);
  }

  @override
  Future<TwinsSpace> joinSpaceWithCode(String code) async {
    // Calls the secure `join_space_with_code` RPC (see migrations) which
    // validates the invite, enforces the two-member cap, and inserts the
    // membership row atomically server-side.
    final spaceId = await supa.rpc('join_space_with_code', params: {'invite_code': code}) as String;
    final row = await supa.from('spaces').select().eq('id', spaceId).single();
    return TwinsSpace.fromJson(row);
  }

  @override
  Future<void> leaveSpace(String spaceId) async {
    final userId = supa.auth.currentUser!.id;
    await supa.from('space_members').delete().eq('space_id', spaceId).eq('user_id', userId);
  }

  // ---- Folders ----
  @override
  Future<TwinsFolder?> getFolder(String folderId) async {
    final row = await supa.from('folders').select().eq('id', folderId).maybeSingle();
    return row == null ? null : TwinsFolder.fromJson(row);
  }

  @override
  Stream<List<TwinsFolder>> watchFolders(String spaceId, {String? parentId}) {
    final stream = supa.from('folders').stream(primaryKey: ['id']).eq('space_id', spaceId);
    return stream.map((rows) => rows
        .where((r) => r['parent_id'] == parentId)
        .map(TwinsFolder.fromJson)
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.position.compareTo(b.position);
      }));
  }

  @override
  Future<TwinsFolder> createFolder({
    required String spaceId,
    String? parentId,
    required String name,
    required int colorValue,
    required String icon,
  }) async {
    final row = await supa
        .from('folders')
        .insert({
          'space_id': spaceId,
          'parent_id': parentId,
          'name': name,
          'color': '0x${colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
          'icon': icon,
          'created_by': supa.auth.currentUser!.id,
        })
        .select()
        .single();
    return TwinsFolder.fromJson(row);
  }

  @override
  Future<TwinsFolder> updateFolder(TwinsFolder folder) async {
    final row = await supa.from('folders').update(folder.toJson()).eq('id', folder.id).select().single();
    return TwinsFolder.fromJson(row);
  }

  @override
  Future<void> deleteFolder(String folderId) => supa.from('folders').delete().eq('id', folderId);

  // ---- Items ----
  @override
  Stream<List<TwinsItem>> watchItems(String spaceId, {String? folderId, ItemType? type}) {
    final stream = supa.from('items').stream(primaryKey: ['id']).eq('space_id', spaceId);
    return stream.map((rows) {
      var list = rows.where((r) => r['folder_id'] == folderId);
      if (type != null) list = list.where((r) => r['type'] == type.name);
      return list.map(TwinsItem.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Stream<List<TwinsItem>> watchAllItems(String spaceId) {
    final stream = supa.from('items').stream(primaryKey: ['id']).eq('space_id', spaceId);
    return stream.map((rows) => rows.map(TwinsItem.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Stream<List<TwinsItem>> watchRecentItems(String spaceId, {int limit = 10}) {
    final stream = supa.from('items').stream(primaryKey: ['id']).eq('space_id', spaceId);
    return stream.map((rows) {
      final list = rows.map(TwinsItem.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    });
  }

  @override
  Future<TwinsItem?> getItem(String itemId) async {
    final row = await supa.from('items').select().eq('id', itemId).maybeSingle();
    return row == null ? null : TwinsItem.fromJson(row);
  }

  @override
  Future<TwinsItem> createItem(TwinsItem draft) async {
    final payload = draft.toJson()..['created_by'] = supa.auth.currentUser!.id;
    final row = await supa.from('items').insert(payload).select().single();
    return TwinsItem.fromJson(row);
  }

  @override
  Future<TwinsItem> updateItem(TwinsItem item) async {
    final row = await supa.from('items').update(item.toJson()).eq('id', item.id).select().single();
    return TwinsItem.fromJson(row);
  }

  @override
  Future<void> deleteItem(String itemId) => supa.from('items').delete().eq('id', itemId);

  @override
  Future<List<TwinsItem>> searchItems(
    String spaceId,
    String query, {
    ItemType? type,
    int limit = 60,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Ranked search lives in the search_items() RPC (migration 0009) so the
    // weighted tsvector and trigram indexes actually get used - the previous
    // multi-column `ilike` could not hit an index and ranked nothing.
    final rows = await supa.rpc('search_items', params: {
      'p_space_id': spaceId,
      'p_query': trimmed,
      'p_type': type?.name,
      'p_limit': limit,
    });
    return (rows as List).map((r) => TwinsItem.fromJson(r as Map<String, dynamic>)).toList();
  }

  // ---- Search history ----
  @override
  Future<List<String>> recentSearches(String spaceId, {int limit = 8}) async {
    final userId = supa.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await supa
        .from('search_history')
        .select('query')
        .eq('space_id', spaceId)
        .eq('user_id', userId)
        .order('searched_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => (r as Map<String, dynamic>)['query'] as String).toList();
  }

  @override
  Future<void> recordSearch(String spaceId, String query) async {
    if (query.trim().isEmpty) return;
    await supa.rpc('record_search', params: {'p_space_id': spaceId, 'p_query': query.trim()});
  }

  @override
  Future<void> clearSearchHistory(String spaceId) async {
    final userId = supa.auth.currentUser?.id;
    if (userId == null) return;
    await supa.from('search_history').delete().eq('space_id', spaceId).eq('user_id', userId);
  }

  // ---- Tags ----
  @override
  Stream<List<TwinsTag>> watchTags(String spaceId) {
    return supa.from('tags').stream(primaryKey: ['id']).eq('space_id', spaceId).map(
        (rows) => rows.map(TwinsTag.fromJson).toList());
  }

  @override
  Future<TwinsTag> createTag(String spaceId, String name, int colorValue) async {
    final row = await supa
        .from('tags')
        .insert({
          'space_id': spaceId,
          'name': name,
          'color': '0x${colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        })
        .select()
        .single();
    return TwinsTag.fromJson(row);
  }

  @override
  Future<void> deleteTag(String tagId) => supa.from('tags').delete().eq('id', tagId);

  static const _tagPalette = [
    0xFF7EE7E1, 0xFFF6A5C0, 0xFFFFCC80, 0xFF90CAF9, 0xFFB39DDB, 0xFF80CBC4,
  ];

  @override
  Future<List<TwinsTag>> ensureTags(String spaceId, List<String> names) async {
    final clean = <String>{
      for (final n in names)
        if (n.trim().isNotEmpty) n.trim().toLowerCase(),
    }.toList();
    if (clean.isEmpty) return const [];

    final existing = (await supa.from('tags').select().eq('space_id', spaceId) as List)
        .map((r) => TwinsTag.fromJson(r as Map<String, dynamic>))
        .toList();
    final byName = {for (final t in existing) t.name.toLowerCase(): t};

    final toCreate = clean.where((n) => !byName.containsKey(n)).toList();
    if (toCreate.isNotEmpty) {
      final rows = await supa
          .from('tags')
          .insert([
            for (var i = 0; i < toCreate.length; i++)
              {
                'space_id': spaceId,
                'name': toCreate[i],
                'color': '0x${_tagPalette[(byName.length + i) % _tagPalette.length].toRadixString(16).padLeft(8, '0').toUpperCase()}',
              },
          ])
          .select() as List;
      for (final r in rows) {
        final t = TwinsTag.fromJson(r as Map<String, dynamic>);
        byName[t.name.toLowerCase()] = t;
      }
    }
    return [for (final n in clean) if (byName[n] != null) byName[n]!];
  }

  @override
  Stream<List<TwinsTag>> watchItemTags(String itemId) {
    // item_tags has no updated_at to stream cheaply, so key on the join rows
    // and resolve tag details per emission.
    return supa.from('item_tags').stream(primaryKey: ['item_id', 'tag_id']).eq('item_id', itemId).asyncMap((rows) async {
      final ids = rows.map((r) => r['tag_id'] as String).toList();
      if (ids.isEmpty) return <TwinsTag>[];
      final tagRows = await supa.from('tags').select().inFilter('id', ids) as List;
      return tagRows.map((r) => TwinsTag.fromJson(r as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  @override
  Future<void> setItemTags({
    required String spaceId,
    required String itemId,
    required List<String> tagNames,
  }) async {
    final tags = await ensureTags(spaceId, tagNames);
    await supa.from('item_tags').delete().eq('item_id', itemId);
    if (tags.isNotEmpty) {
      await supa.from('item_tags').insert([
        for (final t in tags) {'item_id': itemId, 'tag_id': t.id},
      ]);
    }
  }

  // ---- Comments ----
  @override
  Stream<List<TwinsComment>> watchComments(String itemId) {
    return supa.from('item_comments').stream(primaryKey: ['id']).eq('item_id', itemId).map(
        (rows) => rows.map(TwinsComment.fromJson).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  @override
  Future<TwinsComment> addComment({
    required String itemId,
    required String body,
    String? parentId,
    int? mediaTimestampMs,
  }) async {
    final item = await getItem(itemId);
    final row = await supa
        .from('item_comments')
        .insert({
          'space_id': item?.spaceId,
          'item_id': itemId,
          'author_id': supa.auth.currentUser!.id,
          'parent_id': parentId,
          'body': body,
          'media_timestamp_ms': mediaTimestampMs,
        })
        .select()
        .single();
    return TwinsComment.fromJson(row);
  }

  // ---- Chats ----
  @override
  Stream<List<TwinsChat>> watchChats(String spaceId) {
    return supa.from('chats').stream(primaryKey: ['id']).eq('space_id', spaceId).map(
        (rows) => rows.map(TwinsChat.fromJson).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
  }

  @override
  Future<TwinsChat> createChat({required String spaceId, String? name}) async {
    final row = await supa
        .from('chats')
        .insert({
          'space_id': spaceId,
          'name': name,
          'created_by': supa.auth.currentUser!.id,
        })
        .select()
        .single();
    return TwinsChat.fromJson(row);
  }

  @override
  Future<TwinsChat> renameChat(String chatId, String name) async {
    final row = await supa.from('chats').update({'name': name}).eq('id', chatId).select().single();
    return TwinsChat.fromJson(row);
  }

  @override
  Future<void> deleteChat(String chatId) => supa.from('chats').delete().eq('id', chatId);

  // ---- Messages ----
  @override
  Stream<List<TwinsMessage>> watchMessages(String chatId) {
    return supa.from('messages').stream(primaryKey: ['id']).eq('chat_id', chatId).map(
        (rows) => rows.map(TwinsMessage.fromJson).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  @override
  Future<TwinsMessage> sendMessage({
    required String spaceId,
    required String chatId,
    required String body,
    String? attachedItemId,
  }) async {
    final row = await supa
        .from('messages')
        .insert({
          'space_id': spaceId,
          'chat_id': chatId,
          'author_id': supa.auth.currentUser!.id,
          'body': body,
          'attached_item_id': attachedItemId,
        })
        .select()
        .single();
    // Bump the chat's updated_at so the chat list resorts by recency.
    await supa.from('chats').update({'updated_at': DateTime.now().toIso8601String()}).eq('id', chatId);
    return TwinsMessage.fromJson(row);
  }

  @override
  Stream<List<TwinsMessage>> watchRecentMessages(String spaceId, {int limit = 15}) {
    return supa.from('messages').stream(primaryKey: ['id']).eq('space_id', spaceId).map((rows) {
      final sorted = rows.map(TwinsMessage.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted.take(limit).toList();
    });
  }

  // ---- Reactions ----
  @override
  Stream<List<TwinsReaction>> watchReactions(String spaceId, ReactionTargetType type, String targetId) {
    return supa
        .from('reactions')
        .stream(primaryKey: ['id'])
        .eq('target_id', targetId)
        .map((rows) => rows.where((r) => r['target_type'] == type.name).map(TwinsReaction.fromJson).toList());
  }

  @override
  Future<void> toggleReaction({
    required String spaceId,
    required ReactionTargetType targetType,
    required String targetId,
    required String emoji,
  }) async {
    final userId = supa.auth.currentUser!.id;
    final existing = await supa
        .from('reactions')
        .select('id')
        .eq('user_id', userId)
        .eq('target_type', targetType.name)
        .eq('target_id', targetId)
        .eq('emoji', emoji)
        .maybeSingle();
    if (existing != null) {
      await supa.from('reactions').delete().eq('id', existing['id']);
    } else {
      await supa.from('reactions').insert({
        'space_id': spaceId,
        'user_id': userId,
        'target_type': targetType.name,
        'target_id': targetId,
        'emoji': emoji,
      });
    }
  }

  // ---- Settings ----
  @override
  Future<TwinsUserSettings> getSettings(String userId) async {
    final row = await supa.from('user_settings').select().eq('user_id', userId).maybeSingle();
    return row == null ? TwinsUserSettings(userId: userId) : TwinsUserSettings.fromJson(row);
  }

  @override
  Future<TwinsUserSettings> updateSettings(TwinsUserSettings settings) async {
    final row = await supa
        .from('user_settings')
        .upsert({
          'user_id': settings.userId,
          'theme': settings.theme.name,
          'default_folder_id': settings.defaultFolderId,
          'default_sort': settings.defaultSort,
          'media_quality': settings.mediaQuality,
          'notifications_enabled': settings.notificationsEnabled,
        })
        .select()
        .single();
    return TwinsUserSettings.fromJson(row);
  }

  // ---- Export ----
  @override
  Future<Map<String, dynamic>> exportSpace(String spaceId) async {
    final folders = await supa.from('folders').select().eq('space_id', spaceId);
    final items = await supa.from('items').select().eq('space_id', spaceId);
    final comments = await supa.from('item_comments').select().eq('space_id', spaceId);
    final messages = await supa.from('messages').select().eq('space_id', spaceId);
    return {
      'space_id': spaceId,
      'folders': folders,
      'items': items,
      'comments': comments,
      'messages': messages,
    };
  }

  // ---- Storage ----
  static const _signedUrlTtlSeconds = 60 * 60 * 24 * 365; // 1 year

  @override
  Future<UploadResult> uploadFile({
    required String spaceId,
    required String localPath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await File(localPath).readAsBytes();
    final ext = fileName.contains('.') ? fileName.substring(fileName.lastIndexOf('.')) : '';
    // Object name is relative to the `spaces` bucket. The first path segment
    // must be the space id: the storage RLS policy (migration 0006) checks
    // `is_space_member((storage.foldername(name))[1]::uuid)`, so a leading
    // literal like `spaces/` here would fail the ::uuid cast and block uploads.
    final path = '$spaceId/items/${const Uuid().v4()}$ext';
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

    onProgress?.call(0);
    await supa.storage.from('spaces').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    onProgress?.call(1);

    final url = await supa.storage.from('spaces').createSignedUrl(path, _signedUrlTtlSeconds);
    return UploadResult(storagePath: path, url: url);
  }

  @override
  Future<String> uploadAvatar({required String userId, required String localPath}) async {
    final bytes = await File(localPath).readAsBytes();
    final fileName = localPath.split(Platform.pathSeparator).last;
    final ext = fileName.contains('.') ? fileName.substring(fileName.lastIndexOf('.')) : '.jpg';
    final path = '$userId/${const Uuid().v4()}$ext';
    final mimeType = lookupMimeType(fileName) ?? 'image/jpeg';

    await supa.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    // The avatars bucket is public (see migration 0006), so a stable public
    // URL works directly - no signing/expiry to manage.
    return supa.storage.from('avatars').getPublicUrl(path);
  }
}
