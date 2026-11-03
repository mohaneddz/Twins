import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/event.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/event_card.dart';
import 'event_editor_sheet.dart';

/// The shared calendar: a month to pick a day from, that day's plans, and
/// what's coming up after it.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selected = DateUtils.dateOnly(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int by) => setState(() => _month = DateTime(_month.year, _month.month + by));

  void _goToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _selected = today;
      _month = DateTime(today.year, today.month);
    });
  }

  Future<void> _newPlan(String spaceId, DateTime day) async {
    final saved = await showEventEditor(context, spaceId: spaceId, day: day);
    if (saved != null && mounted) {
      setState(() {
        _selected = DateUtils.dateOnly(saved.startsAt);
        _month = DateTime(saved.startsAt.year, saved.startsAt.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final space = ref.watch(currentSpaceProvider).valueOrNull;
    if (space == null) return const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final events = (ref.watch(eventsProvider(space.id)).valueOrNull ?? const <TwinsEvent>[])
        .where((e) => !e.isCancelled)
        .toList();
    final onDay = events.where((e) => e.occursOn(_selected)).toList();
    final endOfSelected = _selected.add(const Duration(days: 1));
    final now = DateTime.now();
    final later = events.where((e) => !e.startsAt.isBefore(endOfSelected) && e.isUpcoming(now)).take(8).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'newPlan',
        backgroundColor: TwinsColors.mikuGreen,
        foregroundColor: Colors.white,
        tooltip: 'New plan',
        onPressed: () => _newPlan(space.id, _selected),
        child: const Icon(PhosphorIconsBold.calendarPlus),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(TwinsSpacing.lg, TwinsSpacing.md, TwinsSpacing.lg, 96),
          children: [
            Row(
              children: [
                Expanded(child: Text('Our calendar', style: TwinsTypography.heading(palette.textPrimary, size: 22))),
                TextButton(onPressed: _goToday, child: const Text('Today')),
              ],
            ),
            const SizedBox(height: TwinsSpacing.sm),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: Icon(PhosphorIconsBold.caretLeft, color: palette.textPrimary),
                  onPressed: () => _shiftMonth(-1),
                ),
                Expanded(
                  child: Text(
                    '${monthNamesLong[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: TwinsTypography.label(palette.textPrimary, size: 16),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: Icon(PhosphorIconsBold.caretRight, color: palette.textPrimary),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            GestureDetector(
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v.abs() > 200) _shiftMonth(v < 0 ? 1 : -1);
              },
              child: MonthGrid(
                month: _month,
                selected: _selected,
                events: events,
                myId: myId,
                onSelect: (day) => setState(() {
                  _selected = day;
                  if (day.month != _month.month) _month = DateTime(day.year, day.month);
                }),
                onLongPress: (day) => _newPlan(space.id, day),
              ),
            ),
            const SizedBox(height: TwinsSpacing.lg),
            Text(formatDayLabel(_selected), style: TwinsTypography.heading(palette.textPrimary, size: 17)),
            const SizedBox(height: TwinsSpacing.sm),
            if (onDay.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.sm),
                child: Text(
                  'Nothing planned. Tap + to plan something, or type /plan in a chat.',
                  style: TwinsTypography.body(palette.textSecondary, size: 13.5),
                ),
              )
            else
              for (final event in onDay)
                Padding(
                  padding: const EdgeInsets.only(bottom: TwinsSpacing.xs),
                  child: EventCard(
                    event: event,
                    accent: planAccent(event, myId),
                    onTap: () => context.push('/event/${event.id}'),
                  ),
                ),
            if (later.isNotEmpty) ...[
              const SizedBox(height: TwinsSpacing.lg),
              Text('Coming up', style: TwinsTypography.heading(palette.textPrimary, size: 17)),
              const SizedBox(height: TwinsSpacing.sm),
              for (final event in later)
                Padding(
                  padding: const EdgeInsets.only(bottom: TwinsSpacing.xs),
                  child: EventCard(
                    event: event,
                    accent: planAccent(event, myId),
                    onTap: () => context.push('/event/${event.id}'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A month of days, Monday first, with a dot per plan (up to three).
class MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final List<TwinsEvent> events;
  final String? myId;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime>? onLongPress;

  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.events,
    required this.myId,
    required this.onSelect,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final first = DateTime(month.year, month.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((first.weekday - 1 + daysInMonth) / 7).ceil();
    final today = DateUtils.dateOnly(DateTime.now());

    Widget cell(DateTime day) => _DayCell(
          day: day,
          inMonth: day.month == month.month,
          isToday: DateUtils.isSameDay(day, today),
          isSelected: DateUtils.isSameDay(day, selected),
          dots: events.where((e) => e.occursOn(day)).take(3).map((e) => planAccent(e, myId)).toList(),
          onTap: onSelect,
          onLongPress: onLongPress,
        );

    return Column(
      children: [
        Row(
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(child: Text(d, style: TwinsTypography.label(palette.textSecondary, size: 12))),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++) Expanded(child: cell(DateTime(gridStart.year, gridStart.month, gridStart.day + r * 7 + c))),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<Color> dots;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<DateTime>? onLongPress;

  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.dots,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final textColor = isSelected
        ? Colors.white
        : inMonth
            ? palette.textPrimary
            : palette.textSecondary.withValues(alpha: 0.45);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => onTap(day),
      onLongPress: onLongPress == null ? null : () => onLongPress!(day),
      child: SizedBox(
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? TwinsColors.mikuGreen : null,
                border: isToday && !isSelected ? Border.all(color: TwinsColors.mikuGreen, width: 1.5) : null,
              ),
              child: Text(
                '${day.day}',
                style: TwinsTypography.label(textColor, size: 14, weight: isToday ? FontWeight.w800 : FontWeight.w600),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in dots)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
