class TwinsComment {
  final String id;
  final String spaceId;
  final String itemId;
  final String authorId;
  final String? parentId;
  final String body;
  final int? mediaTimestampMs;
  final DateTime createdAt;

  const TwinsComment({
    required this.id,
    required this.spaceId,
    required this.itemId,
    required this.authorId,
    this.parentId,
    required this.body,
    this.mediaTimestampMs,
    required this.createdAt,
  });

  factory TwinsComment.fromJson(Map<String, dynamic> json) => TwinsComment(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        itemId: json['item_id'] as String,
        authorId: json['author_id'] as String,
        parentId: json['parent_id'] as String?,
        body: json['body'] as String,
        mediaTimestampMs: json['media_timestamp_ms'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'space_id': spaceId,
        'item_id': itemId,
        'parent_id': parentId,
        'body': body,
        'media_timestamp_ms': mediaTimestampMs,
      };
}
