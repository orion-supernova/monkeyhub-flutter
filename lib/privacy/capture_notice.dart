import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../update/update_destination.dart' show kDownloadPageUrl;
import '../widgets/sheet_kit.dart';
import 'capture_protection.dart';

/// What the app says on a platform where it cannot block screen capture:
/// the browser and Linux (see [CaptureProtection.platformProtects]).
///
/// Everywhere else an ephemeral room or a view-once message is simply
/// protected and nothing needs saying. Here it is not, and the honest thing
/// is to say so at the two moments it matters, and to point at the apps
/// that do block it:
///
///  * **Entering an ephemeral room**, once per room per launch. Telling
///    someone on every visit stops being information and starts being noise.
///  * **Before a view-once message opens**, every time, because opening it
///    spends the one look. The reader decides before that happens, not after.
class CaptureNotice {
  const CaptureNotice._();

  static final _warnedRooms = <String>{};

  @visibleForTesting
  static void debugReset() => _warnedRooms.clear();

  /// Warns that this ephemeral room can be captured here. A no-op where the
  /// platform protects it, and after the first time for [roomId].
  static Future<void> warnRoomOnce(BuildContext context, String roomId) async {
    if (CaptureProtection.platformProtects) return;
    if (!_warnedRooms.add(roomId)) return;
    final l10n = AppLocalizations.of(context);
    final get = await showIosAlert<bool>(
      context,
      title: l10n.captureNoticeRoomTitle,
      message: l10n.captureNoticeRoomBody,
      actions: [
        IosAlertAction(label: l10n.captureNoticeGetApp, value: true),
        IosAlertAction(
          label: l10n.captureNoticeGotIt,
          value: false,
          cancel: true,
          preferred: true,
        ),
      ],
    );
    if (get == true) await _openDownloads();
  }

  /// Whether to go ahead and open a view-once message. Always true where the
  /// platform protects it; elsewhere the reader is asked first.
  static Future<bool> confirmViewOnce(BuildContext context) async {
    if (CaptureProtection.platformProtects) return true;
    final l10n = AppLocalizations.of(context);
    final choice = await showIosAlert<_ViewOnceChoice>(
      context,
      title: l10n.captureNoticeViewOnceTitle,
      message: l10n.captureNoticeViewOnceBody,
      actions: [
        IosAlertAction(
          label: l10n.captureNoticeOpenAnyway,
          value: _ViewOnceChoice.open,
        ),
        IosAlertAction(
          label: l10n.captureNoticeGetApp,
          value: _ViewOnceChoice.getApp,
        ),
        IosAlertAction(
          label: l10n.captureNoticeNotNow,
          value: _ViewOnceChoice.cancel,
          cancel: true,
        ),
      ],
    );
    if (choice == _ViewOnceChoice.getApp) await _openDownloads();
    return choice == _ViewOnceChoice.open;
  }

  static Future<void> _openDownloads() async {
    try {
      await launchUrl(
        Uri.parse(kDownloadPageUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('capture notice: downloads page did not open: $e');
    }
  }
}

enum _ViewOnceChoice { open, getApp, cancel }
