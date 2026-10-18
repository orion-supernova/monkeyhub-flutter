import '../models/app_release.dart';
import 'store_answer.dart';
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

/// [decideWatchAction] with the store's own answer folded in — the one
/// decision both `UpdateChecker.checkNow` and `watch` go through.
///
/// Where the store can answer ([StoreVerdict.notApplicable] aside), the row's
/// `version` is no longer evidence of anything: it says what deploy.sh
/// uploaded, and an upload in review, in certification, or on Play's internal
/// track is not something this install can get. So the store decides *whether*
/// there is an update and *which* version it is; the row only contributes what
/// a store can't know — `minSupported`, the notes, an `updateUrl` override.
///
/// The returned release is the one to show: for a store channel it carries the
/// store's version, so the sheet's "v1.3.9 → v1.3.10" names the build the
/// button will actually install.
///
/// One rule beyond the row-only path: an update is mandatory only when what the
/// store would install actually clears `minSupported`. Otherwise a minimum
/// raised ahead of approval would lock users behind a sheet whose button leads
/// to a build that is still too old — a trap, not a prompt.
({UpdateWatchAction action, AppRelease? release, bool mandatory}) decideUpdate({
  required AppRelease? release,
  required StoreAnswer store,
  required String currentVersion,
  required bool isFirstDelivery,
}) {
  switch (store.verdict) {
    case StoreVerdict.notApplicable:
      final d = decideWatchAction(
        release: release,
        currentVersion: currentVersion,
        isFirstDelivery: isFirstDelivery,
      );
      return (action: d.action, release: release, mandatory: d.mandatory);
    case StoreVerdict.noAnswer:
      return (action: UpdateWatchAction.ignore, release: null, mandatory: false);
    case StoreVerdict.upToDate:
      return (
        action: UpdateWatchAction.clearBadge,
        release: null,
        mandatory: false,
      );
    case StoreVerdict.available:
      break;
  }

  final storeVersion = store.version?.trim();
  final hasStoreVersion = storeVersion != null && storeVersion.isNotEmpty;
  // A store that names a version no newer than this one is contradicting
  // itself (a stale cache on its side); believe the number, not the flag.
  if (hasStoreVersion && compareVersions(currentVersion, storeVersion) >= 0) {
    return (
      action: UpdateWatchAction.clearBadge,
      release: null,
      mandatory: false,
    );
  }

  final version = hasStoreVersion ? storeVersion : (release?.version ?? '');
  // Notes are prose about one specific build. Shown only when the row is
  // talking about the build the store is offering, so a note written for an
  // upload still in review never decorates the previous one.
  final notes = release != null && compareVersions(release.version, version) == 0
      ? release.notes
      : null;
  final offered = AppRelease(
    channel: release?.channel ?? '',
    version: version,
    minSupported: release?.minSupported,
    updateUrl: release?.updateUrl,
    notes: notes,
    publishedAt: release?.publishedAt ?? 0,
  );

  final min = release?.minSupported;
  final mandatory = min != null &&
      min.isNotEmpty &&
      compareVersions(currentVersion, min) < 0 &&
      // Unknown store version (Play): trust the store's yes, as the Play gate
      // always has. Known: it must actually reach the minimum.
      (!hasStoreVersion || compareVersions(storeVersion, min) >= 0);

  return (
    action: mandatory && !isFirstDelivery
        ? UpdateWatchAction.badgeAndPrompt
        : UpdateWatchAction.badgeOnly,
    release: offered,
    mandatory: mandatory,
  );
}
