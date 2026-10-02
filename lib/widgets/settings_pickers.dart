import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_page_body.dart';
import 'ios_kit.dart';

// The settings sub-pages' shared pieces, on top of ios_kit: a page that keeps a
// readable width on a wide window, an iOS "Display & Brightness" style pair of
// preview tiles with radio checks under them, and a live hero preview that
// crossfades when the choice under it changes.

/// An [IosPage] whose content keeps a readable width on a tablet or desktop
/// window. Settings pages are short, so a plain column is fine.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.controller,
    this.bottomPadding,
    this.showBack = true,
  });

  final String title;
  final List<Widget> children;
  final ScrollController? controller;

  /// Extra room under the last section; defaults to clearing the home
  /// indicator.
  final double? bottomPadding;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return IosPage(
      title: title,
      controller: controller,
      showBack: showBack,
      slivers: [
        SliverToBoxAdapter(
          child: AdaptivePageBody(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                bottomPadding ?? edgeToEdgeBottom(context, 40),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One option in a [PreviewChoiceTiles] row.
class PreviewChoice<T> {
  const PreviewChoice({
    required this.value,
    required this.label,
    required this.preview,
  });

  final T value;
  final String label;

  /// The picture of the option, drawn inside the tile's rounded frame.
  final Widget preview;
}

/// Two or three options side by side, each a picture with its name and a radio
/// check under it — the Light / Dark picker from iOS Display & Brightness.
///
/// For choices you judge by looking: a layout, a navigation style. The picture
/// carries the meaning, so the tile itself stays quiet: no glow, no badge, just
/// a ring on the chosen one and a check that springs in.
class PreviewChoiceTiles<T> extends StatelessWidget {
  const PreviewChoiceTiles({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
    this.aspectRatio = 0.62,
  });

  final List<PreviewChoice<T>> choices;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Width over height of each picture.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < choices.length; i++) ...[
            if (i > 0) const SizedBox(width: 18),
            Expanded(
              child: _ChoiceTile<T>(
                choice: choices[i],
                selected: choices[i].value == selected,
                aspectRatio: aspectRatio,
                onTap: () {
                  if (choices[i].value != selected) onChanged(choices[i].value);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.choice,
    required this.selected,
    required this.aspectRatio,
    required this.onTap,
  });

  final PreviewChoice<T> choice;
  final bool selected;
  final double aspectRatio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final radius = (theme.radiusLg + 2).clamp(6.0, 18.0);
    return SpringPress(
      onTap: onTap,
      semanticLabel: choice.label,
      child: Column(
        children: [
          AnimatedContainer(
            duration: motion.d(const Duration(milliseconds: 220)),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius + 3),
              border: Border.all(
                color: selected ? theme.accent : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.background,
                    border: Border.all(
                      color: theme.ink.withValues(alpha: 0.08),
                    ),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: choice.preview,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            choice.label,
            textAlign: TextAlign.center,
            style: theme.body.copyWith(fontSize: 15, color: theme.ink),
          ),
          const SizedBox(height: 8),
          RadioCheck(selected: selected),
        ],
      ),
    );
  }
}

/// The round check iOS draws under a picker tile: an empty ring, or a filled
/// accent disc with a tick that springs in.
class RadioCheck extends StatelessWidget {
  const RadioCheck({super.key, required this.selected, this.size = 22});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.inkMuted.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
          ),
          AnimatedScale(
            scale: selected ? 1 : 0,
            duration: motion.d(const Duration(milliseconds: 420)),
            curve: selected ? Curves.elasticOut : Curves.easeIn,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.checkmark_alt,
                size: size * 0.66,
                color: theme.accentInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A large live picture of whatever is chosen below it, crossfading (with a
/// slight spring in scale) whenever [valueKey] changes.
class HeroPreview extends StatelessWidget {
  const HeroPreview({
    super.key,
    required this.valueKey,
    required this.child,
    this.height = 200,
    this.padding = const EdgeInsets.all(16),
  });

  /// Identity of what is shown. A new key animates the swap.
  final Object valueKey;
  final Widget child;

  /// The least the preview takes, so swapping choices does not make the page
  /// below it jump.
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Container(
        // A floor, not a fixed height: the preview is real text, and at a
        // large accessibility size it has to be allowed to grow.
        constraints: BoxConstraints(minHeight: height),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          border: Border.all(color: theme.ink.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: motion.d(const Duration(milliseconds: 360)),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(valueKey),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Selection feedback every picker on these pages gives: the tick UIKit
/// pickers make.
void pickFeedback() => HapticFeedback.selectionClick();

/// A grouped-list footer for content that is not a [GroupedSection] (a row of
/// preview tiles, say). Cross-fades when its text changes, so a footer that
/// describes the current choice follows the choice.
class GroupedFooter extends StatelessWidget {
  const GroupedFooter(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: AnimatedSwitcher(
        duration: motion.d(const Duration(milliseconds: 200)),
        child: SizedBox(
          key: ValueKey(text),
          width: double.infinity,
          child: Text(
            text,
            style: theme.bodySoft.copyWith(
              fontSize: 13,
              height: 1.35,
              color: theme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A phone's worth of chat rows in miniature — a disc and two lines each —
/// for a picker tile to draw its control over.
class MiniListBackdrop extends StatelessWidget {
  const MiniListBackdrop({super.key, required this.child, this.rows = 6});

  final Widget child;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final line = theme.ink.withValues(alpha: 0.10);
    final list = Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 7,
            decoration: BoxDecoration(
              color: theme.ink.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows; i++) ...[
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.avatarGradient(i * 7 + 3).first,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.55,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.ink.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
    return Stack(
      children: [
        // Drawn at its natural height and cut off at the frame, the way a
        // phone screen cuts off a list, so a narrow tile shows fewer rows
        // rather than overflowing.
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: list,
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
