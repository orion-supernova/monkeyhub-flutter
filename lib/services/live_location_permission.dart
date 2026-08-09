import 'location_service.dart';

/// How much background location this app currently holds.
///
/// Not the same question as [LocationAvailability], and the two are deliberately
/// kept apart: availability answers "can we get a fix at all", which is what the
/// *static* share needs, while this answers "how long do we keep getting them
/// after the user leaves the app", which is what a *live* share needs. A device
/// can be perfectly [LocationAvailability.ready] and still be [whenInUse] here.
enum BackgroundLocationTier {
  /// No usable location permission. Nothing can be shared.
  none,

  /// When-In-Use. Everything in Tier 1: the share keeps publishing while the
  /// app is backgrounded, because iOS's `location` background mode and Android's
  /// location foreground service both work on When-In-Use as long as the service
  /// was started while the app was on screen.
  ///
  /// What it does not survive is the process ending — a force-quit, a reboot, or
  /// the system reclaiming memory. The share then goes STALE on every viewer's
  /// screen and ends on time server-side, which is the honest outcome.
  whenInUse,

  /// Always. Adds the one thing When-In-Use cannot do: being relaunched after
  /// termination — iOS significant-change monitoring, Android's boot receiver.
  always,
}

/// What starting a live share should do about permissions, right now.
///
/// One value per distinct remedy, because every one of these has a different
/// next screen and offering the wrong one is a dead end the user cannot reason
/// their way out of.
enum LiveShareStartAction {
  /// Nothing to ask. Start the share.
  start,

  /// Start the share, but explain the Always upgrade first and offer it.
  ///
  /// Note the order this implies at the call site: the share starts either way.
  /// A user who declines gets the full Tier 1 experience and is never asked
  /// again — see [LiveShareResumeStore.hasOfferedAlwaysUpgrade].
  offerAlwaysUpgrade,

  /// The app has never asked for location. Ask.
  requestPermission,

  /// Permanently denied. The OS will not show a prompt, so the only honest
  /// offer is the app's own Settings page.
  openAppSettings,

  /// Location is switched off device-wide. A permission screen has no switch
  /// that helps.
  openLocationSettings,
}

/// The one place that decides what a live-share tap does about permissions.
///
/// Written as a pure function over four inputs rather than as branches inside
/// the room screen for two reasons. The first is that it is the part of this
/// feature most likely to be got subtly wrong — the failure mode of a permission
/// flow is not a crash, it is a prompt that appears at the wrong moment or a
/// user who gets asked the same question every day — and a pure function is the
/// part that can be pinned by tests on a machine with no location hardware. The
/// second is that the rules genuinely are a table, and writing a table as
/// nested ifs is how a cell goes missing.
///
/// The table, in full:
///
/// | availability | tier | offered? | supported? | →                     |
/// |--------------|------|----------|------------|-----------------------|
/// | servicesDisabled | * | *      | *          | openLocationSettings  |
/// | deniedForever    | * | *      | *          | openAppSettings       |
/// | denied           | * | *      | *          | requestPermission     |
/// | ready | always      | *      | *          | start                 |
/// | ready | whenInUse   | no     | yes        | offerAlwaysUpgrade    |
/// | ready | whenInUse   | yes    | yes        | start                 |
/// | ready | whenInUse   | *      | no         | start                 |
/// | ready | none        | *      | *          | start                 |
///
/// The last row looks wrong and is not. `availability` is derived from the same
/// OS answer as `tier` but through `geolocator`, which reports Always and
/// When-In-Use identically; if the two ever disagree, availability is the one
/// that was computed by the code that actually takes fixes, and refusing to
/// start a share because a *secondary* signal is confused would break the
/// feature to protect an upgrade prompt.
///
/// ## Why the escalation is here and not at launch
///
/// The prompt this returns [offerAlwaysUpgrade] for is the most expensive one
/// this app can show: on iOS "Always" can be requested exactly once, and a
/// refusal is permanent short of a trip to Settings. Spending it at first
/// launch — before the user has ever shared a location, in a chat app where most
/// people never will — spends it on somebody with no way to evaluate the
/// question. Spending it at the moment they have chosen to be findable for the
/// next eight hours spends it on somebody who has all the context there is.
LiveShareStartAction decideLiveShareStart({
  required LocationAvailability availability,
  required BackgroundLocationTier tier,
  required bool alreadyOfferedAlways,
  required bool platformSupportsAlways,
}) {
  switch (availability) {
    case LocationAvailability.servicesDisabled:
      return LiveShareStartAction.openLocationSettings;
    case LocationAvailability.deniedForever:
      return LiveShareStartAction.openAppSettings;
    case LocationAvailability.denied:
      return LiveShareStartAction.requestPermission;
    case LocationAvailability.ready:
      break;
  }
  if (tier == BackgroundLocationTier.always) return LiveShareStartAction.start;
  if (!platformSupportsAlways) return LiveShareStartAction.start;
  if (alreadyOfferedAlways) return LiveShareStartAction.start;
  return LiveShareStartAction.offerAlwaysUpgrade;
}

/// The strongest [LiveLocationMode] escalation this tier can actually deliver.
///
/// Used by the publisher to decide whether asking the platform for
/// significant-change monitoring is worth a channel hop, and by the docs to say
/// out loud what each permission buys. A [BackgroundLocationTier.whenInUse]
/// device gets every bit of Tier 1 and no Tier 2, with no error and no nag: the
/// share simply stops when the process does.
bool tierSurvivesTermination(BackgroundLocationTier tier) =>
    tier == BackgroundLocationTier.always;
