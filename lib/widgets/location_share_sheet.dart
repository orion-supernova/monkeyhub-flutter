import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/location_share.dart';
import '../services/location_service.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'location_address.dart';
import 'location_map_preview.dart';
import 'ios_kit.dart' show GroupedRow, TileTone;
import 'sheet_kit.dart';
import '../l10n/text_case.dart';

/// What the user picked in the location sheet.
///
/// A duration or the absence of one, rather than a mode plus an optional
/// duration, so "live with no duration" is not a value that can be constructed
/// — which is the shape of the bug this feature must not have.
class LocationShareChoice {
  const LocationShareChoice.now() : duration = null, choosePlace = false;
  const LocationShareChoice.live(LiveShareDuration this.duration)
    : choosePlace = false;

  /// Pick any spot on a map (or by search) and send that, once.
  const LocationShareChoice.choose() : duration = null, choosePlace = true;

  /// Null means one fix, sent once.
  final LiveShareDuration? duration;
  final bool choosePlace;

  bool get isLive => duration != null;
}

/// Asks whether to send one position or share live, and for how long.
///
/// Deliberately a single sheet rather than a menu that opens a second one. The
/// difference between the two modes is one line of text each, and burying the
/// durations a tap deeper made the safe option (a fixed 15 minutes) the
/// expensive one to reach.
///
/// No "until I turn it off" row. Every duration here ends by itself; the
/// server enforces it and cannot be asked for more. That is the feature.
///
/// [allowLive] is false in a Chamber of Secrets room, where every message
/// carries the room's own self-destruct deadline. Two clocks on one row is a
/// promise the app cannot keep — a 60-second room lifetime would delete an
/// eight-hour share after a minute — so the server refuses live shares there
/// and downgrades them to a static pin. Hiding the rows is what stops the user
/// picking a duration they will not get; the server's refusal is the backstop,
/// not the mechanism.
Future<LocationShareChoice?> showLocationShareSheet(
  BuildContext context, {
  bool allowLive = true,
}) {
  return showAdaptiveSheet<LocationShareChoice>(
    context,
    builder: (_) => _LocationSheet(allowLive: allowLive),
  );
}

class _LocationSheet extends StatelessWidget {
  const _LocationSheet({required this.allowLive});

  final bool allowLive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    String durationLabel(LiveShareDuration d) => switch (d) {
          LiveShareDuration.fifteenMinutes => l10n.locationShareFor15Minutes,
          LiveShareDuration.oneHour => l10n.locationShareFor1Hour,
          LiveShareDuration.eightHours => l10n.locationShareFor8Hours,
        };

    void pick(LocationShareChoice c) {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop(c);
    }

    // Titled like every sheet, so it carries the × too — it used to open as
    // a bare group with no way out but a swipe.
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.attachmentMenuLocationLabel),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CurrentSpot(),
          SheetRise(
            child: SheetGroup(
              children: [
                GroupedRow(
                  icon: CupertinoIcons.location_fill,
                  tone: TileTone.blue,
                  title: l10n.locationSheetSendCurrent,
                  subtitle: l10n.locationSheetSendCurrentDetail,
                  chevron: false,
                  onTap: () => pick(const LocationShareChoice.now()),
                ),
                GroupedRow(
                  icon: CupertinoIcons.map_pin_ellipse,
                  tone: TileTone.orange,
                  title: l10n.locationSheetChoosePlace,
                  subtitle: l10n.locationSheetChoosePlaceDetail,
                  onTap: () => pick(const LocationShareChoice.choose()),
                ),
              ],
            ),
          ),
          if (allowLive) ...[
            const SizedBox(height: 22),
            SheetRise(
              index: 1,
              child: SheetGroup(
                header: l10n.locationSheetLiveHeading,
                children: [
                  for (final d in LiveShareDuration.values)
                    GroupedRow(
                      icon: CupertinoIcons.dot_radiowaves_left_right,
                      tone: TileTone.green,
                      title: durationLabel(d),
                      // Restated on every row rather than once above them,
                      // because this is the promise the feature makes and
                      // each row is a separate act of making it.
                      subtitle: l10n.locationSheetLiveDetail,
                      chevron: false,
                      onTap: () => pick(LocationShareChoice.live(d)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where "Send your current location" would put you, on a small map with the
/// street under it, so you see what you are about to send.
///
/// Only when location is already allowed: this sheet opens before any
/// permission is asked (see `_shareLocation` in the room), and a preview must
/// not be the thing that asks. Uses the last known position, which costs no
/// GPS fix; the send itself still takes a fresh one.
class _CurrentSpot extends StatefulWidget {
  const _CurrentSpot();

  @override
  State<_CurrentSpot> createState() => _CurrentSpotState();
}

class _CurrentSpotState extends State<_CurrentSpot> {
  LocationFix? _fix;
  ({String title, String subtitle})? _address;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = LocationService.instance;
    try {
      if (await service.check() != LocationAvailability.ready) return;
      final fix = await service.lastKnownFix();
      if (!mounted || fix == null) return;
      setState(() {
        _fix = fix;
        _address = LocationAddress.peek(fix.latitude, fix.longitude);
      });
      final r = await LocationAddress.lookup(fix.latitude, fix.longitude);
      if (mounted && r != null) setState(() => _address = r);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final fix = _fix;
    if (fix == null) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final address = _address;
    final line = address == null
        ? formatCoordinates(fix.latitude, fix.longitude)
        : [address.title, address.subtitle]
              .where((s) => s.isNotEmpty)
              .join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 128,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LocationMapPreview(
                theme: theme,
                latitude: fix.latitude,
                longitude: fix.longitude,
                accuracyM: fix.accuracyM,
                bare: true,
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.45, 1],
                        colors: [Color(0x00000000), Color(0xB3000000)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 9,
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFFFFF),
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains what "Always" buys before the OS asks for it, and offers the choice.
///
/// Shown once per install, at the moment a live share starts, and never again —
/// see `LiveShareResumeStore.hasOfferedAlwaysUpgrade`. The three rules this
/// encodes are the whole difference between a permission flow people accept and
/// one they resent:
///
///  * **After the choice, not before it.** A user who has just decided to be
///    findable for the next eight hours has every piece of context needed to
///    answer this. The same person at first launch has none.
///  * **Both answers work.** Declining is not a degraded state with a warning
///    triangle. The share still keeps publishing when the app is backgrounded —
///    that needs no Always at all — and the only thing given up is being picked
///    back up after a force-quit or a reboot. So the second row says what it
///    does rather than what it lacks.
///  * **Asked once.** The flag is set when this sheet is SHOWN, not when the
///    permission is granted, so a considered "no" is never re-litigated. The
///    Settings app remains for anybody who changes their mind.
///
/// Returns true if the user asked for background sharing. On iOS a true answer
/// leads to a system prompt that may show nothing at all right now and instead
/// arrive later as "Keep Only While Using / Change to Always" — see
/// `LiveLocationPlatform.requestAlwaysAuthorization`. That is by design and this
/// sheet promises nothing more specific than "we'll ask".
Future<bool> showLiveShareBackgroundSheet(BuildContext context) async {
  final res = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => const _BackgroundUpgradeSheet(),
  );
  // A dismissed sheet is a no. Not asking is the same answer as declining, and
  // treating a swipe-away as consent to a background permission would be the
  // single worst thing this file could do.
  return res ?? false;
}

class _BackgroundUpgradeSheet extends StatelessWidget {
  const _BackgroundUpgradeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.locationBackgroundSheetTitle),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.locationBackgroundSheetBody,
            textAlign: TextAlign.center,
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
          ),
          const SizedBox(height: 18),
          SheetGroup(
            children: [
              GroupedRow(
                icon: CupertinoIcons.dot_radiowaves_left_right,
                tone: TileTone.green,
                title: l10n.locationBackgroundSheetKeepRunning,
                subtitle: l10n.locationBackgroundSheetKeepRunningDetail,
                chevron: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(true);
                },
              ),
              GroupedRow(
                icon: CupertinoIcons.app_fill,
                tone: TileTone.gray,
                title: l10n.locationBackgroundSheetAppOnly,
                subtitle: l10n.locationBackgroundSheetAppOnlyDetail,
                chevron: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(false);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
