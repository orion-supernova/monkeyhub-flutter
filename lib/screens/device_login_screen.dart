import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/device_login_panel.dart';

/// Desktop/web side of "scan to sign in", full-screen: mints a request and
/// shows [DeviceLoginPanel] in place of the password form.
///
/// Only reached on a window too narrow for `LoginScreen`'s side-by-side
/// layout — see `isWebOrDesktop` there for the width this yields to.
class DeviceLoginScreen extends StatelessWidget {
  const DeviceLoginScreen({super.key, required this.auth, required this.onCancel});

  final AuthService auth;

  /// Back to the ordinary username/password form.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.auth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
                  child: DeviceLoginPanel(auth: auth, onCancel: onCancel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
