import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'route_landing.dart';

/// Horizontal inset of the pill's contents. Public because
/// [SearchFieldHero]'s shuttle has to land the magnifier on exactly the pixel
/// the real field draws it at, and a flight that stops one padding step short
/// of its destination is a flight you can see snap.
const double searchFieldHPadding = 16;

/// The same, for a *door* — a card that opens a search screen rather than
/// being one (Discover's FIND PEOPLE / SEARCH ROOMS rows). It lives here for
/// the same reason: it is the other end of the flight the shuttle interpolates.
const double searchDoorHPadding = 14;

/// One size for every magnifier in the app, so the one that flies is the same
/// glyph at both ends and never resizes mid-air.
const double searchFieldIconSize = 18;

/// The pill.
///
/// The theme's own input box, just rounder: colour, border and fill all come
/// from [AppTheme.inputDecoration] so a theme that restyles its text fields
/// restyles search too. Fully round rather than the app's moderate radius
/// because that is what makes a text field read as a *search* field — every
/// big chat app draws it this way, and the shape is doing work no icon can.
BoxDecoration searchFieldDecoration(AppTheme theme) =>
    theme.inputDecoration().copyWith(borderRadius: BorderRadius.circular(999));

/// The app's search bar: magnifier, field, clear button, in a pill.
///
/// Three screens drew their own before this existed — the chat list's
/// pull-down panel, and both halves of Discover's search screen — and they had
/// already drifted apart: one was a pill and one was a rounded box, one had a
/// clear button and one left you selecting text to erase it. They are one
/// widget now, which is also what makes the flight between them possible: a
/// hero can only morph two boxes that agree on what they are.
///
/// Deliberately not a `TextField` with `InputDecoration.prefixIcon`. The
/// surrounding [Container] is what carries the theme's decoration, and the
/// field inside draws no border of its own — see [InputDecoration] below, and
/// the [Material] wrapper, which is what stops Flutter painting its debug
/// underline on a field that lives outside a Material-themed ancestor.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
    this.heroTag,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

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

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> with RouteLanding {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  bool _asked = false;

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
    if (!landed || !widget.autofocus || _asked) return;
    _asked = true;
    _node.requestFocus();
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  void _clear() {
    final custom = widget.onClear;
    if (custom != null) {
      custom();
      return;
    }
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final field = Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: searchFieldDecoration(theme),
        padding: const EdgeInsets.symmetric(horizontal: searchFieldHPadding),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: theme.inkMuted,
              size: searchFieldIconSize,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _node,
                style: theme.body.copyWith(color: theme.ink),
                cursorColor: theme.accent,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.hintText,
                  hintStyle: theme.body.copyWith(color: theme.inkMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: widget.onChanged,
              ),
            ),
            // Rebuilds only this small row on every keystroke — the controller
            // is a Listenable, and the clear button's whole job is reacting to
            // its text, so there's no reason to rebuild the rest of the bar
            // (or lift state up) for it.
            AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => widget.controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: FocusableTap(
                        onTap: _clear,
                        semanticLabel: l10n.pullRevealClearSearchSemanticLabel,
                        shape: FocusRingShape.circle,
                        radius: 999,
                        child: GestureDetector(
                          onTap: _clear,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            CupertinoIcons.clear_circled_solid,
                            size: searchFieldIconSize,
                            color: theme.inkMuted,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    final tag = widget.heroTag;
    return tag == null ? field : SearchFieldHero(tag: tag, child: field);
  }
}

/// The flight between a search *door* and the search bar it opens.
///
/// Wrap both ends in this with the same [tag]. Both may — and Discover's door
/// does — carry content of completely different shapes; only the box travels.
///
/// A plain [Hero] between these two was tried and removed once, because its
/// default shuttle renders the *destination's* child at every intermediate
/// size: a one-line field asked to draw itself inside a box the height of a
/// two-line card is fine, but the same card's own text inside a box collapsing
/// toward one line overflows on every frame of the flight. The shuttle below
/// carries nothing that can overflow — the box itself, and the one glyph both
/// ends genuinely share.
class SearchFieldHero extends StatelessWidget {
  const SearchFieldHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Hero(tag: tag, flightShuttleBuilder: _shuttle, child: child);

  /// What actually flies: the two decorations lerped, with the magnifier
  /// gliding from the door's trailing edge to the field's leading one.
  ///
  /// `animation.value` is 1 at the *search screen* end of the flight in both
  /// directions — Flutter hands the shuttle the pushed route's animation on a
  /// push and the popping route's on a pop — so a single `t` describes
  /// "how much of a search bar is this right now" without consulting
  /// [HeroFlightDirection] at all.
  ///
  /// Nothing here draws text. That is not only about overflow: an overlay
  /// entry sits outside both routes' [Material] and [DefaultTextStyle], and
  /// this app does not let Flutter's debug fallback underline anything.
  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    // Read from the flight context, not from either hero's: those two are
    // mid-flight and their elements are being handed around. `ThemeScope` sits
    // above the app's navigator, so the overlay is inside it either way.
    final theme = ThemeScope.of(flightContext);
    final door = theme.inputDecoration();
    final bar = searchFieldDecoration(theme);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value.clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration.lerp(door, bar, t)!,
          child: Align(
            alignment:
                Alignment.lerp(Alignment.centerRight, Alignment.centerLeft, t)!,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    lerpDouble(searchDoorHPadding, searchFieldHPadding, t)!,
              ),
              child: Icon(
                Icons.search,
                size: searchFieldIconSize,
                color: theme.inkMuted,
              ),
            ),
          ),
        );
      },
    );
  }
}
