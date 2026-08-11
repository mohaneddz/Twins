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

/// Data access abstraction. [MockTwinsRepository] backs the app when no
/// Supabase credentials are configured; [SupabaseTwinsRepository] backs it
/// with the real backend. UI code should only ever depend on this interface.
abstract class TwinsRepository {
  // ---- Auth ----
  Stream<Profile?> authState();
  Profile? get currentProfile;
  Future<Profile> signUp({required String email, required String password, required String displayName});
  Future<Profile> logIn({required String email, required String password});
  Future<void> logOut();
  Future<void> resetPassword(String email);
  Future<Profile> updateProfile({String? displayName, String? username, String? bio, String? avatarUrl});

  // ---- Space / pairing ----
  Future<TwinsSpace?> currentSpace();
  Future<List<Profile>> spaceMembers(String spaceId);
  Future<TwinsSpace> createSpace(String name);
  Future<SpaceInvite> createInvite(String spaceId);
  Future<TwinsSpace> joinSpaceWithCode(String code);
  Future<void> leaveSpace(String spaceId);

  // ---- Folders ----
  Future<TwinsFolder?> getFolder(String folderId);
  Stream<List<TwinsFolder>> watchFolders(String spaceId, {String? parentId});
  Future<TwinsFolder> createFolder({
    required String spaceId,
    String? parentId,
    required String name,
    required int colorValue,
    required String icon,
  });
  Future<TwinsFolder> updateFolder(TwinsFolder folder);
  Future<void> deleteFolder(String folderId);

  // ---- Items ----
  Stream<List<TwinsItem>> watchItems(String spaceId, {String? folderId, ItemType? type});
  /// Every item in the space regardless of which folder (or no folder) it's
  /// in - used for space-wide stats (profile screen) rather than a single
  /// folder's contents.
  Stream<List<TwinsItem>> watchAllItems(String spaceId);
  Stream<List<TwinsItem>> watchRecentItems(String spaceId, {int limit = 10});
  Future<TwinsItem?> getItem(String itemId);
  Future<TwinsItem> createItem(TwinsItem draft);
  Future<TwinsItem> updateItem(TwinsItem item);
  Future<void> deleteItem(String itemId);
  /// Relevance-ranked search across item text, tag names and folder names.
  /// [type] narrows to a single kind of item; null means "all".
  Future<List<TwinsItem>> searchItems(
    String spaceId,
    String query, {
    ItemType? type,
    int limit = 60,
  });

  // ---- Search history ----
  /// Most recent distinct queries this user ran in the space, newest first.
  Future<List<String>> recentSearches(String spaceId, {int limit = 8});

  /// Records [query] as a recent search (no-op for blank queries).
  Future<void> recordSearch(String spaceId, String query);

  /// Clears this user's recent searches for the space.
  Future<void> clearSearchHistory(String spaceId);

  // ---- Tags ----
  /// The space's curated tag catalog (what the AI picks from, and what the
  /// "Manage tags" screen edits).
  Stream<List<TwinsTag>> watchTags(String spaceId);
  Future<TwinsTag> createTag(String spaceId, String name, int colorValue);
  Future<void> deleteTag(String tagId);

  /// Resolves [names] to tag rows in the space's catalog, creating any that
  /// don't exist yet (case-insensitive). Used when saving AI-suggested or
  /// user-typed tags that aren't in the catalog.
  Future<List<TwinsTag>> ensureTags(String spaceId, List<String> names);

  /// Tags currently attached to an item, kept live.
  Stream<List<TwinsTag>> watchItemTags(String itemId);

  /// Replaces the full set of tags attached to [itemId] with [tagNames]
  /// (creating any missing catalog tags first).
  Future<void> setItemTags({
    required String spaceId,
    required String itemId,
    required List<String> tagNames,
  });

  // ---- Comments ----
  Stream<List<TwinsComment>> watchComments(String itemId);
  Future<TwinsComment> addComment({
    required String itemId,
    required String body,
    String? parentId,
    int? mediaTimestampMs,
  });

  // ---- Messages (Twins chat) ----
  Stream<List<TwinsMessage>> watchMessages(String spaceId);
  Future<TwinsMessage> sendMessage({required String spaceId, required String body, String? attachedItemId});

  // ---- Reactions ----
  Stream<List<TwinsReaction>> watchReactions(String spaceId, ReactionTargetType type, String targetId);
  Future<void> toggleReaction({
    required String spaceId,
    required ReactionTargetType targetType,
    required String targetId,
    required String emoji,
  });

  // ---- Settings ----
  Future<TwinsUserSettings> getSettings(String userId);
  Future<TwinsUserSettings> updateSettings(TwinsUserSettings settings);

  // ---- Export ----
  Future<Map<String, dynamic>> exportSpace(String spaceId);

  // ---- Storage ----
  /// Uploads a local file (image/video/document/audio) into the space's
  /// storage area. [onProgress] receives 0.0-1.0 where supported (Supabase
  /// resumable upload does not report progress today, so it may only ever
  /// emit 0.0 then 1.0 - callers must not assume smooth increments).
  Future<UploadResult> uploadFile({
    required String spaceId,
    required String localPath,
    required String fileName,
    void Function(double progress)? onProgress,
  });

  /// Uploads image bytes (e.g. an already-cropped avatar) to the user's
  /// avatar storage area and returns a display URL.
  Future<String> uploadAvatar({required String userId, required String localPath});
}
