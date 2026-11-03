/// Reads a plan typed in chat, like "movie night fri 8pm !1h", into a title,
/// a start (and maybe an end) and a reminder. Rule-based on purpose: the
/// composer shows what it understood as you type, so it has to be instant
/// and give the same answer every time.
///
/// Understands, anywhere in the text:
///  - days: today, tonight, tomorrow (tmrw), day after tomorrow, weekday
///    names ("fri", "next friday"), this weekend, next week
///  - dates: 12/11 and 12/11/2026 (day first), 2026-11-12, "12 nov",
///    "nov 12th", "the 12th"
///  - times: 8pm, 8:30pm, 8 pm, 20:00, 20h30, "at 8" (afternoon/evening
///    unless "morning" is said), noon, midnight, morning, afternoon,
///    evening, night
///  - ranges: 8-10pm, 8pm to 10pm, until 11
///  - relative: "in 2 hours", "in 30m", "in 3 days"
///  - reminders: !30m, !1h, !2d, !0 (at the time), !no, "remind 1h before"
class ParsedPlan {
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;

  /// Set when the text says when to remind; see [reminderGiven].
  final int? remindMinutes;

  /// True when the text chose the reminder (including "!no"), so the
  /// default shouldn't replace it.
  final bool reminderGiven;

  const ParsedPlan({
    required this.title,
    required this.startsAt,
    this.endsAt,
    required this.allDay,
    this.remindMinutes,
    this.reminderGiven = false,
  });
}

const _weekdays = {
  'mon': 1, 'monday': 1,
  'tue': 2, 'tues': 2, 'tuesday': 2,
  'wed': 3, 'weds': 3, 'wednesday': 3,
  'thu': 4, 'thur': 4, 'thurs': 4, 'thursday': 4,
  'fri': 5, 'friday': 5,
  'sat': 6, 'saturday': 6,
  'sun': 7, 'sunday': 7,
};

const _months = {
  'jan': 1, 'january': 1,
  'feb': 2, 'february': 2,
  'mar': 3, 'march': 3,
  'apr': 4, 'april': 4,
  'may': 5,
  'jun': 6, 'june': 6,
  'jul': 7, 'july': 7,
  'aug': 8, 'august': 8,
  'sep': 9, 'sept': 9, 'september': 9,
  'oct': 10, 'october': 10,
  'nov': 11, 'november': 11,
  'dec': 12, 'december': 12,
};

const _partsOfDay = {'morning': 9, 'afternoon': 15, 'evening': 19, 'night': 21, 'noon': 12, 'midnight': 0};

/// Words that only glue a date or time to the sentence ("on fri", "at 8").
const _fillers = {'at', 'on', 'in', 'this', 'by', 'from', '@', 'the', 'for'};

final _durationRe = RegExp(r'^(\d+)(m|min|mins|minute|minutes|h|hr|hrs|hour|hours|d|day|days|w|wk|week|weeks)$');
final _clockRe = RegExp(r'^(\d{1,2})(?:[:.h](\d{2}))?(am|pm|a|p|h)?$');
final _rangeRe = RegExp(r'^(\d{1,2}(?:[:.]\d{2})?)(am|pm)?[-–](\d{1,2}(?:[:.]\d{2})?)(am|pm)$');
final _slashDateRe = RegExp(r'^(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?$');
final _isoDateRe = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
final _ordinalRe = RegExp(r'^(\d{1,2})(st|nd|rd|th)?$');

int? _unitMinutes(String unit) {
  if (unit.startsWith('m')) return 1;
  if (unit.startsWith('h')) return 60;
  if (unit.startsWith('d')) return 1440;
  if (unit.startsWith('w')) return 10080;
  return null;
}

/// "30m", "1h" and friends as minutes, or null.
int? parseDuration(String token) {
  final match = _durationRe.firstMatch(token);
  if (match == null) return null;
  return int.parse(match.group(1)!) * _unitMinutes(match.group(2)!)!;
}

class _Clock {
  final int hour;
  final int minute;

  /// False for a bare "8", whose half of the day is guessed later.
  final bool exact;
  const _Clock(this.hour, this.minute, {this.exact = true});
}

_Clock? _parseClock(String token, {String? suffix, bool allowBare = false}) {
  final match = _clockRe.firstMatch(token);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.tryParse(match.group(2) ?? '') ?? 0;
  final marker = match.group(3) ?? suffix;
  if (minute > 59) return null;
  if (marker == 'am' || marker == 'a' || marker == 'pm' || marker == 'p') {
    if (hour < 1 || hour > 12) return null;
    final pm = marker!.startsWith('p');
    hour = hour % 12 + (pm ? 12 : 0);
    return _Clock(hour, minute);
  }
  if (hour > 23) return null;
  // "20h", "20:00" and "8:30" say exactly what they mean; a bare "8" only
  // counts when something like "at" says it's a time.
  if (marker == 'h' || match.group(2) != null) {
    return _Clock(hour, minute, exact: hour > 12 || hour == 0 || token.contains('h'));
  }
  if (!allowBare) return null;
  return _Clock(hour, minute, exact: hour > 12 || hour == 0);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

ParsedPlan? parsePlan(String text, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = _day(clock);
  final raw = text.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (raw.isEmpty) return null;
  final tokens = raw
      .map((t) => t.toLowerCase().replaceAll(RegExp(r'[,;?]+$'), '').replaceAll(RegExp(r'(?<=[a-z0-9])[.!]+$'), ''))
      .toList();
  final used = List<bool>.filled(tokens.length, false);

  DateTime? date;
  _Clock? time;
  _Clock? endTime;
  DateTime? absolute;
  int? remind;
  var reminderGiven = false;
  var morningHint = false;

  void take(int from, int count) {
    for (var k = from; k < from + count && k < tokens.length; k++) {
      used[k] = true;
    }
  }

  String at(int k) => k >= 0 && k < tokens.length ? tokens[k] : '';

  for (var i = 0; i < tokens.length; i++) {
    if (used[i]) continue;
    final t = tokens[i];

    // ---- reminders ----
    if (t.startsWith('!') && t.length > 1) {
      final spec = t.substring(1);
      if (spec == 'no' || spec == 'none' || spec == 'off') {
        remind = null;
        reminderGiven = true;
        take(i, 1);
        continue;
      }
      if (spec == '0' || spec == 'now') {
        remind = 0;
        reminderGiven = true;
        take(i, 1);
        continue;
      }
      final minutes = parseDuration(spec);
      if (minutes != null) {
        remind = minutes;
        reminderGiven = true;
        take(i, 1);
        continue;
      }
    }
    if (t == 'remind' || t == 'reminder') {
      var j = i + 1;
      if (at(j) == 'me' || at(j) == 'us') j++;
      var minutes = parseDuration(at(j));
      var width = 1;
      if (minutes == null && int.tryParse(at(j)) != null) {
        minutes = parseDuration('${at(j)}${at(j + 1)}');
        width = 2;
      }
      if (minutes != null) {
        var end = j + width;
        if (at(end) == 'before' || at(end) == 'early' || at(end) == 'earlier') end++;
        remind = minutes;
        reminderGiven = true;
        take(i, end - i);
        continue;
      }
    }
    if (t == 'no' && (at(i + 1) == 'reminder' || at(i + 1) == 'reminders')) {
      remind = null;
      reminderGiven = true;
      take(i, 2);
      continue;
    }

    // ---- relative: in 2 hours / in 30m ----
    if (t == 'in') {
      var minutes = parseDuration(at(i + 1));
      var width = 2;
      if (minutes == null && int.tryParse(at(i + 1)) != null) {
        minutes = parseDuration('${at(i + 1)}${at(i + 2)}');
        width = 3;
      }
      if (minutes == null && (at(i + 1) == 'an' || at(i + 1) == 'a')) {
        minutes = parseDuration('1${at(i + 2)}');
        width = 3;
      }
      if (minutes != null) {
        absolute = clock.add(Duration(minutes: minutes));
        take(i, width);
        continue;
      }
    }

    // ---- days ----
    if (t == 'today') {
      date = today;
      take(i, 1);
      continue;
    }
    if (t == 'tonight') {
      date = today;
      time ??= const _Clock(20, 0);
      take(i, 1);
      continue;
    }
    if (t == 'tomorrow' || t == 'tmrw' || t == 'tmr' || t == 'tomorow' || t == 'tommorow') {
      date = today.add(const Duration(days: 1));
      take(i, 1);
      continue;
    }
    if (t == 'day' && at(i + 1) == 'after' && (at(i + 2) == 'tomorrow' || at(i + 2) == 'tmrw')) {
      date = today.add(const Duration(days: 2));
      take(i, 3);
      continue;
    }
    if (t == 'next' && (at(i + 1) == 'week')) {
      date = today.add(Duration(days: 8 - today.weekday));
      take(i, 2);
      continue;
    }
    if (t == 'weekend' || (t == 'this' && at(i + 1) == 'weekend')) {
      final ahead = (6 - today.weekday) % 7;
      date = today.weekday == 7 ? today : today.add(Duration(days: ahead));
      take(i, t == 'this' ? 2 : 1);
      continue;
    }
    final isNext = t == 'next' && _weekdays.containsKey(at(i + 1));
    final weekdayToken = isNext ? at(i + 1) : t;
    if (_weekdays.containsKey(weekdayToken)) {
      final target = _weekdays[weekdayToken]!;
      var ahead = (target - today.weekday + 7) % 7;
      if (isNext) {
        if (ahead == 0) ahead = 7;
        // "next fri" means next week's, unless this week's has gone.
        final sunday = today.add(Duration(days: 7 - today.weekday));
        if (!today.add(Duration(days: ahead)).isAfter(sunday)) ahead += 7;
      }
      date = today.add(Duration(days: ahead));
      take(i, isNext ? 2 : 1);
      continue;
    }

    // ---- dates ----
    final iso = _isoDateRe.firstMatch(t);
    if (iso != null) {
      final d = DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
      if (d.month == int.parse(iso.group(2)!)) {
        date = d;
        take(i, 1);
        continue;
      }
    }
    final slash = _slashDateRe.firstMatch(t);
    if (slash != null) {
      final dayN = int.parse(slash.group(1)!);
      final monthN = int.parse(slash.group(2)!);
      var year = int.tryParse(slash.group(3) ?? '');
      if (year != null && year < 100) year += 2000;
      if (monthN >= 1 && monthN <= 12 && dayN >= 1 && dayN <= 31) {
        var d = DateTime(year ?? today.year, monthN, dayN);
        if (year == null && d.isBefore(today)) d = DateTime(today.year + 1, monthN, dayN);
        if (d.day == dayN) {
          date = d;
          take(i, 1);
          continue;
        }
      }
    }
    if (_months.containsKey(t)) {
      final monthN = _months[t]!;
      // "nov 12" or "12 nov" (the latter is caught from the number's side)
      final dayMatch = _ordinalRe.firstMatch(at(i + 1));
      if (dayMatch != null) {
        final dayN = int.parse(dayMatch.group(1)!);
        var d = DateTime(today.year, monthN, dayN);
        if (d.isBefore(today)) d = DateTime(today.year + 1, monthN, dayN);
        if (d.day == dayN && dayN >= 1) {
          date = d;
          take(i, 2);
          continue;
        }
      }
    }
    final ordinal = _ordinalRe.firstMatch(t);
    if (ordinal != null && _months.containsKey(at(i + 1))) {
      final dayN = int.parse(ordinal.group(1)!);
      final monthN = _months[at(i + 1)]!;
      var d = DateTime(today.year, monthN, dayN);
      if (d.isBefore(today)) d = DateTime(today.year + 1, monthN, dayN);
      if (d.day == dayN && dayN >= 1) {
        date = d;
        take(i, 2);
        continue;
      }
    }
    if (ordinal != null && ordinal.group(2) != null && at(i - 1) == 'the') {
      final dayN = int.parse(ordinal.group(1)!);
      var d = DateTime(today.year, today.month, dayN);
      if (d.isBefore(today)) d = DateTime(today.year, today.month + 1, dayN);
      if (d.day == dayN && dayN >= 1) {
        date = d;
        take(i, 1);
        continue;
      }
    }

    // ---- times ----
    final range = _rangeRe.firstMatch(t);
    if (range != null) {
      final endMarker = range.group(4)!;
      final startClock = _parseClock(range.group(1)!, suffix: range.group(2) ?? endMarker);
      final endClock = _parseClock(range.group(3)!, suffix: endMarker);
      if (startClock != null && endClock != null) {
        time = startClock;
        endTime = endClock;
        take(i, 1);
        continue;
      }
    }
    if (_partsOfDay.containsKey(t)) {
      // "fri night" sets a time; "night" alone in a title ("game night")
      // only does when nothing else gives one, see below.
      final glued = at(i - 1) == 'in' || at(i - 1) == 'the' || at(i - 1) == 'at' || (i > 0 && used[i - 1] && date != null);
      if (t == 'morning') morningHint = true;
      if (glued || t == 'noon' || t == 'midnight') {
        time ??= _Clock(_partsOfDay[t]!, 0);
        take(i, 1);
        if (at(i - 1) == 'the' && at(i - 2) == 'in') take(i - 2, 2);
        continue;
      }
    }
    final afterAt = at(i - 1) == 'at' || at(i - 1) == '@' || at(i - 1) == 'from' || at(i - 1) == 'to' || at(i - 1) == 'until' || at(i - 1) == 'till';
    final nextMarker = at(i + 1);
    final markerNext = nextMarker == 'am' || nextMarker == 'pm';
    final parsedClock = _parseClock(t, suffix: markerNext ? nextMarker : null, allowBare: afterAt);
    if (parsedClock != null) {
      final isEnd = time != null && (at(i - 1) == 'to' || at(i - 1) == 'until' || at(i - 1) == 'till' || at(i - 1) == '-');
      if (isEnd) {
        endTime = parsedClock;
        take(i - 1, 1);
      } else if (time == null || !time.exact || afterAt) {
        time = parsedClock;
      } else {
        continue;
      }
      take(i, markerNext ? 2 : 1);
      continue;
    }
  }

  // Glue words left dangling in front of what was understood.
  for (var pass = 0; pass < 2; pass++) {
    for (var i = tokens.length - 2; i >= 0; i--) {
      if (!used[i] && used[i + 1] && _fillers.contains(tokens[i])) used[i] = true;
    }
  }

  // A part of day mentioned in passing still sets the time if nothing else did.
  if (time == null && date != null) {
    for (var i = 0; i < tokens.length; i++) {
      final hour = _partsOfDay[tokens[i]];
      if (!used[i] && hour != null && (tokens[i] == 'morning' || tokens[i] == 'afternoon' || tokens[i] == 'evening')) {
        time = _Clock(hour, 0);
        used[i] = true;
        break;
      }
    }
  }

  final title = _title([for (var i = 0; i < raw.length; i++) if (!used[i]) raw[i]]);

  if (absolute != null) {
    return ParsedPlan(title: title, startsAt: absolute, allDay: false, remindMinutes: remind, reminderGiven: reminderGiven);
  }
  if (date == null && time == null) return null;

  // A bare "at 8" is the afternoon/evening one, unless "morning" was said.
  _Clock resolve(_Clock c) {
    if (c.exact || c.hour == 12 || morningHint) return c;
    return _Clock(c.hour + 12, c.minute);
  }

  if (time == null) {
    return ParsedPlan(
      title: title,
      startsAt: date!,
      allDay: true,
      remindMinutes: remind,
      reminderGiven: reminderGiven,
    );
  }
  final start = resolve(time);
  var day = date ?? today;
  var startsAt = DateTime(day.year, day.month, day.day, start.hour, start.minute);
  if (date == null && !startsAt.isAfter(clock)) {
    day = today.add(const Duration(days: 1));
    startsAt = DateTime(day.year, day.month, day.day, start.hour, start.minute);
  }
  DateTime? endsAt;
  if (endTime != null) {
    var end = endTime;
    // "8-10" in the evening: the end follows the start's half of the day.
    if (!end.exact && start.hour >= 12 && end.hour < 12) end = _Clock(end.hour + 12, end.minute);
    endsAt = DateTime(day.year, day.month, day.day, end.hour, end.minute);
    if (!endsAt.isAfter(startsAt)) endsAt = endsAt.add(const Duration(days: 1));
  }
  return ParsedPlan(
    title: title,
    startsAt: startsAt,
    endsAt: endsAt,
    allDay: false,
    remindMinutes: remind,
    reminderGiven: reminderGiven,
  );
}

String _title(List<String> words) {
  final joined = words.join(' ').trim().replaceAll(RegExp(r'^[-–,:]+|[-–,:]+$'), '').trim();
  if (joined.isEmpty) return '';
  return joined[0].toUpperCase() + joined.substring(1);
}
