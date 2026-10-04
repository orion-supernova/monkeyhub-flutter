import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_message.dart';
import '../models/location_share.dart';
import 'map_app_picker.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'attachment_bubble_frame.dart';
import 'location_map_preview.dart';
import 'message_stamp.dart';
import 'meta_text.dart';

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

    final map = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: widget.radius.topLeft,
          topRight: widget.radius.topRight,
        ),
        child: SizedBox(
          width: widget.width,
          height: widget.width * 0.54,
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
      ),
    );

    return AttachmentBubbleFrame(
      theme: theme,
      width: widget.width,
      radius: widget.radius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
              child: map,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.attachmentMenuLocationLabel,
                        style: theme.body.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.ink,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (live)
                      _badge(
                        theme,
                        text: sentenceCaseOf(
                          context,
                          l10n.locationBubbleLiveBadge,
                        ),
                        live: true,
                      ),
                    if (ended)
                      _badge(
                        theme,
                        text: sentenceCaseOf(
                          context,
                          l10n.locationBubbleEndedBadge,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                _caption(theme, l10n, share, now, live: live, ended: ended),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _openButton(theme, l10n),
                    if (live &&
                        widget.onStopSharing != null &&
                        widget.publishing)
                      _stopButton(theme, l10n),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  Widget _badge(AppTheme theme, {required String text, bool live = false}) {
    final color = live
        ? attachmentReadableInk(theme, locationMapAccent(theme))
        : attachmentSecondaryInk(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: attachmentRowFill(theme),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: attachmentMetaStyle(
              theme,
            ).copyWith(color: color, fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// The map's readout, kept inside the quiet card footer.
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
      lines.add(
        _line(
          theme,
          CupertinoIcons.dot_radiowaves_left_right,
          l10n.locationBubbleLiveUntil(formatClockTime(share.liveExpiresAt!)),
        ),
      );
      if (share.isStaleAt(now)) {
        // Said plainly rather than shown as a subtle dimming, because the
        // difference between "they have stopped walking" and "their phone
        // stopped reporting" is the entire reliability of this feature, and only
        // one of those is safe to act on.
        lines.add(
          _line(
            theme,
            CupertinoIcons.exclamationmark_triangle,
            l10n.locationBubbleNoRecentUpdate,
            warn: true,
          ),
        );
      }
    } else if (ended) {
      lines.add(
        _line(
          theme,
          CupertinoIcons.stop_circle,
          l10n.locationBubbleLiveEnded(
            formatClockTime(share.liveEndedAt ?? share.liveExpiresAt!),
          ),
        ),
      );
    }

    final acc = share.accuracyM;
    lines.add(
      _line(
        theme,
        null,
        acc == null
            ? formatCoordinates(share.latitude, share.longitude)
            : '${formatCoordinates(share.latitude, share.longitude)}  '
                  '${l10n.locationBubbleAccuracy(acc.round())}',
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.width),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }

  Widget _line(
    AppTheme theme,
    IconData? icon,
    String text, {
    bool warn = false,
  }) {
    final color = warn ? theme.danger : attachmentSecondaryInk(theme);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              style: metaText(theme, color: color).copyWith(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopButton(AppTheme theme, AppLocalizations l10n) => _action(
    theme,
    l10n.locationBubbleStopSharing,
    onTap: _stop,
    color: attachmentReadableInk(theme, theme.danger),
  );

  Widget _openButton(AppTheme theme, AppLocalizations l10n) => _action(
    theme,
    l10n.locationBubbleOpenInMaps,
    onTap: _openInMaps,
    color: attachmentReadableInk(theme, locationMapAccent(theme)),
    icon: CupertinoIcons.arrow_up_right,
  );

  Widget _action(
    AppTheme theme,
    String label, {
    required VoidCallback onTap,
    required Color color,
    IconData? icon,
  }) => FocusableTap(
    onTap: onTap,
    shape: FocusRingShape.capsule,
    semanticLabel: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: attachmentRowFill(theme),
            border: Border.all(color: attachmentEdge(theme), width: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: theme.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 5),
                Icon(icon, size: 12, color: color),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _stop() async {
    HapticFeedback.mediumImpact();
    await widget.onStopSharing?.call();
  }

  Future<void> _openInMaps() async {
    final share = widget.message.locationShare;
    if (share == null || _openingMaps) return;
    _openingMaps = true;
    final toast = AppToast.of(context);
    final failed = AppLocalizations.of(context).locationBubbleNoMapsApp;
    try {
      final result = await openMapLocation(
        context,
        latitude: share.latitude,
        longitude: share.longitude,
        label: widget.message.senderName.isEmpty
            ? null
            : widget.message.senderName,
      );
      if (result == MapOpenResult.failed) {
        toast.show(failed, tone: ToastTone.danger);
      }
    } finally {
      _openingMaps = false;
    }
  }
}
