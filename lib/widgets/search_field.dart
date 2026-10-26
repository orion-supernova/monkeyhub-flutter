import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'glass_buttons.dart';
import 'liquid_glass.dart';
import 'ios_kit.dart' show groupedTitleStyle, groupedValueStyle;
import 'route_landing.dart';
import 'spring_press.dart';
import 'sunlit_surface.dart' show sunlitHairline;
import '../l10n/text_case.dart';

/// Leading inset of the pill, to the magnifier. Public because
/// [SearchFieldHero]'s shuttle has to land the magnifier on exactly the pixel
/// the real field draws it at, and a flight that stops one padding step short
/// of its destination is a flight you can see snap.
const double searchFieldHPadding = 10;

/// Kept for the old card doors' callers. Every door is now a
/// [SearchField.door] — the same pill as the field — so nothing new should
/// read this.
const double searchDoorHPadding = 14;

/// One size for every magnifier in the app, so the one that flies is the same
/// glyph at both ends and never resizes mid-air. The clear disc matches it.
const double searchFieldIconSize = 17;

/// The pill's height: the chrome-button height (44 on a phone), so a search
/// bar and the discs beside it sit on one line. Fixed, never padding-derived — that is
/// how four search bars drifted to 36, 38, 40 and 44pt (a character theme's
/// 15pt body made a shorter pill than Basic's 17).
const double searchFieldHeight = 44;

/// The compact pill (Settings' search, the iOS Settings.app size): 36pt with
/// a 15pt magnifier. Opt-in via [SearchField.compact]; Chats keeps 44.
const double searchFieldCompactHeight = 36;
const double _kCompactIconSize = 15;

/// Glyph → text gap inside the pill.
const double _kGlyphGap = 6;

/// The field, its door and hero shuttle use the app's live glass material.
Widget _searchGlass(Widget child) =>
    LiquidGlass(shape: LiquidGlassShape.capsule, child: child);

/// THE search bar of the app: magnifier, field, clear disc, in a 44pt pill —
/// and, at the top of a screen, a Cancel that slides in while it is in use.
///
/// Every search in the app is this widget (or its [SearchField.door]); none
/// draws its own pill. Several screens did, and they drifted in height,
/// glyph, fill and clear button until the user noticed. One widget is also
/// what makes the flight from a door possible: a hero can only morph two
/// boxes that agree on what they are.
///
/// Type is the grouped-row voice (17, the body face) whatever the theme's
/// body size; the hint is a sentence-case "Search people" with no ellipsis.
///
/// Deliberately not a `TextField` with `InputDecoration.prefixIcon`. The
/// surrounding box is what carries the decoration, and the field inside draws
/// no border of its own — see [InputDecoration] below, and the [Material]
/// wrapper, which is what stops Flutter painting its debug underline on a
/// field that lives outside a Material-themed ancestor.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required TextEditingController this.controller,
    required this.hintText,
    required ValueChanged<String> this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
    this.heroTag,
    this.showCancel = true,
    this.onCancel,
    this.onSubmitted,
    this.leadingAccessory,
    this.compact = false,
  }) : _doorTap = null,
       semanticLabel = null;

  /// A search *door*: the same pill, not editable — tapping it opens the
  /// screen that really searches (Discover's "Search people", the reaction
  /// picker's search). Pixel-identical to the field, so with a [heroTag] the
  /// flight into that screen moves one box that never changes shape.
  const SearchField.door({
    super.key,
    required String hint,
    required VoidCallback onTap,
    this.heroTag,
    this.semanticLabel,
  }) : hintText = hint,
       _doorTap = onTap,
       controller = null,
       onChanged = null,
       onClear = null,
       autofocus = false,
       focusNode = null,
       showCancel = false,
       onCancel = null,
       onSubmitted = null,
       leadingAccessory = null,
       compact = false;

  /// Null only on a [SearchField.door].
  final TextEditingController? controller;
  final String hintText;

  /// Null only on a [SearchField.door].
  final ValueChanged<String>? onChanged;

  /// What the clear button does. Null empties [controller] and reports the
  /// empty query through [onChanged]; a caller supplies its own only when
  /// clearing means more than that — cancelling a pending debounce, say, which
  /// is the difference between the list coming back now and coming back in the
  /// 250ms a typed keystroke waits out.
  final VoidCallback? onClear;

  /// Takes the keyboard once the screen has finished arriving — never during
  /// the route transition. See [_SearchFieldState.onRouteLandingChanged].
  final bool autofocus;

  /// Supply one to drive focus from outside; otherwise this owns its own.
  final FocusNode? focusNode;

  /// Ties this bar to the door it flew out of. Null renders no [Hero] at all —
  /// a hero with no match on the other route still installs a flight-manager
  /// entry, so skipping it outright keeps the no-tag case honest.
  final Object? heroTag;

  /// The trailing Cancel that slides in while the field is focused or holds
  /// text. On for a search at the top of a screen (the search screen, the
  /// Settings hub, the chat list's pull panel); pass false inside sheets and
  /// pickers, where the sheet's own × is the way out.
  final bool showCancel;

  /// Cancel leaving the screen — the search screen pops itself here. Given
  /// one, Cancel only unfocuses before calling it; without, Cancel clears.
  final VoidCallback? onCancel;

  /// Return on the keyboard (whose key reads "Search").
  final ValueChanged<String>? onSubmitted;

  /// Sits between the magnifier and the text — a scope tag ("Stickers ×").
  final Widget? leadingAccessory;

  /// A door's screen-reader label; defaults to the hint.
  final String? semanticLabel;

  /// The 36pt glass capsule with a 15pt magnifier, for a hub's search
  /// (Settings). Cancel and clear shrink with it; their hit areas stay
  /// 44pt wide.
  final bool compact;

  final VoidCallback? _doorTap;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> with RouteLanding {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  FocusNode? _listened;

  bool _asked = false;
  bool _focused = false;
  bool _traditional =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  bool get _isDoor => widget._doorTap != null;

  @override
  void initState() {
    super.initState();
    if (_isDoor) return;
    _listen();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void didUpdateWidget(SearchField old) {
    super.didUpdateWidget(old);
    if (!_isDoor && old.focusNode != widget.focusNode) _listen();
  }

  void _listen() {
    _listened?.removeListener(_onFocus);
    _listened = _node..addListener(_onFocus);
    _focused = _node.hasFocus;
  }

  void _onFocus() {
    if (!mounted || _focused == _node.hasFocus) return;
    setState(() => _focused = _node.hasFocus);
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    final t = mode == FocusHighlightMode.traditional;
    if (mounted && t != _traditional) setState(() => _traditional = t);
  }

  /// Takes the keyboard only once the route has landed.
  ///
  /// `TextField.autofocus` would fire on the first frame of the incoming
  /// route, which is a frame too early in two different ways. A [Hero] tears
  /// its child out of the tree for the length of a flight, so the field would
  /// take focus, be unmounted, lose it, and take it again on touchdown — the
  /// keyboard visibly flashing up and back down under a bar that is still
  /// moving. And even with no hero, a keyboard rising through a page that is
  /// still sliding in is two animations spending the same 300ms arguing.
  @override
  void onRouteLandingChanged() {
    if (_isDoor || !landed || !widget.autofocus || _asked) return;
    _asked = true;
    _node.requestFocus();
  }

  @override
  void dispose() {
    if (!_isDoor) {
      FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
      _listened?.removeListener(_onFocus);
    }
    _ownNode?.dispose();
    super.dispose();
  }

  void _clear() {
    final custom = widget.onClear;
    if (custom != null) {
      custom();
      return;
    }
    widget.controller!.clear();
    widget.onChanged!('');
  }

  /// Clears only when the bar stays on screen. A Cancel that leaves (the
  /// search screen pops in [SearchField.onCancel]) keeps its query: clearing
  /// it reported an empty query on the way out, and the rooms list reloaded
  /// behind a spinner for the whole flight back to the door.
  void _cancel() {
    final leave = widget.onCancel;
    if (leave == null && widget.controller!.text.isNotEmpty) _clear();
    _node.unfocus();
    leave?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final pill = _isDoor ? _door(context, theme) : _field(context, theme);
    final tag = widget.heroTag;
    final flown = tag == null
        ? pill
        : SearchFieldHero(
            tag: tag,
            hint: sentenceCaseOf(context, widget.hintText),
            text: widget.controller,
            child: pill,
          );
    if (_isDoor || !widget.showCancel) return flown;
    return Row(
      children: [
        Expanded(child: flown),
        _CancelSlot(
          controller: widget.controller!,
          focused: _focused,
          onCancel: _cancel,
          compact: widget.compact,
        ),
      ],
    );
  }

  /// The capsule both variants share: fill, height, the magnifier at the
  /// same x. [trailing] is the clear disc's slot.
  Widget _capsule(
    AppTheme theme, {
    required Widget content,
    Widget? trailing,
    bool ring = false,
  }) {
    final compact = widget.compact;
    final iconSize = compact ? _kCompactIconSize : searchFieldIconSize;
    // Compact keeps the glass (its lit rim is the house look); only the
    // height and glyph shrink.
    return Material(
      type: MaterialType.transparency,
      child: _searchGlass(
        Container(
          constraints: BoxConstraints(
            minHeight:
                compact ? searchFieldCompactHeight : searchFieldHeight,
          ),
          // Keyboard focus only: a touch user has the caret; a hardware-
          // keyboard user tabbing through needs to see where they landed.
          foregroundDecoration: ring
              ? ShapeDecoration(
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: theme.accent,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                )
              : null,
          padding: const EdgeInsets.only(left: searchFieldHPadding),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.search,
                color: theme.inkMuted,
                size: iconSize,
              ),
              const SizedBox(width: _kGlyphGap),
              Expanded(child: content),
              trailing ?? const SizedBox(width: searchFieldHPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _door(BuildContext context, AppTheme theme) {
    final hint = sentenceCaseOf(context, widget.hintText);
    return SpringPress(
      onTap: widget._doorTap,
      scale: 0.98,
      haptic: false,
      focusShape: FocusRingShape.capsule,
      semanticLabel: widget.semanticLabel ?? hint,
      child: _capsule(
        theme,
        content: Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: groupedValueStyle(theme),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller!;
    final accessory = widget.leadingAccessory;
    final input = TextField(
      controller: controller,
      focusNode: _node,
      style: groupedTitleStyle(theme),
      cursorColor: theme.accent,
      cursorWidth: 2,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        // Sentence case whatever the caller passes: most hints in the ARBs
        // were written lower-case for the old chrome.
        hintText: sentenceCaseOf(context, widget.hintText),
        hintStyle: groupedValueStyle(theme),
        hintMaxLines: 1,
        contentPadding:
            EdgeInsets.symmetric(vertical: widget.compact ? 6 : 8),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
    return _capsule(
      theme,
      ring: _focused && _traditional,
      content: accessory == null
          ? input
          : Row(
              children: [
                accessory,
                const SizedBox(width: _kGlyphGap),
                Expanded(child: input),
              ],
            ),
      // Rebuilds only this small slot on every keystroke — the controller is
      // a Listenable, and the clear button's whole job is reacting to its
      // text, so there's no reason to rebuild the rest of the bar (or lift
      // state up) for it.
      trailing: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => controller.text.isEmpty
            ? const SizedBox(width: searchFieldHPadding)
            : Padding(
                padding: EdgeInsets.only(right: widget.compact ? 0 : 4),
                child: SpringPress(
                  onTap: _clear,
                  scale: 0.86,
                  haptic: false,
                  focusShape: FocusRingShape.circle,
                  semanticLabel: l10n.pullRevealClearSearchSemanticLabel,
                  child: SizedBox(
                    // Compact: the full 36pt capsule height by 44 wide, so
                    // the disc is smaller but the hit area is not.
                    width: widget.compact ? 44 : 32,
                    height: widget.compact ? searchFieldCompactHeight : 32,
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: widget.compact
                          ? _kCompactIconSize
                          : searchFieldIconSize,
                      color: theme.inkMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The search bar's trailing Cancel: slides in while the field is focused or
/// holds text, slides out once it is neither. Instant under reduced motion.
class _CancelSlot extends StatelessWidget {
  const _CancelSlot({
    required this.controller,
    required this.focused,
    required this.onCancel,
    this.compact = false,
  });

  final TextEditingController controller;
  final bool focused;
  final VoidCallback onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final calm = MotionScope.of(context).calm;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final show = focused || controller.text.isNotEmpty;
        final button = GlassCloseButton(
          semanticLabel: MaterialLocalizations.of(
            context,
          ).cancelButtonLabel,
          onTap: onCancel,
        );
        return ClipRect(
          child: AnimatedSize(
            duration: calm ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            child: show
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: compact ? _compactCancel(context) : button,
                  )
                : SizedBox(
                    height: compact
                        ? searchFieldCompactHeight
                        : searchFieldHeight,
                  ),
          ),
        );
      },
    );
  }
}

/// The compact Cancel: a 36pt disc to sit beside the 36pt capsule, inside a
/// 44pt hit square (the outer tap catches the ring around the disc).
extension on _CancelSlot {
  Widget _compactCancel(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCancel,
        child: SizedBox.square(
          dimension: searchFieldHeight,
          child: Center(
            child: GlassIconButton(
              icon: CupertinoIcons.xmark,
              iconSize: 15,
              size: searchFieldCompactHeight,
              semanticLabel: MaterialLocalizations.of(
                context,
              ).cancelButtonLabel,
              onTap: onCancel,
            ),
          ),
        ),
      );
}

/// The flight between a search *door* and the search bar it opens.
///
/// Wrap both ends in this with the same [tag]. The ends may — and Discover's
/// door does — carry content of completely different shapes: the box morphs
/// from one to the other, and each end's content fades on its own end of the
/// flight rather than being stretched across it.
///
/// A plain [Hero] between these two was tried and removed once, because its
/// default shuttle renders the *destination's* child at every intermediate
/// size: the card's own text inside a box collapsing toward one line
/// overflowed on every frame. Here the card is drawn at its own size, clipped
/// by the morphing box, and gone before the box is small enough to matter.
class SearchFieldHero extends StatelessWidget {
  const SearchFieldHero({
    super.key,
    required this.tag,
    required this.child,
    this.hint,
    this.text,
    this.radius,
  });

  final Object tag;
  final Widget child;

  /// A pill end: the hint its field shows when empty. The shuttle draws the
  /// magnifier and this (or [text], when it holds a query) where the field
  /// draws them, so touchdown hands over to the real field without a pop.
  /// Null for an end that is not a pill — its [child] is flown instead.
  final String? hint;

  /// The field's live text, for a pill end that is an editable field.
  final TextEditingController? text;

  /// Corner radius of a non-pill end (Discover's grouped card door). Null is
  /// the capsule.
  final double? radius;

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    // A straight line. MaterialApp's default arcs the rect, and re-plots the
    // arc on every frame its destination moves: a path that bends under the
    // bar while it flies, read as a shake.
    createRectTween: (begin, end) => RectTween(begin: begin, end: end),
    flightShuttleBuilder: _shuttle,
    child: child,
  );

  /// What actually flies: one box morphing from the door's shape to the
  /// pill's, the door's content fading out over the first part of the flight
  /// and the field's fading in over the last.
  ///
  /// The box is blur-free glass. A [BackdropFilter] flying through a route
  /// transition samples two cross-fading pages moving under it: it smeared
  /// whatever passed beneath into the pill — a green blur of a room's
  /// "Joined" badge on the way up. The still twin is what the pill looks like
  /// at rest on a plain page, and touchdown swaps in the real glass.
  ///
  /// Text drawn here sits under its own [Material]: an overlay entry is
  /// outside both routes' [DefaultTextStyle], and this app does not let
  /// Flutter's debug fallback underline anything.
  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    // Read the theme from the flight context: `ThemeScope` sits above the
    // app's navigator, so the overlay is inside it either way.
    final theme = ThemeScope.of(flightContext);
    // By role, not by direction: the animation is the search route's in both
    // directions, so 0 is always the door and 1 always the field.
    final push = direction == HeroFlightDirection.push;
    final doorCtx = push ? fromHeroContext : toHeroContext;
    final fieldCtx = push ? toHeroContext : fromHeroContext;
    final door = _End.of(doorCtx);
    final field = _End.of(fieldCtx);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value.clamp(0.0, 1.0);
          return LayoutBuilder(
            builder: (context, box) {
              final capsule = box.maxHeight / 2;
              final shape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  lerpDouble(door?.radius ?? capsule, capsule, t)!,
                ),
              );
              return _stillGlass(
                theme,
                shape,
                // The card door casts nothing; the pill's shadow grows in.
                shadow: door?.radius == null ? 1 : t,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (door != null)
                      Opacity(
                        opacity: 1 - Curves.easeOut.transform(
                          (t / 0.45).clamp(0.0, 1.0),
                        ),
                        child: door.content(theme),
                      ),
                    if (field != null)
                      Opacity(
                        opacity: Curves.easeIn.transform(
                          ((t - 0.55) / 0.45).clamp(0.0, 1.0),
                        ),
                        child: field.content(theme),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// [LiquidGlass]'s matched recipe without the blur: its tint laid over the
  /// page colour instead of over a backdrop, the light pooled at the top, the
  /// specular rim. Paint only — nothing here rasterises per frame.
  static Widget _stillGlass(
    AppTheme theme,
    OutlinedBorder shape, {
    required double shadow,
    required Widget child,
  }) {
    final isLight = theme.background.computeLuminance() > 0.5;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: Color.alphaBlend(
          Colors.white.withValues(alpha: isLight ? 0.72 : 0.07),
          theme.background,
        ),
        shadows: shadow <= 0
            ? null
            : [
                BoxShadow(
                  color: (isLight ? theme.ink : Colors.black).withValues(
                    alpha: (isLight ? 0.09 : 0.24) * shadow,
                  ),
                  blurRadius: isLight ? 14 : 18,
                  offset: Offset(0, isLight ? 3 : 5),
                ),
                // Light: the contact shadow that gives a white pill an edge.
                if (isLight)
                  BoxShadow(
                    color: theme.ink.withValues(alpha: 0.05 * shadow),
                    blurRadius: 2.5,
                    offset: const Offset(0, 1),
                  ),
              ],
      ),
      child: CustomPaint(
        foregroundPainter: SpecularRim(
          shape: shape,
          light: isLight,
          edge: isLight ? sunlitHairline(theme) : null,
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isLight ? 0.25 : 0.10),
                  // Transparent WHITE, as in [LiquidGlass]: transparent black
                  // lays a grey band across the glass.
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.55],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// One end of a [SearchFieldHero] flight, read once as the flight starts.
class _End {
  const _End(this.hero, this.size);

  final SearchFieldHero hero;

  /// The end's laid-out size — what a flown [SearchFieldHero.child] is drawn
  /// at, so the shrinking box clips it instead of squeezing it.
  final Size? size;

  double? get radius => hero.hint == null ? hero.radius : null;

  static _End? of(BuildContext heroContext) {
    final hero = heroContext.findAncestorWidgetOfExactType<SearchFieldHero>();
    if (hero == null) return null;
    final box = heroContext.findRenderObject();
    final size = box is RenderBox && box.hasSize ? box.size : null;
    return _End(hero, size);
  }

  Widget content(AppTheme theme) {
    final hint = hero.hint;
    if (hint == null) {
      final s = size;
      if (s == null) return const SizedBox.shrink();
      return OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: s.width,
        maxWidth: s.width,
        minHeight: s.height,
        maxHeight: s.height,
        child: hero.child,
      );
    }
    // The field's own row, glyph for glyph: [SearchField._capsule]'s padding,
    // magnifier and gap, the hint in the field's hint voice or the query in
    // its typed one.
    final query = hero.text?.text ?? '';
    return Padding(
      padding: const EdgeInsets.only(left: searchFieldHPadding),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            size: searchFieldIconSize,
            color: theme.inkMuted,
          ),
          const SizedBox(width: _kGlyphGap),
          Expanded(
            child: Text(
              query.isEmpty ? hint : query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: query.isEmpty
                  ? groupedValueStyle(theme)
                  : groupedTitleStyle(theme),
            ),
          ),
          const SizedBox(width: searchFieldHPadding),
        ],
      ),
    );
  }
}
