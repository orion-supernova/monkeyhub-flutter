import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../backend/chat_api.dart';
import '../family/family_service.dart';
import '../theme/app_theme.dart';
import '../models/family.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/ios_kit.dart';
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
    final l10n = AppLocalizations.of(context);
    final ctx = widget.family.context;
    final children = ctx.children;
    final waiting = ctx.pendingCount;

    return RefreshIndicator(
      color: theme.accent,
      onRefresh: () {
        HapticFeedback.lightImpact();
        return widget.family.refresh();
      },
      child: IosPage(
        title: l10n.acctSectionFamily,
        slivers: readableSlivers(context, [
          GroupedSection(
            children: [
              GroupedRow(
                icon: CupertinoIcons.checkmark_seal_fill,
                tone: TileTone.orange,
                title: l10n.acctRowApprovals,
                subtitle: waiting > 0
                    ? l10n.familyScreenPendingBanner(waiting)
                    : l10n.apprEmptyTitle,
                badge: waiting,
                onTap: () => _open(ApprovalsScreen(
                  api: widget.api,
                  guardianId: widget.userId,
                  family: widget.family,
                )),
              ),
            ],
          ),
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
          GroupedSection(
            children: [
              GroupedRow(
                icon: CupertinoIcons.person_crop_circle_badge_plus,
                tone: TileTone.green,
                title: l10n.famAddChild,
                onTap: () => _open(ChildSetupScreen(
                  api: widget.api,
                  guardianId: widget.userId,
                )),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// One child: who they are and whether they're around, with their three
/// everyday actions as tiles underneath — the profile action-row shape.
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

  /// Opens the code a grown-up reads into the child's phone to hand it back.
  final VoidCallback onRelease;

  String _presence(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = summary.status;
    final seen = summary.lastSeen;
    if (status == 'online') return l10n.famOnlineNow;
    if (seen == null) return l10n.famNotPaired;
    final ago = DateTime.now().difference(seen);
    if (status == 'away' && ago.inMinutes < 5) return l10n.famJustNow;
    if (ago.inMinutes < 1) return l10n.famJustNow;
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
    if (status == 'away') return const Color(0xFFE0A33C);
    return theme.inkMuted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: [
          InsetGroup(
            margin: const EdgeInsets.only(bottom: 8),
            children: [
              PressRow(
                onTap: onOpen,
                semanticLabel: summary.user.displayName,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    UserAvatar(user: summary.user, size: 48, api: api),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.user.displayName,
                            style: theme.bodyEmph.copyWith(
                              fontSize: 17,
                              color: theme.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          StatusDotLine(
                            color: _dot(theme),
                            label: _presence(context),
                          ),
                        ],
                      ),
                    ),
                    if (summary.pendingCount > 0)
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.danger,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          '${summary.pendingCount}',
                          style: theme.caption.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 15,
                      color: theme.inkMuted.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ProfileActionBar(
            tiles: [
              ProfileActionTile(
                icon: CupertinoIcons.qrcode,
                label: l10n.famPair,
                emphasis: true,
                onTap: onPair,
              ),
              ProfileActionTile(
                icon: CupertinoIcons.arrow_turn_up_left,
                label: l10n.famRelease,
                onTap: onRelease,
              ),
              ProfileActionTile(
                icon: CupertinoIcons.slider_horizontal_3,
                label: l10n.famSettings,
                onTap: onOpen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.person_3_fill,
            size: 48,
            color: theme.inkMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(l10n.famEmptyTitle, style: theme.displaySmall),
          const SizedBox(height: 6),
          Text(
            l10n.familyScreenEmptyStateBody,
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
