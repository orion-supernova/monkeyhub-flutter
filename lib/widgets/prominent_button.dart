import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'action_buttons.dart';

/// The one big button on a first-run or sign-in screen — now a thin alias of
/// [SheetActionButton], so the login CTA and every sheet's CTA are the same
/// capsule (they were a 54pt gradient capsule here and a 52pt slab there,
/// often one screen apart).
///
/// The only thing it adds is the heavier commit haptic: this is the one big
/// commit on the screen. While [busy] it trades its label for a spinner
/// without changing size, so nothing under it moves.
class ProminentButton extends StatelessWidget {
  const ProminentButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    return SheetActionButton(
      label: label,
      busy: busy,
      icon: icon,
      haptic: false,
      onTap: tap == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              tap();
            },
    );
  }
}
