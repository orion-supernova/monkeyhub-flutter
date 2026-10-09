import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_errors.dart';
import '../backend/chat_api.dart';
import '../backend/server_store.dart';
import '../data/chat_repository.dart';
import '../invites/invite_link.dart';
import '../invites/room_admin_errors.dart';
import '../l10n/generated/app_localizations.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../models/room_admin.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/approval_gate.dart';
import '../widgets/labeled_field.dart';
import '../widgets/remote_image.dart';
import '../widgets/sheet_kit.dart' show FormErrorBanner, SheetActionButton;
import 'room_screen.dart';
import '../widgets/ios_kit.dart';

/// Where a tapped invite link lands, and where a typed code is entered.
///
/// One screen for both, because they are the same act on the same token — see
/// `invites/invite_link.dart`. Opened with a [code] it goes straight to the
/// confirmation; opened without one it asks for the code first.
///
/// Nothing here joins anything on its own. A link that opened the app and
/// immediately dropped the user into a room would be a URL that changes your
/// account state on tap, which is the behaviour every phishing link wants. The
/// confirmation step is the feature.
class JoinByInviteScreen extends StatefulWidget {
  const JoinByInviteScreen({
    super.key,
    required this.repo,
    required this.api,
    this.code,
    this.serverUrl,
  });

  final ChatRepository repo;
  final ChatApi api;

  /// From a tapped link. Null when the user opened "join with a code".
  final String? code;

  /// The deployment the invite named, when it named one. Compared against the
  /// active server before anything is attempted — a room id from one backend
  /// means nothing on another, and resolving it anyway is how somebody ends up
  /// looking at a room they were never invited to.
  final String? serverUrl;

  @override
  State<JoinByInviteScreen> createState() => _JoinByInviteScreenState();
}

class _JoinByInviteScreenState extends State<JoinByInviteScreen> {
  final _codeField = TextEditingController();
  InvitePreview? _preview;
  bool _loading = false;
  bool _joining = false;
  String? _error;

  /// Set when the ask below succeeds, so the button becomes the waiting notice
  /// without a second round trip. The preview's own [ChildGate.asked] covers
  /// every other way of arriving here already waiting — including a child who
  /// asked yesterday, whom this screen must not offer the ask again.
  bool _justAsked = false;

  /// Set when the invite belongs to a different backend. Held as a field
  /// rather than folded into [_error] because the copy needs the host name and
  /// the screen offers no retry — there is nothing to try again.
  String? _foreignServer;

  @override
  void initState() {
    super.initState();
    final code = widget.code;
    if (code != null) {
      _codeField.text = code;
      _checkServerThenPreview(code);
    }
  }

  @override
  void dispose() {
    _codeField.dispose();
    super.dispose();
  }

  void _checkServerThenPreview(String code) {
    final link = InviteLink(code: code, serverUrl: widget.serverUrl);
    if (!link.matchesActiveServer(ServerStore.instance)) {
      setState(() {
        _foreignServer =
            Uri.tryParse(widget.serverUrl ?? '')?.host ?? widget.serverUrl;
      });
      return;
    }
    _load(code);
  }

  Future<void> _load(String code) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await widget.repo.previewInvite(code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _justAsked = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = humanizeAuthError(
          e,
          l10n,
          fallback: l10n.joinInviteLookupFailed,
          overrides: roomAdminErrorMessages(l10n),
        );
      });
    }
  }

  /// Whether a grown-up has to answer before this one can be joined at all.
  /// Straight from the server: [ChildGate.none] for an adult, and
  /// [ChildGate.granted] once a guardian has said yes, both of which join the
  /// ordinary way.
  bool get _mustAsk =>
      _preview?.childGate == ChildGate.needed ||
      _preview?.childGate == ChildGate.asked;

  /// Asked and not yet answered — on this tap or on an earlier one.
  bool get _waiting => _justAsked || _preview?.childGate == ChildGate.asked;

  /// The child's half of the join: raise it with a grown-up, and stop. The
  /// room is entered later, by the child, from the invite their guardian
  /// releases — never from here.
  Future<void> _askGrownUp(InvitePreview preview) async {
    final uid = widget.repo.userId;
    final roomId = preview.roomId;
    if (uid == null || roomId == null) return;
    final l10n = AppLocalizations.of(context);
    final wantsToAsk = await showApprovalGate(
      context,
      what: l10n.enterPublicRoomJoinWhat(preview.name ?? ''),
      detail: preview.description,
      alreadyAsked: _waiting,
    );
    // Both halves load-bearing, as in `enterPublicRoom`: the already-asked
    // state suppresses a second request even when the gate returns true, which
    // is what stops a re-tap reaching the guardian's queue twice.
    if (!mounted || !wantsToAsk || _waiting) return;
    setState(() => _joining = true);
    try {
      await widget.api.requestApproval(
        childId: uid,
        kind: 'joinRoom',
        targetRoomId: roomId,
      );
      if (!mounted) return;
      setState(() {
        _joining = false;
        _justAsked = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        // Its own message: "couldn't join" is the wrong verb for an action
        // they cannot perform in the first place.
        _error = l10n.enterPublicRoomAskFailedMessage;
      });
    }
  }

  Future<void> _join() async {
    final preview = _preview;
    if (preview == null || !preview.isJoinable) return;
    // A child never redeems. A link is not a way around a guardian — the
    // server refuses it in `roomInvites.redeem` — but this screen used to let
    // them discover that by tapping JOIN and getting a generic failure, with
    // no request filed and no way to ask anyone. It is the third door onto the
    // flow `navigation/enter_public_room.dart` already fixed for Discover and
    // Search; see the note there, which counted two.
    if (_mustAsk) {
      await _askGrownUp(preview);
      return;
    }
    setState(() => _joining = true);
    try {
      final result = await widget.repo.redeemInvite(_codeField.text.trim());
      if (!mounted) return;
      setState(() => _joining = false);
      if (result == null) return;
      switch (result.outcome) {
        case RedeemOutcome.joined:
          HapticFeedback.mediumImpact();
          _leaveForRoom(result.roomId);
        case RedeemOutcome.alreadyMember:
          _leaveForRoom(result.roomId);
        case RedeemOutcome.requested:
          setState(() {
            _preview = InvitePreview(
              problem: InviteProblem.requestPending,
              roomId: preview.roomId,
              name: preview.name,
              description: preview.description,
              memberCount: preview.memberCount,
              isPrivate: preview.isPrivate,
              avatarStorageId: preview.avatarStorageId,
              joinPolicy: preview.joinPolicy,
              childGate: preview.childGate,
            );
          });
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _joining = false;
        _error = humanizeAuthError(
          e,
          l10n,
          fallback: l10n.roomAdminGenericError,
          overrides: roomAdminErrorMessages(l10n),
        );
      });
    }
  }

  /// Hand off to the room and take this screen out of the stack.
  ///
  /// Deliberately not `navigation/open_room.dart`: that helper PUSHES, which
  /// would leave a join screen sitting under the room for a room the user has
  /// already joined — back out of the chat and you are looking at "you're
  /// already a member" instead of wherever you started. Same two window-class
  /// branches as that helper otherwise, and the same selection bookkeeping,
  /// which the desktop pane needs whether or not anything is pushed.
  void _leaveForRoom(String roomId) {
    final nav = Navigator.of(context);
    UiSelectionStore.instance.selectRoom(roomId);
    if (context.usesSplitShell) {
      SettingsStore.instance.setSection(HomeSection.chat);
      nav.pop();
      return;
    }
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            RoomScreen(roomId: roomId, repo: widget.repo, api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    // THE pushed page: glass back, a large title that hands off to the bar
    // as it scrolls — not a hand-built back-and-title row.
    return IosPage(
      title: l10n.joinInviteTitle,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      children: [AdaptivePageBody(child: _body(theme, l10n))],
    );
  }

  Widget _body(AppTheme theme, AppLocalizations l10n) {
    final foreign = _foreignServer;
    if (foreign != null) {
      return _Notice(
        icon: CupertinoIcons.exclamationmark_triangle,
        tone: theme.danger,
        headline: l10n.joinInviteWrongServerHeadline,
        body: l10n.joinInviteWrongServerBody(foreign),
      );
    }

    if (widget.code == null && _preview == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.joinInviteCodeBlurb, style: groupedFooterStyle(theme)),
          const SizedBox(height: 18),
          LabeledField(
            label: l10n.joinInviteCodeLabel,
            controller: _codeField,
            hint: l10n.joinInviteCodeHint,
          ),
          const SizedBox(height: 8),
          if (_error != null) FormErrorBanner(_error!),
          const SizedBox(height: 14),
          SheetActionButton(
            label: l10n.joinInviteLookupButton,
            onTap: _loading
                ? null
                : () {
                    final parsed = parseInviteLink(_codeField.text);
                    if (parsed == null) {
                      setState(() => _error = l10n.joinInviteCodeInvalid);
                      return;
                    }
                    _codeField.text = parsed.code;
                    _load(parsed.code);
                  },
          ),
        ],
      );
    }

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CupertinoActivityIndicator(
              radius: 11,
              color: theme.inkMuted,
            ),
          ),
        ),
      );
    }

    final preview = _preview;
    if (preview == null) {
      return _Notice(
        icon: CupertinoIcons.link,
        tone: theme.danger,
        headline: l10n.joinInviteBadLinkHeadline,
        body: _error ?? l10n.joinInviteBadLinkBody,
      );
    }

    // A dead link has no room to show, so the whole screen is the explanation.
    if (preview.roomId == null) {
      return _Notice(
        icon: CupertinoIcons.link,
        tone: theme.danger,
        headline: _problemHeadline(l10n, preview.problem),
        body: _problemBody(l10n, preview.problem),
      );
    }

    final pending = preview.problem == InviteProblem.requestPending;
    final already = preview.problem == InviteProblem.alreadyMember;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoomCard(preview: preview, api: widget.api),
        const SizedBox(height: 22),
        if (pending)
          _Notice(
            icon: CupertinoIcons.hourglass,
            tone: theme.accent,
            headline: l10n.joinInvitePendingHeadline,
            body: l10n.joinInvitePendingBody,
          )
        else if (already)
          SheetActionButton(
            label: l10n.joinInviteOpenRoom,
            onTap: () => _leaveForRoom(preview.roomId!),
          )
        // Waiting on a grown-up, not on an admin: the same shape as the
        // `pending` notice above, because from here they are the same wait.
        else if (_waiting)
          _Notice(
            icon: CupertinoIcons.hourglass,
            tone: theme.accent,
            headline: l10n.approvalGateAlreadyAskedLabel,
            body: l10n.approvalGateAlreadyAskedFooter,
          )
        else ...[
          if (_error != null) ...[
            FormErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          // The button says what will actually happen. Under the approval
          // policy this is a request, and finding that out only after tapping
          // "Join" is the kind of small dishonesty that makes a product feel
          // untrustworthy. For a child it is an ask, whatever the room's own
          // policy says, because the grown-up answers first either way.
          SheetActionButton(
            label: _mustAsk
                ? l10n.approvalGateAskButton
                : preview.joinPolicy == RoomJoinPolicy.approval
                    ? l10n.joinInviteRequestButton
                    : l10n.joinInviteJoinButton,
            onTap: _joining ? null : _join,
          ),
          const SizedBox(height: 10),
          Text(
            _mustAsk
                ? l10n.approvalGateWillNotifyFooter
                : preview.joinPolicy == RoomJoinPolicy.approval
                    ? l10n.joinInviteApprovalNote
                    : l10n.joinInviteOpenNote,
            style: groupedFooterStyle(theme),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  String _problemHeadline(AppLocalizations l10n, InviteProblem p) => switch (p) {
        InviteProblem.expired => l10n.joinInviteExpiredHeadline,
        InviteProblem.exhausted => l10n.joinInviteExhaustedHeadline,
        InviteProblem.revoked => l10n.joinInviteRevokedHeadline,
        _ => l10n.joinInviteBadLinkHeadline,
      };

  String _problemBody(AppLocalizations l10n, InviteProblem p) => switch (p) {
        InviteProblem.expired => l10n.joinInviteExpiredBody,
        InviteProblem.exhausted => l10n.joinInviteExhaustedBody,
        InviteProblem.revoked => l10n.joinInviteRevokedBody,
        _ => l10n.joinInviteBadLinkBody,
      };
}

/// The room, as much of it as an outsider is allowed to see.
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.preview, required this.api});

  final InvitePreview preview;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusLg),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusMd),
            child: SizedBox(
              width: 84,
              height: 84,
              child: preview.avatarStorageId == null
                  ? Container(
                      color: theme.surface,
                      alignment: Alignment.center,
                      child: Icon(
                        CupertinoIcons.person_3,
                        size: 36,
                        color: theme.inkMuted,
                      ),
                    )
                  : RemoteImage(
                      storageId: preview.avatarStorageId!,
                      api: api,
                      width: 84,
                      height: 84,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            preview.name ?? '',
            style: theme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.joinInviteMemberCount(preview.memberCount),
            style: groupedSubtitleStyle(theme),
          ),
          if ((preview.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              preview.description!,
              style: theme.bodySoft,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.tone,
    required this.headline,
    required this.body,
  });

  final IconData icon;
  final Color tone;
  final String headline;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      // A grouped block, no tinted outline: the glyph carries the tone.
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: tone),
          const SizedBox(height: 12),
          Text(
            headline,
            style: groupedHeaderStyle(theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: groupedFooterStyle(theme),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
