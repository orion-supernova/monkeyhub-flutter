import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart';

/// How the chat list is laid out and how its filters are offered. Both
/// choices are pictures — tiny phones drawn in the current theme — because a
/// layout is judged by looking at it.
class RoomLayoutScreen extends StatelessWidget {
  const RoomLayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final store = SettingsStore.instance;
        final layout = store.roomLayout;
        final filter = store.filterStyle;
        return SettingsPage(
          title: l10n.settingsHubChatList,
          children: [
            GroupedHeader(l10n.chatListPageLayoutHeader),
            PreviewChoiceTiles<RoomLayout>(
              selected: layout,
              onChanged: (v) {
                pickFeedback();
                store.setRoomLayout(v);
              },
              choices: [
                PreviewChoice(
                  value: RoomLayout.list,
                  label: l10n.settingsHubLayoutRows,
                  preview: const MiniListBackdrop(child: SizedBox.shrink()),
                ),
                PreviewChoice(
                  value: RoomLayout.cards,
                  label: l10n.settingsHubLayoutCards,
                  preview: const _Clipped(_CardsPreview()),
                ),
                PreviewChoice(
                  value: RoomLayout.grid,
                  label: l10n.settingsHubLayoutGrid,
                  preview: const _Clipped(_GridPreview()),
                ),
              ],
            ),
            GroupedFooter(switch (layout) {
              RoomLayout.list => l10n.chatListPageRowsSub,
              RoomLayout.cards => l10n.chatListPageCardsSub,
              RoomLayout.grid => l10n.chatListPageGridSub,
            }),

            GroupedHeader(l10n.chatListPageFiltersHeader),
            PreviewChoiceTiles<FilterStyle>(
              selected: filter,
              aspectRatio: 1.15,
              onChanged: (v) {
                pickFeedback();
                store.setFilterStyle(v);
              },
              choices: [
                PreviewChoice(
                  value: FilterStyle.chips,
                  label: l10n.chatListPageChips,
                  preview: const _Clipped(_FilterPreview(chips: true)),
                ),
                PreviewChoice(
                  value: FilterStyle.drawer,
                  label: l10n.chatListPageButton,
                  preview: const _Clipped(_FilterPreview(chips: false)),
                ),
              ],
            ),
            GroupedFooter(
              filter == FilterStyle.chips
                  ? l10n.chatListPageChipsSub
                  : l10n.chatListPageButtonSub,
            ),
          ],
        );
      },
    );
  }
}

/// A miniature drawn at its natural height and cut off at the tile's edge, the
/// way a phone screen cuts off a list — so a narrow tile shows less list
/// rather than overflowing.
class _Clipped extends StatelessWidget {
  const _Clipped(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: child,
        ),
      );
}

/// Bordered cards stacked down a phone — the original layout.
class _CardsPreview extends StatelessWidget {
  const _CardsPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 14, 7, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleBar(theme),
          const SizedBox(height: 8),
          for (var i = 0; i < 4; i++) ...[
            Container(
              height: 30,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.ink.withValues(alpha: 0.10)),
              ),
              // The card's own shape: a face, then the name over the
              // preview, as the real card draws a row on its own surface.
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: theme.avatarGradient(i * 4 + 1).first,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.55,
                          child: _line(theme, 0.35),
                        ),
                        const SizedBox(height: 3),
                        _line(theme, 0.10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

/// Two columns of square tiles.
class _GridPreview extends StatelessWidget {
  const _GridPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    Widget tile(int i) => Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.ink.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: theme.avatarGradient(i * 5 + 2).first,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  FractionallySizedBox(
                    widthFactor: 0.7,
                    child: _line(theme, 0.35),
                  ),
                  const SizedBox(height: 3),
                  _line(theme, 0.10),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 14, 7, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleBar(theme),
          const SizedBox(height: 8),
          for (var r = 0; r < 3; r++) ...[
            Row(
              children: [
                tile(r * 2),
                const SizedBox(width: 5),
                tile(r * 2 + 1),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

/// The top of the chat list: a title, then either a row of filter capsules
/// under it, or a single filter button beside it.
class _FilterPreview extends StatelessWidget {
  const _FilterPreview({required this.chips});
  final bool chips;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    Widget capsule(double w, {bool on = false}) => Container(
          width: w,
          height: 13,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: on
                ? quietFill(theme)
                : theme.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _titleBar(theme),
              const Spacer(),
              if (!chips)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.ink.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 10,
                    color: theme.inkSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          if (chips) ...[
            Row(
              children: [
                capsule(18, on: true),
                capsule(30),
                capsule(36),
                capsule(22),
              ],
            ),
            const SizedBox(height: 9),
          ],
          for (var i = 0; i < (chips ? 2 : 3); i++) ...[
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.avatarGradient(i * 3 + 1).first,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: _line(theme, 0.35),
                      ),
                      const SizedBox(height: 3),
                      _line(theme, 0.10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

Widget _titleBar(AppTheme theme) => Container(
      width: 30,
      height: 6,
      decoration: BoxDecoration(
        color: theme.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
      ),
    );

Widget _line(AppTheme theme, double alpha) => Container(
      height: 3,
      decoration: BoxDecoration(
        color: theme.ink.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(2),
      ),
    );
