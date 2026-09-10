import 'package:supabase_flutter/supabase_flutter.dart';

/// Public project values - safe to ship in the client bundle (that's what
/// publishable/anon keys are for; access is enforced by RLS, not secrecy).
/// The admin secret key never appears here or anywhere in lib/.
const _supabaseUrl = 'https://lgxfmapeuwvltgeixnib.supabase.co';
const _supabasePublishableKey = 'sb_publishable_NO-uxIHf6yL3I6Ja_1CMcQ_HbdDil-1';

Future<void> initSupabase() async {
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabasePublishableKey);
}

SupabaseClient get supa => Supabase.instance.client;
