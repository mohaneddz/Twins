import 'package:flutter/material.dart';

class TwinsTag {
  final String id;
  final String spaceId;
  final String name;
  final Color color;

  const TwinsTag({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.color,
  });

  factory TwinsTag.fromJson(Map<String, dynamic> json) => TwinsTag(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        name: json['name'] as String,
        color: Color(int.parse((json['color'] as String? ?? '0xFF7EE7E1'))),
      );
}
