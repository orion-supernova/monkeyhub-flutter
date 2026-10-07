import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_user.dart';

/// The visibility screen must show what the server enforces. An absent key is
/// `DEFAULT_LEVEL` in backend/convex/visibility.ts — public avatar, friends for
/// the rest — and the screen used to draw it as "Nobody" while the server
/// treated avatar/status/last seen as public.
void main() {
  test('absent keys read as the server defaults', () {
    final v = ProfileVisibility.fromJson(const {});
    expect(v.avatar, FieldVisibility.public);
    expect(v.status, FieldVisibility.friends);
    expect(v.lastSeen, FieldVisibility.friends);
    expect(v.seen, FieldVisibility.friends);
    expect(v.friendRequests, FieldVisibility.public);
    expect(v.feed, FieldVisibility.friends);
    expect(v.pointsPast, FieldVisibility.nobody);
  });

  test('stored values win, unknown values fail closed', () {
    final v = ProfileVisibility.fromJson(
        const {'seen': 'nobody', 'avatar': 'nobody', 'status': 'bogus'});
    expect(v.seen, FieldVisibility.nobody);
    expect(v.avatar, FieldVisibility.nobody);
    expect(v.status, FieldVisibility.nobody);
  });
}
