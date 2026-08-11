import 'item_type.dart';

class TwinsItem {
  final String id;
  final String spaceId;
  final String? folderId;
  final String createdBy;
  final ItemType type;
  final ItemPlatform platform;
  final String? sourceUrl;
  final String? storagePath;
  final String? thumbnailUrl;
  final String title;
  final String? description;
  final String? content; // note body / markdown
  final Map<String, dynamic> metadata;
  final int? durationMs;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int commentCount;
  final int reactionCount;
  final List<String> tagIds;

  const TwinsItem({
    required this.id,
    required this.spaceId,
    this.folderId,
    required this.createdBy,
    required this.type,
    this.platform = ItemPlatform.device,
    this.sourceUrl,
    this.storagePath,
    this.thumbnailUrl,
    required this.title,
    this.description,
    this.content,
    this.metadata = const {},
    this.durationMs,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.commentCount = 0,
    this.reactionCount = 0,
    this.tagIds = const [],
  });

  TwinsItem copyWith({
    String? folderId,
    String? title,
    String? description,
    String? content,
    bool? isPinned,
    List<String>? tagIds,
    int? commentCount,
    int? reactionCount,
  }) {
    return TwinsItem(
      id: id,
      spaceId: spaceId,
      folderId: folderId ?? this.folderId,
      createdBy: createdBy,
      type: type,
      platform: platform,
      sourceUrl: sourceUrl,
      storagePath: storagePath,
      thumbnailUrl: thumbnailUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      metadata: metadata,
      durationMs: durationMs,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      commentCount: commentCount ?? this.commentCount,
      reactionCount: reactionCount ?? this.reactionCount,
      tagIds: tagIds ?? this.tagIds,
    );
  }

  factory TwinsItem.fromJson(Map<String, dynamic> json) => TwinsItem(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        folderId: json['folder_id'] as String?,
        createdBy: json['created_by'] as String,
        type: ItemType.fromString(json['type'] as String),
        platform: ItemPlatform.fromString(json['platform'] as String?),
        sourceUrl: json['source_url'] as String?,
        storagePath: json['storage_path'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        title: json['title'] as String? ?? 'Untitled',
        description: json['description'] as String?,
        content: json['content'] as String?,
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
        durationMs: json['duration_ms'] as int?,
        isPinned: json['is_pinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        commentCount: json['comment_count'] as int? ?? 0,
        reactionCount: json['reaction_count'] as int? ?? 0,
        tagIds: (json['tag_ids'] as List?)?.cast<String>() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'space_id': spaceId,
        'folder_id': folderId,
        'type': type.name,
        'platform': platform.name,
        'source_url': sourceUrl,
        'storage_path': storagePath,
        'thumbnail_url': thumbnailUrl,
        'title': title,
        'description': description,
        'content': content,
        'metadata': metadata,
        'duration_ms': durationMs,
        'is_pinned': isPinned,
      };
}
