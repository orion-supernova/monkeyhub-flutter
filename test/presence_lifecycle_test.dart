import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/app.dart'
    show presenceStatusFor, presenceStatusOnAttach;

/// Guards the two states that must NOT write presence.
///
/// Both were writing before, and between them they produced the Android bug
/// this test exists to prevent coming back: the window losing and regaining
/// focus once a second turned into two `users` row writes a second, each one
/// invalidating every subscription that had read that row. The mapping reads
/// like a formality — which is exactly why someone would "tidy" `inactive` back
/// into the `away` arm without realising what it costs.
void main() {
  group('presenceStatusFor', () {
    test('resumed is the only state that reports online', () {
      expect(presenceStatusFor(AppLifecycleState.resumed), 'online');
    });

    test('a real background reports away', () {
      expect(presenceStatusFor(AppLifecycleState.paused), 'away');
    });

    test('hidden reports away everywhere except web', () {
      // Same flap, one state over. Flutter web fires `hidden` for a plain
      // window blur — address bar, alt-tab, devtools — so on web it carries no
      // more information than `inactive` does, and honouring it wrote
      // away/online six times in 84 seconds while the person sat reading the
      // page. On mobile `hidden` still means the app actually went away.
      //
      // Both arms are real: this file runs under `flutter test` (kIsWeb false)
      // and under `flutter test --platform chrome` (kIsWeb true).
      expect(
        presenceStatusFor(AppLifecycleState.hidden),
        kIsWeb ? isNull : 'away',
      );
    });

    test('inactive writes nothing — it is still foreground', () {
      // A notification-shade pull, an app-switcher peek, a permission dialog,
      // and on Android every window-focus change. ConnectionHealth already
      // counts this as foreground (see setForeground in app.dart); presence
      // has to agree or the two disagree inside one method.
      expect(presenceStatusFor(AppLifecycleState.inactive), isNull);
    });

    test('detached writes nothing — the engine outlives its Activity', () {
      // shouldDestroyEngineWithHost() is false, so detached means the engine
      // lost its host (routine when a call is answered through the callkit
      // relaunch), not that the app died. Claiming 'offline' here asserts
      // something we cannot know; the server's staleness sweep is the honest
      // detector for a client that actually went away.
      expect(presenceStatusFor(AppLifecycleState.detached), isNull);
    });

    test('every lifecycle state is handled', () {
      // The switch is exhaustive today. If Flutter adds a state, this fails
      // loudly here rather than silently defaulting to a write.
      for (final state in AppLifecycleState.values) {
        expect(
          () => presenceStatusFor(state),
          returnsNormally,
          reason: 'unhandled lifecycle state: $state',
        );
      }
    });
  });

  /// Guards the write that made being CALLED look like being present.
  ///
  /// `AppDelegate.didFinishLaunchingWithOptions` runs `engine.run()` on every
  /// iOS launch, including the background one an incoming VoIP push triggers.
  /// So a ringing phone runs the attach path headless, with nobody looking at
  /// it — and attach used to assert 'online' flat out. The callee turned green
  /// in the caller's UI having never opened the app, and stayed green because
  /// the presence heartbeat then kept `lastSeen` fresh underneath the lie.
  group('presenceStatusOnAttach', () {
    test('only a resumed app attaches as online', () {
      expect(presenceStatusOnAttach(AppLifecycleState.resumed), 'online');
    });

    test('a headless background launch attaches as away, not online', () {
      // THE regression. `detached` is what a VoIP-woken engine reports: it has
      // no host view controller, which is precisely what detached means. If
      // this ever returns 'online' again, ringing someone marks them present.
      expect(presenceStatusOnAttach(AppLifecycleState.detached), 'away');
    });

    test('an unknown lifecycle state attaches as away', () {
      // `lifecycleState` is null until the first platform lifecycle message
      // arrives, which on a background launch may be never. Null is the most
      // likely value at attach in exactly the case that matters, so it must
      // land on the conservative side rather than fall through to online.
      expect(presenceStatusOnAttach(null), 'away');
    });

    test('no state other than resumed reports online', () {
      for (final state in AppLifecycleState.values) {
        if (state == AppLifecycleState.resumed) continue;
        expect(
          presenceStatusOnAttach(state),
          'away',
          reason: '$state must not attach as online',
        );
      }
    });

    test('attach never stays silent the way a transition may', () {
      // The two mappings must NOT be collapsed into one. presenceStatusFor
      // returns null for inactive/detached meaning "nothing changed, don't
      // write" — safe only because a transition has a previous assertion
      // behind it. Attach has none: the stored status is whatever the last
      // session left, very often a stale 'online', and the heartbeat refreshes
      // lastSeen under it while users.heartbeat only refuses to resurrect
      // 'offline'. Saying nothing here would preserve the lie, not fix it.
      for (final state in AppLifecycleState.values) {
        expect(
          presenceStatusOnAttach(state),
          isNotNull,
          reason: 'attach must always assert a status, got null for $state',
        );
      }
      expect(presenceStatusOnAttach(null), isNotNull);
    });
  });
}
