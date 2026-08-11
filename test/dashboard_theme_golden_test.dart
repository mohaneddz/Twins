import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twins/features/home/home_dashboard_screen.dart';
import 'package:twins/theme/app_theme.dart';

/// Renders the real dashboard under each theme. The screen used to pin itself
/// to navy regardless of the setting, so this is the regression guard for
/// "the light/dark toggle actually reaches the screens".
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // cached_network_image reaches for path_provider, which has no
    // implementation under `flutter test`; point it at the temp dir so the
    // thumbnail widgets can build. Images themselves still fail to load and
    // fall back to their placeholder, which is what these goldens capture.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('dashboard - ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(780, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
            home: const HomeDashboardScreen(),
          ),
        ),
      );
      // Avoid pumpAndSettle: shimmer skeletons and thumbnail retries never
      // quiesce under the test harness's stubbed HttpClient.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      await expectLater(
        find.byType(HomeDashboardScreen),
        matchesGoldenFile('goldens/dashboard_${brightness.name}.png'),
      );
    });
  }
}
