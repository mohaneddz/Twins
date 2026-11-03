import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/event.dart';
import '../../state/data_providers.dart';
import '../../state/plan_reminder_provider.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/filter_chip_twins.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_bottom_sheet.dart';

/// Opens the plan form: a new plan (optionally on [day], about [itemId], or
/// made from [chatId]) or [existing] to edit. Returns the saved plan.
Future<TwinsEvent?> showEventEditor(
  BuildContext context, {
  required String spaceId,
  TwinsEvent? existing,
  DateTime? day,
  String? itemId,
  String? chatId,
  String? initialTitle,
}) {
  return showTwinsBottomSheet<TwinsEvent>(
    context: context,
    title: existing == null ? 'New plan' : 'Edit plan',
    child: _EventEditor(
      spaceId: spaceId,
      existing: existing,
      day: day,
      itemId: itemId,
      chatId: chatId,
      initialTitle: initialTitle,
    ),
  );
}

class _EventEditor extends ConsumerStatefulWidget {
  final String spaceId;
  final TwinsEvent? existing;
  final DateTime? day;
  final String? itemId;
  final String? chatId;
  final String? initialTitle;

  const _EventEditor({
    required this.spaceId,
    this.existing,
    this.day,
    this.itemId,
    this.chatId,
    this.initialTitle,
  });

  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _date;
  late TimeOfDay _start;
  TimeOfDay? _end;
  late bool _allDay;
  int? _remind;
  String? _itemId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? widget.initialTitle ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _itemId = existing?.itemId ?? widget.itemId;
    if (existing != null) {
      _date = DateUtils.dateOnly(existing.startsAt);
      _start = TimeOfDay.fromDateTime(existing.startsAt);
      _end = existing.endsAt == null ? null : TimeOfDay.fromDateTime(existing.endsAt!);
      _allDay = existing.allDay;
      _remind = existing.remindMinutes;
    } else {
      // The next whole hour, on the chosen day (or today).
      final now = DateTime.now();
      final nextHour = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      _date = DateUtils.dateOnly(widget.day ?? (now.hour == 23 ? now.add(const Duration(days: 1)) : now));
      _start = widget.day != null && !DateUtils.isSameDay(widget.day, now) ? const TimeOfDay(hour: 20, minute: 0) : nextHour;
      _allDay = false;
      _remind = ref.read(planDefaultReminderProvider);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool end}) async {
    final picked = await showTimePicker(context: context, initialTime: end ? (_end ?? _start.replacing(hour: (_start.hour + 1) % 24)) : _start);
    if (picked == null) return;
    setState(() => end ? _end = picked : _start = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showTwinsToast(context, 'Give the plan a name', isError: true);
      return;
    }
    final startsAt = _allDay ? _date : _at(_start);
    DateTime? endsAt;
    if (!_allDay && _end != null) {
      endsAt = _at(_end!);
      if (!endsAt.isAfter(startsAt)) endsAt = endsAt.add(const Duration(days: 1));
    }
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    try {
      final existing = widget.existing;
      final saved = existing == null
          ? await repo.createEvent(
              spaceId: widget.spaceId,
              title: title,
              startsAt: startsAt,
              endsAt: endsAt,
              allDay: _allDay,
              remindMinutes: _remind,
              notes: _notes.text.trim(),
              itemId: _itemId,
              chatId: widget.chatId,
            )
          : await repo.updateEvent(existing.copyWith(
              title: title,
              notes: _notes.text.trim(),
              startsAt: startsAt,
              endsAt: endsAt,
              clearEndsAt: endsAt == null,
              allDay: _allDay,
              remindMinutes: _remind,
              clearReminder: _remind == null,
              itemId: _itemId,
              clearItem: _itemId == null,
            ));
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showTwinsToast(context, "Couldn't save the plan", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final item = _itemId == null ? null : ref.watch(itemByIdProvider(_itemId!)).valueOrNull;

    Widget row({required IconData icon, required String label, required VoidCallback onTap, Widget? trailing}) {
      return InkWell(
        borderRadius: TwinsRadius.smRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: TwinsColors.mikuGreen),
              const SizedBox(width: TwinsSpacing.sm),
              Expanded(child: Text(label, style: TwinsTypography.body(palette.textPrimary))),
              ?trailing,
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.existing == null && (widget.initialTitle ?? '').isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What are we doing?'),
            ),
            const SizedBox(height: TwinsSpacing.sm),
            row(
              icon: PhosphorIconsBold.sun,
              label: 'All day',
              onTap: () => setState(() => _allDay = !_allDay),
              trailing: Switch(
                value: _allDay,
                activeTrackColor: TwinsColors.mikuGreen,
                onChanged: (v) => setState(() => _allDay = v),
              ),
            ),
            row(icon: PhosphorIconsBold.calendarBlank, label: formatDayLabel(_date), onTap: _pickDate),
            if (!_allDay) ...[
              row(
                icon: PhosphorIconsBold.clock,
                label: _end == null
                    ? formatClockTime(_at(_start))
                    : '${formatClockTime(_at(_start))} – ${formatClockTime(_at(_end!))}',
                onTap: () => _pickTime(end: false),
                trailing: _end == null
                    ? TextButton(onPressed: () => _pickTime(end: true), child: const Text('Add end'))
                    : IconButton(
                        tooltip: 'Remove end time',
                        icon: Icon(Icons.close, size: 18, color: palette.textSecondary),
                        onPressed: () => setState(() => _end = null),
                      ),
              ),
            ],
            const SizedBox(height: TwinsSpacing.sm),
            Text('Remind us', style: TwinsTypography.label(palette.textSecondary)),
            const SizedBox(height: TwinsSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final choice in planReminderChoices)
                  TwinsFilterChip(
                    label: choice == null ? 'None' : choice == 0 ? 'At the time' : formatLeadTime(choice),
                    selected: _remind == choice,
                    onTap: () => setState(() => _remind = choice),
                  ),
              ],
            ),
            if (item != null) ...[
              const SizedBox(height: TwinsSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.sm, vertical: 6),
                decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: TwinsRadius.smRadius),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsBold.paperclip, size: 16, color: TwinsColors.mikuGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TwinsTypography.body(palette.textPrimary, size: 13)),
                    ),
                    IconButton(
                      tooltip: 'Unlink',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 16, color: palette.textSecondary),
                      onPressed: () => setState(() => _itemId = null),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: TwinsSpacing.md),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Notes (where, what to bring…)'),
            ),
            const SizedBox(height: TwinsSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : widget.existing == null ? 'Add to our calendar' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
