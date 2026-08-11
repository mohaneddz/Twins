import 'package:flutter_test/flutter_test.dart';
import 'package:twins/data/mock/mock_repository.dart';
import 'package:twins/data/mock/mock_seed.dart';
import 'package:twins/data/models/item_type.dart';

void main() {
  late MockTwinsRepository repo;

  setUp(() => repo = MockTwinsRepository());

  group('searchItems', () {
    test('ranks a title match above a body-only match', () async {
      final results = await repo.searchItems(MockSeed.spaceId, 'room');
      expect(results, isNotEmpty);
      // "aesthetic room inspo" / "room lighting ideas" carry the word in the
      // title, so they must come before anything that only mentions it in a
      // description or note body.
      expect(results.first.title.toLowerCase(), contains('room'));
    });

    test('matches case-insensitively', () async {
      final lower = await repo.searchItems(MockSeed.spaceId, 'room');
      final upper = await repo.searchItems(MockSeed.spaceId, 'ROOM');
      expect(upper.map((e) => e.id).toList(), lower.map((e) => e.id).toList());
    });

    test('narrows to a single item type when asked', () async {
      final all = await repo.searchItems(MockSeed.spaceId, 'room');
      final notesOnly = await repo.searchItems(MockSeed.spaceId, 'room', type: ItemType.note);
      expect(notesOnly.every((i) => i.type == ItemType.note), isTrue);
      expect(notesOnly.length, lessThanOrEqualTo(all.length));
    });

    test('finds items by their folder name', () async {
      // "Big Sur Road Trip" lives in the Travel folder; searching the folder
      // name should surface its contents even though the word is not in the
      // item's own text.
      final results = await repo.searchItems(MockSeed.spaceId, 'travel');
      expect(results, isNotEmpty);
    });

    test('returns nothing for a blank query', () async {
      expect(await repo.searchItems(MockSeed.spaceId, '   '), isEmpty);
    });

    test('respects the limit', () async {
      final results = await repo.searchItems(MockSeed.spaceId, 'a', limit: 2);
      expect(results.length, lessThanOrEqualTo(2));
    });

    test('does not leak items from another space', () async {
      final results = await repo.searchItems('some-other-space', 'room');
      expect(results, isEmpty);
    });
  });

  group('search history', () {
    test('records queries newest first', () async {
      await repo.recordSearch(MockSeed.spaceId, 'ramen');
      await repo.recordSearch(MockSeed.spaceId, 'room');
      expect(await repo.recentSearches(MockSeed.spaceId), ['room', 'ramen']);
    });

    test('de-duplicates and floats a repeated query to the top', () async {
      await repo.recordSearch(MockSeed.spaceId, 'ramen');
      await repo.recordSearch(MockSeed.spaceId, 'room');
      await repo.recordSearch(MockSeed.spaceId, 'ramen');
      expect(await repo.recentSearches(MockSeed.spaceId), ['ramen', 'room']);
    });

    test('ignores blank queries', () async {
      await repo.recordSearch(MockSeed.spaceId, '   ');
      expect(await repo.recentSearches(MockSeed.spaceId), isEmpty);
    });

    test('clears history', () async {
      await repo.recordSearch(MockSeed.spaceId, 'ramen');
      await repo.clearSearchHistory(MockSeed.spaceId);
      expect(await repo.recentSearches(MockSeed.spaceId), isEmpty);
    });
  });
}
