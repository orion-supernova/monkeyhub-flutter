import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
                      ),
                      const SizedBox(width: 4),
                      Text('BLOCKED', style: theme.label.copyWith(letterSpacing: 3)),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2))
                      : _blocked.isEmpty
                          ? Center(
                              child: Text(
                                'you haven\'t blocked anyone.',
                                style: theme.bodySoft,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: _blocked.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final u = _blocked[i];
                                final busy = _pendingUnblock == u.id;
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: theme.surface,
                                    border: Border.all(color: theme.divider),
                                    borderRadius: BorderRadius.circular(theme.radiusMd),
                                  ),
                                  child: Row(
                                    children: [
                                      UserAvatar(user: u, size: 36, api: widget.api, showStatus: false),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(u.displayName, style: theme.displaySmall.copyWith(fontSize: 16)),
                                            Text('@${u.username}', style: theme.monoTiny),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: busy ? null : () => _unblock(u),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: theme.surfaceRaised,
                                            borderRadius: BorderRadius.circular(theme.radiusMd),
                                            border: Border.all(color: theme.divider),
                                          ),
                                          child: busy
                                              ? SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: theme.accent,
                                                  ),
                                                )
                                              : Text('UNBLOCK',
                                                  style: theme.monoTiny.copyWith(color: theme.accent)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
