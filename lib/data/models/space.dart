class TwinsSpace {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  const TwinsSpace({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory TwinsSpace.fromJson(Map<String, dynamic> json) => TwinsSpace(
        id: json['id'] as String,
        name: json['name'] as String,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class SpaceInvite {
  final String id;
  final String spaceId;
  final String code;
  final String createdBy;
  final DateTime expiresAt;
  final DateTime? usedAt;

  const SpaceInvite({
    required this.id,
    required this.spaceId,
    required this.code,
    required this.createdBy,
    required this.expiresAt,
    this.usedAt,
  });

  bool get isValid => usedAt == null && expiresAt.isAfter(DateTime.now());

  factory SpaceInvite.fromJson(Map<String, dynamic> json) => SpaceInvite(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        code: json['code'] as String,
        createdBy: json['created_by'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        usedAt: json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
      );
}
