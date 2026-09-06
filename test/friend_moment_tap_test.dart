import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/ui_selection_store.dart';

/// A tapped friend-activity notification has to arrive somewhere specific.
///
/// The whole value of this push over a generic "something happened" is that it
/// names ONE card, and every link in that chain is a string agreed across four
/// languages: `socialPush.ts` writes `momentId` into the payload, the two
/// native handlers forward it as an `onOpenMoment` call on the
/// `monkeyhub/notifications` channel, and `PushManager` turns that back into a
/// Dart callback that hands the id to [UiSelectionStore].
///
/// The failure this guards is quiet in the worst way: the notification still
/// arrives, still reads correctly, and still opens the app. It just lands on
/// the Feed in general, which looks like the feature working to everybody
/// except the person who tapped it.
///
/// Split in two because the seam is: `PushManager` installs its channel
/// handler only on iOS and Android (`_pushSupported`), so a host test cannot
/// drive a platform message through it at all. The method NAME is therefore
/// checked the way `push_payload_contract_test.dart` checks the rest of this
/// contract — by grep, which is exactly the check a compiler cannot do across
/// Swift, Kotlin and Dart — and the behaviour underneath it is checked for
/// real.
void main() {
  // [UiSelectionStore] defers its notify through `SchedulerBinding.instance`,
  // which throws outright without a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  String source(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'missing $path');
    return file.readAsStringSync();
  }

  setUp(() {
    // The store is a singleton that outlives a test, and a one-shot left set
    // by one case is exactly the ambush the next one would blame on itself.
    UiSelectionStore.instance.consumeMoment();
  });

  test('every layer of the tap route spells onOpenMoment the same way', () {
    // Four files, three languages, one string. A rename in any of them is a
    // compile error in none — the tap just falls through to "raise the app".
    const route = 'onOpenMoment';
    for (final path in [
      'lib/push/push_manager.dart',
      'ios/Runner/AppDelegate.swift',
      'android/app/src/main/kotlin/com/walhallaa/chattest20241220/'
          'MainActivity.kt',
    ]) {
      expect(
        source(path).contains(route),
        isTrue,
        reason: '$path no longer mentions "$route" — a tapped highlight lands '
            'on the Feed instead of on the card it named, on that platform '
            'only, with nothing else changing',
      );
    }
    // The Dart end must also HANDLE it, not merely define the setter — a
    // `setOnOpenMoment` with no matching case in `_handleNotifCall` is a
    // callback nothing ever calls.
    final dart = source('lib/push/push_manager.dart');
    expect(dart.contains("case '$route':"), isTrue,
        reason: 'PushManager defines the handler but never dispatches to it');
  });

  test('the moment id is the argument, under the name native sends', () {
    // The native sides send `["momentId": id]`; Dart reads `args['momentId']`.
    // A mismatch here is a tap that routes correctly and then opens nothing.
    expect(
      source('lib/push/push_manager.dart').contains("args['momentId']"),
      isTrue,
    );
  });

  test('the id survives as a one-shot until something consumes it', () {
    // The Feed can mount well after the tap — on a cold start the notification
    // is handled before any widget exists — so this has to outlive widget
    // mounting rather than being delivered and dropped.
    UiSelectionStore.instance.requestMoment('moment-7');
    expect(UiSelectionStore.instance.momentIdPending, 'moment-7');

    expect(UiSelectionStore.instance.consumeMoment(), 'moment-7');
    // …and exactly once. A second reader must not open the same card again,
    // and a rebuild is a second reader.
    expect(UiSelectionStore.instance.consumeMoment(), isNull);
    expect(UiSelectionStore.instance.momentIdPending, isNull);
  });

  test('two taps before anything consumes them: the last one wins', () {
    // Somebody tapped the second banner. Steering them to the first would be
    // answering a question they have already changed their mind about.
    UiSelectionStore.instance.requestMoment('moment-7');
    UiSelectionStore.instance.requestMoment('moment-8');
    expect(UiSelectionStore.instance.consumeMoment(), 'moment-8');
  });

  test('the games one-shot is untouched by a moment tap', () {
    // Two different destinations sharing one store. A moment tap that also set
    // the games flag would open the hub on top of the card.
    UiSelectionStore.instance.requestMoment('moment-7');
    expect(UiSelectionStore.instance.gamesViewPending, isFalse);
    UiSelectionStore.instance.consumeMoment();
  });
}
