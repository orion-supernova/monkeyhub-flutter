import 'package:flutter/material.dart';

import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});
  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
                  ),
                ]),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    UserAvatar(user: user, size: 96),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: theme.displayLarge),
                          const SizedBox(height: 6),
                          Text('@${user.username}', style: theme.mono.copyWith(color: theme.inkMuted)),
                          const SizedBox(height: 10),
                          // Visibility in v02 is implicit-public; private profiles are a Phase 2 concept.
                          VisibilityBadge(isPublic: true, dense: false),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (user.bio != null && user.bio!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: theme.roomCardDecoration(ephemeral: false, active: false),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ABOUT', style: theme.label),
                        const SizedBox(height: 8),
                        Text('"${user.bio!}"', style: theme.bodyEmph),
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
