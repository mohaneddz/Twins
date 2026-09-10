import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A "special" build bakes these in at build time via
/// `--dart-define-from-file` (see scripts/build_special.ps1), reading from a
/// local, git-ignored .env - the source tree itself never contains real
/// project values. A "normal" build (plain `flutter build`/`flutter run`)
/// leaves these empty and falls back to values entered once at first launch
/// (see SupabaseSetupScreen) and cached in SharedPreferences.
const _buildTimeUrl = String.fromEnvironment('SUPABASE_URL');
const _buildTimePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

const _prefsUrlKey = 'twins_supabase_url';
const _prefsPublishableKeyKey = 'twins_supabase_publishable_key';

bool get isSpecialBuild => _buildTimeUrl.isNotEmpty && _buildTimePublishableKey.isNotEmpty;

/// Whether we already know where to connect - either this is a special
/// build, or someone completed first-launch setup on this device before.
Future<bool> get hasStoredSupabaseConfig async {
  if (isSpecialBuild) return true;
  final prefs = await SharedPreferences.getInstance();
  final url = prefs.getString(_prefsUrlKey);
  final key = prefs.getString(_prefsPublishableKeyKey);
  return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
}

/// Initializes Supabase from whichever source has values: build-time first,
/// then the first-launch setup screen's saved values.
Future<void> initSupabaseFromStoredConfig() async {
  var url = _buildTimeUrl;
  var key = _buildTimePublishableKey;
  if (url.isEmpty || key.isEmpty) {
    final prefs = await SharedPreferences.getInstance();
    url = prefs.getString(_prefsUrlKey) ?? '';
    key = prefs.getString(_prefsPublishableKeyKey) ?? '';
  }
  await Supabase.initialize(url: url, publishableKey: key);
}

/// Called by the first-launch setup screen once it has working values.
Future<void> saveSupabaseConfig({required String url, required String publishableKey}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsUrlKey, url);
  await prefs.setString(_prefsPublishableKeyKey, publishableKey);
}

SupabaseClient get supa => Supabase.instance.client;
