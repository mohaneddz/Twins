import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/supabase/supabase_client_provider.dart';
import 'routing/app_router.dart';
import 'sharing/share_intent_service.dart';
import 'state/auth_providers.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional - the app falls back to mock mode without it.
  }
  await initSupabase();
  runApp(const ProviderScope(child: TwinsApp()));
}

class TwinsApp extends ConsumerStatefulWidget {
  const TwinsApp({super.key});

  @override
  ConsumerState<TwinsApp> createState() => _TwinsAppState();
}

class _TwinsAppState extends ConsumerState<TwinsApp> {
  @override
  void initState() {
    super.initState();
    ShareIntentService.instance.start();
    ShareIntentService.instance.sharedTextStream.listen(_handleIncomingShare);
  }

  Future<void> _handleIncomingShare(String text) async {
    final router = ref.read(routerProvider);
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) {
      // Not logged in yet - stash it and the home shell will pick it up
      // via consumePendingShare() once auth completes.
      await ShareIntentService.instance.stashPendingShare(text);
      return;
    }
    router.push('/add', extra: {'sharedText': text});
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '¡Twins!',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
