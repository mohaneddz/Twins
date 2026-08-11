import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/models/item_type.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_twins.dart';
import '../../widgets/item_card.dart';
import '../../widgets/skeletons.dart';

class SearchScreen extends ConsumerStatefulWidget {
  /// Pre-fills the query (e.g. when arriving from a tapped tag chip).
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  ItemType? _filter;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _controller.text = q;
      _query = q;
    }
  }

  static const _filters = <String, ItemType?>{
    'All': null,
    'Reels': ItemType.reel,
    'Images': ItemType.image,
    'Notes': ItemType.note,
    'Docs': ItemType.document,
  };

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value);
    });
  }

  /// Commits a query to history. Only called on submit or when a suggestion is
  /// tapped - recording every debounced keystroke would fill the list with
  /// prefixes of whatever the user actually meant.
  Future<void> _commit(String value, String spaceId) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();
    setState(() => _query = trimmed);
    await ref.read(repositoryProvider).recordSearch(spaceId, trimmed);
    ref.invalidate(recentSearchesProvider(spaceId));
  }

  void _useSuggestion(String value, String spaceId) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _commit(value, spaceId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final spaceAsync = ref.watch(currentSpaceProvider);

    return Scaffold(
      body: SafeArea(
        child: spaceAsync.when(
          data: (space) {
            if (space == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(TwinsSpacing.lg, TwinsSpacing.sm, TwinsSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onChanged: _onChanged,
                          onSubmitted: (v) => _commit(v, space.id),
                          style: TwinsTypography.body(palette.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search our stuff...',
                            prefixIcon: Icon(PhosphorIconsBold.magnifyingGlass, size: 20, color: palette.textSecondary),
                            // Pill-shaped like the brand sheet's search field.
                            border: OutlineInputBorder(
                              borderRadius: TwinsRadius.pillRadius,
                              borderSide: BorderSide(color: palette.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: TwinsRadius.pillRadius,
                              borderSide: BorderSide(color: palette.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: TwinsRadius.pillRadius,
                              borderSide: const BorderSide(color: TwinsColors.mikuGreen, width: 1.6),
                            ),
                          ),
                        ),
                      ),
                      TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
                    ],
                  ),
                  const SizedBox(height: TwinsSpacing.md),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _filters.entries
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: TwinsFilterChip(
                                  label: e.key,
                                  selected: _filter == e.value,
                                  onTap: () => setState(() => _filter = e.value),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  if (_query.trim().isEmpty) _BrowseByTag(spaceId: space.id, onPick: (q) => _useSuggestion(q, space.id)),
                  const SizedBox(height: TwinsSpacing.md),
                  Expanded(
                    child: _query.trim().isEmpty
                        ? _RecentSearches(spaceId: space.id, onPick: (q) => _useSuggestion(q, space.id))
                        : _Results(spaceId: space.id, query: _query, type: _filter),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text("Couldn't search right now.", style: TwinsTypography.body(palette.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  final String spaceId;
  final String query;
  final ItemType? type;

  const _Results({required this.spaceId, required this.query, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.twins;
    final resultsAsync = ref.watch(
      searchResultsProvider(SearchQuery(spaceId: spaceId, query: query, type: type)),
    );

    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return const EmptyState(
            emoji: '🌀',
            title: 'Nothing in our chaos matches that.',
            subtitle: 'Try another word, or a different filter.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${results.length} ${results.length == 1 ? 'result' : 'results'}',
              style: TwinsTypography.label(palette.textSecondary, size: 13),
            ),
            const SizedBox(height: TwinsSpacing.sm),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: TwinsSpacing.xl),
                itemCount: results.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: TwinsSpacing.sm,
                  crossAxisSpacing: TwinsSpacing.sm,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  final item = results[index];
                  return ItemCard(item: item, onTap: () => context.push('/item/${item.id}'));
                },
              ),
            ),
          ],
        );
      },
      loading: () => const _ResultsSkeleton(),
      error: (e, _) => const EmptyState(
        emoji: '😵‍💫',
        title: "Couldn't search right now.",
        subtitle: 'Check your connection and try again.',
      ),
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: TwinsSpacing.sm,
        crossAxisSpacing: TwinsSpacing.sm,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, index) => TwinsSkeletonBox(radius: TwinsRadius.mdRadius, height: double.infinity),
    );
  }
}

class _RecentSearches extends ConsumerWidget {
  final String spaceId;
  final ValueChanged<String> onPick;

  const _RecentSearches({required this.spaceId, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.twins;
    final recentAsync = ref.watch(recentSearchesProvider(spaceId));

    return recentAsync.when(
      data: (recent) {
        if (recent.isEmpty) {
          return const EmptyState(
            emoji: '🔎',
            title: 'Search titles, notes, tags, and links',
            subtitle: 'Everything we saved, in one place.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent', style: TwinsTypography.heading(palette.textPrimary, size: 15)),
                TextButton(
                  onPressed: () async {
                    await ref.read(repositoryProvider).clearSearchHistory(spaceId);
                    ref.invalidate(recentSearchesProvider(spaceId));
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recent.length,
                itemBuilder: (context, index) {
                  final q = recent[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(PhosphorIconsRegular.clockCounterClockwise, size: 20, color: palette.textSecondary),
                    title: Text(q, style: TwinsTypography.body(palette.textPrimary)),
                    trailing: Icon(PhosphorIconsRegular.arrowUpLeft, size: 16, color: palette.textSecondary),
                    onTap: () => onPick(q),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const EmptyState(
        emoji: '🔎',
        title: 'Search titles, notes, tags, and links',
      ),
    );
  }
}

/// Quick chips over the space's tag catalog so tags are browsable, not just
/// typeable. Tapping one runs a search for that tag.
class _BrowseByTag extends ConsumerWidget {
  final String spaceId;
  final ValueChanged<String> onPick;

  const _BrowseByTag({required this.spaceId, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.twins;
    final tags = ref.watch(tagsProvider(spaceId)).valueOrNull ?? const [];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: TwinsSpacing.xs),
        Text('Browse by tag', style: TwinsTypography.heading(palette.textPrimary, size: 15)),
        const SizedBox(height: TwinsSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tags)
              ActionChip(
                avatar: CircleAvatar(backgroundColor: t.color, radius: 7),
                label: Text('#${t.name}'),
                visualDensity: VisualDensity.compact,
                onPressed: () => onPick(t.name),
              ),
          ],
        ),
      ],
    );
  }
}
