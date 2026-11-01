import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/twin_slot.dart';
import '../../state/repository_provider.dart';
import '../../widgets/toast.dart';

/// Accounts have no email to recover through, so a signed-in twin sets a
/// new password for whichever of the two forgot theirs.
Future<void> showResetTwinPasswordDialog(BuildContext context, WidgetRef ref) async {
  final slots = await ref.read(repositoryProvider).twinSlots();
  if (!context.mounted) return;
  final message = await showDialog<String>(
    context: context,
    builder: (context) => _ResetTwinPasswordDialog(slots: slots),
  );
  if (message != null && context.mounted) showTwinsToast(context, message);
}

class _ResetTwinPasswordDialog extends ConsumerStatefulWidget {
  final List<TwinSlot> slots;

  const _ResetTwinPasswordDialog({required this.slots});

  @override
  ConsumerState<_ResetTwinPasswordDialog> createState() => _ResetTwinPasswordDialogState();
}

class _ResetTwinPasswordDialogState extends ConsumerState<_ResetTwinPasswordDialog> {
  final _password = TextEditingController();
  late int _slot = widget.slots.length > 1 ? widget.slots[1].slot : widget.slots.first.slot;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 6) {
      setState(() => _error = 'Use at least 6 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).resetTwinPassword(slot: _slot, password: _password.text);
      final name = widget.slots.firstWhere((s) => s.slot == _slot).displayName;
      if (mounted) Navigator.pop(context, "$name's password is updated.");
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't update the password.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New password for'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final slot in widget.slots)
                ChoiceChip(
                  label: Text(slot.displayName),
                  selected: _slot == slot.slot,
                  onSelected: (_) => setState(() => _slot = slot.slot),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(hintText: 'New password', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
