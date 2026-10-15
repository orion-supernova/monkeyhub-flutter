import 'package:flutter/material.dart';

import '../data/username_availability_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';

/// The one-line verdict under a username field.
///
/// Holds its own height whatever the state, [UsernameCheck.idle] included, so
/// the field below it does not hop by a line the moment the user starts typing.
/// That jump is the whole reason this is a widget rather than a conditional
/// `Text` at each of the four call sites.
class UsernameStatusLabel extends StatelessWidget {
  const UsernameStatusLabel({super.key, required this.controller});

  final UsernameAvailabilityController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final (String text, Color color) = switch (controller.status) {
          UsernameCheck.idle => ('', theme.inkMuted),
          UsernameCheck.checking => (l10n.usernameStatusChecking, theme.inkMuted),
          UsernameCheck.available => (l10n.usernameStatusAvailable, theme.success),
          UsernameCheck.taken => (l10n.usernameStatusTaken, theme.danger),
          UsernameCheck.reserved => (l10n.usernameStatusReserved, theme.danger),
          UsernameCheck.inappropriate => (l10n.nameInappropriate, theme.danger),
          UsernameCheck.invalid => (l10n.usernameStatusInvalid, theme.danger),
          // Muted, not red: this is a statement about the connection, and
          // colouring it as a rejection would read as "that name is no good".
          UsernameCheck.unknown => (l10n.usernameStatusUnknown, theme.inkMuted),
        };

        return SizedBox(
          height: 18,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              text,
              style: theme.monoTiny.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
