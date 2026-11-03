import 'package:flutter_test/flutter_test.dart';
import 'package:twins/utils/when_parser.dart';

void main() {
  // Tuesday 3 November 2026, 14:00.
  final now = DateTime(2026, 11, 3, 14);
  ParsedPlan plan(String text) => parsePlan(text, now: now)!;

  test('weekday and evening time', () {
    final p = plan('movie night fri 8pm');
    expect(p.title, 'Movie night');
    expect(p.startsAt, DateTime(2026, 11, 6, 20));
    expect(p.allDay, isFalse);
  });

  test('a bare "at 8" is the evening', () {
    expect(plan('dinner tomorrow at 8').startsAt, DateTime(2026, 11, 4, 20));
    expect(plan('run tomorrow morning at 7').startsAt, DateTime(2026, 11, 4, 7));
  });

  test('24h and french style clocks', () {
    expect(plan('call mom 20:30').startsAt, DateTime(2026, 11, 3, 20, 30));
    expect(plan('gym 18h').startsAt, DateTime(2026, 11, 3, 18));
    expect(plan('gym 9h30 thu').startsAt, DateTime(2026, 11, 5, 9, 30));
  });

  test('a time already gone today means tomorrow', () {
    expect(plan('coffee 10am').startsAt, DateTime(2026, 11, 4, 10));
  });

  test('dates are day first', () {
    final p = plan('exam 12/11');
    expect(p.startsAt, DateTime(2026, 11, 12));
    expect(p.allDay, isTrue);
    expect(plan('trip 2027-01-05').startsAt, DateTime(2027, 1, 5));
    expect(plan('birthday 2/1').startsAt, DateTime(2027, 1, 2));
  });

  test('month names either way round', () {
    expect(plan('concert nov 20th 9pm').startsAt, DateTime(2026, 11, 20, 21));
    expect(plan('concert 20 nov').startsAt, DateTime(2026, 11, 20));
    expect(plan('party on the 15th').startsAt, DateTime(2026, 11, 15));
  });

  test('next weekday is next week', () {
    expect(plan('brunch next sat 11am').startsAt, DateTime(2026, 11, 14, 11));
    expect(plan('brunch sat 11am').startsAt, DateTime(2026, 11, 7, 11));
    expect(plan('lunch next mon noon').startsAt, DateTime(2026, 11, 9, 12));
  });

  test('tonight and relative times', () {
    expect(plan('pizza tonight').startsAt, DateTime(2026, 11, 3, 20));
    expect(plan('stretch in 30m').startsAt, DateTime(2026, 11, 3, 14, 30));
    expect(plan('check oven in 2 hours').startsAt, DateTime(2026, 11, 3, 16));
    expect(plan('call back in an hour').title, 'Call back');
  });

  test('ranges', () {
    final p = plan('game night sat 8-11pm');
    expect(p.title, 'Game night');
    expect(p.startsAt, DateTime(2026, 11, 7, 20));
    expect(p.endsAt, DateTime(2026, 11, 7, 23));
    final q = plan('study fri 2pm to 5pm');
    expect(q.endsAt, DateTime(2026, 11, 6, 17));
  });

  test('reminders', () {
    final p = plan('movie fri 8pm !1h');
    expect(p.remindMinutes, 60);
    expect(p.reminderGiven, isTrue);
    expect(p.title, 'Movie');
    expect(plan('dentist thu 10am remind me 1 day before').remindMinutes, 1440);
    final none = plan('walk tomorrow !no');
    expect(none.reminderGiven, isTrue);
    expect(none.remindMinutes, isNull);
    expect(plan('walk tomorrow').reminderGiven, isFalse);
  });

  test('words that look like times stay in the title', () {
    expect(plan('watch 2 movies sat 9pm').title, 'Watch 2 movies');
    expect(plan('game night fri 9pm').title, 'Game night');
  });

  test('nothing about when gives null', () {
    expect(parsePlan('just a title', now: now), isNull);
  });
}
