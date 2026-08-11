import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/profile.dart';
import '../data/models/space.dart';
import 'repository_provider.dart';

final authStateProvider = StreamProvider<Profile?>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.authState();
});

/// Resolves once auth is known: the current space (or null if the user
/// hasn't paired yet). Re-fetched whenever auth state changes.
final currentSpaceProvider = FutureProvider<TwinsSpace?>((ref) async {
  final auth = ref.watch(authStateProvider);
  final repo = ref.watch(repositoryProvider);
  return auth.when(
    data: (profile) => profile == null ? Future.value(null) : repo.currentSpace(),
    loading: () => Future.value(null),
    error: (_, __) => Future.value(null),
  );
});

final spaceMembersProvider = FutureProvider.family<List<Profile>, String>((ref, spaceId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.spaceMembers(spaceId);
});
