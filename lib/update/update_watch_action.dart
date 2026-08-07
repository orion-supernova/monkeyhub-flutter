import '../models/app_release.dart';
import 'version_compare.dart';

/// What one delivery from `UpdateChecker.watch`'s subscription should cause.
enum UpdateWatchAction {
  /// Leave whatever we already knew alone.
  ignore,

  /// Retract a previously reported update.
  clearBadge,

  /// Light the badge, silently.
  badgeOnly,

  /// Light the badge *and* interrupt with the blocking sheet.
  badgeAndPrompt,
}

/// The whole decision behind a live release delivery, as a pure function.
///
/// Split out of `UpdateChecker` for two reasons. `watch()` itself can't run
/// under test at all — `resolveChannel()` returns `ReleaseChannel.unknown`
/// whenever `kDebugMode` is set, which is always true in `flutter test`. And
/// `update_checker.dart` reaches `main.dart` for the root navigator key, so
/// anything importing it drags in the entire app. Here the dependency cone is
/// two leaf files, and the fiddly part — first-delivery gating, retraction,
/// what counts as mandatory — is testable on its own.
///
/// [isFirstDelivery] is what keeps the subscription from double-prompting:
/// `UpdateChecker.ensure()` already owns the cold-start sheet via a one-shot
/// query, and the subscription's first payload only repeats what it said.
/// Later deliveries are genuinely new information, so a mandatory one
/// interrupts.
({UpdateWatchAction action, bool mandatory}) decideWatchAction({
  required AppRelease? release,
  required String currentVersion,
  required bool isFirstDelivery,
}) {
  // Nothing published for this channel, or a row we can't read. Both are
  // transport states rather than answers, so they must not clear a badge.
  if (release == null || release.version.isEmpty) {
    return (action: UpdateWatchAction.ignore, mandatory: false);
  }

  if (compareVersions(currentVersion, release.version) >= 0) {
    // A rollback or an unpublish. The subscription is authoritative here in a
    // way a one-shot check never was, so retract rather than sit on a signal
    // that has become false.
    return (action: UpdateWatchAction.clearBadge, mandatory: false);
  }

  final min = release.minSupported;
  final mandatory =
      min != null && min.isNotEmpty && compareVersions(currentVersion, min) < 0;

  // An ordinary update never interrupts: the badge is enough, and a release
  // published mid-conversation must not throw a modal over it.
  return (
    action: mandatory && !isFirstDelivery
        ? UpdateWatchAction.badgeAndPrompt
        : UpdateWatchAction.badgeOnly,
    mandatory: mandatory,
  );
}
