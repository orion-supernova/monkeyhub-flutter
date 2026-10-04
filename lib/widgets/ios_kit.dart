import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'action_buttons.dart';
import 'glass_buttons.dart';
import 'spring_press.dart';
import 'teardown_safe.dart';
import '../l10n/text_case.dart';

export 'action_buttons.dart';
export 'empty_state.dart';
export 'fit_label.dart';
export 'glass_buttons.dart';
export 'quick_actions.dart';
export 'segmented_control.dart';
export 'selection_check.dart';
export 'spring_press.dart';

// The app's shared iOS vocabulary: a page with a large title, inset grouped
// sections, and the rows that live in them. Every secondary screen builds from
// these so a settings page, a profile and a room's info all read as one app —
// the way every Apple app reads as one OS.
//
// Theme-aware rather than hard-coded iOS: radii come from the theme, colours
// from its surfaces and inks, type from its ramp. On a Basic palette that IS
// the iOS look; on a character theme it is that theme's take on the same
// structure, so personality never costs the layout.

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
    this.onRefresh,
    this.flatBackground = false,
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

  /// Pull-to-refresh, iOS-style: the spinner appears above the large title as
  /// the page is pulled down. Null — most pages — and there is no gesture.
  final Future<void> Function()? onRefresh;

  /// Paints the theme's plain background colour instead of its
  /// [AppTheme.backgroundLayer]. Off for every ordinary page; on for a screen
  /// that must not be able to animate under itself — the diagnostics log,
  /// whose job includes catching a strobing backdrop.
  final bool flatBackground;

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

    // Top 0: the large title's box starts 52pt below the safe area (the bar's
    // height), the line Feed, Discover and Chats draw theirs on — a tab root
    // and a pushed page put their titles at one y.
    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
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
          if (widget.flatBackground)
            SizedBox.expand(child: ColoredBox(color: theme.background))
          else
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
                    // The bounce is what reveals the refresh spinner, so a
                    // refreshable page asks for it on every platform.
                    physics: widget.onRefresh == null
                        ? null
                        : const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                    slivers: [
                      if (widget.onRefresh != null)
                        CupertinoSliverRefreshControl(
                          onRefresh: widget.onRefresh,
                        ),
                      header,
                      ...body,
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

/// An inset grouped section: an optional header above, a rounded block of
/// rows, an optional footer explaining them.
///
/// Rows are separated automatically by a hairline that starts where their
/// text does, so callers pass bare rows and never think about dividers.
///
/// The header is the T3 [GroupedHeader] — pushed pages and sheets. On a TAB
/// ROOT (the Settings hub) pass [pageHeader]: the header becomes the T2
/// [PageSectionHeader], the size Feed's and Discover's sections use, with its
/// left edge on theirs (x = 20 on a 16pt-gutter page).
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = const EdgeInsets.only(bottom: 28),
    this.pageHeader = false,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsets margin;

  /// Draw [header] as a tab root's [PageSectionHeader] (T2) rather than a
  /// [GroupedHeader] (T3). Pair it with a 32pt bottom [margin], the gap
  /// between sections on every tab root.
  final bool pageHeader;

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
            pageHeader
                ? PageSectionHeader(
                    header!,
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  )
                : GroupedHeader(header!),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(footer!, style: groupedFooterStyle(theme)),
            ),
        ],
      ),
    );
  }

  static double _dividerInset(Widget row) => groupedDividerInset(row);
}

// ── The settings type scale ─────────────────────────────────────────────
// Every grouped page and sheet reads its sizes from here, never a literal:
//
//   section header   17 / w600  ink        [GroupedHeader]
//   row title        17 / w400  ink        [groupedTitleStyle]
//   row value        17 / w400  inkMuted   [groupedValueStyle]
//   row subtitle     15 / w400  inkMuted   [groupedSubtitleStyle]
//   section footer   15 / 1.35  inkMuted   [groupedFooterStyle]
//   meta / badge     13         as needed  [groupedMetaStyle]
//
// All on the theme's body face, never its caption: on a character theme the
// caption slot is often a tracked monospace, which turns a sentence of help
// text into a wall of terminal output.

TextStyle groupedHeaderStyle(AppTheme theme) => theme.bodyEmph.copyWith(
      fontSize: 17,
      height: 1.25,
      color: theme.ink,
    );

TextStyle groupedTitleStyle(AppTheme theme) =>
    theme.body.copyWith(fontSize: 17, height: 1.25, color: theme.ink);

TextStyle groupedValueStyle(AppTheme theme) =>
    theme.body.copyWith(fontSize: 17, height: 1.25, color: theme.inkMuted);

TextStyle groupedSubtitleStyle(AppTheme theme) => theme.bodySoft.copyWith(
      fontSize: 15,
      height: 1.3,
      color: theme.inkMuted,
    );

TextStyle groupedFooterStyle(AppTheme theme) => theme.bodySoft.copyWith(
      fontSize: 15,
      height: 1.35,
      color: theme.inkMuted,
    );

TextStyle groupedMetaStyle(AppTheme theme) =>
    theme.bodySoft.copyWith(fontSize: 13, color: theme.inkMuted);

/// THE section header, over a [GroupedSection], a [SheetGroup], or anything
/// laid out like one (a grid of tiles). Sentence case, the theme's ink, an
/// optional [trailing] action (a reset glyph) on the far edge.
class GroupedHeader extends StatelessWidget {
  const GroupedHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = Text(
      sentenceCaseOf(context, text),
      style: groupedHeaderStyle(theme),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: trailing == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                trailing!,
              ],
            ),
    );
  }
}

/// Where the hairline under [row] starts inside a grouped block: under the
/// text, past a row's tile or avatar. Shared by [GroupedSection] and
/// `SheetGroup`.
double groupedDividerInset(Widget row) {
  if (row is GroupedRow && row.icon != null) return 60;
  if (row is PersonRow) return kPersonRowTextInset;
  return 16;
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

/// The fill of a quiet control — a chip, capsule, tag, icon disc or selected
/// row — with the accent kept for the text or glyph on top.
///
/// Deliberately NOT the accent at low opacity. Over a near-black page a blue
/// at 15% renders as navy, and enough of those made every dark theme read
/// "dark blue" rather than black. iOS draws these as a neutral grey fill.
Color quietFill(AppTheme theme) =>
    theme.ink.withValues(alpha: theme.isLight ? 0.06 : 0.10);

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

/// The height of a one-line [GroupedRow] — and the floor every grouped row
/// (a hub row with a custom leading, an `InsetGroup` row) should share.
const double kGroupedRowMinHeight = 52;

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
        trailing: RowSwitch(value: value, onChanged: onChanged),
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

class _GroupedRowState extends State<GroupedRow>
    with TeardownSafe<GroupedRow> {
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

    // iOS 26 Settings density: a one-line row is 52pt (11 + a 30pt tile +
    // 11). At 48 with 7pt padding the tile all but touched the hairlines and
    // the hub read cramped. Text starts at 16 + 30 + 14 = 60, where the
    // hairline does.
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kGroupedRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
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
                  borderRadius: BorderRadius.circular(7.5),
                ),
                child: Icon(
                  w.icon,
                  size: 18,
                  color: w.tone == TileTone.accent && !w.destructive
                      ? theme.accentInk
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: _TitleValue(
                title: w.title,
                titleColor: titleColor,
                titleTrailing: w.titleTrailing,
                subtitle: w.subtitle,
                value: w.value,
              ),
            ),
            if (w.badge > 0) ...[
              const SizedBox(width: 8),
              RowBadge(count: w.badge),
            ],
            if (w.trailing != null) ...[
              const SizedBox(width: 10),
              w.trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: 10),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: theme.inkMuted.withValues(alpha: 0.55),
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

/// THE switch of a settings row ([GroupedRow.toggle] draws it). Public for
/// the rare row that is not a [GroupedRow] — never a raw `Switch.adaptive`,
/// whose off-track all but vanishes on a cream or white page.
class RowSwitch extends StatelessWidget {
  const RowSwitch({super.key, required this.value, required this.onChanged});
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
      // The off track in the theme's own ink: the platform grey disappears
      // on cream (Risograph) and on Daylight's white plates.
      inactiveTrackColor: theme.ink.withValues(alpha: 0.16),
      inactiveThumbColor: Colors.white,
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
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

/// A [GroupedRow]'s title (with its subtitle) and value, laid out the way
/// iOS Settings does it.
///
/// The title keeps its natural width — it is the row's name. The value gets
/// what is left, and at least ~45% of the row, ellipsizing inside that; when
/// even that leaves the title no room on one line ("Speaker colours" beside
/// "Auto · Risograph Pop" in Turkish at 1.3×), the value drops under the
/// title instead, the large-text layout of a UIKit value cell. The old cap
/// (value ≤ 170pt, title Expanded) let the value win and the title wrap to
/// "Linked / accounts".
class _TitleValue extends StatelessWidget {
  const _TitleValue({
    required this.title,
    required this.titleColor,
    required this.titleTrailing,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final Color titleColor;
  final Widget? titleTrailing;
  final String? subtitle;
  final String? value;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final titleStyle = groupedTitleStyle(theme).copyWith(color: titleColor);
    final valueStyle = groupedValueStyle(theme);

    Widget titleColumn({String? below}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(child: Text(title, style: titleStyle)),
                if (titleTrailing != null) ...[
                  const SizedBox(width: 8),
                  titleTrailing!,
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: groupedSubtitleStyle(theme)),
            ],
            if (below != null) ...[
              const SizedBox(height: 3),
              Text(
                below,
                style: valueStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );

    final v = value;
    if (v == null || v.isEmpty) return titleColumn();

    return LayoutBuilder(
      builder: (context, box) {
        final total = box.maxWidth;
        final scaler = MediaQuery.textScalerOf(context);
        final dir = Directionality.of(context);
        double measure(String text, TextStyle style) {
          final p = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: dir,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = p.width;
          p.dispose();
          return w.ceilToDouble() + 1;
        }

        final valueWidth = measure(v, valueStyle);
        // A tag after the title is a widget we cannot measure; budget a
        // short word's worth for it rather than pretending it is not there.
        final titleWidth =
            measure(title, titleStyle) + (titleTrailing == null ? 0 : 78);
        final room = total - titleWidth - _gap;
        final floor = total * 0.45;
        if (room >= valueWidth || room >= floor) {
          return Row(
            children: [
              Expanded(child: titleColumn()),
              const SizedBox(width: _gap),
              ConstrainedBox(
                // A cap, not a width: the value still sizes to its own
                // text, so a measurement taken before a web/Google font
                // finished loading can never clip a short value.
                constraints: BoxConstraints(
                  maxWidth: room > floor ? room : floor,
                ),
                child: Text(
                  v,
                  style: valueStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          );
        }
        return titleColumn(below: v);
      },
    );
  }
}

/// THE red count pill of a row — unread requests, pending approvals: solid
/// danger, white 13/w600 tabular figures on the body face. Renders nothing
/// at zero.
class RowBadge extends StatelessWidget {
  const RowBadge({super.key, required this.count, this.max = 99});
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),

      decoration: BoxDecoration(
        color: theme.danger,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          count > max ? '$max+' : '$count',
          style: groupedMetaStyle(theme).copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Width of the avatar slot in a [PersonRow].
const double kPersonRowAvatar = 40;

/// Where a [PersonRow]'s text starts — and so where the hairline under it
/// starts in a [GroupedSection] / [SheetGroup].
const double kPersonRowTextInset = 16 + kPersonRowAvatar + 12;

/// THE row for a person or a room: a 40pt avatar, the name at 17 regular, an
/// optional 15pt subtitle (handle, member count, last seen) and a trailing
/// slot ([SelectionCheck], [RowPillButton], a value). Pickers, friend lists,
/// request lists, search results, forward/share targets.
///
/// No chevron of its own: tapping a destination row picks it, it does not
/// navigate — pass one in [trailing] if this row really opens a page.
/// Inside a [GroupedSection] or [SheetGroup] its hairline starts under the
/// text, past the avatar, the Contacts list's rule.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.avatar,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleTrailing,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
  });

  /// Sized to [kPersonRowAvatar] by the row; pass the avatar widget at 40.
  final Widget avatar;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// A tag right after the name — "You", "Admin", a verified glyph.
  final Widget? titleTrailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// False dims the row (already a member, can't be picked) and drops taps.
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
        child: Row(
          children: [
            SizedBox.square(dimension: kPersonRowAvatar, child: avatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: groupedTitleStyle(theme),
                        ),
                      ),
                      if (titleTrailing != null) ...[
                        const SizedBox(width: 6),
                        titleTrailing!,
                      ],
                    ],
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: groupedSubtitleStyle(theme),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
    final body = Opacity(opacity: enabled ? 1 : 0.45, child: row);
    if (onTap == null && onLongPress == null) {
      return Semantics(label: semanticLabel, child: body);
    }
    return SpringPress(
      onTap: enabled ? onTap ?? () {} : null,
      onLongPress: enabled ? onLongPress : null,
      scale: 0.98,
      haptic: false,
      semanticLabel: semanticLabel ?? title,
      child: ColoredBox(color: Colors.transparent, child: body),
    );
  }
}

/// T2 of the header ramp — THE header of a section on a TAB ROOT: Feed's
/// "Highlights", Discover's "Friends", the Settings hub's "General", the
/// leaderboard's "Today's puzzles". The theme's `displaySmall` (each theme's
/// own ~18–22pt display face) in ink.
///
/// The ramp, one rule anyone can apply:
///   * T1 — the large title (`IosPage`, the tab mastheads), `displayLarge`.
///   * T2 — this, on every tab root.
///   * T3 — [GroupedHeader] (17/w600), on pushed pages and in sheets.
///
/// Optional [count] ("Friends 12") in the row-value voice, on the title's
/// baseline; optional [actionLabel] drawn as "Label ›" — the one action
/// style, never a centred "See all" row under the list. The title wraps to a
/// second line rather than clip (Turkish at 1.3×); the action keeps its 44pt
/// target on the title's centre line.
///
/// The parent owns the space ABOVE (32pt between tab-root sections); the
/// default padding is 10pt below, to the section's body. Its left edge is the
/// caller's: put it on the T1 title's x (20pt from the screen edge).
class PageSectionHeader extends StatelessWidget {
  const PageSectionHeader(
    this.title, {
    super.key,
    this.count,
    this.actionLabel,
    this.onAction,
    this.actionSemanticLabel,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 10),
  });

  final String title;

  /// A number after the title ("12"). Null or empty draws none.
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// What a screen reader says for the action, when the label alone is
  /// ambiguous ("See all friends" for a bare "See all").
  final String? actionSemanticLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final titleStyle = theme.displaySmall.copyWith(color: theme.ink);
    final n = count;
    final heading = Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: sentenceCaseOf(context, title)),
            if (n != null && n.isNotEmpty) ...[
              // One paragraph, not a Row: the count shares the title's
              // baseline at any text size, and wraps with it instead of
              // being pushed off the row.
              const WidgetSpan(child: SizedBox(width: 6)),
              TextSpan(
                text: n,
                style: groupedValueStyle(theme).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
        style: titleStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final label = actionLabel;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: heading),
          if (label != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextLinkButton(
              label: label,
              icon: CupertinoIcons.chevron_forward,
              onTap: onAction,
              semanticLabel: actionSemanticLabel,
            ),
          ],
        ],
      ),
    );
  }
}

/// The "or" between two ways of doing the same thing (scan a code / use a
/// password): two hairlines and a muted word.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final line = Expanded(
      child: Container(
        height: 1 / MediaQuery.devicePixelRatioOf(context),
        color: theme.ink.withValues(alpha: 0.14),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              sentenceCaseOf(context, label),
              style: groupedMetaStyle(theme),
            ),
          ),
          line,
        ],
      ),
    );
  }
}
