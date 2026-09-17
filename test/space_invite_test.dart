import 'package:flutter_test/flutter_test.dart';
import 'package:twins/data/models/space.dart';

SpaceInvite _invite({DateTime? expiresAt, DateTime? usedAt}) => SpaceInvite(
      id: 'invite-1',
      spaceId: 'space-1',
      code: '7HG2K9',
      createdBy: 'user-1',
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      usedAt: usedAt,
    );

void main() {
  group('SpaceInvite.isValid', () {
    test('is valid when unused and not yet expired', () {
      expect(_invite().isValid, isTrue);
    });

    test('is invalid once expired', () {
      final invite = _invite(expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(invite.isValid, isFalse);
    });

    test('is invalid once used, even if not expired', () {
      final invite = _invite(usedAt: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(invite.isValid, isFalse);
    });

    test('is invalid when both used and expired', () {
      final invite = _invite(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        usedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(invite.isValid, isFalse);
    });
  });
}
