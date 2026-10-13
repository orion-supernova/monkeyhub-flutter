import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether any call is up on this phone right now: ringing, connected or on
/// hold, ours or anybody's.
///
/// Two sources, OR'ed:
///   - the OS (`monkeyhub/phone_call`): CXCallObserver on iOS, the audio mode
///     on Android 12+. This is the one that sees a carrier call, a WhatsApp
///     call, and a call answered from the compact banner, none of which moves
///     the app out of `resumed`;
///   - the app's own call services, wired in by [attachAppCalls]. Already
///     covered on iOS by CallKit, but a desktop or simulator call raises no
///     native card at all.
///
/// Built for the daily games' clock (see `GamePlayController`), which pauses
/// on the edge into a call. Anything that wants to know "is the player on the
/// phone" can listen.
class PhoneCallActivity extends ChangeNotifier
    implements ValueListenable<bool> {
  PhoneCallActivity._();

  static final PhoneCallActivity instance = PhoneCallActivity._();

  static const _channel = MethodChannel('monkeyhub/phone_call');

  bool _native = false;
  bool _value = false;
  bool _listening = false;
  List<Listenable> _appSources = const [];
  bool Function()? _appInCall;

  @override
  bool get value => _value;

  /// Hooks the app's own call services in. Called once the call stack is
  /// attached; a later call replaces the earlier sources.
  void attachAppCalls(List<Listenable> sources, bool Function() inCall) {
    for (final s in _appSources) {
      s.removeListener(_recompute);
    }
    _appSources = sources;
    _appInCall = inCall;
    for (final s in sources) {
      s.addListener(_recompute);
    }
    _recompute();
  }

  /// Starts listening to the OS. Idempotent, and cheap to call on every board
  /// open: the native side only reports edges.
  void ensureListening() {
    if (_listening || kIsWeb) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
        _native = call.arguments == true;
        _recompute();
      }
    });
    _channel.invokeMethod<bool>('active').then(
      (active) {
        _native = active ?? false;
        _recompute();
      },
      // Desktop and tests have no native half. Not being able to tell is
      // the same as no call: the app's own services still count.
      onError: (Object _) {},
    );
  }

  void _recompute() {
    final next = _native || (_appInCall?.call() ?? false);
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }
}
