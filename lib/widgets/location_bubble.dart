import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_message.dart';
import '../models/location_share.dart';
import 'package:latlong2/latlong.dart';

import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../screens/location_map_screen.dart';
import 'location_map_snapshot.dart' show MapPicture;
import 'map_app_picker.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'attachment_bubble_frame.dart';
import 'location_address.dart';
import 'location_map_preview.dart';
import 'user_avatar.dart';
import 'message_stamp.dart';

/// A location in the transcript: one fix, or a live share that is running, or
/// one that has finished.
///
/// One widget for all three rather than three, because the three differ by two
/// booleans and share a card, a coordinate readout and a tap target — and
/// because the transition between them happens *while the widget is mounted*.
/// A live share reaching its deadline is not a rebuild with different data; it
/// is the same bubble, on the same screen, changing state on a clock tick. Three
/// widgets would need the parent to notice that moment and swap them, and
/// nothing is watching.
///
/// ## The clock
///
/// This ticks itself once a second while a share is live, and stops the moment
/// it is not. That is the whole mechanism behind "expires while you are looking
/// at it": [LocationShare.stateAt] is a pure function of `now`, so the tick that
/// crosses the deadline redraws this as ended without the server, the socket or
/// the parent being involved at all. The server's own expiry lands a moment
/// later and agrees.
///
/// A static or already-ended share starts no timer and no animation, which is
/// also what keeps a transcript full of old locations costing nothing.
class LocationBubble extends StatefulWidget {
  const LocationBubble({
    super.key,
    this.author,
    this.api,
    required this.theme,
    required this.message,
    required this.isMine,
    required this.width,
    required this.radius,
    this.stamp,
    this.onStopSharing,
    this.publishing = false,
    this.clock = DateTime.now,
  });

  final AppTheme theme;
  final ChatMessage message;

  /// Who sent it and the API to load their face with, for the full-screen
  /// map's marker and card. Null in previews.
  final ChatUser? author;
  final ChatApi? api;
  final bool isMine;
  final double width;
  final BorderRadius radius;

  /// The timestamp/receipt block, laid over the map's bottom edge. Null where
  /// the caller owns it instead.
  final MessageStamp? stamp;

  /// Ends the share. Non-null only on the sender's own running share — a
  /// recipient has nothing to stop, and a share this device is not publishing
  /// belongs to another device of the same account, which stops it via the
  /// server rather than through this button.
  final Future<void> Function()? onStopSharing;

  /// Whether THIS device is the one feeding the share. Drives the difference
  /// between "you are sharing" and "someone is sharing", which matters on the
  /// sender's own second device: it can see its own share running and must not
  /// claim to be the thing keeping it alive.
  final bool publishing;

  /// What time it is.
  ///
  /// A seam, and a necessary one. The behaviour worth testing here is a share
  /// ending WHILE it is on screen, and `WidgetTester.pump(Duration)` advances
  /// the binding's timers without advancing the wall clock — so a widget that
  /// read `DateTime.now()` directly could have its ticker fired a hundred times
  /// and still believe no time had passed. Injecting the clock is what lets the
  /// one transition that has no external trigger be asserted at all.
  final DateTime Function() clock;

  @override
  State<LocationBubble> createState() => _LocationBubbleState();
}

class _LocationBubbleState extends State<LocationBubble>
    with SingleTickerProviderStateMixin {
  Timer? _tick;
  AnimationController? _pulse;
  bool _openingMaps = false;

  /// Read once per build and threaded down, so the countdown, the state and the
  /// staleness in a single frame can never disagree about what time it is.
  ///
  /// Seeded from the INJECTED clock, not `DateTime.now()`. The first build
  /// after [_syncClock] has started the ticker reads this field before the
  /// ticker has ever fired, and a wall-clock seed there rendered one frame of
  /// the wrong state whenever the injected clock disagreed with the wall —
  /// which is every test with a fixed clock, from the day after it was
  /// written.
  late DateTime _now = widget.clock();

  @override
  void initState() {
    super.initState();
    final share = widget.message.locationShare;
    if (share != null) _recordTrail(share);
    _syncClock();
  }

  /// What an open full-screen map shows. Fed on every rebuild with the
  /// message's newest copy, so a live share keeps moving there by itself.
  ValueNotifier<LocationShare>? _live;

  /// The card's map picture, once drawn: it is what flies up into the
  /// full-screen map.
  final _picture = ValueNotifier<MapPicture?>(null);
  final _mapKey = GlobalKey();

  /// Where a live share has been since this bubble appeared, for the path on
  /// the full-screen map.
  final _trail = <LatLng>[];

  void _recordTrail(LocationShare share) {
    if (share.stateAt(widget.clock()) != LiveShareState.live) return;
    final p = LatLng(share.latitude, share.longitude);
    if (_trail.isNotEmpty && _trail.last == p) return;
    _trail.add(p);
    if (_trail.length > 400) _trail.removeAt(0);
  }

  @override
  void didUpdateWidget(LocationBubble old) {
    super.didUpdateWidget(old);
    final share = widget.message.locationShare;
    if (share != null) {
      _live?.value = share;
      _recordTrail(share);
    }
    // A share can arrive live and later be replaced by an ended copy from the
    // subscription; re-evaluate rather than assuming the state at mount holds.
    _syncClock();
  }

  @override
  void dispose() {
    _live?.dispose();
    _picture.dispose();
    _tick?.cancel();
    _pulse?.dispose();
    super.dispose();
  }

  /// Starts or stops the once-a-second rebuild and the halo, according to
  /// whether there is anything live to draw.
  ///
  /// Both are torn down as soon as the share ends, which is the point: a
  /// transcript that has scrolled past forty old locations should be running
  /// zero timers and zero animation controllers.
  void _syncClock() {
    final live =
        widget.message.locationShare?.stateAt(widget.clock()) ==
        LiveShareState.live;
    if (live) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = widget.clock());
        // Re-entrant on purpose. The tick that crosses the deadline is the tick
        // that makes this share not-live, and nothing else will notice: no
        // rebuild from the parent, no message from the server. Without this the
        // bubble would keep ticking once a second, and keep the halo running,
        // for a share that finished hours ago.
        _syncClock();
      });
      _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat();
    } else {
      _tick?.cancel();
      _tick = null;
      _pulse?.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final l10n = AppLocalizations.of(context);
    final share = widget.message.locationShare;

    // A location-typed message with no coordinates. Reachable from history
    // written before this feature, and from a send whose coordinates the server
    // refused — which it turns into a text message, but a stale client cache
    // can still hold the old shape. A plate that says so beats a blank card.
    if (share == null) {
      return _plate(
        theme,
        icon: CupertinoIcons.location_slash,
        label: l10n.locationBubbleUnavailable,
      );
    }

    final now = _tick == null ? widget.clock() : _now;
    final state = share.stateAt(now);
    final ended = state == LiveShareState.ended;
    final live = state == LiveShareState.live;

    final accent = locationMapAccent(theme);
    final face = widget.author != null && (live || ended);
    final address = live
        ? null
        : LocationAddress.peek(share.latitude, share.longitude);
    if (address == null && !live) _lookUpAddress(share);
    final coords = formatCoordinates(share.latitude, share.longitude);
    final acc = share.accuracyM;

    // The card is all map. Everything else sits on it: a badge top right,
    // and over a soft dark fade at the bottom, what this is, the time line,
    // and Stop on your own running share. Light text on the fade reads the
    // same on a day map, a night map and a satellite photo.
    final String title;
    final String subtitle;
    var warn = false;
    if (live) {
      title = l10n.locationMapTitleLive;
      if (share.isStaleAt(now)) {
        subtitle = l10n.locationBubbleNoRecentUpdate;
        warn = true;
      } else {
        subtitle = l10n.locationBubbleLiveUntil(
          formatClockTime(share.liveExpiresAt!),
        );
      }
    } else if (ended) {
      // Titled by the place, and still says where they were: the room
      // already saw it while the share ran, so hiding it would only cost the
      // transcript its record.
      final hasAddress = address?.title.isNotEmpty ?? false;
      title = hasAddress ? address!.title : l10n.attachmentMenuLocationLabel;
      final endedLine = l10n.locationBubbleLiveEnded(
        formatClockTime(share.liveEndedAt ?? share.liveExpiresAt!),
      );
      subtitle = hasAddress ? endedLine : '$endedLine\n$coords';
    } else {
      title = (address?.title.isNotEmpty ?? false)
          ? address!.title
          : l10n.attachmentMenuLocationLabel;
      final where = address?.subtitle ?? '';
      // Without an address the coordinates stand in, with how precise they
      // are; an unknown accuracy is left unsaid rather than guessed.
      subtitle = where.isNotEmpty
          ? where
          : acc == null
          ? coords
          : '$coords  ${l10n.locationBubbleAccuracy(acc.round())}';
    }
    final showStop = live && widget.onStopSharing != null && widget.publishing;
    final height = widget.width * 0.86;

    Widget mapLayer() => LocationMapPreview(
      theme: theme,
      latitude: share.latitude,
      longitude: share.longitude,
      accuracyM: share.accuracyM,
      dimmed: ended,
      pulse: live && _pulse != null ? _pulse!.value : 0,
      pictureOut: _picture,
      showDot: !face,
      bare: true,
    );

    final card = RepaintBoundary(
      key: _mapKey,
      child: ClipRRect(
        borderRadius: widget.radius,
        child: SizedBox(
          width: widget.width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              live && _pulse != null
                  ? AnimatedBuilder(
                      animation: _pulse!,
                      builder: (_, _) => mapLayer(),
                    )
                  : mapLayer(),
              if (face)
                Center(
                  child: _Face(
                    user: widget.author!,
                    api: widget.api,
                    ring: ended ? theme.inkMuted : accent,
                    surface: theme.surface,
                    dimmed: ended,
                  ),
                ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 0.78, 1],
                        colors: [
                          Color(0x00000000),
                          Color(0x8C000000),
                          Color(0xD9000000),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (live || ended)
                Positioned(
                  top: 9,
                  right: 9,
                  child: _overlayBadge(
                    theme,
                    sentenceCaseOf(
                      context,
                      live
                          ? l10n.locationBubbleLiveBadge
                          : l10n.locationBubbleEndedBadge,
                    ),
                    live: live,
                  ),
                ),
              Positioned(
                left: 13,
                // Clear of the time stamp in the corner.
                right: widget.stamp == null ? 13 : 70,
                bottom: 11,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFFFFF),
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.body.copyWith(
                        fontSize: 13,
                        color: warn
                            ? const Color(0xFFFF8A80)
                            : const Color(0xD9FFFFFF),
                        height: 1.25,
                        letterSpacing: 0,
                      ),
                    ),
                    if (showStop) ...[
                      const SizedBox(height: 8),
                      _overlayStop(l10n),
                    ],
                  ],
                ),
              ),
              if (widget.stamp != null)
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: KeyedSubtree(
                    key: kVisibleStampKey,
                    child: widget.stamp!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return AttachmentBubbleFrame(
      theme: theme,
      width: widget.width,
      radius: widget.radius,
      child: FocusableTap(
        onTap: _openMap,
        radius: theme.radiusLg,
        semanticLabel: '$title, $subtitle',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openMap,
          // No `onLongPress` here: one would sit in the same gesture arena
          // as `_BubbleGestureDetector`'s in `message_bubble.dart` and race
          // the standard long-press menu (reply, forward, copy coordinates…)
          // instead of losing to it.
          child: card,
        ),
      ),
    );
  }

  ({double lat, double lng})? _lookedUp;

  /// The street name for a one-off location, from the shared OS-geocoder
  /// cache; the bubble rebuilds once it arrives.
  void _lookUpAddress(LocationShare share) {
    final at = (lat: share.latitude, lng: share.longitude);
    if (_lookedUp == at) return;
    _lookedUp = at;
    LocationAddress.lookup(share.latitude, share.longitude).then((r) {
      if (mounted && r != null) setState(() {});
    });
  }

  Widget _overlayBadge(AppTheme theme, String text, {required bool live}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: live ? locationMapAccent(theme) : const Color(0xB3000000),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: theme.body.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFFFFF),
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
      );

  Widget _overlayStop(AppLocalizations l10n) {
    final label = l10n.locationBubbleStopSharing;
    return FocusableTap(
      onTap: _stop,
      shape: FocusRingShape.capsule,
      semanticLabel: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _stop,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF453A),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: widget.theme.body.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFFFFFF),
              letterSpacing: 0,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _plate(
    AppTheme theme, {
    required IconData icon,
    required String label,
  }) {
    return AttachmentBubbleFrame(
      theme: theme,
      width: widget.width,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      radius: widget.radius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.inkMuted),
          const SizedBox(width: 9),
          Flexible(child: Text(label, style: attachmentMetaStyle(theme))),
        ],
      ),
    );
  }

  Future<void> _stop() async {
    HapticFeedback.mediumImpact();
    await widget.onStopSharing?.call();
  }

  Future<void> _openMap() async {
    final share = widget.message.locationShare;
    if (share == null) return;
    HapticFeedback.selectionClick();
    final live = _live ??= ValueNotifier(share);
    live.value = share;
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : LocationMapOrigin(
            rect: box.localToGlobal(Offset.zero) & box.size,
            radius: widget.radius.topLeft.x,
            spanMeters: spanMetersFor(share.accuracyM),
            picture: _picture.value,
          );
    await LocationMapScreen.open(
      context,
      share: live,
      clock: widget.clock,
      name: widget.message.senderName.isEmpty
          ? null
          : widget.message.resolvedSenderName(context),
      author: widget.author,
      api: widget.api,
      isMine: widget.isMine,
      onStopSharing: widget.publishing ? widget.onStopSharing : null,
      origin: origin,
      initialTrail: List.of(_trail),
      onOpenInMaps: (from) => _openInMaps(from),
    );
  }

  /// [from] is where the app picker and the failure toast appear: the
  /// full-screen map passes its own context so they show above it.
  Future<void> _openInMaps([BuildContext? from]) async {
    final share = widget.message.locationShare;
    if (share == null || _openingMaps) return;
    _openingMaps = true;
    final at = from ?? context;
    final toast = AppToast.of(at);
    final failed = AppLocalizations.of(at).locationBubbleNoMapsApp;
    // The newest fix: the full-screen map may have watched it move since
    // this bubble last built.
    final latest = _live?.value ?? share;
    try {
      final result = await openMapLocation(
        at,
        latitude: latest.latitude,
        longitude: latest.longitude,
        label: widget.message.senderName.isEmpty
            ? null
            : widget.message.resolvedSenderName(at),
      );
      if (result == MapOpenResult.failed) {
        toast.show(failed, tone: ToastTone.danger);
      }
    } finally {
      _openingMaps = false;
    }
  }
}

/// The sharer's face on a live share's card, where the dot would be: the
/// person is the point.
class _Face extends StatelessWidget {
  const _Face({
    required this.user,
    required this.api,
    required this.ring,
    required this.surface,
    required this.dimmed,
  });

  final ChatUser user;
  final ChatApi? api;
  final Color ring;
  final Color surface;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    Widget avatar = UserAvatar(user: user, api: api, size: 34, showStatus: false);
    if (dimmed) {
      avatar = Opacity(
        opacity: 0.7,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: avatar,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: ring,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
        child: avatar,
      ),
    );
  }
}
