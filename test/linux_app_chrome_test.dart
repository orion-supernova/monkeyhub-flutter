import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/services/linux_app_chrome.dart';

void main() {
  String decide(bool? keep, bool tray, {List<int>? asked}) =>
      LinuxAppChrome.decideClose(
        keepRunning: keep,
        tray: tray,
        ask: () => asked?.add(1),
      );

  test('never decided, with a tray: hides, Steam-style, without asking', () {
    final asked = <int>[];
    expect(decide(null, true, asked: asked), 'hide');
    expect(asked, isEmpty);
  });

  test('never decided, no tray: asks, and leaves the window open meanwhile', () {
    final asked = <int>[];
    expect(decide(null, false, asked: asked), 'none');
    expect(asked, hasLength(1));
  });

  test('chose to keep running, no tray: minimizes', () {
    expect(decide(true, false), 'minimize');
  });

  test('chose to keep running, with a tray: hides', () {
    expect(decide(true, true), 'hide');
  });

  test('chose to quit: quits, tray or not', () {
    expect(decide(false, true), 'quit');
    expect(decide(false, false), 'quit');
  });
}
