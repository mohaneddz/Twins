import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/mock_repository.dart';
import '../data/repositories/twins_repository.dart';
import '../data/supabase/supabase_client_provider.dart';
import '../data/supabase/supabase_repository.dart';

/// Single source of truth for which backend the app is running against.
/// Falls back to the mock repository whenever Supabase env vars are missing
/// so the whole app stays explorable without credentials.
final repositoryProvider = Provider<TwinsRepository>((ref) {
  if (hasSupabaseCredentials) {
    return SupabaseTwinsRepository();
  }
  return MockTwinsRepository();
});

final isMockModeProvider = Provider<bool>((ref) => !hasSupabaseCredentials);
