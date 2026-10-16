import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/app_shortcuts.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'glass_buttons.dart';
import 'liquid_glass.dart';
import 'message_stamp.dart' show formatClockTime;

/// The top bar every full-screen media viewer wears — the photo viewer, the
/// video viewer, the gallery pager and the view-once viewer — so all four look
/// and behave as one: the close where Photos keeps it (top left), a centred
/// title or [center] widget, trailing [actions], and a scrim so white glass
/// and text stay legible over a bright sky.
///
/// Positioning and fading stay with the caller, which knows its own dismiss
/// gesture; this is only the bar. What the bar does own is the rule about its
/// glass: a `BackdropFilter` is never faded, so while the bar is moving — the
/// route flying in or out, or [still] because the caller is fading it with a
/// drag — its discs draw as [ViewerChromeButton]'s blur-free twin, and become
/// real glass again once everything has come to rest.
class ViewerTopBar extends StatefulWidget {
  const ViewerTopBar({
    super.key,
    required this.onClose,
    this.closeLabel,
    this.title,
    this.subtitle,
    this.subtitleSemanticLabel,
    this.center,
    this.actions = const [],
    this.still = false,
    this.band = true,
  });

  final VoidCallback onClose;

  /// The solid bar behind the chrome. False lays a soft scrim over the
  /// picture instead, which reaches a little below the buttons and fades to
  /// nothing: for a viewer whose picture has nowhere else to be (the
  /// view-once photo, shown once, whole), where a solid band would sit on
  /// top of a portrait shot's top edge.
  final bool band;

  /// Screen-reader label for the close. Defaults to the platform's "Close".
  final String? closeLabel;
  final String? title;
  final String? subtitle;

  /// What a screen reader hears instead of [subtitle] — the pager's "3 of 8",
  /// which the eye gets from the filmstrip and the ear has no other way to.
  final String? subtitleSemanticLabel;

  /// Replaces the title column — e.g. the view-once badge.
  final Widget? center;

  /// Trailing buttons. Build them as [ViewerChromeButton]s and pass them
  /// [ViewerTopBar.stillOf] so they follow the same glass rule as the ×.
  final List<Widget> actions;

  /// The caller is fading or moving the bar right now (a dismiss drag, a
  /// tap-to-hide fade), so its discs must not blur.
  final bool still;

  static const double _button = 40;

  /// Whether the bar's discs are drawing blur-free right now — for trailing
  /// actions built by the caller, which cannot see the route's animation.
  static bool stillOf(BuildContext context) =>
      _ViewerStill.maybeOf(context) ?? false;

  @override
  State<ViewerTopBar> createState() => _ViewerTopBarState();
}

class _ViewerTopBarState extends State<ViewerTopBar> {
  Animation<double>? _route;
  bool _routeMoving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context)?.animation;
    if (identical(next, _route)) return;
    _route?.removeStatusListener(_onRouteStatus);
    _route = next;
    _route?.addStatusListener(_onRouteStatus);
    _routeMoving = _moving(_route?.status);
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  // A status listener, not an AnimatedBuilder: the bar only needs to know
  // WHETHER the route is moving, and rebuilding it on every frame of the
  // flight to learn that would be work spent on the one moment that has none
  // to spare.
  static bool _moving(AnimationStatus? s) =>
      s == AnimationStatus.forward || s == AnimationStatus.reverse;

  void _onRouteStatus(AnimationStatus s) {
    final moving = _moving(s);
    if (moving != _routeMoving && mounted) setState(() => _routeMoving = moving);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    final still = widget.still || _routeMoving;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final Widget? middle = widget.center ??
        (title == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyEmph.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: MediaGlass.ink,
                      decoration: TextDecoration.none,
                      shadows: _kGlyphShadow,
                    ),
                  ),
                  if (subtitle != null)
                    // The body face at 13 in near-white — the caption slot
                    // was tracked mono at low contrast on a character
                    // theme, nearly gone over a bright sky.
                    Semantics(
                      label: widget.subtitleSemanticLabel,
                      excludeSemantics: widget.subtitleSemanticLabel != null,
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.body.copyWith(
                          fontSize: 13,
                          height: 1.25,
                          color: MediaGlass.ink.withValues(alpha: 0.85),
                          decoration: TextDecoration.none,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: _kGlyphShadow,
                        ),
                      ),
                    ),
                ],
              ));
    // The title is centred on the SCREEN, like a sheet bar's: inset by the
    // wider side's chrome on both sides, so two trailing actions no longer
    // shove it left of centre.
    final actions = widget.actions;
    final side =
        ViewerTopBar._button * (actions.isEmpty ? 1 : actions.length) + 8;

    return _ViewerStill(
      still: still,
      child: Stack(
        clipBehavior: widget.band ? Clip.hardEdge : Clip.none,
        children: [
          if (!widget.band)
            // Over the picture, not above it: the same wash the editor's
            // chrome wears, a step further down so white glass and text stay
            // legible over a bright sky. Never blurred, for the band's reason.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: -48,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            )
          else
          // A real bar, not a scrim: the ×, who sent it and Show in chat read
          // as one navigation bar over the black void. Solid, never blurred —
          // this chrome fades on every tap, and a fading blur is the one
          // thing the app never draws.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xE0141416),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1 / MediaQuery.devicePixelRatioOf(context),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, pad.top + 6, 8, 10),
            // At least the buttons' height, and taller when large text makes
            // the name and the date need it — the bar grows rather than
            // clipping the second line.
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: ViewerTopBar._button),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (middle != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      child: middle,
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    // The shared media ×, 17pt glyph like every close.
                    // Always the blur-free disc: the bar behind it is solid,
                    // so live glass bought nothing — and swapping glass for
                    // the still disc whenever the route moved made the ×
                    // visibly flicker on every open and dismiss.
                    child: ViewerChromeButton(
                      icon: CupertinoIcons.xmark,
                      iconSize: 17,
                      semanticLabel: widget.closeLabel ??
                          MaterialLocalizations.of(context).closeButtonLabel,
                      onTap: widget.onClose,
                    ),
                  ),
                  if (actions.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child:
                          Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carries [ViewerTopBar]'s "moving right now" down to trailing actions the
/// caller built, so one flag decides every disc in the bar.
class _ViewerStill extends InheritedWidget {
  const _ViewerStill({required this.still, required super.child});

  final bool still;

  static bool? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ViewerStill>()?.still;

  @override
  bool updateShouldNotify(_ViewerStill old) => old.still != still;
}

/// A 40pt disc in a viewer's top bar.
///
/// At rest it IS the media glass button — this adds nothing to the material.
/// [still] draws the same disc, same hairline, same shadow, with no blur
/// behind it, for the frames when the chrome is fading or flying: the app's
/// one rule about glass is that a `BackdropFilter` is never animated, and the
/// viewer chrome fades every time a tap hides it or a drag sends the picture
/// home. The fill is a shade darker than the glass's to make up for the
/// photograph no longer being softened behind it — side by side for one frame
/// at the start of a 90ms fade, the two read as the same button.
///
/// [still] defaults to whatever the enclosing [ViewerTopBar] says.
class ViewerChromeButton extends StatelessWidget {
  const ViewerChromeButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.iconSize = 19,
    this.still,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double iconSize;
  final bool? still;

  /// A mouse's hover hint, usually from [viewerShortcutTip]. Null on a
  /// phone, which has no hover to show it on.
  final String? tooltip;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    // The media glass every control over a photo wears — the camera's, the
    // composer's — blur-free, because this chrome fades.
    final button = GlassIconButton(
      icon: icon,
      iconSize: iconSize,
      semanticLabel: semanticLabel,
      onTap: onTap,
      tone: GlassTone.media,
      // Never live glass in the viewer — see the × in [ViewerTopBar]. One
      // material for the whole flight, so nothing changes mid-animation.
      still: true,
    );
    final tip = tooltip;
    if (tip == null) return button;
    return _hint(tip, button);
  }
}

/// The hover hint every viewer control wears on a desk: the action, then its
/// keys as the platform prints them ("Save  ⌘S", "Save  Ctrl+S").
String viewerShortcutTip(String label, ShortcutDef def) {
  final caps = def.chords.first.caps();
  final keys = KeyCombo.appleModifiers ? caps.join() : caps.join('+');
  return '$label  $keys';
}

/// A tooltip that waits a beat, as a Mac's does: an instant one flashes up
/// under every pass of the pointer across the chrome. Excluded from
/// semantics, because the button already says what it is.
Widget _hint(String message, Widget child) => Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 600),
      excludeFromSemantics: true,
      child: child,
    );

/// The previous / next disc at a viewer's left or right edge, Apple Photos'
/// way: shown while a mouse moves over the picture, gone at the end of the
/// set, never on touch (the caller decides all three and passes [visible]).
///
/// The same blur-free media disc as every other viewer control. It fades with
/// the chrome, and a fading `BackdropFilter` is the one thing the app never
/// draws; and a disc floating over the middle of a photograph is exactly
/// where a live blur would cost a full-height pass per frame of the fade.
class ViewerEdgeChevron extends StatelessWidget {
  const ViewerEdgeChevron({
    super.key,
    required this.start,
    required this.visible,
    required this.opacity,
    required this.tooltip,
    required this.onTap,
    this.onHover,
  });

  /// The left edge (true) or the right one, as drawn: the caller has
  /// already turned previous / next into sides for the reading direction.
  final bool start;
  final bool visible;

  /// The chrome's opacity, so the discs leave with the bars and not before.
  final double opacity;
  final String tooltip;
  final VoidCallback onTap;
  final ValueChanged<bool>? onHover;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final shown = visible ? opacity : 0.0;
    return Positioned(
      left: start ? 16 : null,
      right: start ? null : 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: IgnorePointer(
          ignoring: shown < 0.05,
          child: AnimatedOpacity(
            opacity: shown,
            duration: const Duration(milliseconds: 140),
            child: MouseRegion(
              onEnter: onHover == null ? null : (_) => onHover!(true),
              onExit: onHover == null ? null : (_) => onHover!(false),
              child: _hint(
                tooltip,
                GlassIconButton(
                  icon: start
                      ? CupertinoIcons.chevron_left
                      : CupertinoIcons.chevron_right,
                  size: size,
                  iconSize: 20,
                  semanticLabel: tooltip,
                  onTap: onTap,
                  tone: GlassTone.media,
                  still: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The soft shadow every bare white glyph and label over a photograph wears:
/// enough to lift white off a bright sky, invisible over a dark room.
const List<Shadow> _kGlyphShadow = [Shadow(color: Color(0x99000000), blurRadius: 6)];

/// One button in a [ViewerToolbar].
class ViewerToolbarAction {
  const ViewerToolbarAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Delete. Tinted, not filled: a red disc at the bottom of a photograph is
  /// an alarm, a pink-white glyph is a choice.
  final bool danger;
}

/// The actions under a full-screen picture — Share, Save, Forward, Delete —
/// laid out the iOS 26 Photos way: the first action alone on the left, the
/// last alone on the right, anything between grouped in one pill in the
/// middle. All of it in the same 40pt disc material as the × and Show in
/// chat above, so the viewer has one family of controls.
///
/// A grouped capsule with dividers between every icon read as Android; iOS
/// groups by position and shape, never with rules between glyphs.
///
/// Blur-free discs ([GlassIconButton] `still`): the toolbar fades with the
/// rest of the chrome on every tap and dismiss, and a fading blur is the one
/// thing the app never draws — swapping materials mid-fade is what made the
/// buttons flicker.
class ViewerToolbar extends StatelessWidget {
  const ViewerToolbar({super.key, required this.actions});

  final List<ViewerToolbarAction> actions;

  /// Height of the row, for callers reserving space above it.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    Widget disc(ViewerToolbarAction a) => GlassIconButton(
          icon: a.icon,
          onTap: a.onTap,
          semanticLabel: a.semanticLabel,
          color: a.danger ? theme.danger : null,
          tone: GlassTone.media,
          still: true,
        );
    final middle = actions.length > 2
        ? actions.sublist(1, actions.length - 1)
        : const <ViewerToolbarAction>[];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (actions.isNotEmpty) disc(actions.first),
            const Spacer(),
            if (middle.length == 1) disc(middle.single),
            if (middle.length > 1)
              // The middle group: the shared grouped pill, blur-free because
              // this toolbar fades with the rest of the chrome.
              GlassButtonGroup(
                still: true,
                items: [
                  for (final a in middle)
                    GlassGroupItem(
                      icon: a.icon,
                      semanticLabel: a.semanticLabel,
                      onTap: a.onTap,
                      color: a.danger ? theme.danger : null,
                    ),
                ],
              ),
            const Spacer(),
            if (actions.length > 1) disc(actions.last),
          ],
        ),
      ),
    );
  }
}

/// When a picture was sent, the way the viewer's subtitle says it: "Today at
/// 14:32", "Yesterday at 09:10", "Oct 3 at 14:32" this year, else
/// "Oct 3, 2025 at 14:32".
///
/// The time is the transcript's own 24h clock, so the viewer and the bubble it
/// came from never disagree about when something was said.
String viewerWhenLabel(BuildContext context, DateTime at) {
  final l10n = AppLocalizations.of(context);
  final local = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = formatClockTime(local);
  if (day == today) return l10n.photoChromeWhenToday(time);
  if (today.difference(day).inDays == 1) {
    return l10n.photoChromeWhenYesterday(time);
  }
  final material = MaterialLocalizations.of(context);
  // The year only when it is not this one — and then always, which
  // `formatMediumDate` (weekday, month, day) would silently drop.
  final date = day.year == now.year
      ? material.formatShortMonthDay(day)
      : material.formatShortDate(day);
  return l10n.photoChromeWhenDate(date, time);
}
