class TwinsChat {
  final String id;
  final String spaceId;
  final String? name;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TwinsChat({
    required this.id,
    required this.spaceId,
    this.name,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  TwinsChat copyWith({String? name}) => TwinsChat(
        id: id,
        spaceId: spaceId,
        name: name ?? this.name,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  factory TwinsChat.fromJson(Map<String, dynamic> json) => TwinsChat(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        name: json['name'] as String?,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'space_id': spaceId,
        'name': name,
      };
}
