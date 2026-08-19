import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat.dart';
import '../data/models/comment.dart';
import '../data/models/folder.dart';
import '../data/models/item.dart';
import '../data/models/item_type.dart';
import '../data/models/message.dart';
import '../data/models/reaction.dart';
import '../data/models/tag.dart';
import 'repository_provider.dart';

class FolderQuery {
  final String spaceId;
  final String? parentId;
  const FolderQuery(this.spaceId, this.parentId);

  @override
  bool operator ==(Object other) =>
      other is FolderQuery && other.spaceId == spaceId && other.parentId == parentId;
  @override
  int get hashCode => Object.hash(spaceId, parentId);
}

final folderByIdProvider = FutureProvider.family<TwinsFolder?, String>((ref, folderId) {
  final repo = ref.watch(repositoryProvider);
  return repo.getFolder(folderId);
});

final foldersProvider = StreamProvider.family<List<TwinsFolder>, FolderQuery>((ref, query) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchFolders(query.spaceId, parentId: query.parentId);
});

class ItemQuery {
  final String spaceId;
  final String? folderId;
  final ItemType? type;
  const ItemQuery(this.spaceId, this.folderId, [this.type]);

  @override
  bool operator ==(Object other) =>
      other is ItemQuery && other.spaceId == spaceId && other.folderId == folderId && other.type == type;
  @override
  int get hashCode => Object.hash(spaceId, folderId, type);
}

final itemsProvider = StreamProvider.family<List<TwinsItem>, ItemQuery>((ref, query) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchItems(query.spaceId, folderId: query.folderId, type: query.type);
});

final recentItemsProvider = StreamProvider.family<List<TwinsItem>, String>((ref, spaceId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchRecentItems(spaceId);
});

final allItemsProvider = StreamProvider.family<List<TwinsItem>, String>((ref, spaceId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllItems(spaceId);
});

final itemByIdProvider = FutureProvider.family<TwinsItem?, String>((ref, itemId) {
  final repo = ref.watch(repositoryProvider);
  return repo.getItem(itemId);
});

final tagsProvider = StreamProvider.family<List<TwinsTag>, String>((ref, spaceId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTags(spaceId);
});

/// Tags currently attached to a single item, kept live.
final itemTagsProvider = StreamProvider.family<List<TwinsTag>, String>((ref, itemId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchItemTags(itemId);
});

final commentsProvider = StreamProvider.family<List<TwinsComment>, String>((ref, itemId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchComments(itemId);
});

final chatsProvider = StreamProvider.family<List<TwinsChat>, String>((ref, spaceId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchChats(spaceId);
});

final messagesProvider = StreamProvider.family<List<TwinsMessage>, String>((ref, chatId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchMessages(chatId);
});

/// Recent messages across every chat in the space, for the activity feed.
final recentMessagesProvider = StreamProvider.family<List<TwinsMessage>, String>((ref, spaceId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchRecentMessages(spaceId);
});

class ReactionQuery {
  final String spaceId;
  final ReactionTargetType type;
  final String targetId;
  const ReactionQuery(this.spaceId, this.type, this.targetId);

  @override
  bool operator ==(Object other) =>
      other is ReactionQuery && other.spaceId == spaceId && other.type == type && other.targetId == targetId;
  @override
  int get hashCode => Object.hash(spaceId, type, targetId);
}

final reactionsProvider = StreamProvider.family<List<TwinsReaction>, ReactionQuery>((ref, query) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchReactions(query.spaceId, query.type, query.targetId);
});

class SearchQuery {
  final String spaceId;
  final String query;

  /// null = every kind of item.
  final ItemType? type;

  const SearchQuery({required this.spaceId, required this.query, this.type});

  @override
  bool operator ==(Object other) =>
      other is SearchQuery && other.spaceId == spaceId && other.query == query && other.type == type;

  @override
  int get hashCode => Object.hash(spaceId, query, type);
}

/// Ranked results. The type filter is part of the query rather than applied
/// client-side so the backend can narrow before its limit is applied -
/// filtering after the fact would silently drop matches beyond the cut.
final searchResultsProvider = FutureProvider.family<List<TwinsItem>, SearchQuery>((ref, args) {
  final repo = ref.watch(repositoryProvider);
  if (args.query.trim().isEmpty) return Future.value(<TwinsItem>[]);
  return repo.searchItems(args.spaceId, args.query, type: args.type);
});

final recentSearchesProvider = FutureProvider.family<List<String>, String>((ref, spaceId) {
  final repo = ref.watch(repositoryProvider);
  return repo.recentSearches(spaceId);
});
