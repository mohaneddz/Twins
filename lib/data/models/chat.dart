class TwinsChat {
  final String id;
  final String spaceId;
  final String? name;

  /// True when [name] came from the auto-namer (so it may be refreshed),
  /// false when someone typed it.
  final bool nameIsAuto;

  /// Message count when the auto-namer last named the chat.
  final int? namedAtCount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TwinsChat({
    required this.id,
    required this.spaceId,
    this.name,
    this.nameIsAuto = false,
    this.namedAtCount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  TwinsChat copyWith({String? name}) => TwinsChat(
        id: id,
        spaceId: spaceId,
        name: name ?? this.name,
        nameIsAuto: nameIsAuto,
        namedAtCount: namedAtCount,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  factory TwinsChat.fromJson(Map<String, dynamic> json) => TwinsChat(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        name: json['name'] as String?,
        nameIsAuto: json['name_source'] == 'auto',
        namedAtCount: json['named_at_count'] as int?,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'space_id': spaceId,
        'name': name,
      };
}
