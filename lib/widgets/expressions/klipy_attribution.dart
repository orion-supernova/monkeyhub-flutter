import 'package:flutter/material.dart';

import '../../theme/theme_scope.dart';
import '../meta_text.dart';

/// "Powered by KLIPY", wherever KLIPY content is browsed.
///
/// KLIPY's attribution page makes one thing mandatory — "Search KLIPY" as the
/// search field's placeholder, which the panel does — and asks for this mark
/// beside KLIPY content. Drawn as text in the theme's own ink rather than as
/// KLIPY's logo file, so it sits right on all fifteen themes; the name is not
/// translated because it is a brand.
class KlipyAttribution extends StatelessWidget {
  const KlipyAttribution({super.key, this.compact = false});

  /// A smaller one-line version for the panel's footer.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final base = (compact ? metaText(theme) : theme.caption).copyWith(
      color: theme.inkMuted,
      decoration: TextDecoration.none,
    );
    return Semantics(
      label: 'Powered by KLIPY',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            text: 'Powered by ',
            style: base,
            children: [
              TextSpan(
                text: 'KLIPY',
                style: base.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: theme.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
