import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../calls/call_models.dart';
import '../../calls/widgets/call_chrome.dart' show kCallAcceptGreen;
import '../../keyboard/focusable_tap.dart' show FocusRingShape;
import '../../keyboard/overlay_modal_scope.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_user.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/chat_row_action_menu.dart' show ChatRowLongPress;
import '../../widgets/pull_down_menu.dart';
import '../../widgets/spring_press.dart';
import '../../widgets/user_avatar.dart';

/// The small heading over a Calls section. Smaller than a tab root's usual
/// section header on purpose: the history is the hero of this tab.
class CallsSectionLabel extends StatelessWidget {
  const CallsSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.bodyEmph.copyWith(fontSize: 17, color: theme.ink),
        ),
      ),
    );
  }
}

/// The people the USER pinned, as circles, in the order they were added. The
/// app never fills this row: a frequent contact is only ever suggested (see
/// calls_fav_suggestion.dart). A tap springs a small voice / video chooser out
/// of the circle, a hold offers "Remove from favourites", and a trailing "+"
/// opens the friend picker.
///
/// A person who is added pops in with a jelly spring; one who is removed
/// shrinks out. Everything else is crisp.
class CallsFavourites extends StatefulWidget {
  const CallsFavourites({
    super.key,
    required this.people,
    required this.onPick,
    required this.onRemove,
    this.onAdd,
    this.api,
  });

  /// The pins, resolved, in the order added.
  final List<ChatUser> people;
  final ChatApi? api;

  /// A person and the kind of call chosen from their chooser.
  final void Function(ChatUser person, CallMediaKind kind) onPick;
  final void Function(ChatUser person) onRemove;

  /// Opens the friend picker; null hides the "+" (no way to pick without it).
  final VoidCallback? onAdd;

  @override
  State<CallsFavourites> createState() => _CallsFavouritesState();
}

class _Slot {
  _Slot(this.user, this.id, {this.fresh = false, this.leaving = false});
  final ChatUser user;
  final int id;

  /// Pops in (an add) rather than simply being there (the first build).
  final bool fresh;
  final bool leaving;
}

class _CallsFavouritesState extends State<CallsFavourites> {
  int _seq = 0;
  late List<_Slot> _slots = [
    for (final u in widget.people) _Slot(u, _seq++),
  ];

  @override
  void didUpdateWidget(CallsFavourites old) {
    super.didUpdateWidget(old);
    final now = {for (final u in widget.people) u.id: u};
    final next = <_Slot>[];
    final held = <String>{};
    for (final s in _slots) {
      final u = now[s.user.id];
      if (u == null) {
        next.add(s.leaving ? s : _Slot(s.user, s.id, leaving: true));
      } else if (s.leaving) {
        // Added back while shrinking out: a new circle.
        next.add(_Slot(u, _seq++, fresh: true));
        held.add(u.id);
      } else {
        next.add(_Slot(u, s.id));
        held.add(u.id);
      }
    }
    for (final u in widget.people) {
      if (!held.contains(u.id)) next.add(_Slot(u, _seq++, fresh: true));
    }
    _slots = next;
  }

  void _gone(int id) {
    if (!mounted) return;
    setState(() => _slots = [
          for (final s in _slots)
            if (s.id != id) s,
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final empty = widget.people.isEmpty;
    final add = widget.onAdd == null
        ? null
        : _AddCircle(onTap: widget.onAdd!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: CallsSectionLabel(l10n.callsTabFavourites),
        ),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final s in _slots)
                _SlotAnim(
                  key: ValueKey(s.id),
                  animateIn: s.fresh,
                  leaving: s.leaving,
                  onGone: () => _gone(s.id),
                  child: _Circle(
                    user: s.user,
                    api: widget.api,
                    onPick: widget.onPick,
                    onRemove: widget.onRemove,
                  ),
                ),
              ?add,
              if (empty && add != null)
                Container(
                  width: 220,
                  height: 58,
                  margin: const EdgeInsets.only(top: 4, left: 6),
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.callsTabFavEmpty,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySoft.copyWith(
                      fontSize: 13.5,
                      color: theme.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// Grows a circle in with a jelly spring, or shrinks it out when [leaving]
/// and then calls [onGone].
class _SlotAnim extends StatefulWidget {
  const _SlotAnim({
    super.key,
    required this.child,
    required this.animateIn,
    required this.leaving,
    required this.onGone,
  });
  final Widget child;
  final bool animateIn;
  final bool leaving;
  final VoidCallback onGone;

  @override
  State<_SlotAnim> createState() => _SlotAnimState();
}

class _SlotAnimState extends State<_SlotAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    reverseDuration: const Duration(milliseconds: 220),
    value: widget.animateIn ? 0 : 1,
  );
  late final Animation<double> _size = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
    reverseCurve: Curves.easeInOut,
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _c,
    curve: const ElasticOutCurve(0.6),
    reverseCurve: Curves.easeIn,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((st) {
      if (st == AnimationStatus.dismissed && widget.leaving) widget.onGone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final calm = MotionScope.of(context).calm;
    if (calm) {
      _c.value = widget.leaving ? 0 : 1;
      if (widget.leaving) {
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onGone());
      }
      return;
    }
    if (widget.leaving) {
      _c.reverse();
    } else if (widget.animateIn) {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(_SlotAnim old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) {
      if (MotionScope.of(context).calm) {
        widget.onGone();
      } else {
        _c.reverse();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      axis: Axis.horizontal,
      alignment: Alignment.centerLeft,
      child: IgnorePointer(
        ignoring: widget.leaving,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class _AddCircle extends StatelessWidget {
  const _AddCircle({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: onTap,
      scale: 0.93,
      haptic: false,
      semanticLabel: l10n.callsTabFavAddTitle,
      focusShape: FocusRingShape.rounded,
      focusRadius: 16,
      hoverRadius: 16,
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            const SizedBox(height: 4),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.accent.withValues(alpha: 0.14),
              ),
              child: Icon(CupertinoIcons.plus, size: 24, color: theme.accent),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.callsTabFavAddLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySoft.copyWith(fontSize: 12.5, color: theme.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatefulWidget {
  const _Circle({
    required this.user,
    required this.onPick,
    required this.onRemove,
    this.api,
  });
  final ChatUser user;
  final ChatApi? api;
  final void Function(ChatUser, CallMediaKind) onPick;
  final void Function(ChatUser) onRemove;

  @override
  State<_Circle> createState() => _CircleState();
}

class _CircleState extends State<_Circle> {
  final GlobalKey _face = GlobalKey(debugLabel: 'fav-face');
  final GlobalKey _cell = GlobalKey(debugLabel: 'fav-cell');

  void _open() {
    final box = _face.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    showCallChooser(
      context,
      anchor: rect,
      onPick: (kind) => widget.onPick(widget.user, kind),
    );
  }

  Future<void> _menu() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPullDownMenu<bool>(
      context: context,
      anchorKey: _cell,
      items: [
        PullDownItem(
          value: true,
          label: l10n.callsTabFavRemove,
          icon: CupertinoIcons.star_slash,
          destructive: true,
        ),
      ],
    );
    if (picked == true && mounted) widget.onRemove(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final first = widget.user.displayName.trim().split(RegExp(r'\s+')).first;
    return ChatRowLongPress(
      key: _cell,
      onLongPress: _menu,
      child: SpringPress(
        onTap: _open,
        scale: 0.93,
        haptic: false,
        semanticLabel: l10n.callsTabFavouriteSemantic(widget.user.displayName),
        focusShape: FocusRingShape.rounded,
        focusRadius: 16,
        hoverRadius: 16,
        child: SizedBox(
          width: 74,
          child: Column(
            children: [
              const SizedBox(height: 4),
              SizedBox(
                key: _face,
                width: 58,
                height: 58,
                child: UserAvatar(
                  user: widget.user,
                  size: 58,
                  api: widget.api,
                  showStatus: false,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySoft.copyWith(fontSize: 12.5, color: theme.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Springs a voice / video pair out of [anchor] (a circle's global rect).
/// Resolves through [onPick] only; a tap anywhere else puts them back.
void showCallChooser(
  BuildContext context, {
  required Rect anchor,
  required void Function(CallMediaKind kind) onPick,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final l10n = AppLocalizations.of(context);
  late OverlayEntry entry;
  void close([CallMediaKind? picked]) {
    try {
      entry.remove();
    } catch (_) {}
    if (picked != null) onPick(picked);
  }

  HapticFeedback.selectionClick();
  entry = OverlayEntry(
    builder: (_) => _Chooser(
      anchor: anchor,
      voiceLabel: l10n.callsTabVoiceCall,
      videoLabel: l10n.callsTabVideoCall,
      onClose: close,
    ),
  );
  overlay.insert(entry);
}

class _Chooser extends StatefulWidget {
  const _Chooser({
    required this.anchor,
    required this.voiceLabel,
    required this.videoLabel,
    required this.onClose,
  });
  final Rect anchor;
  final String voiceLabel;
  final String videoLabel;
  final void Function([CallMediaKind? picked]) onClose;

  @override
  State<_Chooser> createState() => _ChooserState();
}

class _ChooserState extends State<_Chooser>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 140),
  );
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _close([CallMediaKind? picked]) async {
    if (_closing) return;
    _closing = true;
    if (picked != null) HapticFeedback.lightImpact();
    await _c.reverse();
    widget.onClose(picked);
  }

  @override
  Widget build(BuildContext context) {
    final calm = MotionScope.of(context).calm;
    final centre = widget.anchor.center;
    const disc = 48.0;
    // Above the circle when there is room, otherwise below it.
    final room = centre.dy - widget.anchor.height / 2 > 120;
    final dy = room
        ? -(widget.anchor.height / 2 + disc / 2 + 10)
        : (widget.anchor.height / 2 + disc / 2 + 10);
    final targets = <(CallMediaKind, Offset, Color, IconData, String)>[
      (
        CallMediaKind.audio,
        Offset(-(disc / 2 + 8), dy),
        kCallAcceptGreen,
        CupertinoIcons.phone_fill,
        widget.voiceLabel,
      ),
      (
        CallMediaKind.video,
        Offset(disc / 2 + 8, dy),
        ThemeScope.of(context).accent,
        CupertinoIcons.videocam_fill,
        widget.videoLabel,
      ),
    ];
    return OverlayModalScope(
      onDismiss: _close,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            for (final (kind, offset, color, icon, label) in targets)
              AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  // Springs out of the circle's centre: elastic on the way
                  // in, a plain ease on the way back.
                  final raw = _c.value;
                  final t = calm
                      ? raw.clamp(0.0, 1.0)
                      : (_c.status == AnimationStatus.reverse
                          ? Curves.easeIn.transform(raw)
                          : const ElasticOutCurve(0.62).transform(raw));
                  final p = Offset.lerp(Offset.zero, offset, t)!;
                  return Positioned(
                    left: centre.dx + p.dx - disc / 2,
                    top: centre.dy + p.dy - disc / 2,
                    child: Opacity(
                      opacity: math.min(1, raw * 3),
                      child: Transform.scale(
                        scale: math.max(0.01, 0.3 + 0.7 * t),
                        child: child,
                      ),
                    ),
                  );
                },
                child: SpringPress(
                  onTap: () => _close(kind),
                  scale: 0.9,
                  haptic: false,
                  semanticLabel: label,
                  focusShape: FocusRingShape.circle,
                  child: Container(
                    width: disc,
                    height: disc,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 22, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
