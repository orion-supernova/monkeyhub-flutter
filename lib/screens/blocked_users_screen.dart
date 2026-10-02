import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/ios_kit.dart';
import '../widgets/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<ChatUser> _blocked = const [];
  bool _loading = true;
  String? _pendingUnblock;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final me = widget.repo.userId;
    if (me == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final list = await widget.api.listBlocked(me);
      if (!mounted) return;
      setState(() {
        _blocked = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _unblock(ChatUser u) async {
    final me = widget.repo.userId;
    if (me == null) return;
    setState(() => _pendingUnblock = u.id);
    try {
      await widget.api.unblockUser(userId: me, targetUserId: u.id);
      if (!mounted) return;
      setState(() => _blocked = _blocked.where((b) => b.id != u.id).toList());
    } catch (_) {} finally {
      if (mounted) setState(() => _pendingUnblock = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return IosPage(
      title: l10n.acctRowBlocked,
      slivers: readableSlivers(context, [
        if (_loading)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                color: theme.accent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_blocked.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.hand_raised,
                  size: 44,
                  color: theme.inkMuted.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.acctBlockedEmpty,
                  textAlign: TextAlign.center,
                  style: theme.bodySoft,
                ),
              ],
            ),
          )
        else
          InsetGroup(
            dividerInset: 66,
            children: [
              for (final u in _blocked) _row(theme, l10n, u),
            ],
          ),
      ]),
    );
  }

  Widget _row(AppTheme theme, AppLocalizations l10n, ChatUser u) {
    final busy = _pendingUnblock == u.id;
    return PressRow(
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
      child: Row(
        children: [
          UserAvatar(user: u, size: 38, api: widget.api, showStatus: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.displayName,
                  style: theme.body.copyWith(color: theme.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${u.username}',
                  style: theme.caption.copyWith(color: theme.inkMuted),
                ),
              ],
            ),
          ),
          busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accent,
                  ),
                )
              : SpringPress(
                  onTap: () => _unblock(u),
                  semanticLabel: l10n.acctUnblock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.acctUnblock,
                      style: theme.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.accent,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
