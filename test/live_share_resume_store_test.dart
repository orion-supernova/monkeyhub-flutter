import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/location_share.dart';
import 'package:monkeyhub/services/live_share_resume_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The handle that makes surviving termination possible at all, and the key
/// names that make it readable from Kotlin.
///
/// Two things are pinned here that nothing else can pin. The first is that an
/// expired share never comes back — the one bug in this feature that would be
/// genuinely bad, because it means a phone reporting its position for a share
/// its owner believes ended. The second is the key names themselves: Android's
/// boot receiver reads these strings out of the `FlutterSharedPreferences` XML
/// before there is a Dart isolate to ask, so renaming one here silently breaks a
/// file in another language.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notice = LiveShareNotice(
    title: 'Sharing your live location',
    body: 'Tap to open the chat, or Stop to end it now',
    stopLabel: 'Stop sharing',
  );

  final t0 = DateTime.utc(2026, 8, 9, 14, 0);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  LiveShareHandle handle({Duration until = const Duration(hours: 1)}) =>
      LiveShareHandle(
        messageId: 'msg_123',
        roomId: 'room_456',
        expiresAt: t0.add(until),
        notice: notice,
      );

  test('a saved share comes back whole', () async {
    final store = LiveShareResumeStore();
    await store.save(handle());

    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.messageId, 'msg_123');
    expect(loaded.roomId, 'room_456');
    // Compared as an instant, not as a `DateTime`. The store round-trips
    // through epoch milliseconds and reads back in local time, matching how
    // `ChatMessage` parses the same field off the wire; `DateTime.==` would
    // call that a mismatch even though every comparison the publisher makes
    // (`isBefore`) is instant-based and correct.
    expect(
      loaded.expiresAt.millisecondsSinceEpoch,
      t0.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    // The copy travels with it so the notification can be posted by a process
    // that has no locale, no context and no widget tree.
    expect(loaded.notice.title, notice.title);
    expect(loaded.notice.stopLabel, notice.stopLabel);
  });

  test('nothing saved is nothing to resume', () async {
    expect(await LiveShareResumeStore().load(), isNull);
  });

  test('the key names are the contract Kotlin reads', () async {
    // `LiveLocationBootReceiver` looks these up under the `flutter.` prefix the
    // shared_preferences legacy API adds on Android. Changing one of these
    // strings without changing that file leaves a device that reboots mid-share
    // silently doing nothing.
    final store = LiveShareResumeStore();
    await store.save(handle());

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mh.liveShare.messageId'), 'msg_123');
    expect(prefs.getString('mh.liveShare.roomId'), 'room_456');
    expect(
      prefs.getInt('mh.liveShare.expiresAt'),
      t0.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    expect(prefs.getString('mh.liveShare.title'), notice.title);
    expect(prefs.getString('mh.liveShare.body'), notice.body);
    expect(prefs.getString('mh.liveShare.stopLabel'), notice.stopLabel);
  });

  group('resumability', () {
    test('a share still inside its window resumes', () async {
      final store = LiveShareResumeStore();
      await store.save(handle());
      final got = await store.takeResumable(
        t0.add(const Duration(minutes: 59)),
      );
      expect(got?.messageId, 'msg_123');
      // And is left on disk: the process could die again in the next second.
      expect(await store.load(), isNotNull);
    });

    test('a share past its deadline does not, and is erased', () async {
      final store = LiveShareResumeStore();
      await store.save(handle(until: const Duration(minutes: 15)));

      expect(await store.takeResumable(t0.add(const Duration(hours: 3))), isNull);
      // The erase is the point. A handle for an expired share is litter that
      // would be re-read on every launch forever, and every one of those reads
      // is a chance for a bug elsewhere to act on it.
      expect(await store.load(), isNull);
    });

    test('the deadline is exclusive, matching the bubble and the server', () {
      // `stateAt` on the bubble goes ENDED at exactly the deadline rather than
      // after it, and `updateLiveLocation` refuses a write at `liveExpiresAt <=
      // now`. A publisher that resumed on the tick would be publishing into a
      // share the other two consider finished.
      expect(handle().isResumableAt(t0.add(const Duration(hours: 1))), isFalse);
      expect(
        handle().isResumableAt(
          t0.add(const Duration(hours: 1) - const Duration(milliseconds: 1)),
        ),
        isTrue,
      );
    });

    test('a torn write is refused rather than resumed', () async {
      // The deadline is written last and read first, so a process killed
      // mid-save leaves an id with no stopping condition — which must read as
      // "nothing to do" rather than as a share that runs forever.
      SharedPreferences.setMockInitialValues({
        'mh.liveShare.messageId': 'msg_123',
        'mh.liveShare.roomId': 'room_456',
      });
      expect(await LiveShareResumeStore().load(), isNull);
    });

    test('missing notification copy still resumes', () async {
      // Cosmetic damage must not cost the share. An empty notification line is
      // a bad look; refusing to keep publishing because of it is a bug.
      SharedPreferences.setMockInitialValues({
        'mh.liveShare.messageId': 'msg_123',
        'mh.liveShare.roomId': 'room_456',
        'mh.liveShare.expiresAt':
            t0.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      });
      final loaded = await LiveShareResumeStore().load();
      expect(loaded?.messageId, 'msg_123');
      expect(loaded?.notice.title, '');
    });
  });

  test('clearing forgets the share but not that the user was asked', () async {
    final store = LiveShareResumeStore();
    await store.save(handle());
    await store.markAlwaysUpgradeOffered();

    await store.clear();

    expect(await store.load(), isNull);
    // The flag describes the person, not the share. Clearing it with the handle
    // would re-ask for background permission on every single live share, which
    // is the exact nagging the flag exists to prevent.
    expect(await store.hasOfferedAlwaysUpgrade(), isTrue);
  });

  test('a fresh install has not been asked', () async {
    expect(await LiveShareResumeStore().hasOfferedAlwaysUpgrade(), isFalse);
  });

  test('saving a second share replaces the first', () async {
    final store = LiveShareResumeStore();
    await store.save(handle());
    await store.save(LiveShareHandle(
      messageId: 'msg_999',
      roomId: 'room_999',
      expiresAt: t0.add(const Duration(hours: 8)),
      notice: notice,
    ));

    // One publisher, one share, one handle. A second handle left behind would
    // have a rebooted device resume a share the user superseded hours ago.
    final loaded = await store.load();
    expect(loaded?.messageId, 'msg_999');
    expect(loaded?.roomId, 'room_999');
  });
}
