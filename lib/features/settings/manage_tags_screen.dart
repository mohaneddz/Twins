import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/twins_input.dart';

/// The space's tag catalog: the list ¡Twins! auto-tags from. The pair curates
/// it here; the AI reuses these first before inventing new ones.
class ManageTagsScreen extends ConsumerStatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  ConsumerState<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends ConsumerState<ManageTagsScreen> {
  final _controller = TextEditingController();
  bool _adding = false;

  static const _palette = [
    0xFF7EE7E1, 0xFFF6A5C0, 0xFFFFCC80, 0xFF90CAF9, 0xFFB39DDB, 0xFF80CBC4,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add(String spaceId, int existingCount) async {
    final name = _controller.text.trim().toLowerCase();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    await ref.read(repositoryProvider).createTag(spaceId, name, _palette[existingCount % _palette.length]);
    _controller.clear();
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final spaceAsync = ref.watch(currentSpaceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: spaceAsync.when(
        data: (space) {
          if (space == null) return const SizedBox.shrink();
          final tags = ref.watch(tagsProvider(space.id)).valueOrNull ?? const [];
          return ListView(
            padding: const EdgeInsets.all(TwinsSpacing.lg),
            children: [
              Text(
                'These are the tags ¡Twins! picks from automatically when you save '
                'something. Add your own — the AI reuses these before inventing new ones.',
                style: TwinsTypography.body(palette.textSecondary, size: 13),
              ),
              const SizedBox(height: TwinsSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TwinsInput(
                      hint: 'Add a tag (e.g. recipes)',
                      controller: _controller,
                    ),
                  ),
                  const SizedBox(width: TwinsSpacing.sm),
                  IconButton.filled(
                    onPressed: _adding ? null : () => _add(space.id, tags.length),
                    icon: const Icon(PhosphorIconsBold.plus),
                  ),
                ],
              ),
              const SizedBox(height: TwinsSpacing.lg),
              if (tags.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: TwinsSpacing.xl),
                  child: Text('No tags yet.', style: TwinsTypography.body(palette.textSecondary)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      Chip(
                        label: Text('#${t.name}'),
                        avatar: CircleAvatar(backgroundColor: t.color, radius: 7),
                        onDeleted: () => ref.read(repositoryProvider).deleteTag(t.id),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SizedBox.shrink(),
      ),
    );
  }
}
