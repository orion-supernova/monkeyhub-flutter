import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/family.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/destructive_sheet.dart';
import '../widgets/people_picker.dart';
import '../widgets/search_field.dart';
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

  /// The guardian's own friends, for the people picker.
  ///
  /// Fetched once on open rather than threaded in from a repository: this
  /// screen is reached from Settings, which does not carry one, and the list
  /// is small and static for the length of a visit. Null means "still
  /// loading" — distinct from an empty list, which means "you have no friends
  /// to add from", and the picker says different things for the two.
  List<ChatUser>? _myFriends;

  /// The guardian's own group rooms this child is not already in.
  List<RoomBrief>? _grantableRooms;

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
    _loadPickerSources();
  }

  /// Both picker sources, in parallel.
  ///
  /// Neither blocks the screen: the policy toggles and the existing grants are
  /// what a guardian usually came for, and they are already on screen while
  /// these land. A failure leaves the corresponding ADD button saying it has
  /// nothing to offer, which is survivable — the username path is still there.
  Future<void> _loadPickerSources() async {
    final results = await Future.wait([
      widget.api
          .listFriends(widget.guardianId)
          .catchError((_) => <ChatUser>[]),
      widget.api
          .grantableRooms(
            guardianId: widget.guardianId,
            childId: widget.child.user.id,
          )
          .catchError((_) => <RoomBrief>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _myFriends = (results[0] as List<ChatUser>)
          .where((f) => !f.isSystem)
          .toList(growable: false);
      _grantableRooms = results[1] as List<RoomBrief>;
    });
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
    } catch (_) {
      /* dashboard still works without the grant list */
    }
  }

  Future<void> _set({
    bool? callsEnabled,
    bool? mediaEnabled,
    bool? canRequestContacts,
    bool? canCreateRooms,
    bool? locationSharingEnabled,
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
        locationSharingEnabled: locationSharingEnabled,
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
        locationSharingEnabled: locationSharingEnabled,
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
    } catch (_) {
      /* surfaced by the list simply not changing */
    }
  }

  /// One path for every row in the allowed list, whitelisted or not: find out
  /// what would be destroyed, confirm if there's anything to lose, then a
  /// single mutation that severs the contact AND wipes the conversation.
  ///
  /// The backend cascades either way — `revokeApproval` on a whitelist row
  /// does the same teardown as `revokeContact` — so this never issues two
  /// calls that could fail apart from each other.
  Future<void> _takeBack(ChildContact c) async {
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);

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
      toast.show(
        l10n.childPolicyScreenTakeBackFailed,
        tone: ToastTone.danger,
      );
    }
  }

  /// "Allow someone", from the guardian's own friends.
  ///
  /// The list is the point. Typing a username from memory was the only way in
  /// before, and it is the wrong shape for the commonest case by a mile: the
  /// person a parent wants to allow is nearly always someone the PARENT
  /// already knows — an aunt, a neighbour, the other kid's mum — which means
  /// they are already in the parent's own friends list. Picking them from it
  /// cannot be misspelled, cannot land on a stranger with a similar handle,
  /// and shows a face before the decision instead of after it.
  ///
  /// Typing a handle is still there underneath, for the person a parent
  /// genuinely does not have: [_addContactByUsername].
  Future<void> _addContactFromFriends() async {
    final l10n = AppLocalizations.of(context);
    // Already-allowed people are filtered out here rather than greyed out in
    // the sheet: a row that does nothing is worse than a shorter list.
    final already = {
      for (final c in _grants?.contacts ?? const <ChildContact>[]) c.user.id,
    };
    final pool = (_myFriends ?? const <ChatUser>[])
        .where((f) => f.id != widget.child.user.id && !already.contains(f.id))
        .toList(growable: false);

    final picked = await showAdaptiveSheet<ChatUser>(
      context,
      useSafeArea: true,
      builder: (_) => _PickPersonSheet(
        people: pool,
        api: widget.api,
        guardianId: widget.guardianId,
        loading: _myFriends == null,
        childName: widget.child.user.displayName,
      ),
    );
    if (picked == null || !mounted) return;
    await _allowContact(picked.username, l10n);
  }

  /// The escape hatch: allow somebody by typing their handle.
  Future<void> _addContactByUsername() async {
    final result = await showAdaptiveSheet<_AddContactResult>(
      context,
      builder: (_) =>
          _AddContactSheet(childName: widget.child.user.displayName),
    );
    if (result == null || !mounted) return;
    await _allowContact(
      result.username,
      AppLocalizations.of(context),
      sendNow: result.sendNow,
    );
  }

  /// One write path for both doors above, so the toast and the error mapping
  /// cannot drift between them.
  Future<void> _allowContact(
    String username,
    AppLocalizations l10n, {
    bool sendNow = true,
  }) async {
    final toast = AppToast.of(context);
    try {
      final requested = await widget.api.allowContactByUsername(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
        username: username,
        sendRequestNow: sendNow,
      );
      await _loadGrants();
      toast.show(
        requested
            ? l10n.childPolicyScreenContactAddedRequestSent
            : l10n.childPolicyScreenContactAddedToList,
        tone: ToastTone.success,
      );
    } catch (e) {
      toast.show(_humanizeAdd(e, l10n));
    }
  }

  /// Puts the child into one of the guardian's own rooms.
  ///
  /// This section had no ADD at all — it could only list and revoke, which
  /// meant a room could only ever get there by the child asking for it or
  /// somebody inviting them. A parent setting up a family group chat had to
  /// go and invite their own child from the room, then approve their own
  /// invite from the approvals queue: two screens and a round trip to say yes
  /// to themselves.
  ///
  /// Only the guardian's OWN rooms are offered — see `grantableRooms` in
  /// backend/convex/family.ts for why that is the whole safety argument here.
  Future<void> _addRoom() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showAdaptiveSheet<RoomBrief>(
      context,
      useSafeArea: true,
      builder: (_) => _PickRoomSheet(
        rooms: _grantableRooms ?? const [],
        loading: _grantableRooms == null,
        childName: widget.child.user.displayName,
      ),
    );
    if (picked == null || !mounted) return;

    final toast = AppToast.of(context);
    try {
      await widget.api.grantRoomToChild(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
        roomId: picked.id,
      );
      // Both lists moved: the room is now granted, and it is no longer
      // offerable. Refreshed together so the picker cannot show a room the
      // list below already has.
      await Future.wait([_loadGrants(), _loadPickerSources()]);
      if (!mounted) return;
      toast.show(
        l10n.childPolicyScreenRoomAdded(
          widget.child.user.displayName,
          picked.name,
        ),
        tone: ToastTone.success,
      );
    } catch (e) {
      toast.show(_humanizeAddRoom(e, l10n));
    }
  }

  String _humanizeAddRoom(Object e, AppLocalizations l10n) {
    final s = e.toString();
    if (s.contains('NOT_A_GUARDIAN')) {
      return l10n.childPolicyScreenErrorNotYours;
    }
    if (s.contains('CHILD_NOT_ALLOWED')) {
      return l10n.childPolicyScreenErrorRoomNotAllowed;
    }
    if (s.contains('ROOM_NOT_FOUND')) {
      return l10n.childPolicyScreenErrorRoomGone;
    }
    return l10n.childPolicyScreenErrorAddRoomGeneric;
  }

  String _humanizeAdd(Object e, AppLocalizations l10n) {
    final s = e.toString();
    if (s.contains('USER_NOT_FOUND')) {
      return l10n.childPolicyScreenErrorUserNotFound;
    }
    if (s.contains('CANNOT_ADD_SELF')) {
      return l10n.childPolicyScreenErrorCannotAddSelf;
    }
    if (s.contains('NOT_A_GUARDIAN')) {
      return l10n.childPolicyScreenErrorNotYours;
    }
    return l10n.childPolicyScreenErrorAddContactGeneric;
  }

  // ── Grown-ups ────────────────────────────────────────────────────────────

  Future<void> _addGuardian() async {
    final l10n = AppLocalizations.of(context);
    final username = await showAdaptiveSheet<String>(
      context,
      builder: (_) => _PromptSheet(
        heading: l10n.childPolicyScreenAddGuardianHeading,
        blurb: l10n.childPolicyScreenAddGuardianBlurb(_child.user.displayName),
        hint: l10n.childPolicyScreenAddGuardianHint,
        ctaLabel: l10n.childPolicyScreenAddCta,
      ),
    );
    if (username == null || !mounted) return;

    final toast = AppToast.of(context);
    try {
      await widget.api.addGuardian(
        guardianId: widget.guardianId,
        childId: _child.user.id,
        newGuardianUsername: username,
      );
      await widget.family.refresh();
      toast.show(
        l10n.childPolicyScreenGuardianAdded,
        tone: ToastTone.success,
      );
    } catch (e) {
      toast.show(_humanizeGuardian(e, l10n));
    }
  }

  Future<void> _removeGuardian(ChatUser guardian) async {
    final l10n = AppLocalizations.of(context);
    final isMe = guardian.id == widget.guardianId;
    final name = isMe ? l10n.childPolicyScreenYou : guardian.displayName;
    final ok = await showConfirmSheet(
      context,
      headline: isMe
          ? l10n.childPolicyScreenStopSupervisingHeadline
          : l10n.childPolicyScreenRemoveGuardianHeadline(
              guardian.displayName.toUpperCase(),
            ),
      body: isMe
          ? l10n.childPolicyScreenStopSupervisingBody(_child.user.displayName)
          : l10n.childPolicyScreenRemoveGuardianBody(
              _child.user.displayName,
              guardian.displayName,
            ),
      confirmLabel: isMe
          ? l10n.childPolicyScreenStopSupervisingCta
          : l10n.childPolicyScreenRemoveLabel,
    );
    if (!ok || !mounted) return;

    final toast = AppToast.of(context);
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
        toast.show(
          l10n.childPolicyScreenGuardianRemoved(name),
          tone: ToastTone.success,
        );
      }
    } catch (e) {
      toast.show(_humanizeGuardian(e, l10n));
    }
  }

  String _humanizeGuardian(Object e, AppLocalizations l10n) {
    final s = e.toString();
    if (s.contains('LAST_GUARDIAN')) {
      return l10n.childPolicyScreenErrorLastGuardian;
    }
    if (s.contains('USER_NOT_FOUND')) {
      return l10n.childPolicyScreenErrorUserNotFound;
    }
    if (s.contains('CHILD_NOT_ALLOWED')) {
      return l10n.childPolicyScreenErrorChildNotAllowed;
    }
    if (s.contains('NOT_A_GUARDIAN')) {
      return l10n.childPolicyScreenErrorNotYours;
    }
    return l10n.childPolicyScreenErrorGenericGuardian;
  }

  // ── Danger zone ──────────────────────────────────────────────────────────

  Future<void> _graduate() async {
    final l10n = AppLocalizations.of(context);
    final password = await showAdaptiveSheet<String>(
      context,
      builder: (_) => _PromptSheet(
        heading: l10n.childPolicyScreenGraduateHeading(
          _child.user.displayName.toUpperCase(),
        ),
        blurb: l10n.childPolicyScreenGraduateBlurb,
        hint: l10n.childPolicyScreenGraduateHint,
        ctaLabel: l10n.childPolicyScreenGraduateCta,
        obscure: true,
        minLength: 8,
      ),
    );
    if (password == null || !mounted) return;

    final toast = AppToast.of(context);
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
      toast.show(
        l10n.childPolicyScreenGraduateFailed,
        tone: ToastTone.danger,
      );
    }
  }

  Future<void> _deleteChild() async {
    final l10n = AppLocalizations.of(context);
    final name = _child.user.displayName;
    final ok = await showConfirmSheet(
      context,
      headline: l10n.childPolicyScreenDeleteAccountHeadline(name.toUpperCase()),
      body: l10n.childPolicyScreenDeleteAccountBody,
      confirmLabel: l10n.childPolicyScreenDeleteForeverCta,
    );
    if (!ok || !mounted) return;

    final toast = AppToast.of(context);
    final nav = Navigator.of(context);
    try {
      await widget.api.deleteChildAccount(
        guardianId: widget.guardianId,
        childId: _child.user.id,
      );
      await widget.family.refresh();
      if (mounted) nav.pop();
    } catch (_) {
      toast.show(
        l10n.childPolicyScreenDeleteAccountFailed,
        tone: ToastTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final grants = _grants;
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
                          child: Icon(
                            Icons.arrow_back,
                            size: 20,
                            color: theme.inkSoft,
                          ),
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
                      padding: EdgeInsets.fromLTRB(
                        20,
                        4,
                        20,
                        edgeToEdgeBottom(context, 40),
                      ),
                      children: [
                        _SectionHeader(
                          l10n.childPolicyScreenSectionWhatTheyCanDo,
                        ),
                        const SizedBox(height: 12),
                        // Public rooms used to be a toggle here. It is now fixed
                        // off for every kid and cannot be switched on, so it is a
                        // statement rather than a control — but it still has to
                        // be SAID. A guardian who saw the switch before would
                        // otherwise assume the setting was lost or reset, and one
                        // who never did deserves to know the limit exists.
                        _FixedNote(
                          label: l10n.childPolicyScreenPublicRoomsLabel,
                          body: l10n.childPolicyScreenPublicRoomsBody,
                        ),
                        const SizedBox(height: 10),
                        _Toggle(
                          label: l10n.childPolicyScreenAskToAddLabel,
                          on: _policy.canRequestContacts,
                          onDesc: l10n.childPolicyScreenAskToAddOnDesc,
                          offDesc: l10n.childPolicyScreenAskToAddOffDesc,
                          onChanged: (v) => _set(canRequestContacts: v),
                        ),
                        const SizedBox(height: 10),
                        _Toggle(
                          label: l10n.childPolicyScreenCallsLabel,
                          on: _policy.callsEnabled,
                          onDesc: l10n.childPolicyScreenCallsOnDesc,
                          offDesc: l10n.childPolicyScreenCallsOffDesc,
                          onChanged: (v) => _set(callsEnabled: v),
                        ),
                        const SizedBox(height: 10),
                        _Toggle(
                          label: l10n.childPolicyScreenMediaLabel,
                          on: _policy.mediaEnabled,
                          onDesc: l10n.childPolicyScreenMediaOnDesc,
                          offDesc: l10n.childPolicyScreenMediaOffDesc,
                          onChanged: (v) => _set(mediaEnabled: v),
                        ),
                        const SizedBox(height: 10),
                        _Toggle(
                          label: l10n.childPolicyScreenCreateRoomsLabel,
                          on: _policy.canCreateRooms,
                          onDesc: l10n.childPolicyScreenCreateRoomsOnDesc,
                          offDesc: l10n.childPolicyScreenCreateRoomsOffDesc,
                          onChanged: (v) => _set(canCreateRooms: v),
                        ),
                        const SizedBox(height: 10),
                        // The only switch on this screen that starts OFF, and
                        // its own switch rather than part of MEDIA — see
                        // `LOCATION_POLICY_FLAG` in childGuard.ts. Allowing
                        // photos is not the same decision as allowing a child
                        // to tell a room where they physically are.
                        _Toggle(
                          label: l10n.childPolicyScreenLocationLabel,
                          on: _policy.locationSharingEnabled,
                          onDesc: l10n.childPolicyScreenLocationOnDesc,
                          offDesc: l10n.childPolicyScreenLocationOffDesc,
                          onChanged: (v) => _set(locationSharingEnabled: v),
                        ),

                        const SizedBox(height: 30),
                        _SectionHeader(
                          l10n.childPolicyScreenSectionPeopleAllowed,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.childPolicyScreenPeopleAllowedDesc,
                          style: theme.bodySoft,
                        ),
                        const SizedBox(height: 12),
                        if (grants == null)
                          _Placeholder(l10n.childPolicyScreenLoading)
                        else ...[
                          for (final c in grants.contacts)
                            _GrantRow(
                              title: c.user.displayName,
                              subtitle: '@${c.user.username} · ${c.stateLabel}',
                              leading: UserAvatar(
                                user: c.user,
                                size: 32,
                                api: widget.api,
                              ),
                              onRevoke: () => _takeBack(c),
                            ),
                          // Two doors, on purpose. The picker is the one
                          // almost everyone wants — the person is already in
                          // your own friends, or one search away — and typing
                          // a handle stays for the case where they are
                          // neither, and for anyone who simply prefers it.
                          _AddByUsernameButton(
                            icon: Icons.person_search_outlined,
                            label: l10n.childPolicyScreenAddSomeoneLabel,
                            onTap: _addContactFromFriends,
                          ),
                          _AddByUsernameButton(onTap: _addContactByUsername),
                        ],

                        const SizedBox(height: 30),
                        _SectionHeader(
                          l10n.childPolicyScreenSectionRoomsAllowed,
                        ),
                        const SizedBox(height: 12),
                        if (grants == null)
                          _Placeholder(l10n.childPolicyScreenLoading)
                        else ...[
                          if (grants.rooms.isEmpty)
                            _Placeholder(l10n.childPolicyScreenNoRoomsYet)
                          else
                            for (final r in grants.rooms)
                              _GrantRow(
                                title: r.name,
                                subtitle: l10n.childPolicyScreenRoomMemberCount(
                                  r.memberCount,
                                ),
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: theme.accentSoft,
                                    borderRadius: BorderRadius.circular(
                                      theme.radiusMd,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.tag,
                                    size: 13,
                                    color: theme.accent,
                                  ),
                                ),
                                onRevoke: () => _revokeRoom(r),
                              ),
                          // The section could only ever take rooms AWAY before
                          // this. See [_addRoom].
                          _AddByUsernameButton(
                            icon: Icons.add_circle_outline,
                            label: l10n.childPolicyScreenAddRoomLabel,
                            onTap: _addRoom,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          l10n.childPolicyScreenGrantsFooterNote,
                          style: theme.monoTiny.copyWith(color: theme.inkMuted),
                        ),

                        const SizedBox(height: 30),
                        _SectionHeader(l10n.childPolicyScreenSectionGrownUps),
                        const SizedBox(height: 12),
                        Text(
                          l10n.childPolicyScreenGrownUpsDesc,
                          style: theme.bodySoft,
                        ),
                        const SizedBox(height: 12),
                        for (final g in _child.guardians)
                          _GrantRow(
                            title: g.id == widget.guardianId
                                ? l10n.childPolicyScreenGuardianYouSuffix(
                                    g.displayName,
                                  )
                                : g.displayName,
                            subtitle: '@${g.username}',
                            leading: UserAvatar(
                              user: g,
                              size: 32,
                              api: widget.api,
                            ),
                            // The last grown-up standing can't step away — the
                            // account would be stranded with nobody able to
                            // re-adopt or delete it. Graduate or delete instead.
                            onRevoke: _child.isSoleGuardian
                                ? null
                                : () => _removeGuardian(g),
                            revokeLabel: g.id == widget.guardianId
                                ? l10n.childPolicyScreenStepAwayLabel
                                : l10n.childPolicyScreenRemoveLabel,
                          ),
                        _AddByUsernameButton(
                          label: l10n.childPolicyScreenAddGuardianHeading,
                          onTap: _addGuardian,
                        ),

                        const SizedBox(height: 30),
                        _SectionHeader(l10n.childPolicyScreenSectionWhenDone),
                        const SizedBox(height: 12),
                        if (_child.isSoleGuardian)
                          Text(
                            l10n.childPolicyScreenSoleGuardianNote(
                              _child.user.displayName,
                            ),
                            style: theme.bodySoft,
                          )
                        else
                          Text(
                            l10n.childPolicyScreenBothFinalNote,
                            style: theme.bodySoft,
                          ),
                        const SizedBox(height: 12),
                        _DangerAction(
                          label: l10n.childPolicyScreenGraduateDangerLabel,
                          detail: l10n.childPolicyScreenGraduateDangerDetail,
                          onTap: _graduate,
                        ),
                        const SizedBox(height: 10),
                        _DangerAction(
                          label: l10n.childPolicyScreenDeleteDangerLabel(
                            _child.user.displayName.toUpperCase(),
                          ),
                          detail: l10n.childPolicyScreenDeleteDangerDetail,
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
  const _AddByUsernameButton({required this.onTap, this.label, this.icon});
  final VoidCallback onTap;

  /// Null falls back to the default "ADD BY USERNAME" copy; callers that
  /// reuse this button for a different action (e.g. adding a grown-up, or
  /// opening one of the pickers) override it.
  final String? label;

  /// Likewise for the glyph — the same outline button now fronts four
  /// different actions, and four identical person-plus icons would make them
  /// indistinguishable at a glance.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final resolvedLabel =
        label ??
        AppLocalizations.of(context).childPolicyScreenAddByUsernameLabel;
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
            Icon(icon ?? Icons.person_add_alt, size: 14, color: theme.accent),
            const SizedBox(width: 8),
            Text(
              resolvedLabel,
              style: theme.label.copyWith(
                letterSpacing: 2.4,
                color: theme.accent,
              ),
            ),
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
    final l10n = AppLocalizations.of(context);
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
                  Text(
                    l10n.childPolicyScreenAllowSomeoneHeading,
                    style: theme.label.copyWith(
                      letterSpacing: 2.4,
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.childPolicyScreenAllowSomeoneBlurb(widget.childName),
                    style: theme.bodySoft,
                  ),
                  const SizedBox(height: 18),
                  ThemedInput(
                    controller: _username,
                    hint: l10n.childPolicyScreenUsernameHint,
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
                                Text(
                                  l10n.childPolicyScreenSendRequestNowLabel,
                                  style: theme.label,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _sendNow
                                      ? l10n.childPolicyScreenSendNowOnDesc
                                      : l10n.childPolicyScreenSendNowOffDesc,
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
                      child: Text(
                        l10n.childPolicyScreenAllowCta,
                        style: theme.label.copyWith(
                          color: theme.accentInk,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      alignment: Alignment.center,
                      child: Text(
                        l10n.childPolicyScreenCancelLabel,
                        style: theme.label.copyWith(color: theme.inkSoft),
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
    final l10n = AppLocalizations.of(context);
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
                  Text(
                    widget.heading,
                    style: theme.label.copyWith(
                      letterSpacing: 2.4,
                      color: theme.accent,
                    ),
                  ),
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
                    semanticLabel: l10n.childPolicyScreenCancelSemanticLabel,
                    radius: theme.radiusMd,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.childPolicyScreenCancelLabel,
                          style: theme.label.copyWith(color: theme.inkSoft),
                        ),
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
        Text(
          label,
          style: theme.label.copyWith(letterSpacing: 2.8, color: theme.accent),
        ),
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
              Text(
                AppLocalizations.of(context).childPolicyScreenLockedLabel,
                style: theme.label.copyWith(color: theme.inkMuted),
              ),
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
    this.revokeLabel,
  });

  final String title;
  final String subtitle;
  final Widget leading;

  /// Null renders the row without an action — used for the last remaining
  /// guardian, who isn't allowed to step away.
  final VoidCallback? onRevoke;

  /// Null falls back to the default "TAKE BACK" copy; callers that reuse
  /// this row for a different action (e.g. removing a grown-up) override it.
  final String? revokeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final resolvedRevokeLabel =
        revokeLabel ??
        AppLocalizations.of(context).childPolicyScreenTakeBackLabel;
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
                Text(title, style: theme.body, overflow: TextOverflow.ellipsis),
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
                child: Text(
                  resolvedRevokeLabel,
                  style: theme.label.copyWith(color: theme.danger),
                ),
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

// ─────────────────────────── the two pickers ───────────────────────────

/// Height of a picker sheet, as a fraction of the window.
///
/// Fixed rather than fitted to the list, for the same reason the chat list's
/// `+` sheet is: a box that shrinks as the filter narrows moves the rows out
/// from under the finger reaching for them. Tall enough that a real list is
/// worth scrolling, short enough that the sheet still reads as a sheet rather
/// than a page that arrived from the bottom. Shared by both pickers so they
/// open to the same size — two sheets reached from adjacent rows that differ
/// in height read as a glitch.
const double _pickerHeightFraction = 0.78;

/// Chrome shared by both pickers: the panel, the grabber, a heading, a blurb,
/// and a bounded body. Written once because the two sheets are the same
/// object with a different list in it, and because the padding arithmetic
/// below (keyboard, home indicator) is the kind that gets subtly wrong on the
/// second copy.
class _PickerShell extends StatelessWidget {
  const _PickerShell({
    required this.heading,
    required this.blurb,
    required this.child,
  });

  final String heading;
  final String blurb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final media = MediaQuery.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(theme.radiusLg),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: media.size.height * _pickerHeightFraction,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          // `viewInsets` and `padding` are never both non-zero — raising the
          // keyboard zeroes the second — so one expression covers a sheet at
          // rest and a sheet being typed into.
          12 + media.padding.bottom + media.viewInsets.bottom,
        ),
        child: DefaultTextStyle(
          style: theme.body,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrabber(),
              Text(
                heading,
                style: theme.label.copyWith(
                  letterSpacing: 2.4,
                  color: theme.accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(blurb, style: theme.bodySoft),
              const SizedBox(height: 16),
              // Flexible rather than Expanded so the heading and blurb above
              // are laid out first and the list takes what is left. The sheet
              // height itself is fixed on purpose — see [_pickerHeightFraction].
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Allow someone" — the guardian's own friends first, then anyone they can
/// find by searching.
///
/// Both halves matter and neither replaces the other. The friends list covers
/// the overwhelmingly common case (the person is already someone the PARENT
/// knows) with no typing and no chance of landing on a stranger with a
/// similar handle; the search covers the classmate's parent they have never
/// added. They are one box because they answer one question.
class _PickPersonSheet extends StatelessWidget {
  const _PickPersonSheet({
    required this.people,
    required this.api,
    required this.guardianId,
    required this.loading,
    required this.childName,
  });

  final List<ChatUser> people;
  final ChatApi api;
  final String guardianId;
  final bool loading;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _PickerShell(
      heading: l10n.childPolicyScreenAllowSomeoneHeading,
      blurb: l10n.childPolicyScreenAllowSomeoneBlurb(childName),
      child: loading
          ? _Placeholder(l10n.childPolicyScreenLoading)
          : PeoplePicker(
              people: people,
              api: api,
              hintText: l10n.childPolicyScreenPickPersonHint,
              emptyLabel: l10n.childPolicyScreenPickPersonEmpty,
              noMatchLabel: l10n.childPolicyScreenPickPersonNoMatch,
              localHeader: l10n.childPolicyScreenPickPersonFriendsHeader,
              remoteHeader: l10n.childPolicyScreenPickPersonEveryoneHeader,
              // The guardian's own search, run as the guardian — so their own
              // blocks apply and a child's restricted search rules do not.
              searchMore: (q) =>
                  api.searchUsers(query: q, currentUserId: guardianId),
              onPick: (u) => Navigator.of(context).pop(u),
            ),
    );
  }
}

/// "Add a room" — the guardian's own group rooms, filtered as they type.
///
/// No search beyond that list, and that is the safety argument rather than an
/// omission: a parent is vouching for the people in the room, and the only
/// rooms they can vouch for are the ones they are standing in. See
/// `grantableRooms` in backend/convex/family.ts, which does the same filtering
/// server-side so the client is never handed a roster it has no reason to see.
class _PickRoomSheet extends StatefulWidget {
  const _PickRoomSheet({
    required this.rooms,
    required this.loading,
    required this.childName,
  });

  final List<RoomBrief> rooms;
  final bool loading;
  final String childName;

  @override
  State<_PickRoomSheet> createState() => _PickRoomSheetState();
}

class _PickRoomSheetState extends State<_PickRoomSheet> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<RoomBrief> get _visible {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return widget.rooms;
    return widget.rooms
        .where((r) => r.name.toLowerCase().contains(needle))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final visible = _visible;
    final searching = _query.trim().isNotEmpty;
    return _PickerShell(
      heading: l10n.childPolicyScreenPickRoomHeading,
      blurb: l10n.childPolicyScreenPickRoomBlurb(widget.childName),
      child: widget.loading
          ? _Placeholder(l10n.childPolicyScreenLoading)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchField(
                  controller: _q,
                  hintText: l10n.childPolicyScreenPickRoomHint,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() => _query = ''),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Text(
                              searching
                                  ? l10n.childPolicyScreenPickRoomNoMatch
                                  : l10n.childPolicyScreenPickRoomEmpty,
                              style: theme.bodySoft,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.zero,
                          itemCount: visible.length,
                          itemBuilder: (_, i) {
                            final r = visible[i];
                            return _RoomTile(
                              key: ValueKey(r.id),
                              room: r,
                              onTap: () => Navigator.of(context).pop(r),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({super.key, required this.room, required this.onTap});

  final RoomBrief room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.accentSoft,
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.tag, size: 15, color: theme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.name,
                    style: theme.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.childPolicyScreenRoomMemberCount(room.memberCount),
                    style: theme.monoTiny,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
          ],
        ),
      ),
    );
  }
}
