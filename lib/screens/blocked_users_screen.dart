import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart' show readableSlivers;
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
              child: CupertinoActivityIndicator(color: theme.inkMuted),
            ),
          )
        else if (_blocked.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: CupertinoIcons.hand_raised,
              title: l10n.acctBlockedEmpty,
            ),
          )
        else
          GroupedSection(
            children: [for (final u in _blocked) _row(l10n, u)],
          ),
      ]),
    );
  }

  /// A blocked person: face, name, handle, and the shared inline Unblock —
  /// which keeps its gap from a long, truncated name and draws its own
  /// spinner while the unblock is in flight.
  Widget _row(AppLocalizations l10n, ChatUser u) => PersonRow(
        avatar: UserAvatar(user: u, size: 40, api: widget.api, showStatus: false),
        title: u.displayName,
        subtitle: '@${u.username}',
        trailing: RowPillButton(
          label: l10n.acctUnblock,
          busy: _pendingUnblock == u.id,
          onTap: () => _unblock(u),
        ),
      );
}
