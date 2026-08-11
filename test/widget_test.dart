import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:twins/main.dart';

void main() {
  testWidgets('App boots straight into the seeded mock space', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TwinsApp()));
    // Avoid pumpAndSettle: the dashboard's shimmer skeletons and network
    // thumbnails animate/retry indefinitely under the test harness's
    // stubbed HttpClient, which would never let pumpAndSettle converge.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Mock mode starts pre-authenticated with seeded data so the whole app
    // is explorable without Supabase credentials (see MockTwinsRepository).
    expect(find.text('Hey twins! 👋'), findsOneWidget);
    expect(find.text('Funny Reels 😂'), findsOneWidget);
  });
}
