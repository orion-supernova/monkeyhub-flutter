import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../backend/chat_api.dart';
import '../family/family_service.dart';
import '../theme/app_theme.dart';
import '../models/family.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
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
    _backfill();
  }

  /// Links up families created before auto-friending existed. Idempotent and
  /// cheap, so it just runs on open rather than needing a migration or a
  /// "repair" button the user would have to know to press.
  Future<void> _backfill() async {
    try {
      await widget.api.backfillFamilyFriendships(widget.userId);
    } catch (_) {/* nothing user-visible depends on this succeeding */}
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
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
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
                      Text(AppLocalizations.of(context).familyScreenTitle,
                          style: theme.label.copyWith(letterSpacing: 2.8)),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: theme.accent,
                    onRefresh: widget.family.refresh,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        4,
                        20,
                        edgeToEdgeBottom(context, 40),
                      ),
                      children: [
                        // ALWAYS drawn, count or no count.
                        //
                        // It used to appear only while `pendingCount > 0`, and
                        // that count was itself incomplete — it never included
                        // room invitations (see `pendingCountFor` in
                        // backend/convex/family.ts). So "someone invited your
                        // child to a group chat" arrived as a push notification
                        // pointing at a screen with no way in: no banner, and
                        // the approvals list was reachable through nothing else.
                        // A door that exists only when the app already knows
                        // there is something behind it is a door that cannot be
                        // used to check.
                        _ApprovalsRow(
                          count: ctx.pendingCount,
                          onTap: () => _open(ApprovalsScreen(
                            api: widget.api,
                            guardianId: widget.userId,
                            family: widget.family,
                          )),
                        ),
                        const SizedBox(height: 20),
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
                              onRelease: () => _open(PairingCodeScreen(
                                api: widget.api,
                                guardianId: widget.userId,
                                child: c.user,
                                purpose: CodePurpose.release,
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
          ),
        ],
      ),
    );
  }
}

/// The permanent way into [ApprovalsScreen].
///
/// Two appearances, one row: it shouts in accent when something is waiting and
/// sits quietly in the ordinary surface colour when nothing is. The quiet
/// state is the point — it is what makes "let me go and check" a thing a
/// parent can do, rather than something the app decides for them.
class _ApprovalsRow extends StatelessWidget {
  const _ApprovalsRow({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final waiting = count > 0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: waiting ? theme.accentSoft : theme.surface,
          border: Border.all(
            color: waiting ? theme.accent.withValues(alpha: 0.4) : theme.divider,
          ),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(
              Icons.pending_actions,
              size: 18,
              color: waiting ? theme.accent : theme.inkSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.approvalsScreenTitle,
                    style: theme.label.copyWith(
                      letterSpacing: 2.2,
                      color: waiting ? theme.accent : theme.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    waiting
                        ? loc.familyScreenPendingBanner(count)
                        : loc.approvalsScreenEmptyTitle,
                    style: theme.monoTiny.copyWith(
                      color: waiting ? theme.accent : theme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: waiting ? theme.accent : theme.inkMuted,
            ),
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
    required this.onRelease,
  });

  final ChildSummary summary;
  final ChatApi api;
  final VoidCallback onOpen;
  final VoidCallback onPair;

  /// Mints the code that hands the child's phone back — the inverse of
  /// [onPair], and the only way a child device can be signed out.
  final VoidCallback onRelease;

  /// Reads the presence pair the way the rest of the app does: an "away" that
  /// has gone stale is really just offline.
  String _presence(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = summary.status;
    final seen = summary.lastSeen;
    if (status == 'online') return l10n.familyScreenPresenceOnline;
    if (seen == null) return l10n.familyScreenPresenceNotPaired;
    final ago = DateTime.now().difference(seen);
    if (status == 'away' && ago.inMinutes < 5) {
      return l10n.familyScreenPresenceJustNow;
    }
    if (ago.inMinutes < 1) return l10n.familyScreenPresenceJustNow;
    if (ago.inMinutes < 60) {
      return l10n.familyScreenPresenceMinutesAgo(ago.inMinutes);
    }
    if (ago.inHours < 24) {
      return l10n.familyScreenPresenceHoursAgo(ago.inHours);
    }
    return l10n.familyScreenPresenceDaysAgo(ago.inDays);
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
                            Text(_presence(context), style: theme.monoTiny),
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
                  label: AppLocalizations.of(context).familyScreenPairButton,
                  onTap: onPair,
                ),
              ),
              Container(width: 1, height: 38, color: theme.divider),
              Expanded(
                child: _CardAction(
                  icon: Icons.phonelink_erase,
                  label:
                      AppLocalizations.of(context).familyScreenReleaseButton,
                  onTap: onRelease,
                ),
              ),
              Container(width: 1, height: 38, color: theme.divider),
              Expanded(
                child: _CardAction(
                  icon: Icons.tune,
                  label:
                      AppLocalizations.of(context).familyScreenSettingsButton,
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
            Text(AppLocalizations.of(context).familyScreenAddChildButton,
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
          Text(AppLocalizations.of(context).familyScreenEmptyStateTitle,
              style: theme.displaySmall),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).familyScreenEmptyStateBody,
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
