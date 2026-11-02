import 'package:flutter_test/flutter_test.dart';
import 'package:twins/data/supabase/invite_link.dart';

void main() {
  const url = 'https://abcdefgh.supabase.co';
  const key = 'sb_publishable_ABC-123_xyz';

  test('a built invite parses back to the same project', () {
    final invite = parseInvite(buildInviteLink(url: url, publishableKey: key));
    expect(invite?.url, url);
    expect(invite?.publishableKey, key);
  });

  test('finds the link inside a shared message', () {
    final message = 'Join me on Twins! Open this: ${buildInviteLink(url: url, publishableKey: key)} 💚';
    expect(parseInvite(message)?.url, url);
  });

  test('rejects text without a complete invite', () {
    expect(parseInvite('no link here'), isNull);
    expect(parseInvite('twins://join?u=$url'), isNull);
    expect(parseInvite('twins://join?u=http://insecure.example&k=$key'), isNull);
  });
}
