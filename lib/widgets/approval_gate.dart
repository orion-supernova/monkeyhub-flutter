import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

// The guard error codes and `isChildGateError` live in models/family.dart so
// non-UI layers can use them too; this file is only the sheet that renders
// the result.

/// The sheet a child sees whenever they hit something that needs a grown-up.
///
/// Every gated action in the app routes here so the wording, the tone, and
/// the "already asked" state are written exactly once. Returns true when the
/// child chose to send the request.
Future<bool> showApprovalGate(
  BuildContext context, {
  required String what,
  String? detail,
  bool alreadyAsked = false,
  bool canAsk = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ApprovalGateSheet(
      what: what,
      detail: detail,
      alreadyAsked: alreadyAsked,
      canAsk: canAsk,
    ),
  );
  return result ?? false;
}

class _ApprovalGateSheet extends StatelessWidget {
  const _ApprovalGateSheet({
    required this.what,
    required this.detail,
    required this.alreadyAsked,
    required this.canAsk,
  });

  final String what;
  final String? detail;
  final bool alreadyAsked;
  final bool canAsk;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Wrapped so nothing here renders with Flutter's debug yellow underlines
    // when the sheet sits outside a Material ancestor.
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(color: theme.divider),
              borderRadius: BorderRadius.circular(theme.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: theme.accent),
                    const SizedBox(width: 10),
                    Text(
                      alreadyAsked ? 'ALREADY ASKED' : 'ASK A GROWN-UP',
                      style: theme.label
                          .copyWith(letterSpacing: 2.4, color: theme.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  alreadyAsked
                      ? 'You already asked about $what.'
                      : canAsk
                          ? 'You need a grown-up to say yes before you can $what.'
                          : 'A grown-up has switched this off for now.',
                  style: theme.displaySmall,
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(detail!, style: theme.bodySoft),
                ],
                const SizedBox(height: 8),
                Text(
                  alreadyAsked
                      ? 'They\'ll get a message about it. Check back soon.'
                      : canAsk
                          ? 'We\'ll let them know. You\'ll see it here when they answer.'
                          : 'You can talk to them about it if you think it should change.',
                  style: theme.bodySoft,
                ),
                const SizedBox(height: 22),
                if (canAsk && !alreadyAsked)
                  _GateButton(
                    label: 'ASK',
                    filled: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                if (canAsk && !alreadyAsked) const SizedBox(height: 10),
                _GateButton(
                  label: canAsk && !alreadyAsked ? 'NOT NOW' : 'OK',
                  filled: false,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GateButton extends StatelessWidget {
  const _GateButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? theme.accent : Colors.transparent,
          border: filled ? null : Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          style: theme.label.copyWith(
            color: filled ? theme.accentInk : theme.inkSoft,
            letterSpacing: 2.4,
          ),
        ),
      ),
    );
  }
}

/// The inline "waiting for a grown-up" pill, for rows the child has already
/// asked about (a room in Discover, a person in search).
class WaitingPill extends StatelessWidget {
  const WaitingPill({super.key, this.label = 'waiting for a grown-up'});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.accent.withValues(alpha: 0.32), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 11, color: theme.accent),
          const SizedBox(width: 5),
          Text(label, style: theme.monoTiny.copyWith(color: theme.accent)),
        ],
      ),
    );
  }
}
