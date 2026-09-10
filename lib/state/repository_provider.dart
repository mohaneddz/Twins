import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/twins_repository.dart';
import '../data/supabase/supabase_repository.dart';

final repositoryProvider = Provider<TwinsRepository>((ref) => SupabaseTwinsRepository());
