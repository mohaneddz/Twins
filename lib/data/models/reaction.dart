enum ReactionTargetType { item, comment, message }

class TwinsReaction {
  final String id;
  final String spaceId;
  final String userId;
  final ReactionTargetType targetType;
  final String targetId;
  final String emoji;
  final DateTime createdAt;

  const TwinsReaction({
    required this.id,
    required this.spaceId,
    required this.userId,
    required this.targetType,
    required this.targetId,
    required this.emoji,
    required this.createdAt,
  });

  factory TwinsReaction.fromJson(Map<String, dynamic> json) => TwinsReaction(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        userId: json['user_id'] as String,
        targetType: ReactionTargetType.values.firstWhere(
          (e) => e.name == json['target_type'],
          orElse: () => ReactionTargetType.item,
        ),
        targetId: json['target_id'] as String,
        emoji: json['emoji'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
