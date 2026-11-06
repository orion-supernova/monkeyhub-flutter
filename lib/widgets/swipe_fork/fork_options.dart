/// What the swipe-up fork can offer in a room: a pure function of room state.
///
/// No widgets and no services in here. The room screen reads its own state,
/// hands it over as a [ForkRoomState] at touch-down, and gets back zero, one or
/// two [ForkOption]s. See the "Room rules" table in docs/design/swipe-up-fork.html.
library;

/// What committing an option does.
enum ForkKind {
  /// Start a huddle: a group call that rings no one.
  startHuddle,

  /// Join the huddle others are already in.
  joinHuddle,

  /// Turn vanish mode on.
  vanishOn,

  /// Turn vanish mode off. Never a second "turn on".
  vanishOff,
}

/// One choice on the fork.
class ForkOption {
  const ForkOption(this.kind, {this.joinCount = 0, this.joinUserIds = const []});

  final ForkKind kind;

  /// For [ForkKind.joinHuddle]: how many are in the huddle and who (faces).
  final int joinCount;
  final List<String> joinUserIds;

  bool get isVanish => kind == ForkKind.vanishOn || kind == ForkKind.vanishOff;
  bool get isTalk => !isVanish;

  @override
  bool operator ==(Object other) =>
      other is ForkOption &&
      other.kind == kind &&
      other.joinCount == joinCount;

  @override
  int get hashCode => Object.hash(kind, joinCount);

  @override
  String toString() => 'ForkOption($kind)';
}

/// The slice of room state the options depend on.
class ForkRoomState {
  const ForkRoomState({
    this.isSecret = false,
    this.vanishOn = false,
    this.canEditVanish = true,
    this.inCall = false,
    this.othersHuddle = false,
    this.huddleCount = 0,
    this.huddleUserIds = const [],
  });

  /// A secret room already self-destructs: no vanish.
  final bool isSecret;

  /// Vanish mode is on: the vanish option becomes "Turn off".
  final bool vanishOn;

  /// A DM, or a group where the viewer may change settings.
  final bool canEditVanish;

  /// The viewer is already in any call (here or elsewhere): no talk.
  final bool inCall;

  /// Others are in a live huddle in this room: talk becomes "Join".
  final bool othersHuddle;
  final int huddleCount;
  final List<String> huddleUserIds;
}

/// The options for [s], in logical order: vanish first (the start side, left
/// in left-to-right layouts), talk second. Zero, one or two entries.
List<ForkOption> forkOptionsFor(ForkRoomState s) => [
      if (!s.isSecret && s.canEditVanish)
        ForkOption(s.vanishOn ? ForkKind.vanishOff : ForkKind.vanishOn),
      if (!s.inCall)
        s.othersHuddle
            ? ForkOption(
                ForkKind.joinHuddle,
                joinCount: s.huddleCount,
                joinUserIds: s.huddleUserIds,
              )
            : const ForkOption(ForkKind.startHuddle),
    ];
