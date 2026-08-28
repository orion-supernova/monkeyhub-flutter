import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/location_share.dart';
import '../services/maps_handoff.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'location_map_preview.dart';
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
  final bool isMine;
  final double width;
  final BorderRadius radius;

  /// The timestamp/receipt block, laid over the card's bottom edge. Null where
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
    _syncClock();
  }

  @override
  void didUpdateWidget(LocationBubble old) {
    super.didUpdateWidget(old);
    // A share can arrive live and later be replaced by an ended copy from the
    // subscription; re-evaluate rather than assuming the state at mount holds.
    _syncClock();
  }

  @override
  void dispose() {
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

    final card = ClipRRect(
      borderRadius: widget.radius,
      child: SizedBox(
        width: widget.width,
        // 8:5. Wide enough that the graticule reads as a plan view rather than
        // a strip, short enough that a run of shared locations doesn't push the
        // conversation off the screen.
        height: widget.width * 0.625,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _pulse == null || !live
                ? LocationMapPreview(
                    theme: theme,
                    latitude: share.latitude,
                    longitude: share.longitude,
                    accuracyM: share.accuracyM,
                    dimmed: ended,
                  )
                : AnimatedBuilder(
                    animation: _pulse!,
                    builder: (_, _) => LocationMapPreview(
                      theme: theme,
                      latitude: share.latitude,
                      longitude: share.longitude,
                      accuracyM: share.accuracyM,
                      pulse: _pulse!.value,
                    ),
                  ),
            if (live) Positioned(top: 8, left: 8, child: _liveBadge(theme, l10n)),
            if (ended)
              Positioned(top: 8, left: 8, child: _endedBadge(theme, l10n)),
            if (widget.stamp != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: KeyedSubtree(
                  key: kVisibleStampKey,
                  child: widget.stamp!,
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          widget.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        FocusableTap(
          onTap: _openInMaps,
          radius: theme.radiusLg,
          semanticLabel: l10n.locationBubbleOpenInMaps,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openInMaps,
            // No `onLongPress` here, unlike this widget's own history. One
            // set here would sit in the SAME gesture arena as
            // `_BubbleGestureDetector`'s in `message_bubble.dart` — racing
            // the standard long-press instead of losing to it outright — and
            // used to answer every long-press itself with a bare "copy
            // coordinates", which is how a location message ended up the one
            // bubble type with no reply/forward/pin/save/select/delete/
            // report menu at all. The standard menu is wired the same way
            // every other bubble type gets it, from `MessageBubble`'s outer
            // detector; COPY COORDINATES now lives inside it too, as
            // [MessageAction.copyCoordinates] — see
            // [MessageCapabilities.canCopyCoordinates].
            child: card,
          ),
        ),
        const SizedBox(height: 5),
        _caption(theme, l10n, share, now, live: live, ended: ended),
      ],
    );
  }

  Widget _plate(AppTheme theme, {required IconData icon, required String label}) {
    return Container(
      width: widget.width,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: widget.radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.inkMuted),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              style: theme.caption.copyWith(color: theme.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveBadge(AppTheme theme, AppLocalizations l10n) => _badge(
        theme,
        text: l10n.locationBubbleLiveBadge,
        fg: theme.accentInk,
        bg: theme.accent,
      );

  Widget _endedBadge(AppTheme theme, AppLocalizations l10n) => _badge(
        theme,
        text: l10n.locationBubbleEndedBadge,
        fg: theme.inkSoft,
        bg: theme.surface.withValues(alpha: 0.86),
      );

  Widget _badge(
    AppTheme theme, {
    required String text,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Text(
        text,
        style: theme.monoTiny.copyWith(
          color: fg,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Everything under the card, in words.
  ///
  /// The card carries the geometry and the badge carries the state, but neither
  /// survives a screenshot, a screen reader or a viewer who glanced at it. "Live
  /// until 14:30" in text is the part that actually tells someone what they are
  /// looking at, which is why it is a sentence and not an icon.
  Widget _caption(
    AppTheme theme,
    AppLocalizations l10n,
    LocationShare share,
    DateTime now, {
    required bool live,
    required bool ended,
  }) {
    final lines = <Widget>[];

    if (live) {
      lines.add(_line(
        theme,
        CupertinoIcons.dot_radiowaves_left_right,
        l10n.locationBubbleLiveUntil(formatClockTime(share.liveExpiresAt!)),
        emphasis: true,
      ));
      if (share.isStaleAt(now)) {
        // Said plainly rather than shown as a subtle dimming, because the
        // difference between "they have stopped walking" and "their phone
        // stopped reporting" is the entire reliability of this feature, and only
        // one of those is safe to act on.
        lines.add(_line(
          theme,
          CupertinoIcons.exclamationmark_triangle,
          l10n.locationBubbleNoRecentUpdate,
          warn: true,
        ));
      }
    } else if (ended) {
      lines.add(_line(
        theme,
        CupertinoIcons.stop_circle,
        l10n.locationBubbleLiveEnded(
          formatClockTime(share.liveEndedAt ?? share.liveExpiresAt!),
        ),
      ));
    }

    final acc = share.accuracyM;
    lines.add(_line(
      theme,
      CupertinoIcons.location,
      acc == null
          ? formatCoordinates(share.latitude, share.longitude)
          : '${formatCoordinates(share.latitude, share.longitude)}  '
              '${l10n.locationBubbleAccuracy(acc.round())}',
    ));

    if (live && widget.onStopSharing != null && widget.publishing) {
      lines.add(const SizedBox(height: 4));
      lines.add(_stopButton(theme, l10n));
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.width),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            widget.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }

  Widget _line(
    AppTheme theme,
    IconData icon,
    String text, {
    bool emphasis = false,
    bool warn = false,
  }) {
    final color = warn
        ? theme.danger
        : emphasis
            ? theme.accent
            : theme.inkMuted;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.monoTiny.copyWith(color: color, letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopButton(AppTheme theme, AppLocalizations l10n) {
    return FocusableTap(
      onTap: _stop,
      radius: theme.radiusSm,
      semanticLabel: l10n.locationBubbleStopSharing,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _stop,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(
              color: theme.danger.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Text(
            l10n.locationBubbleStopSharing,
            style: theme.monoTiny.copyWith(
              color: theme.danger,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _stop() async {
    HapticFeedback.mediumImpact();
    await widget.onStopSharing?.call();
  }

  Future<void> _openInMaps() async {
    final share = widget.message.locationShare;
    if (share == null) return;
    final toast = AppToast.of(context);
    final failed = AppLocalizations.of(context).locationBubbleNoMapsApp;
    final ok = await MapsHandoff.open(
      latitude: share.latitude,
      longitude: share.longitude,
      label: widget.message.senderName.isEmpty
          ? null
          : widget.message.senderName,
    );
    if (!ok) toast.show(failed, tone: ToastTone.danger);
  }
}
