import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/models/event.dart';
import '../state/twin_color_provider.dart';
import '../theme/palette.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/formatters.dart';

const _weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// Colour of a plan: the colour of whichever twin made it.
Color planAccent(WidgetRef ref, TwinsEvent event) => ref.watch(colorOfUserProvider(event.createdBy)).accent;

/// A plan as a row: a date tile, the title and when. Used on the calendar,
/// on home and as the card a /plan posts in chat.
class EventCard extends StatelessWidget {
  final TwinsEvent event;
  final Color accent;
  final VoidCallback? onTap;
  final bool compact;

  const EventCard({super.key, required this.event, required this.accent, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final cancelled = event.isCancelled;
    final titleStyle = TwinsTypography.label(palette.textPrimary, size: 15).copyWith(
      decoration: cancelled ? TextDecoration.lineThrough : null,
    );
    return Material(
      color: palette.surface,
      borderRadius: TwinsRadius.mdRadius,
      child: InkWell(
        borderRadius: TwinsRadius.mdRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(TwinsSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: TwinsRadius.mdRadius,
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: cancelled ? 0.08 : 0.16),
                  borderRadius: TwinsRadius.smRadius,
                ),
                child: Column(
                  children: [
                    Text(_weekdayShort[event.startsAt.weekday - 1], style: TwinsTypography.label(accent, size: 10)),
                    Text('${event.startsAt.day}', style: TwinsTypography.heading(accent, size: 18)),
                  ],
                ),
              ),
              const SizedBox(width: TwinsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: titleStyle, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      cancelled
                          ? 'Called off'
                          : formatPlanWhen(startsAt: event.startsAt, endsAt: event.endsAt, allDay: event.allDay),
                      style: TwinsTypography.body(palette.textSecondary, size: 12.5),
                    ),
                  ],
                ),
              ),
              if (!cancelled && event.remindMinutes != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(PhosphorIconsBold.bellRinging, size: 16, color: palette.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
