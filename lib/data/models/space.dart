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
