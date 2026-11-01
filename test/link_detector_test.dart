import 'package:flutter_test/flutter_test.dart';
import 'package:twins/utils/link_detector.dart';

void main() {
  group('canonicalLink', () {
    test('mobile and share-param YouTube links become www watch links', () {
      expect(canonicalLink('https://m.youtube.com/watch?v=djV11Xbc914&list=RDdjV11Xbc914&pp=abc'),
          'https://www.youtube.com/watch?v=djV11Xbc914');
      expect(canonicalLink('https://youtu.be/djV11Xbc914?si=xyz'), 'https://www.youtube.com/watch?v=djV11Xbc914');
      expect(canonicalLink('https://music.youtube.com/watch?v=djV11Xbc914&feature=share'),
          'https://www.youtube.com/watch?v=djV11Xbc914');
    });

    test('keeps a start time and the shorts form', () {
      expect(canonicalLink('https://youtu.be/djV11Xbc914?t=42'), 'https://www.youtube.com/watch?v=djV11Xbc914&t=42');
      expect(canonicalLink('https://m.youtube.com/shorts/abcDEF12345?si=q'), 'https://www.youtube.com/shorts/abcDEF12345');
    });

    test('leaves other sites alone', () {
      expect(canonicalLink('https://www.tiktok.com/@a/video/1?is_from_webapp=1'),
          'https://www.tiktok.com/@a/video/1?is_from_webapp=1');
    });
  });

  group('linkFromSharedText', () {
    test('pulls the URL out of share text', () {
      expect(linkFromSharedText('Check this out! https://vm.tiktok.com/ZMabc123/ so funny'), 'https://vm.tiktok.com/ZMabc123/');
      expect(linkFromSharedText('Watch: https://m.youtube.com/watch?v=djV11Xbc914.'),
          'https://www.youtube.com/watch?v=djV11Xbc914');
    });

    test('text without a URL is kept as is', () {
      expect(linkFromSharedText('  just a note  '), 'just a note');
    });
  });
}
