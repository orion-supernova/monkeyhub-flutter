import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/web/web_tab_title.dart';
import 'package:monkeyhub/web/web_url_sync.dart';

void main() {
  group('WebLocation.parse', () {
    test('the chat list, sections and a chat', () {
      expect(WebLocation.parse('/'), WebLocation.home);
      expect(WebLocation.parse(''), WebLocation.home);
      expect(
        WebLocation.parse('/feed'),
        const WebLocation.section(HomeSection.feed),
      );
      expect(
        WebLocation.parse('/discover/'),
        const WebLocation.section(HomeSection.discover),
      );
      expect(
        WebLocation.parse('/settings'),
        const WebLocation.section(HomeSection.settings),
      );
      expect(
        WebLocation.parse('/c/k57abc123def'),
        const WebLocation.room('k57abc123def'),
      );
    });

    test('anything else is not ours', () {
      expect(WebLocation.parse('/c/'), isNull);
      expect(WebLocation.parse('/c/a/b'), isNull);
      expect(WebLocation.parse('/c/has space'), isNull);
      expect(WebLocation.parse('/chat'), isNull);
      expect(WebLocation.parse('feed'), isNull);
      expect(WebLocation.parse('room=abc'), isNull);
    });

    test('path round-trips', () {
      for (final loc in [
        WebLocation.home,
        const WebLocation.section(HomeSection.feed),
        const WebLocation.section(HomeSection.discover),
        const WebLocation.section(HomeSection.settings),
        const WebLocation.room('abc'),
      ]) {
        expect(WebLocation.parse(loc.path), loc);
      }
    });
  });

  group('WebLocation.of', () {
    test('split shell: the room is the location only on the Chat section', () {
      expect(
        WebLocation.of(
          section: HomeSection.chat,
          roomId: 'r1',
          paneShell: true,
        ).path,
        '/c/r1',
      );
      expect(
        WebLocation.of(
          section: HomeSection.feed,
          roomId: 'r1',
          paneShell: true,
        ).path,
        '/feed',
      );
    });

    test('phone: a selected room is on screen whatever tab is beneath', () {
      expect(
        WebLocation.of(
          section: HomeSection.feed,
          roomId: 'r1',
          paneShell: false,
        ).path,
        '/c/r1',
      );
      expect(
        WebLocation.of(
          section: HomeSection.discover,
          roomId: null,
          paneShell: false,
        ).path,
        '/discover',
      );
    });
  });

  group('WebTabTitle.compose', () {
    test('the count wins over the open chat', () {
      expect(WebTabTitle.compose(count: 3, room: 'Alice'), '(3) MonkeyHub');
    });

    test('the open chat names the tab when nothing is unread', () {
      expect(WebTabTitle.compose(count: 0, room: 'Alice'), 'Alice – MonkeyHub');
    });

    test('nothing open, nothing unread', () {
      expect(WebTabTitle.compose(count: 0), 'MonkeyHub');
      expect(WebTabTitle.compose(count: 0, room: '  '), 'MonkeyHub');
    });
  });
}
