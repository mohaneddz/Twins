import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:twins/data/mock/mock_repository.dart';
import 'package:twins/main.dart';
import 'package:twins/state/repository_provider.dart';

void main() {
  testWidgets('App boots into the seeded space when the repository is mocked', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(MockTwinsRepository())],
      child: const TwinsApp(),
    ));
    // Avoid pumpAndSettle: the dashboard's shimmer skeletons and network
    // thumbnails animate/retry indefinitely under the test harness's
    // stubbed HttpClient, which would never let pumpAndSettle converge.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The mock repository starts pre-authenticated with seeded data, so the
    // whole shell renders without a Supabase project.
    expect(find.text('Hey twins! 👋'), findsOneWidget);
    expect(find.text('Funny Reels 😂'), findsOneWidget);
  });
}
