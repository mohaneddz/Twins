import 'package:flutter/material.dart';

class TwinsFolder {
  final String id;
  final String spaceId;
  final String? parentId;
  final String name;
  final Color color;
  final String icon; // emoji or phosphor icon key
  final int position;
  final bool isPinned;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;

  const TwinsFolder({
    required this.id,
    required this.spaceId,
    this.parentId,
    required this.name,
    required this.color,
    required this.icon,
    this.position = 0,
    this.isPinned = false,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.itemCount = 0,
  });

  TwinsFolder copyWith({
    String? name,
    Color? color,
    String? icon,
    bool? isPinned,
    String? parentId,
    int? itemCount,
  }) {
    return TwinsFolder(
      id: id,
      spaceId: spaceId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      position: position,
      isPinned: isPinned ?? this.isPinned,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      itemCount: itemCount ?? this.itemCount,
    );
  }

  factory TwinsFolder.fromJson(Map<String, dynamic> json) => TwinsFolder(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        parentId: json['parent_id'] as String?,
        name: json['name'] as String,
        color: Color(int.parse((json['color'] as String? ?? '0xFF8DEBD9'))),
        icon: json['icon'] as String? ?? '📁',
        position: json['position'] as int? ?? 0,
        isPinned: json['is_pinned'] as bool? ?? false,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        itemCount: json['item_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'space_id': spaceId,
        'parent_id': parentId,
        'name': name,
        'color': '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
        'icon': icon,
        'position': position,
        'is_pinned': isPinned,
      };
}
