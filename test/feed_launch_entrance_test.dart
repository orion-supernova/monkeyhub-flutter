import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_store.dart';

void main() {
  test('the board appears in place once, only when the app opened onto it', () {
    final store = FeedStore.instance;
    store.noteShellLaunch(true);
    // A later shell mount (sign-out, sign-in) never re-decides.
    store.noteShellLaunch(false);
    expect(store.takeLaunchEntrance(), isTrue);
    // Coming back to the tab staggers in as before.
    expect(store.takeLaunchEntrance(), isFalse);
    store.noteShellLaunch(true);
    expect(store.takeLaunchEntrance(), isFalse);
  });
}
