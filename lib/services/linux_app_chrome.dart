import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show rootNavigatorKey;
import '../widgets/destructive_sheet.dart' show showConfirmSheetChoice;

/// What the Linux window's close button does, and the tray it may hide to.
/// The macOS counterpart for its own chrome is [MacAppChrome].
///
/// Linux has no push service, so a quit app hears nothing until it is opened
/// again. Closing therefore keeps it running by default: hidden in the tray
/// when the desktop shows one (Steam's behaviour, and the native side's
/// `create_tray`), minimized when it does not. Minimizing on close is unusual
/// enough that it is never done unannounced — the first close on a desktop
/// with no tray asks, and the answer becomes
/// [SettingsStore.closeKeepsRunning], which Settings can change later.
///
/// The native side asks on every close (`window_delete_cb` in
/// linux/runner/my_application.cc) and carries out the answer; it falls back
/// to its own default if this never replies, so a close can't stop working.
class LinuxAppChrome extends ChangeNotifier {
  LinuxAppChrome._();
  static final LinuxAppChrome instance = LinuxAppChrome._();

  static const _ch = MethodChannel('monkeyhub/window');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  bool? _trayShown;

  /// Whether a tray icon is on screen, as of the last close or [load]. Null
  /// until one of them has answered; Settings words its row from this.
  bool? get trayShown => _trayShown;

  bool _asking = false;

  /// Starts answering the native side's close requests. Once, at startup.
  void install() {
    if (!isSupported) return;
    _ch.setMethodCallHandler(_onCall);
  }

  /// Re-reads [trayShown]; a tray can start or stop while the app runs.
  Future<void> load() async {
    if (!isSupported) return;
    try {
      _setTray(await _ch.invokeMethod<bool>('trayAvailable') ?? false);
    } catch (e) {
      debugPrint('LinuxAppChrome.load failed: $e');
    }
  }

  void _setTray(bool shown) {
    if (_trayShown == shown) return;
    _trayShown = shown;
    notifyListeners();
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'closeRequested') {
      throw MissingPluginException(call.method);
    }
    final args = call.arguments;
    final tray = args is Map && args['tray'] == true;
    _setTray(tray);
    return decideClose(
      keepRunning: SettingsStore.instance.closeKeepsRunning,
      tray: tray,
      ask: () => unawaited(_ask()),
    );
  }

  /// The close button's outcome, as the string the native side acts on.
  @visibleForTesting
  static String decideClose({
    required bool? keepRunning,
    required bool tray,
    required VoidCallback ask,
  }) {
    if (keepRunning == false) return 'quit';
    // Never decided reads as "keep running" when there is a tray to find the
    // app in again: that is what a tray app does, and nobody is surprised.
    if (tray) return 'hide';
    if (keepRunning == true) return 'minimize';
    ask();
    return 'none';
  }

  /// The one-time question. Dismissing it leaves the window open and the
  /// question unanswered, so the next close asks again.
  Future<void> _ask() async {
    if (_asking) return;
    _asking = true;
    try {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) {
        // Nothing on screen to ask with: close the way the app always has.
        await _ch.invokeMethod<void>('quit');
        return;
      }
      final l10n = AppLocalizations.of(ctx);
      final keep = await showConfirmSheetChoice(
        ctx,
        headline: l10n.linuxCloseTitle,
        body: l10n.linuxCloseBody,
        confirmLabel: l10n.linuxCloseKeep,
        cancelLabel: l10n.linuxCloseQuit,
        icon: CupertinoIcons.bell_fill,
        destructive: false,
      );
      if (keep == null) return;
      await SettingsStore.instance.setCloseKeepsRunning(keep);
      await _ch.invokeMethod<void>(keep ? 'minimize' : 'quit');
    } catch (e) {
      debugPrint('LinuxAppChrome: close prompt failed: $e');
    } finally {
      _asking = false;
    }
  }
}
