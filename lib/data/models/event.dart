/// A plan on the shared calendar. Both twins see and edit every plan.
class TwinsEvent {
  final String id;
  final String spaceId;
  final String createdBy;
  final String? updatedBy;
  final String title;
  final String? notes;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;

  /// Minutes before the start to remind both twins; null for no reminder.
  /// All-day plans count from 09:00 on the day.
  final int? remindMinutes;
  final String? itemId;
  final String? chatId;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TwinsEvent({
    required this.id,
    required this.spaceId,
    required this.createdBy,
    this.updatedBy,
    required this.title,
    this.notes,
    required this.startsAt,
    this.endsAt,
    this.allDay = false,
    this.remindMinutes,
    this.itemId,
    this.chatId,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCancelled => cancelledAt != null;

  /// When the reminder goes off, or null when there is none.
  DateTime? get remindAt {
    final minutes = remindMinutes;
    if (minutes == null) return null;
    final base = allDay ? DateTime(startsAt.year, startsAt.month, startsAt.day, 9) : startsAt;
    return base.subtract(Duration(minutes: minutes));
  }

  /// Still to come (or in progress, for all-day plans and ones with an end).
  bool isUpcoming(DateTime now) {
    if (allDay) return !DateTime(startsAt.year, startsAt.month, startsAt.day + 1).isBefore(now);
    return (endsAt ?? startsAt).isAfter(now);
  }

  bool occursOn(DateTime day) {
    final start = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final endSource = endsAt ?? startsAt;
    final end = DateTime(endSource.year, endSource.month, endSource.day);
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  TwinsEvent copyWith({
    String? title,
    String? notes,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
    bool? allDay,
    int? remindMinutes,
    bool clearReminder = false,
    String? itemId,
    bool clearItem = false,
    DateTime? cancelledAt,
    bool restore = false,
  }) =>
      TwinsEvent(
        id: id,
        spaceId: spaceId,
        createdBy: createdBy,
        updatedBy: updatedBy,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        startsAt: startsAt ?? this.startsAt,
        endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
        allDay: allDay ?? this.allDay,
        remindMinutes: clearReminder ? null : remindMinutes ?? this.remindMinutes,
        itemId: clearItem ? null : itemId ?? this.itemId,
        chatId: chatId,
        cancelledAt: restore ? null : cancelledAt ?? this.cancelledAt,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  factory TwinsEvent.fromJson(Map<String, dynamic> json) => TwinsEvent(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        createdBy: json['created_by'] as String,
        updatedBy: json['updated_by'] as String?,
        title: json['title'] as String,
        notes: json['notes'] as String?,
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: json['ends_at'] == null ? null : DateTime.parse(json['ends_at'] as String).toLocal(),
        allDay: json['all_day'] as bool? ?? false,
        remindMinutes: json['remind_minutes'] as int?,
        itemId: json['item_id'] as String?,
        chatId: json['chat_id'] as String?,
        cancelledAt: json['cancelled_at'] == null ? null : DateTime.parse(json['cancelled_at'] as String).toLocal(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// The editable columns, as sent on update.
  Map<String, dynamic> toJson() => {
        'title': title,
        'notes': notes,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'all_day': allDay,
        'remind_minutes': remindMinutes,
        'item_id': itemId,
        'cancelled_at': cancelledAt?.toUtc().toIso8601String(),
      };
}
