import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';

// The app's shared iOS vocabulary: a page with a large title, inset grouped
// sections, and the rows that live in them. Every secondary screen builds from
// these so a settings page, a profile and a room's info all read as one app —
// the way every Apple app reads as one OS.
//
// Theme-aware rather than hard-coded iOS: radii come from the theme, colours
// from its surfaces and inks, type from its ramp. On a Basic palette that IS
// the iOS look; on a character theme it is that theme's take on the same
// structure, so personality never costs the layout.

/// The springy press every tappable in the kit shares: a quick dip to 0.96 and
/// an overshooting return, the Telegram feel. Collapses to nothing under
/// reduced motion.
class SpringPress extends StatefulWidget {
  const SpringPress({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  /// A light selection tick on tap — what UIKit controls do.
  final bool haptic;
  final String? semanticLabel;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    final enabled = widget.onTap != null;
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: motion.d(
            _down
                ? const Duration(milliseconds: 90)
                : const Duration(milliseconds: 420),
          ),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A circular glass button for a bar: back, close, compose, more.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size = 40,
    this.iconSize = 19,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: LiquidGlass(
        size: Size(size, size),
        onTap: onTap,
        child: Icon(icon, size: iconSize, color: color ?? theme.ink),
      ),
    );
  }
}

/// The back control every pushed page wears: a glass circle with a chevron,
/// iOS 26's toolbar treatment.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: CupertinoIcons.chevron_back,
        iconSize: 20,
        semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
      );
}

/// A pushed page in the iOS shape: a bar with a glass back button and actions,
/// a large title that scrolls away under it while a small one fades in, and
/// the content.
///
/// [children] are laid out in a padded list; pass [slivers] instead for a page
/// that needs its own sliver layout. The page paints the theme's background
/// itself, so callers pass nothing but content.
class IosPage extends StatefulWidget {
  const IosPage({
    super.key,
    required this.title,
    this.children = const [],
    this.slivers,
    this.actions = const [],
    this.leading,
    this.showBack = true,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 40),
    this.controller,
  });

  final String title;

  /// One line under the large title — what the page is for, in the reader's
  /// words. Optional; most pages are self-explanatory.
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? slivers;

  /// Trailing bar buttons, usually [GlassIconButton]s.
  final List<Widget> actions;

  /// Replaces the back button (e.g. a Cancel on a modal page).
  final Widget? leading;
  final bool showBack;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  State<IosPage> createState() => _IosPageState();
}

class _IosPageState extends State<IosPage> {
  late final ScrollController _scroll = widget.controller ?? ScrollController();

  @override
  void dispose() {
    if (widget.controller == null) _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final canPop = Navigator.of(context).canPop();
    final leading = widget.leading ??
        (widget.showBack && canPop ? const GlassBackButton() : null);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: theme.displayLarge.copyWith(letterSpacing: 0.37),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: theme.bodySoft),
            ],
          ],
        ),
      ),
    );

    final body = widget.slivers ??
        [
          SliverPadding(
            padding: widget.padding.copyWith(
              bottom: widget.padding.bottom + bottom,
            ),
            sliver: SliverList.list(children: widget.children),
          ),
        ];

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
                              opacity: ((offset - 24) / 24).clamp(0.0, 1.0),
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
                            ?leading,
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
                    slivers: [header, ...body],
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

/// An inset grouped section: an optional header above, a rounded block of
/// rows, an optional footer explaining them.
///
/// Rows are separated automatically by a hairline that starts where their
/// text does, so callers pass bare rows and never think about dividers.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = const EdgeInsets.only(bottom: 28),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final rows = children;
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
                  for (var i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i < rows.length - 1)
                      Padding(
                        padding: EdgeInsets.only(left: _dividerInset(rows[i])),
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

  static double _dividerInset(Widget row) =>
      row is GroupedRow && row.icon != null ? 60 : 16;
}

/// Corner radius of a grouped block. iOS 26 rounds these generously; a theme
/// with a square personality (a small [AppTheme.radiusXl]) keeps its corners.
double groupedRadius(AppTheme theme) => theme.radiusXl.clamp(6.0, 26.0);

/// Fill of a grouped block — the theme's surface, nudged so it separates from
/// the page by luminance alone, without a border.
Color groupedFill(AppTheme theme) {
  final s = theme.surface;
  final distinct = (s.computeLuminance() - theme.background.computeLuminance())
          .abs() >
      0.008;
  if (distinct) return s;
  return Color.alphaBlend(
    (theme.isLight ? Colors.black : Colors.white).withValues(alpha: 0.06),
    theme.background,
  );
}

/// The colour of the little rounded tile behind a row's glyph — iOS Settings'
/// coloured squares. Named roles rather than raw colours so every screen
/// picks from the same set and a theme could one day restyle them.
enum TileTone { blue, green, orange, red, purple, pink, teal, indigo, gray, accent }

Color tileColor(AppTheme theme, TileTone tone) => switch (tone) {
      TileTone.blue => const Color(0xFF0A84FF),
      TileTone.green => const Color(0xFF30B350),
      TileTone.orange => const Color(0xFFFF8D28),
      TileTone.red => const Color(0xFFFF3B30),
      TileTone.purple => const Color(0xFFAF52DE),
      TileTone.pink => const Color(0xFFFF2D55),
      TileTone.teal => const Color(0xFF00A6B4),
      TileTone.indigo => const Color(0xFF5856D6),
      TileTone.gray => const Color(0xFF8E8E93),
      TileTone.accent => theme.accent,
    };

/// One row in a [GroupedSection].
///
/// Leading glyph on a coloured tile, title (and an optional subtitle under
/// it), a value in muted ink, then the trailing control: a chevron when the
/// row navigates, a [Switch] for [GroupedRow.toggle], a checkmark for
/// [GroupedRow.choice], or anything passed as [trailing].
class GroupedRow extends StatefulWidget {
  const GroupedRow({
    super.key,
    required this.title,
    this.icon,
    this.tone = TileTone.accent,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron,
    this.destructive = false,
    this.badge = 0,
    this.titleTrailing,
  });

  /// A switch row. The whole row toggles, not just the switch.
  factory GroupedRow.toggle({
    Key? key,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
    TileTone tone = TileTone.accent,
    String? subtitle,
  }) =>
      GroupedRow(
        key: key,
        title: title,
        icon: icon,
        tone: tone,
        subtitle: subtitle,
        chevron: false,
        onTap: () => onChanged(!value),
        trailing: _RowSwitch(value: value, onChanged: onChanged),
      );

  /// One option in a pick-one list, checked when [selected].
  factory GroupedRow.choice({
    Key? key,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    String? subtitle,
    IconData? icon,
    TileTone tone = TileTone.accent,
  }) =>
      GroupedRow(
        key: key,
        title: title,
        subtitle: subtitle,
        icon: icon,
        tone: tone,
        chevron: false,
        onTap: onTap,
        trailing: _Check(selected: selected),
      );

  final String title;
  final IconData? icon;
  final TileTone tone;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Defaults to true whenever the row has an [onTap] and no [trailing].
  final bool? chevron;

  /// Red title, no tile colour of its own — Sign Out, Delete Account.
  final bool destructive;

  /// Count pill before the chevron. Zero hides it.
  final int badge;

  /// A small tag set right after the title — "Recommended", "New" — where it
  /// annotates the option rather than crowding the row's trailing edge.
  final Widget? titleTrailing;

  @override
  State<GroupedRow> createState() => _GroupedRowState();
}

class _GroupedRowState extends State<GroupedRow> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final w = widget;
    final tappable = w.onTap != null;
    // An action (Sign Out) goes nowhere, so it gets no chevron.
    final showChevron =
        w.chevron ?? (tappable && w.trailing == null && !w.destructive);
    final titleColor = w.destructive ? theme.danger : theme.ink;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: EdgeInsets.fromLTRB(w.icon != null ? 14 : 16, 7, 14, 7),
        child: Row(
          children: [
            if (w.icon != null) ...[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: w.destructive
                      ? theme.danger
                      : tileColor(theme, w.tone),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  w.icon,
                  size: 18,
                  color: w.tone == TileTone.accent && !w.destructive
                      ? theme.accentInk
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          w.title,
                          style: theme.body.copyWith(
                            color: titleColor,
                            fontSize: 17,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (w.titleTrailing != null) ...[
                        const SizedBox(width: 8),
                        w.titleTrailing!,
                      ],
                    ],
                  ),
                  if (w.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      w.subtitle!,
                      style: theme.caption.copyWith(
                        fontSize: 13,
                        height: 1.3,
                        color: theme.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (w.value != null && w.value!.isNotEmpty) ...[
              const SizedBox(width: 10),
              // Capped rather than Flexible: a Flexible shares the row's
              // free space with the Expanded title, which parks the value
              // mid-row instead of against the chevron.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  w.value!,
                  style: theme.body.copyWith(
                    fontSize: 17,
                    color: theme.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
            if (w.badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.danger,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  w.badge > 99 ? '99+' : '${w.badge}',
                  style: theme.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
            if (w.trailing != null) ...[
              const SizedBox(width: 10),
              w.trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 15,
                color: theme.inkMuted.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );

    if (!tappable) return row;
    return FocusableTap(
      onTap: w.onTap,
      semanticLabel: w.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: w.onTap,
        child: AnimatedContainer(
          // Instant on, eased off — the table-cell highlight.
          duration: _pressed ? Duration.zero : const Duration(milliseconds: 260),
          color: _pressed
              ? theme.ink.withValues(alpha: 0.08)
              : Colors.transparent,
          child: row,
        ),
      ),
    );
  }
}

class _RowSwitch extends StatelessWidget {
  const _RowSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: theme.success,
      activeThumbColor: Colors.white,
    );
  }
}

/// The checkmark of a pick-one row, popping in on a spring when chosen.
class _Check extends StatelessWidget {
  const _Check({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return AnimatedScale(
      scale: selected ? 1 : 0,
      duration: motion.d(const Duration(milliseconds: 380)),
      curve: selected ? Curves.elasticOut : Curves.easeIn,
      child: Icon(CupertinoIcons.checkmark_alt, size: 20, color: theme.accent),
    );
  }
}
