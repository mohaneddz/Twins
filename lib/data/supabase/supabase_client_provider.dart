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
const _prefsSetupDoneKey = 'twins_setup_done';

bool get isSpecialBuild => _buildTimeUrl.isNotEmpty && _buildTimePublishableKey.isNotEmpty;

/// Whether this device already finished first-launch setup: the project is
/// known and its database was checked (or installed) for this app version.
/// A special build still goes through setup once, so an empty project baked
/// into it gets installed too.
Future<bool> get isSetupComplete async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_prefsSetupDoneKey) ?? false;
}

/// Values to prefill the setup screen with: the baked-in ones for a special
/// build, otherwise whatever was saved last time.
Future<({String url, String publishableKey})> get knownSupabaseConfig async {
  if (isSpecialBuild) return (url: _buildTimeUrl, publishableKey: _buildTimePublishableKey);
  final prefs = await SharedPreferences.getInstance();
  return (url: prefs.getString(_prefsUrlKey) ?? '', publishableKey: prefs.getString(_prefsPublishableKeyKey) ?? '');
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

/// Called by the setup screen once the project is reachable and its schema
/// is current.
Future<void> completeSetup({required String url, required String publishableKey}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsUrlKey, url);
  await prefs.setString(_prefsPublishableKeyKey, publishableKey);
  await prefs.setBool(_prefsSetupDoneKey, true);
}

SupabaseClient get supa => Supabase.instance.client;
