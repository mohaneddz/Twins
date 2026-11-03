import 'package:flutter/material.dart' show DateUtils;

String formatTimestamp(int ms) {
  final seconds = (ms / 1000).round();
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dt.month}/${dt.day}/${dt.year}';
}

String formatClockTime(DateTime time) {
  // Rows come back from the server in UTC.
  final dt = time.toLocal();
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthNamesLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "30 min", "1 hour", "2 days".
String formatLeadTime(int minutes) {
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';
  if (minutes % 10080 == 0) return plural(minutes ~/ 10080, 'week');
  if (minutes % 1440 == 0) return plural(minutes ~/ 1440, 'day');
  if (minutes % 60 == 0) return plural(minutes ~/ 60, 'hour');
  return '$minutes min';
}

String formatReminder(int? minutes) {
  if (minutes == null) return 'No reminder';
  if (minutes == 0) return 'At the time';
  return '${formatLeadTime(minutes)} before';
}

/// "Today", "Tomorrow", "Fri 6 Nov".
String formatDayLabel(DateTime day, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final d = DateUtils.dateOnly(day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  final base = '${_weekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]}';
  return d.year == today.year ? base : '$base ${d.year}';
}

/// "Fri 6 Nov · 8:00 PM", "Today · 8:00 – 11:00 PM", "Sat 7 Nov · all day".
String formatPlanWhen({required DateTime startsAt, DateTime? endsAt, required bool allDay, DateTime? now}) {
  final day = formatDayLabel(startsAt, now: now);
  if (allDay) return '$day · all day';
  final start = formatClockTime(startsAt);
  if (endsAt == null) return '$day · $start';
  return '$day · $start – ${formatClockTime(endsAt)}';
}
