import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../family/family_service.dart';
import '../theme/app_theme.dart';
import '../models/family.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'approvals_screen.dart';
import 'child_policy_screen.dart';
import 'child_setup_screen.dart';
import 'pairing_code_screen.dart';

/// The parent's family dashboard: who their children are, how they're doing,
/// and what's waiting for a decision.
///
/// Presence here comes through the guardian bypass in `users.getProfile` —
/// a guardian sees their child's status and last-seen even when the child's
/// visibility map says "nobody", without any of it being public.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({
    super.key,
    required this.api,
    required this.userId,
    required this.family,
  });

  final ChatApi api;
  final String userId;
  final FamilyService family;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  @override
  void initState() {
    super.initState();
    widget.family.addListener(_onFamily);
    widget.family.refresh();
  }

  @override
  void dispose() {
    widget.family.removeListener(_onFamily);
    super.dispose();
  }

  void _onFamily() {
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // Coming back from setup / pairing / policy, anything could have changed.
    widget.family.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ctx = widget.family.context;
    final children = ctx.children;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.arrow_back,
                            size: 20, color: theme.inkSoft),
                      ),
                      const SizedBox(width: 14),
                      Text('FAMILY',
                          style: theme.label.copyWith(letterSpacing: 2.8)),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: theme.accent,
                    onRefresh: widget.family.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                      children: [
                        if (ctx.pendingCount > 0) ...[
                          _PendingBanner(
                            count: ctx.pendingCount,
                            onTap: () => _open(ApprovalsScreen(
                              api: widget.api,
                              guardianId: widget.userId,
                              family: widget.family,
                            )),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (children.isEmpty)
                          _EmptyState()
                        else
                          for (final c in children)
                            _ChildCard(
                              summary: c,
                              api: widget.api,
                              onOpen: () => _open(ChildPolicyScreen(
                                api: widget.api,
                                guardianId: widget.userId,
                                child: c,
                                family: widget.family,
                              )),
                              onPair: () => _open(PairingCodeScreen(
                                api: widget.api,
                                guardianId: widget.userId,
                                child: c.user,
                              )),
                            ),
                        const SizedBox(height: 18),
                        _AddChildButton(
                          onTap: () => _open(ChildSetupScreen(
                            api: widget.api,
                            guardianId: widget.userId,
                          )),
                        ),
                      ],
                    ),
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

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.accentSoft,
          border: Border.all(color: theme.accent.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.pending_actions, size: 18, color: theme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? '1 thing needs your OK'
                    : '$count things need your OK',
                style: theme.body.copyWith(color: theme.accent),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: theme.accent),
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.summary,
    required this.api,
    required this.onOpen,
    required this.onPair,
  });

  final ChildSummary summary;
  final ChatApi api;
  final VoidCallback onOpen;
  final VoidCallback onPair;

  /// Reads the presence pair the way the rest of the app does: an "away" that
  /// has gone stale is really just offline.
  String get _presence {
    final status = summary.status;
    final seen = summary.lastSeen;
    if (status == 'online') return 'online now';
    if (seen == null) return 'not paired yet';
    final ago = DateTime.now().difference(seen);
    if (status == 'away' && ago.inMinutes < 5) return 'just now';
    if (ago.inMinutes < 1) return 'just now';
    if (ago.inMinutes < 60) return '${ago.inMinutes}m ago';
    if (ago.inHours < 24) return '${ago.inHours}h ago';
    return '${ago.inDays}d ago';
  }

  Color _dot(AppTheme theme) {
    final status = summary.status;
    if (status == 'online') return theme.success;
    if (status == 'away') return theme.accent;
    return theme.inkMuted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusLg),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  UserAvatar(user: summary.user, size: 46, api: api),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(summary.user.displayName,
                            style: theme.displaySmall),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _dot(theme),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_presence, style: theme.monoTiny),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (summary.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${summary.pendingCount}',
                          style: theme.monoTiny
                              .copyWith(color: theme.accentInk)),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 18, color: theme.inkMuted),
                ],
              ),
            ),
          ),
          Container(height: 1, color: theme.divider),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: Icons.qr_code_2,
                  label: 'PAIR A DEVICE',
                  onTap: onPair,
                ),
              ),
              Container(width: 1, height: 38, color: theme.divider),
              Expanded(
                child: _CardAction(
                  icon: Icons.tune,
                  label: 'SETTINGS',
                  onTap: onOpen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: theme.inkSoft),
            const SizedBox(width: 8),
            Text(label, style: theme.label),
          ],
        ),
      ),
    );
  }
}

class _AddChildButton extends StatelessWidget {
  const _AddChildButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 15, color: theme.accent),
            const SizedBox(width: 8),
            Text('ADD A CHILD',
                style: theme.label
                    .copyWith(letterSpacing: 2.4, color: theme.accent)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Icon(Icons.family_restroom, size: 32, color: theme.inkMuted),
          const SizedBox(height: 14),
          Text('no children yet', style: theme.displaySmall),
          const SizedBox(height: 6),
          Text(
            'Add an account for your child, then pair it to their phone.',
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
