import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';

/// The section is persisted by `.name` and restored through [HomeSection.parse].
///
/// That parse used to be a hand-written switch with a `default:` returning
/// `chat`, so adding a member and forgetting its case compiled perfectly while
/// silently dumping everyone on that section back to Chat at every cold start —
/// no exception, no log, nothing to notice until a user reported it. This test
/// exists to fail the moment that can happen again.
void main() {
  group('HomeSection.parse', () {
    test('every member round-trips through its persisted name', () {
      for (final s in HomeSection.values) {
        expect(HomeSection.parse(s.name), s, reason: 'lost ${s.name}');
      }
    });

    test('discover in particular survives a restart', () {
      // Named explicitly: it's the member that was added, and the one the
      // silent-fallback bug would have swallowed.
      expect(HomeSection.parse('discover'), HomeSection.discover);
    });

    test('unknown and missing names fall back to chat', () {
      expect(HomeSection.parse(null), HomeSection.chat);
      expect(HomeSection.parse(''), HomeSection.chat);
      expect(HomeSection.parse('friends'), HomeSection.chat);
    });
  });
}
