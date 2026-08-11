import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twins/data/models/folder.dart';
import 'package:twins/theme/app_theme.dart';
import 'package:twins/theme/colors.dart';
import 'package:twins/widgets/folder_card.dart';

TwinsFolder _folder(String name, Color color, String icon, int count, {bool pinned = false}) {
  final now = DateTime(2026, 1, 1);
  return TwinsFolder(
    id: name,
    spaceId: 's',
    name: name,
    color: color,
    icon: icon,
    isPinned: pinned,
    createdBy: 'u',
    createdAt: now,
    updatedAt: now,
    itemCount: count,
  );
}

void main() {
  Widget harness(Brightness brightness) {
    final folders = [
      _folder('Funny Reels', TwinsColors.folderMint, '😂', 28, pinned: true),
      _folder('Date Ideas', TwinsColors.folderPink, '💕', 12),
      _folder('Travel Plans', TwinsColors.folderPurple, '✈️', 18),
      _folder('Random Stuff', TwinsColors.folderBlue, '🌀', 37),
      _folder('Our Playlist', TwinsColors.mikuGreen, '🎧', 1),
    ];
    return MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [
              ...folders.map((f) => FolderCard(folder: f)),
              AddFolderCard(onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('folder cards - light', (tester) async {
    tester.view.physicalSize = const Size(780, 1000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(Brightness.light));
    await tester.pumpAndSettle();
    await expectLater(find.byType(GridView), matchesGoldenFile('goldens/folders_light.png'));
  });

  testWidgets('folder silhouette - large', (tester) async {
    tester.view.physicalSize = const Size(640, 340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 260,
                height: 220,
                child: FolderCard(folder: _folder('Date Ideas', TwinsColors.folderMint, '', 12)),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 260,
                height: 220,
                child: FolderCard(folder: _folder('Funny Reels', TwinsColors.mikuGreen, '', 28)),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/folder_shape.png'));
  });

  testWidgets('folder cards - dark', (tester) async {
    tester.view.physicalSize = const Size(780, 1000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(Brightness.dark));
    await tester.pumpAndSettle();
    await expectLater(find.byType(GridView), matchesGoldenFile('goldens/folders_dark.png'));
  });
}
