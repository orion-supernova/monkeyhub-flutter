import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart';
import 'teardown_safe.dart';

// The account-area half of the iOS vocabulary in ios_kit.dart: the Contacts /
// Telegram profile shape (a big face, a name, a row of action tiles, then
// grouped sections) and the helpers the profile, room info and account pages
// share. Built on the kit's atoms, never instead of them.

/// Horizontal padding that keeps a page's grouped blocks at a readable width
/// on a wide window and at the iOS 16pt inset on a phone.
EdgeInsets readableInset(BuildContext context, {double top = 0, double bottom = 0}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = context.isCompact
      ? 16.0
      : ((width - ContentWidth.readable) / 2).clamp(16.0, double.infinity);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// [IosPage] slivers for a plain list of [children], centred at a readable
/// width on wide windows. Clears the home indicator itself.
List<Widget> readableSlivers(BuildContext context, List<Widget> children) => [
      SliverPadding(
        padding: readableInset(
          context,
          bottom: 40 + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: SliverList.list(children: children),
      ),
    ];

/// A page led by a person or a room rather than by a title: the hero (big
/// avatar, name, actions) scrolls away and the name fades into the bar, the
/// way Contacts and Telegram profiles behave.
class HeroPage extends StatefulWidget {
  const HeroPage({
    super.key,
    required this.title,
    required this.hero,
    required this.children,
    this.actions = const [],
  });

  /// What the bar shows once the hero has scrolled away.
  final String title;
  final Widget hero;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  State<HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<HeroPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _scroll,
                          builder: (context, child) {
                            final offset =
                                _scroll.hasClients ? _scroll.offset : 0.0;
                            return Opacity(
                              opacity: ((offset - 150) / 40).clamp(0.0, 1.0),
                              child: child,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 56),
                            child: Text(
                              widget.title,
                              style: theme.bodyEmph.copyWith(color: theme.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            if (canPop) const GlassBackButton(),
                            const Spacer(),
                            for (var i = 0; i < widget.actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              widget.actions[i],
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverToBoxAdapter(child: widget.hero),
                      ...readableSlivers(context, widget.children),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero's avatar: scales in on a soft spring the first time the page
/// shows, the Telegram profile "pop". Static under reduced motion.
class AvatarPop extends StatelessWidget {
  const AvatarPop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.72, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: child,
    );
  }
}

/// Fades and lifts its child in, [index] steps behind the first — the
/// stagger the hero's name, handle and action row arrive on.
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// One tile in a profile's action row — icon over a short label on a rounded
/// surface tile, equal widths, the Telegram / iOS Contacts arrangement.
class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.busy = false,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;

  /// Null greys the tile out.
  final VoidCallback? onTap;
  final bool danger;
  final bool busy;

  /// The one action the page is for (Message, Add friend): accent glyph.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null && !busy;
    final tint = danger
        ? theme.danger
        : (emphasis ? theme.accent : theme.ink);
    final ink = enabled ? tint : theme.inkMuted.withValues(alpha: 0.6);
    return SpringPress(
      onTap: enabled ? onTap : null,
      semanticLabel: label,
      scale: 0.92,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: groupedFill(theme),
          borderRadius: BorderRadius.circular(
            (groupedRadius(theme) * 0.7).clamp(6.0, 16.0),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 20,
                height: 20,
                child: CupertinoActivityIndicator(color: tint),
              )
            else
              Icon(icon, size: 22, color: ink),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of [ProfileActionTile]s, equal widths with an 8pt gap.
class ProfileActionBar extends StatelessWidget {
  const ProfileActionBar({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tiles[i]),
          ],
        ],
      );
}

/// The full-width buttons of a sheet or dialog: a quiet one and a filled one,
/// both capsules, the iOS 26 alert/sheet button shape.
class SheetButton extends StatelessWidget {
  const SheetButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final tone = danger ? theme.danger : theme.accent;
    final bg = filled
        ? (onTap == null ? tone.withValues(alpha: 0.35) : tone)
        : theme.ink.withValues(alpha: 0.08);
    final fg = filled
        ? (danger ? Colors.white : theme.accentInk)
        : (danger ? theme.danger : theme.ink);
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.bodyEmph.copyWith(
            fontSize: 17,
            letterSpacing: 0,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// A small status line under a hero name: a coloured dot and a word.
class StatusDotLine extends StatelessWidget {
  const StatusDotLine({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.caption.copyWith(fontSize: 14, color: theme.inkMuted),
        ),
      ],
    );
  }
}

/// A note under a hero or above a section: an icon and a sentence on a soft
/// fill, for things like "some fields are hidden".
class SoftNote extends StatelessWidget {
  const SoftNote({
    super.key,
    required this.icon,
    required this.text,
    this.tone,
  });

  final IconData icon;
  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final c = tone ?? theme.inkMuted;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(groupedRadius(theme) * 0.7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.caption.copyWith(
                fontSize: 14,
                height: 1.35,
                color: theme.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section spacing helper for code that builds a hero by hand.
const SizedBox kHeroGap = SizedBox(height: 20);

/// A [GroupedSection] for rows that are not [GroupedRow]s — member lists,
/// inline editors — where the divider has to start at a caller-chosen inset
/// (the text column beside an avatar) rather than the kit's two defaults.
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.dividerInset = 16,
    this.margin = const EdgeInsets.only(bottom: 28),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final double dividerInset;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(
                header!,
                style: theme.caption.copyWith(
                  fontSize: 13,
                  color: theme.inkMuted,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(groupedRadius(theme)),
            child: ColoredBox(
              color: groupedFill(theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      Padding(
                        padding: EdgeInsets.only(left: dividerInset),
                        child: Container(
                          height: hairline,
                          color: theme.ink.withValues(alpha: 0.10),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(
                footer!,
                style: theme.caption.copyWith(
                  fontSize: 13,
                  height: 1.35,
                  color: theme.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row with the grouped-row press highlight around arbitrary [child]
/// content — the member rows, the invite rows. Pass null [onTap] for a static
/// row.
class PressRow extends StatefulWidget {
  const PressRow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.padding = const EdgeInsets.fromLTRB(16, 9, 14, 9),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final EdgeInsets padding;

  @override
  State<PressRow> createState() => _PressRowState();
}

class _PressRowState extends State<PressRow>
    with TeardownSafe<PressRow> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final body = Padding(padding: widget.padding, child: widget.child);
    if (widget.onTap == null) return body;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: _down ? Duration.zero : const Duration(milliseconds: 260),
          color: _down
              ? theme.ink.withValues(alpha: 0.08)
              : Colors.transparent,
          child: body,
        ),
      ),
    );
  }
}
