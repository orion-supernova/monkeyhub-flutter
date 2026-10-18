/// What the app says where a feature lives only in the apps.
///
/// MonkeyHub is mobile first. The browser and Linux are companions, and some
/// things they cannot do honestly:
///
///  * **Block a screenshot** (see [CaptureProtection.platformProtects]). A
///    view once message or a secret room is a promise made to the SENDER, so
///    on a platform that cannot keep it, it does not open at all. Warning the
///    reader about their own screenshots and then opening anyway kept nobody's
///    promise. Refusing costs nothing: the look is only spent by an open, so
///    the message is still sealed on the reader's phone.
///  * **Transcribe privately** (web only). Transcripts are made on the device
///    and the browser has no engine for that, so the button stays and says so.
///
/// One panel for all three, so they read as one rule rather than three
/// unrelated refusals: why not here, what the app does instead, and the way
/// to get it.
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/chat_repository.dart';
import '../data/ui_selection_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../screens/data_storage/usage_widgets.dart' show roomTitle;
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../update/update_destination.dart' show kDownloadPageUrl;
import '../widgets/adaptive_sheet.dart';
import '../widgets/glass_buttons.dart';
import '../widgets/ios_kit.dart' show GroupedRow, TileTone;
import '../widgets/sheet_kit.dart' show SheetActionButton, SheetFrame, SheetGroup;
import 'capture_protection.dart';

enum AppOnlyFeature { viewOnce, secretRoom, transcript }

class AppOnly {
  const AppOnly._();

  /// Whether secret rooms and view once messages stay closed here.
  static bool get gatesCapture => !CaptureProtection.platformProtects;

  /// Whether to go ahead and open a view once message: always where the
  /// platform blocks capture. Elsewhere the reader is told why not, and the
  /// look is kept.
  static Future<bool> confirmViewOnce(BuildContext context) async {
    if (!gatesCapture) return true;
    await _show(context, AppOnlyFeature.viewOnce);
    return false;
  }

  /// The transcript button's answer in a browser.
  static Future<void> explainTranscripts(BuildContext context) =>
      _show(context, AppOnlyFeature.transcript);

  static Future<void> _show(BuildContext context, AppOnlyFeature feature) {
    final l10n = AppLocalizations.of(context);
    return showAdaptiveSheet<void>(
      context,
      builder: (_) => SheetFrame(
        title: feature == AppOnlyFeature.transcript
            ? l10n.appOnlyTranscriptTitle
            : l10n.appOnlyViewOnceTitle,
        showClose: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: AppOnlyPanel(feature: feature, onSheet: true),
      ),
    );
  }
}

/// Which branch of the `{platform, select}` copy this device reads.
String get _platformKey => kIsWeb ? 'web' : 'linux';

/// Hero, the reason, the facts, and the way to the app.
class AppOnlyPanel extends StatelessWidget {
  const AppOnlyPanel({super.key, required this.feature, this.onSheet = false});

  final AppOnlyFeature feature;

  /// On a sheet, the title is in the bar. On the secret room page there is
  /// no bar, so the panel carries its own headline.
  final bool onSheet;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final blocked = GroupedRow(
      icon: CupertinoIcons.hand_raised_fill,
      tone: TileTone.blue,
      title: l10n.appOnlyBlockedInApp,
    );
    final (body, rows) = switch (feature) {
      AppOnlyFeature.viewOnce => (
          l10n.appOnlyViewOnceBody(_platformKey),
          [
            GroupedRow(
              icon: CupertinoIcons.lock_fill,
              tone: TileTone.gray,
              title: l10n.appOnlyViewOnceSealed,
            ),
            blocked,
          ],
        ),
      AppOnlyFeature.secretRoom => (
          l10n.appOnlySecretBody(_platformKey),
          [
            blocked,
            GroupedRow(
              icon: CupertinoIcons.timer,
              tone: TileTone.orange,
              title: l10n.appOnlySecretTimers,
            ),
          ],
        ),
      AppOnlyFeature.transcript => (
          l10n.appOnlyTranscriptBody,
          [
            GroupedRow(
              icon: CupertinoIcons.device_phone_portrait,
              tone: TileTone.blue,
              title: l10n.appOnlyTranscriptOnDevice,
            ),
            GroupedRow(
              icon: CupertinoIcons.lock_fill,
              tone: TileTone.gray,
              title: l10n.appOnlyTranscriptNoUpload,
            ),
            GroupedRow(
              icon: CupertinoIcons.wifi_slash,
              tone: TileTone.indigo,
              title: l10n.appOnlyTranscriptOffline,
            ),
          ],
        ),
    };
    // A phone browser is already on the phone: the code would have nobody to
    // scan it. On a computer it is the shortest way to the app.
    final qr = !context.isCompact;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _Hero(feature: feature)),
        const SizedBox(height: 16),
        if (!onSheet) ...[
          Text(
            l10n.appOnlySecretTitle,
            textAlign: TextAlign.center,
            style: theme.displaySmall.copyWith(color: theme.ink),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.body.copyWith(color: theme.inkSoft),
        ),
        const SizedBox(height: 22),
        SheetGroup(children: rows),
        const SizedBox(height: 22),
        if (qr) ...[
          const Center(child: _DownloadQr()),
          const SizedBox(height: 10),
          Text(
            l10n.appOnlyScanHint,
            textAlign: TextAlign.center,
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
          const SizedBox(height: 18),
        ],
        SheetActionButton(label: l10n.appOnlyGetApp, onTap: _openDownloads),
      ],
    );
  }

  static Future<void> _openDownloads() async {
    try {
      await launchUrl(
        Uri.parse(kDownloadPageUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('app only: downloads page did not open: $e');
    }
  }
}

/// The feature's own mark on an accent disc, the way the companion sheet
/// introduces its subject.
class _Hero extends StatelessWidget {
  const _Hero({required this.feature});

  final AppOnlyFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = theme.accentInk;
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
      child: switch (feature) {
        AppOnlyFeature.viewOnce =>
          Icon(CupertinoIcons.eye_slash_fill, size: 32, color: ink),
        AppOnlyFeature.secretRoom => theme.hourglassIcon(size: 32, color: ink),
        AppOnlyFeature.transcript =>
          Icon(CupertinoIcons.text_quote, size: 32, color: ink),
      },
    );
  }
}

class _DownloadQr extends StatelessWidget {
  const _DownloadQr();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        // White in every theme: scanners refuse a QR on a dark surface.
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: QrImageView(
        data: kDownloadPageUrl,
        version: QrVersions.auto,
        size: 132,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// What a secret room is on a platform that cannot block capture: this page,
/// in the room's place. The room itself is never mounted, so none of its
/// messages are fetched, rendered or marked read here.
class SecretRoomGate extends StatelessWidget {
  const SecretRoomGate({
    super.key,
    required this.room,
    required this.repo,
    this.inShellPane = false,
  });

  final ChatRoom room;
  final ChatRepository repo;
  final bool inShellPane;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    void back() => inShellPane
        ? UiSelectionStore.instance.selectRoom(null)
        : Navigator.of(context).maybePop();
    return PopScope(
      canPop: !inShellPane,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inShellPane) back();
      },
      child: Scaffold(
        backgroundColor: theme.background,
        body: Stack(
          children: [
            theme.backgroundLayer(context),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        GlassBackButton(onTap: back),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            roomTitle(l10n, repo, room),
                            style: theme.bodyEmph.copyWith(color: theme.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: const AppOnlyPanel(
                            feature: AppOnlyFeature.secretRoom,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
