import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/enums.dart';
import '../models/friend_request.dart';
import '../screens/friend_request_draft_screen.dart';
import '../screens/navigation/open_room.dart';
import '../theme/theme_scope.dart';
import 'approval_gate.dart';
import 'user_avatar.dart';
import 'visibility_badge.dart';

/// Relative age of a request, short enough to sit in a card's top-right corner.
String requestAgo(BuildContext context, DateTime then) {
  final l10n = AppLocalizations.of(context);
  final d = DateTime.now().difference(then);
  if (d.inMinutes < 60) return l10n.fileMessageAgoMinutes(d.inMinutes);
  if (d.inHours < 24) return l10n.fileMessageAgoHours(d.inHours);
  return l10n.fileMessageAgoDays(d.inDays);
}

/// A connection someone is offering, with the decision attached.
///
/// Lives in `widgets/` because Discover renders these inline — the requests
/// lists went back to being part of the screen rather than a push away, so the
/// cards have to be reachable from more than one file.
class IncomingRequestCard extends StatefulWidget {
  const IncomingRequestCard({
    super.key,
    required this.req,
    required this.repo,
    required this.api,
  });
  final FriendRequest req;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends State<IncomingRequestCard> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final roomId = await widget.repo.approveDirectRequest(widget.req.user.id);
      if (!mounted) return;
      if (roomId != null) {
        openRoom(context, roomId: roomId, repo: widget.repo, api: widget.api);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repo.rejectDirectRequest(widget.req.user.id);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDraft() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendRequestDraftScreen(
          repo: widget.repo,
          api: widget.api,
          req: widget.req,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final req = widget.req;
    return GestureDetector(
      onTap: _openDraft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: theme.roomCardDecoration(
          ephemeral: req.roomType == RoomType.secret,
          active: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(user: req.user, size: 42, api: widget.api),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.user.displayName, style: theme.displaySmall),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${req.user.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.mono.copyWith(color: theme.inkMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (req.roomType == RoomType.secret &&
                              req.messageLifetime != null)
                            EphemeralBadge(
                              ttl: req.messageLifetime!,
                              dense: true,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: theme.chipDecoration(),
                              child: Text(
                                l10n.fileMessageStandardBadge,
                                style: theme.monoTiny,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(requestAgo(context, req.createdAt), style: theme.monoTiny),
              ],
            ),
            if (req.initialMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: theme.surfaceSunken,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                  border: Border(
                    left: BorderSide(color: theme.accent, width: 2),
                  ),
                ),
                child: Text('"${req.initialMessage}"', style: theme.bodyEmph),
              ),
            ],
            if (req.messageCount > 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.forum_outlined, size: 12, color: theme.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.fileMessageDraftMessagesTapToView(req.messageCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.monoTiny.copyWith(color: theme.accent),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: RequestAction(
                    label: _busy ? '…' : l10n.fileMessageApproveButton,
                    filled: true,
                    onTap: _busy ? null : _accept,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RequestAction(
                    label: l10n.fileMessageDeclineButton,
                    filled: false,
                    onTap: _busy ? null : _reject,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A connection you offered, and the only thing you can do about it — cancel.
class OutgoingRequestCard extends StatefulWidget {
  const OutgoingRequestCard({
    super.key,
    required this.req,
    required this.repo,
    required this.api,
  });
  final FriendRequest req;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<OutgoingRequestCard> createState() => _OutgoingRequestCardState();
}

class _OutgoingRequestCardState extends State<OutgoingRequestCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repo.cancelDirectRequest(widget.req.user.id);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final req = widget.req;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: theme.roomCardDecoration(
        ephemeral: req.roomType == RoomType.secret,
        active: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(user: req.user, size: 42, api: widget.api),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.user.displayName, style: theme.displaySmall),
                    const SizedBox(height: 2),
                    Text(
                      '@${req.user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.mono.copyWith(color: theme.inkMuted),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.fileMessageSentAgoLabel(
                  requestAgo(context, req.createdAt).toUpperCase(),
                ),
                style: theme.monoTiny,
              ),
            ],
          ),
          if (req.stage != null) ...[
            const SizedBox(height: 12),
            // Distinguishes "my own grown-up hasn't released it yet" from
            // "it's with them now". Deliberately says nothing about the other
            // side's supervision — that would disclose that they're a child.
            WaitingPill(label: req.stage!.senderLabel(l10n)),
          ],
          if (req.messageCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              l10n.fileMessageMessagesPending(req.messageCount),
              style: theme.bodySoft,
            ),
          ],
          const SizedBox(height: 14),
          RequestAction(
            label: _busy ? '…' : l10n.fileMessageCancelRequestButton,
            filled: false,
            onTap: _busy ? null : _cancel,
          ),
        ],
      ),
    );
  }
}

/// The flat CTA both request cards use.
class RequestAction extends StatelessWidget {
  const RequestAction({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (onTap == null ? theme.accentSoft : theme.accent)
              : Colors.transparent,
          border: Border.all(
            color: filled ? theme.accent : theme.divider,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          style: theme.label.copyWith(
            color: filled ? theme.accentInk : theme.ink,
          ),
        ),
      ),
    );
  }
}
