import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twins/data/models/item.dart';
import 'package:twins/data/models/item_type.dart';
import 'package:twins/theme/app_theme.dart';
import 'package:twins/widgets/filter_chip_twins.dart';
import 'package:twins/widgets/item_card.dart';
import 'package:twins/widgets/twins_bottom_nav.dart';

TwinsItem _item(String title, ItemType type, {int reactions = 0, int comments = 0, String? content}) {
  final now = DateTime(2026, 1, 1);
  return TwinsItem(
    id: title,
    spaceId: 's',
    createdBy: 'u',
    type: type,
    title: title,
    content: content,
    createdAt: now,
    updatedAt: now,
    reactionCount: reactions,
    commentCount: comments,
  );
}

void main() {
  Widget harness(Brightness brightness) {
    return MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TwinsFilterChip(label: 'All', selected: true, onTap: () {}),
                    const SizedBox(width: 8),
                    TwinsFilterChip(label: 'Reels', selected: false, onTap: () {}),
                    const SizedBox(width: 8),
                    TwinsFilterChip(label: 'Notes', selected: false, onTap: () {}),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                    children: [
                      ItemCard(item: _item('this tiny bookstore vibes', ItemType.tiktok, reactions: 12, comments: 3)),
                      ItemCard(
                        item: _item('room lighting ideas', ItemType.note,
                            content: 'string lights over the bed, warm bulbs only, maybe a paper lantern'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: TwinsBottomNav(currentIndex: 0, onTap: (_) {}, onAddTap: () {}),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('item cards + chips + nav - ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(780, 1200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(brightness));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/components_${brightness.name}.png'),
      );
    });
  }
}
