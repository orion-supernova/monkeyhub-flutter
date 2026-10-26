import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'ios_kit.dart';

/// The floating 52pt bar over a tab root's scroll view (Feed, Discover): the
/// same chrome [IosPage] and the Chats header wear. A soft top edge so rows
/// dissolve as they scroll under the status bar, and the small centred title
/// that fades in once the page's large title has scrolled up beneath it.
///
/// Place it in a `Stack` over the scroll view, which starts [clearance] down
/// and keeps its large title as the first content.
class TabRootBar extends StatelessWidget {
  const TabRootBar({
    super.key,
    required this.title,
    required this.scroll,
    this.leading,
    this.trailing,
  });

  final String title;
  final ScrollController scroll;
  final Widget? leading;
  final Widget? trailing;

  /// Where the page's first content starts: under the status bar and the bar.
  static double clearance(BuildContext context) =>
      MediaQuery.paddingOf(context).top + IosPage.barHeight;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final bg = theme.background;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bg,
                      bg.withValues(alpha: 0.92),
                      bg.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.62, 1],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: top, bottom: 14),
            child: SizedBox(
              height: IosPage.barHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 64),
                      child: IgnorePointer(
                        child: CollapsedTitleFade(
                          scroll: scroll,
                          child: Text(
                            title,
                            style: theme.bodyEmph.copyWith(
                              color: theme.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        ?leading,
                        const Spacer(),
                        ?trailing,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
