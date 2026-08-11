import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the client has enough config to talk to a real Supabase project.
/// The app falls back to [MockTwinsRepository] whenever this is false, so
/// development never blocks on missing credentials.
bool get hasSupabaseCredentials {
  if (!dotenv.isInitialized) return false;
  final url = dotenv.maybeGet('EXPO_PUBLIC_SUPABASE_URL') ?? dotenv.maybeGet('SUPABASE_URL');
  final key = dotenv.maybeGet('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY') ?? dotenv.maybeGet('SUPABASE_ANON_KEY');
  return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
}

Future<void> initSupabase() async {
  if (!hasSupabaseCredentials) return;
  final url = dotenv.get('EXPO_PUBLIC_SUPABASE_URL');
  final key = dotenv.get('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY');
  await Supabase.initialize(url: url, publishableKey: key);
}

SupabaseClient get supa => Supabase.instance.client;
