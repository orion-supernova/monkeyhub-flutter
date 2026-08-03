import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../family/family_service.dart';
import '../models/chat_user.dart';
import '../models/family.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/destructive_sheet.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import '../widgets/remove_contact_sheet.dart';
import '../widgets/user_avatar.dart';

/// Per-child controls, plus the list of what they've already been granted.
///
/// Everything here is guardian-only: the child has no screen that can reach
/// these values, and `users.updateVisibility` refuses child accounts outright
/// on the backend.
class ChildPolicyScreen extends StatefulWidget {
  const ChildPolicyScreen({
    super.key,
    required this.api,
    required this.guardianId,
    required this.child,
    required this.family,
  });

  final ChatApi api;
  final String guardianId;
  final ChildSummary child;
  final FamilyService family;

  @override
  State<ChildPolicyScreen> createState() => _ChildPolicyScreenState();
}

class _ChildPolicyScreenState extends State<ChildPolicyScreen> {
  late ChildPolicy _policy = widget.child.policy;
  ChildGrants? _grants;
  bool _saving = false;

  /// The live view of this child. `widget.child` is the snapshot the family
  /// screen was showing when this opened; FamilyService keeps the real one
  /// current, which matters here because a co-parent can add or remove a
  /// guardian while this screen is up.
  ChildSummary get _child => widget.family.context.children.firstWhere(
        (c) => c.user.id == widget.child.user.id,
        orElse: () => widget.child,
      );

  @override
  void initState() {
    super.initState();
    widget.family.addListener(_onFamilyChange);
    _loadGrants();
  }

  @override
  void dispose() {
    widget.family.removeListener(_onFamilyChange);
    super.dispose();
  }

  void _onFamilyChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadGrants() async {
    try {
      final g = await widget.api.listChildGrants(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
      );
      if (mounted) setState(() => _grants = g);
    } catch (_) {/* dashboard still works without the grant list */}
  }

  Future<void> _set({
    bool? callsEnabled,
    bool? mediaEnabled,
    bool? canRequestContacts,
    bool? canCreateRooms,
  }) async {
    if (_saving) return;
    // Optimistic: the toggle should move under the thumb, not after a round
    // trip. Reverted below if the write fails.
    final previous = _policy;
    setState(() {
      _saving = true;
      _policy = _policy.copyWith(
        callsEnabled: callsEnabled,
        mediaEnabled: mediaEnabled,
        canRequestContacts: canRequestContacts,
        canCreateRooms: canCreateRooms,
      );
    });
    try {
      final next = await widget.api.setChildPolicy(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
        callsEnabled: callsEnabled,
        mediaEnabled: mediaEnabled,
        canRequestContacts: canRequestContacts,
        canCreateRooms: canCreateRooms,
      );
      if (mounted) setState(() => _policy = next);
      widget.family.refresh();
    } catch (_) {
      if (mounted) setState(() => _policy = previous);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeRoom(RoomBrief room) async {
    final id = room.approvalId;
    if (id == null) return;
    try {
      await widget.api.revokeApproval(
        guardianId: widget.guardianId,
        approvalId: id,
      );
      await _loadGrants();
    } catch (_) {/* surfaced by the list simply not changing */}
  }

  /// One path for every row in the allowed list, whitelisted or not: find out
  /// what would be destroyed, confirm if there's anything to lose, then a
  /// single mutation that severs the contact AND wipes the conversation.
  ///
  /// The backend cascades either way — `revokeApproval` on a whitelist row
  /// does the same teardown as `revokeContact` — so this never issues two
  /// calls that could fail apart from each other.
  Future<void> _takeBack(ChildContact c) async {
    final messenger = ScaffoldMessenger.of(context);

    // Failing to preview must not mean failing to act, or an offline parent
    // can't remove anyone. Fall back to a preview that reports nothing known,
    // which still routes through the confirmation below.
    ContactRemovalPreview preview;
    try {
      preview = await widget.api.previewContactRemoval(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
        contactUserId: c.user.id,
      );
    } catch (_) {
      preview = ContactRemovalPreview.unknown;
    }
    if (!mounted) return;

    // Nothing to lose — no chats, no shared rooms — so don't make them
    // confirm about nothing.
    if (!preview.isEmpty) {
      final ok = await showRemoveContactSheet(
        context,
        contactName: c.user.displayName,
        childName: widget.child.user.displayName,
        preview: preview,
        api: widget.api,
      );
      if (!ok || !mounted) return;
    }

    try {
      if (c.isWhitelisted) {
        await widget.api.revokeApproval(
          guardianId: widget.guardianId,
          approvalId: c.approvalId!,
        );
      } else {
        await widget.api.revokeContact(
          guardianId: widget.guardianId,
          childId: widget.child.user.id,
          contactUserId: c.user.id,
        );
      }
      await _loadGrants();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('couldn\'t take them back — try again')),
      );
    }
  }

  Future<void> _addByUsername() async {
    final result = await showAdaptiveSheet<_AddContactResult>(
      context,
      builder: (_) => _AddContactSheet(childName: widget.child.user.displayName),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final requested = await widget.api.allowContactByUsername(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
        username: result.username,
        sendRequestNow: result.sendNow,
      );
      await _loadGrants();
      messenger.showSnackBar(SnackBar(
        content: Text(requested
            ? 'added — the request is on its way'
            : 'added to the allowed list'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_humanizeAdd(e))));
    }
  }

  String _humanizeAdd(Object e) {
    final s = e.toString();
    if (s.contains('USER_NOT_FOUND')) return 'no account with that username';
    if (s.contains('CANNOT_ADD_SELF')) return 'that\'s their own username';
    if (s.contains('NOT_A_GUARDIAN')) return 'that\'s not yours to change';
    return 'couldn\'t add them — try again';
  }

  // ── Grown-ups ────────────────────────────────────────────────────────────

  Future<void> _addGuardian() async {
    final username = await showAdaptiveSheet<String>(
      context,
      builder: (_) => _PromptSheet(
        heading: 'ADD A GROWN-UP',
        blurb: 'They get exactly what you have: every request to approve, '
            'every setting to change, and the power to remove you. '
            '${_child.user.displayName} sees them as family straight away.',
        hint: 'their username',
        ctaLabel: 'ADD',
      ),
    );
    if (username == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.addGuardian(
        guardianId: widget.guardianId,
        childId: _child.user.id,
        newGuardianUsername: username,
      );
      await widget.family.refresh();
      messenger.showSnackBar(
        const SnackBar(content: Text('added — they can look after them now')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_humanizeGuardian(e))));
    }
  }

  Future<void> _removeGuardian(ChatUser guardian) async {
    final isMe = guardian.id == widget.guardianId;
    final name = isMe ? 'you' : guardian.displayName;
    final ok = await showConfirmSheet(
      context,
      headline: isMe ? 'STOP SUPERVISING?' : 'REMOVE ${guardian.displayName.toUpperCase()}?',
      body: isMe
          ? 'You\'ll lose every bit of visibility into '
              '${_child.user.displayName}\'s account — their requests, their '
              'people, their rooms. The other grown-ups keep looking after them.'
          : '${guardian.displayName} will no longer see or approve anything '
              'for ${_child.user.displayName}.',
      confirmLabel: isMe ? 'STOP SUPERVISING' : 'REMOVE',
    );
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await widget.api.unlinkChild(
        guardianId: guardian.id,
        childId: _child.user.id,
      );
      await widget.family.refresh();
      if (!mounted) return;
      // Removing yourself means this screen is no longer yours to look at.
      if (isMe) {
        nav.pop();
      } else {
        messenger.showSnackBar(SnackBar(content: Text('$name removed')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_humanizeGuardian(e))));
    }
  }

  String _humanizeGuardian(Object e) {
    final s = e.toString();
    if (s.contains('LAST_GUARDIAN')) {
      return 'someone has to look after them — add another grown-up first';
    }
    if (s.contains('USER_NOT_FOUND')) return 'no account with that username';
    if (s.contains('CHILD_NOT_ALLOWED')) return 'a child can\'t be a grown-up';
    if (s.contains('NOT_A_GUARDIAN')) return 'that\'s not yours to change';
    return 'couldn\'t do that — try again';
  }

  // ── Danger zone ──────────────────────────────────────────────────────────

  Future<void> _graduate() async {
    final password = await showAdaptiveSheet<String>(
      context,
      builder: (_) => _PromptSheet(
        heading: 'GRADUATE ${_child.user.displayName.toUpperCase()}',
        blurb: 'They become a normal account with this password, and every '
            'grown-up loses all visibility. There is no way back — you would '
            'have to be invited like anyone else.',
        hint: 'a password for them',
        ctaLabel: 'GRADUATE',
        obscure: true,
        minLength: 8,
      ),
    );
    if (password == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await widget.api.promoteToAdult(
        guardianId: widget.guardianId,
        childId: _child.user.id,
        password: password,
      );
      await widget.family.refresh();
      if (mounted) nav.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('couldn\'t graduate them — try again')),
      );
    }
  }

  Future<void> _deleteChild() async {
    final name = _child.user.displayName;
    final ok = await showConfirmSheet(
      context,
      headline: 'DELETE $name\'s ACCOUNT?'.toUpperCase(),
      body: 'Everything goes: their messages, photos, rooms, and friends. '
          'This cannot be undone, and the username is freed for anyone else.',
      confirmLabel: 'DELETE FOREVER',
    );
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await widget.api.deleteChildAccount(
        guardianId: widget.guardianId,
        childId: _child.user.id,
      );
      await widget.family.refresh();
      if (mounted) nav.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('couldn\'t delete the account — try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final grants = _grants;
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
                      Expanded(
                        child: Text(
                          widget.child.user.displayName.toUpperCase(),
                          style: theme.label.copyWith(letterSpacing: 2.8),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    children: [
                      _SectionHeader('WHAT THEY CAN DO'),
                      const SizedBox(height: 12),
                      // Public rooms used to be a toggle here. It is now fixed
                      // off for every kid and cannot be switched on, so it is a
                      // statement rather than a control — but it still has to
                      // be SAID. A guardian who saw the switch before would
                      // otherwise assume the setting was lost or reset, and one
                      // who never did deserves to know the limit exists.
                      _FixedNote(
                        label: 'PUBLIC ROOMS',
                        body: 'Always off for kids. Discover — the list of '
                            'rooms belonging to people you don\'t know — is '
                            'hidden completely and can\'t be switched on. '
                            'Rooms someone invites them to still work as '
                            'normal.',
                      ),
                      const SizedBox(height: 10),
                      _Toggle(
                        label: 'ASK TO ADD',
                        on: _policy.canRequestContacts,
                        onDesc: 'they can ask you about new people',
                        offDesc: 'family only — no new requests',
                        onChanged: (v) => _set(canRequestContacts: v),
                      ),
                      const SizedBox(height: 10),
                      _Toggle(
                        label: 'CALLS',
                        on: _policy.callsEnabled,
                        onDesc: 'voice + video with people they\'re allowed',
                        offDesc: 'messages only',
                        onChanged: (v) => _set(callsEnabled: v),
                      ),
                      const SizedBox(height: 10),
                      _Toggle(
                        label: 'PHOTOS + VOICE',
                        on: _policy.mediaEnabled,
                        onDesc: 'they can send pictures, video and voice notes',
                        offDesc: 'text only',
                        onChanged: (v) => _set(mediaEnabled: v),
                      ),
                      const SizedBox(height: 10),
                      _Toggle(
                        label: 'MAKE ROOMS',
                        on: _policy.canCreateRooms,
                        onDesc: 'they can start their own private rooms',
                        offDesc: 'they can\'t start rooms',
                        onChanged: (v) => _set(canCreateRooms: v),
                      ),

                      const SizedBox(height: 30),
                      _SectionHeader('PEOPLE YOU\'VE ALLOWED'),
                      const SizedBox(height: 12),
                      Text(
                        'Anyone here can be added without asking you again — '
                        'whichever of them starts it.',
                        style: theme.bodySoft,
                      ),
                      const SizedBox(height: 12),
                      if (grants == null)
                        _Placeholder('loading…')
                      else ...[
                        for (final c in grants.contacts)
                          _GrantRow(
                            title: c.user.displayName,
                            subtitle: '@${c.user.username} · ${c.stateLabel}',
                            leading: UserAvatar(
                                user: c.user, size: 32, api: widget.api),
                            onRevoke: () => _takeBack(c),
                          ),
                        _AddByUsernameButton(onTap: _addByUsername),
                      ],

                      const SizedBox(height: 30),
                      _SectionHeader('ROOMS YOU\'VE ALLOWED'),
                      const SizedBox(height: 12),
                      if (grants == null)
                        _Placeholder('loading…')
                      else if (grants.rooms.isEmpty)
                        _Placeholder('no rooms yet')
                      else
                        for (final r in grants.rooms)
                          _GrantRow(
                            title: r.name,
                            subtitle: '${r.memberCount} in',
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: theme.accentSoft,
                                borderRadius:
                                    BorderRadius.circular(theme.radiusMd),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.tag,
                                  size: 13, color: theme.accent),
                            ),
                            onRevoke: () => _revokeRoom(r),
                          ),
                      const SizedBox(height: 24),
                      Text(
                        'Taking a room back also removes them from it. '
                        'Taking a person back deletes their chat as well — '
                        'for both of them.',
                        style: theme.monoTiny.copyWith(color: theme.inkMuted),
                      ),

                      const SizedBox(height: 30),
                      _SectionHeader('GROWN-UPS'),
                      const SizedBox(height: 12),
                      Text(
                        'Everyone here can approve, change settings, and see '
                        'everything. Any of them can act alone — nothing waits '
                        'on the others.',
                        style: theme.bodySoft,
                      ),
                      const SizedBox(height: 12),
                      for (final g in _child.guardians)
                        _GrantRow(
                          title: g.id == widget.guardianId
                              ? '${g.displayName} (you)'
                              : g.displayName,
                          subtitle: '@${g.username}',
                          leading:
                              UserAvatar(user: g, size: 32, api: widget.api),
                          // The last grown-up standing can't step away — the
                          // account would be stranded with nobody able to
                          // re-adopt or delete it. Graduate or delete instead.
                          onRevoke: _child.isSoleGuardian
                              ? null
                              : () => _removeGuardian(g),
                          revokeLabel:
                              g.id == widget.guardianId ? 'STEP AWAY' : 'REMOVE',
                        ),
                      _AddByUsernameButton(
                        label: 'ADD A GROWN-UP',
                        onTap: _addGuardian,
                      ),

                      const SizedBox(height: 30),
                      _SectionHeader('WHEN THEY\'RE DONE'),
                      const SizedBox(height: 12),
                      if (_child.isSoleGuardian)
                        Text(
                          'You\'re ${_child.user.displayName}\'s only grown-up, '
                          'so you can\'t just step away — add another first, or '
                          'use one of these.',
                          style: theme.bodySoft,
                        )
                      else
                        Text(
                          'Both of these are final. Stepping away instead is '
                          'up in GROWN-UPS.',
                          style: theme.bodySoft,
                        ),
                      const SizedBox(height: 12),
                      _DangerAction(
                        label: 'GRADUATE TO A FULL ACCOUNT',
                        detail:
                            'They keep everything and get a password. You lose '
                            'all visibility. Irreversible.',
                        onTap: _graduate,
                      ),
                      const SizedBox(height: 10),
                      _DangerAction(
                        label:
                            'DELETE ${_child.user.displayName.toUpperCase()}\'S ACCOUNT',
                        detail:
                            'Messages, photos, rooms and friends all go. Cannot '
                            'be undone.',
                        filled: true,
                        onTap: _deleteChild,
                      ),
                    ],
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

/// What the add-by-username sheet hands back.
class _AddContactResult {
  const _AddContactResult(this.username, this.sendNow);
  final String username;
  final bool sendNow;
}

class _AddByUsernameButton extends StatelessWidget {
  const _AddByUsernameButton({
    required this.onTap,
    this.label = 'ADD BY USERNAME',
  });
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_alt, size: 14, color: theme.accent),
            const SizedBox(width: 8),
            Text(label,
                style: theme.label
                    .copyWith(letterSpacing: 2.4, color: theme.accent)),
          ],
        ),
      ),
    );
  }
}

/// A full-width, spelled-out destructive action. Heavier than [_GrantRow]'s
/// inline "TAKE BACK" because these end an account rather than trim a list.
class _DangerAction extends StatelessWidget {
  const _DangerAction({
    required this.label,
    required this.detail,
    required this.onTap,
    this.filled = false,
  });
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: filled ? theme.danger.withValues(alpha: 0.10) : theme.surface,
          border: Border.all(
            color: theme.danger.withValues(alpha: filled ? 0.55 : 0.30),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.label.copyWith(color: theme.danger)),
            const SizedBox(height: 4),
            Text(detail, style: theme.monoTiny),
          ],
        ),
      ),
    );
  }
}

/// Username field plus the "send it now" choice.
///
/// The distinction matters and is stated plainly: adding to the list only
/// means you won't be asked again. It does not make them contacts — the other
/// person still has to accept, whether the request goes out now or later.
class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({required this.childName});
  final String childName;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _username = TextEditingController();
  bool _sendNow = true;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  void _submit() {
    final u = _username.text.trim();
    if (u.isEmpty) return;
    Navigator.of(context).pop(_AddContactResult(u, _sendNow));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: theme.surface,
                border: Border.all(color: theme.divider),
                borderRadius: BorderRadius.circular(theme.radiusLg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ALLOW SOMEONE',
                      style: theme.label
                          .copyWith(letterSpacing: 2.4, color: theme.accent)),
                  const SizedBox(height: 14),
                  Text(
                    'You won\'t be asked about them again — whether '
                    '${widget.childName} adds them or they add '
                    '${widget.childName}.',
                    style: theme.bodySoft,
                  ),
                  const SizedBox(height: 18),
                  ThemedInput(
                    controller: _username,
                    hint: 'username',
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => setState(() => _sendNow = !_sendNow),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: theme.surfaceSunken,
                        border: Border.all(color: theme.divider),
                        borderRadius: BorderRadius.circular(theme.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SEND THE REQUEST NOW',
                                    style: theme.label),
                                const SizedBox(height: 2),
                                Text(
                                  _sendNow
                                      ? 'they get asked straight away'
                                      : 'nothing happens until someone adds '
                                          'the other',
                                  style: theme.bodySoft,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch.adaptive(
                            value: _sendNow,
                            onChanged: (v) => setState(() => _sendNow = v),
                            activeThumbColor: theme.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _submit,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(theme.radiusMd),
                      ),
                      child: Text('ALLOW',
                          style: theme.label.copyWith(
                              color: theme.accentInk, letterSpacing: 2.4)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      alignment: Alignment.center,
                      child: Text('CANCEL',
                          style: theme.label.copyWith(color: theme.inkSoft)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One-field sheet: a heading, a line of explanation, an input, a CTA.
///
/// Same chrome as [_AddContactSheet] above, which is the reason it exists —
/// adding a grown-up and setting a graduation password are both "type one
/// thing and confirm", and three near-identical copies of that layout would
/// drift.
///
/// Pops the trimmed value, or null on cancel. [minLength] gates the CTA.
class _PromptSheet extends StatefulWidget {
  const _PromptSheet({
    required this.heading,
    required this.blurb,
    required this.hint,
    required this.ctaLabel,
    this.obscure = false,
    this.minLength = 1,
  });

  final String heading;
  final String blurb;
  final String hint;
  final String ctaLabel;
  final bool obscure;
  final int minLength;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  final _value = TextEditingController();

  @override
  void initState() {
    super.initState();
    _value.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  bool get _valid => _value.text.trim().length >= widget.minLength;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(_value.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: theme.surface,
                border: Border.all(color: theme.divider),
                borderRadius: BorderRadius.circular(theme.radiusLg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.heading,
                      style: theme.label
                          .copyWith(letterSpacing: 2.4, color: theme.accent)),
                  const SizedBox(height: 14),
                  Text(widget.blurb, style: theme.bodySoft),
                  const SizedBox(height: 18),
                  // Obscured prompts are passwords (the graduate-child flow),
                  // so they get the show/hide toggle; plain prompts stay a
                  // bare input.
                  if (widget.obscure)
                    PasswordField(
                      controller: _value,
                      hint: widget.hint,
                      autofocus: true,
                      onSubmitted: (_) => _submit(),
                    )
                  else
                    ThemedInput(
                      controller: _value,
                      hint: widget.hint,
                      autofocus: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _submit(),
                    ),
                  const SizedBox(height: 20),
                  FocusableTap(
                    onTap: _valid ? _submit : null,
                    enabled: _valid,
                    semanticLabel: widget.ctaLabel,
                    radius: theme.radiusMd,
                    child: GestureDetector(
                      onTap: _submit,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _valid ? theme.accent : theme.surfaceSunken,
                          borderRadius: BorderRadius.circular(theme.radiusMd),
                        ),
                        child: Text(
                          widget.ctaLabel,
                          style: theme.label.copyWith(
                            color: _valid ? theme.accentInk : theme.inkMuted,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FocusableTap(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: 'Cancel',
                    radius: theme.radiusMd,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        alignment: Alignment.center,
                        child: Text('CANCEL',
                            style: theme.label.copyWith(color: theme.inkSoft)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: theme.label.copyWith(letterSpacing: 2.8, color: theme.accent)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: theme.divider)),
      ],
    );
  }
}

/// A rule that is stated rather than offered — same shape as [_Toggle] so it
/// reads as part of the same list, minus the switch and minus the tap target.
///
/// No disabled Switch on purpose. A greyed-out control still says "this is a
/// setting, and someone could turn it on"; the point here is the opposite.
class _FixedNote extends StatelessWidget {
  const _FixedNote({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: theme.label),
              const SizedBox(width: 8),
              Text('LOCKED',
                  style: theme.label.copyWith(color: theme.inkMuted)),
            ],
          ),
          const SizedBox(height: 2),
          Text(body, style: theme.bodySoft),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.on,
    required this.onDesc,
    required this.offDesc,
    required this.onChanged,
  });

  final String label;
  final bool on;
  final String onDesc;
  final String offDesc;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () => onChanged(!on),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.label),
                  const SizedBox(height: 2),
                  Text(on ? onDesc : offDesc, style: theme.bodySoft),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: on,
              onChanged: onChanged,
              activeThumbColor: theme.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _GrantRow extends StatelessWidget {
  const _GrantRow({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onRevoke,
    this.revokeLabel = 'TAKE BACK',
  });

  final String title;
  final String subtitle;
  final Widget leading;

  /// Null renders the row without an action — used for the last remaining
  /// guardian, who isn't allowed to step away.
  final VoidCallback? onRevoke;

  final String revokeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.body, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: theme.monoTiny),
              ],
            ),
          ),
          if (onRevoke != null)
            GestureDetector(
              onTap: onRevoke,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(revokeLabel,
                    style: theme.label.copyWith(color: theme.danger)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: theme.bodySoft),
    );
  }
}
