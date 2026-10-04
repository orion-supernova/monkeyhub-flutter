import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/family.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/destructive_sheet.dart';
import '../widgets/people_picker.dart';
import '../widgets/search_field.dart';
import '../widgets/labeled_field.dart' show SheetTextField;
import '../widgets/password_field.dart';
import '../widgets/remove_contact_sheet.dart';
import '../widgets/user_avatar.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart'
    show SheetConfirm, SheetFrame, SheetGroup;

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
          : l10n.childPolicyScreenRemoveGuardianHeadline(guardian.displayName),
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
        heading: l10n.childPolicyScreenGraduateHeading(_child.user.displayName),
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
      headline: l10n.childPolicyScreenDeleteAccountHeadline(name),
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

  /// A switch flip with the tap a native switch gives; `Switch.adaptive` has
  /// none.
  ValueChanged<bool> _flip(void Function(bool) apply) => (v) {
        HapticFeedback.lightImpact();
        apply(v);
      };

  String _stateLabel(ChildContact c, AppLocalizations l10n) =>
      switch (c.state) {
        ChildContactState.allowedTalking =>
          l10n.childPolicyScreenContactStateAllowedTalking,
        ChildContactState.talking => l10n.childPolicyScreenContactStateTalking,
        ChildContactState.allowedNotAdded =>
          l10n.childPolicyScreenContactStateAllowedNotAdded,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grants = _grants;
    return IosPage(
      title: _child.user.displayName,
      children: [
        GroupedSection(
          header: l10n.childPolicyScreenSectionWhatTheyCanDo,
          children: [
            // Public rooms used to be a toggle here. It is now fixed off for
            // every kid and cannot be switched on, so it is a statement
            // rather than a control — but it still has to be SAID. A
            // guardian who saw the switch before would otherwise assume the
            // setting was lost or reset, and one who never did deserves to
            // know the limit exists.
            //
            // No disabled Switch on purpose. A greyed-out control still says
            // "this is a setting, and someone could turn it on"; the point
            // here is the opposite — so the row wears a lock and the word.
            GroupedRow(
              title: l10n.childPolicyScreenPublicRoomsLabel,
              subtitle: l10n.childPolicyScreenPublicRoomsBody,
              trailing: _LockedTag(label: l10n.childPolicyScreenLockedLabel),
            ),
            GroupedRow.toggle(
              title: l10n.childPolicyScreenAskToAddLabel,
              subtitle: _policy.canRequestContacts
                  ? l10n.childPolicyScreenAskToAddOnDesc
                  : l10n.childPolicyScreenAskToAddOffDesc,
              value: _policy.canRequestContacts,
              onChanged: _flip((v) => _set(canRequestContacts: v)),
            ),
            GroupedRow.toggle(
              title: l10n.childPolicyScreenCallsLabel,
              subtitle: _policy.callsEnabled
                  ? l10n.childPolicyScreenCallsOnDesc
                  : l10n.childPolicyScreenCallsOffDesc,
              value: _policy.callsEnabled,
              onChanged: _flip((v) => _set(callsEnabled: v)),
            ),
            GroupedRow.toggle(
              title: l10n.childPolicyScreenMediaLabel,
              subtitle: _policy.mediaEnabled
                  ? l10n.childPolicyScreenMediaOnDesc
                  : l10n.childPolicyScreenMediaOffDesc,
              value: _policy.mediaEnabled,
              onChanged: _flip((v) => _set(mediaEnabled: v)),
            ),
            GroupedRow.toggle(
              title: l10n.childPolicyScreenCreateRoomsLabel,
              subtitle: _policy.canCreateRooms
                  ? l10n.childPolicyScreenCreateRoomsOnDesc
                  : l10n.childPolicyScreenCreateRoomsOffDesc,
              value: _policy.canCreateRooms,
              onChanged: _flip((v) => _set(canCreateRooms: v)),
            ),
            // The only switch on this screen that starts OFF, and its own
            // switch rather than part of MEDIA — see `LOCATION_POLICY_FLAG`
            // in childGuard.ts. Allowing photos is not the same decision as
            // allowing a child to tell a room where they physically are.
            GroupedRow.toggle(
              title: l10n.childPolicyScreenLocationLabel,
              subtitle: _policy.locationSharingEnabled
                  ? l10n.childPolicyScreenLocationOnDesc
                  : l10n.childPolicyScreenLocationOffDesc,
              value: _policy.locationSharingEnabled,
              onChanged: _flip((v) => _set(locationSharingEnabled: v)),
            ),
          ],
        ),

        GroupedSection(
          header: l10n.childPolicyScreenSectionPeopleAllowed,
          footer: l10n.childPolicyScreenPeopleAllowedDesc,
          children: [
            if (grants == null)
              EmptyLine(l10n.childPolicyScreenLoading)
            else ...[
              for (final c in grants.contacts)
                PersonRow(
                  avatar: UserAvatar(user: c.user, size: 40, api: widget.api),
                  title: c.user.displayName,
                  // The state alone: it is what this row adds. Handle and
                  // state together ellipsized the state away ("@zeynep ·
                  // All…") at large text and in Turkish, and PersonRow's
                  // subtitle is one line. The labels are short for the same
                  // reason, and drop the "Allowed ·" the section header
                  // already says. The handle stays for VoiceOver.
                  subtitle: _stateLabel(c, l10n),
                  semanticLabel: '${c.user.displayName}, @${c.user.username}, '
                      '${_stateLabel(c, l10n)}',
                  trailing: RowPillButton(
                    label: l10n.childPolicyScreenTakeBackLabel,
                    destructive: true,
                    onTap: () => _takeBack(c),
                  ),
                ),
              // Two doors, on purpose. The picker is the one almost
              // everyone wants — the person is already in your own friends,
              // or one search away — and typing a handle stays for the case
              // where they are neither, and for anyone who simply prefers it.
              // Distinct glyphs, because the same row shape fronts four
              // different actions on this page.
              GroupedRow(
                title: l10n.childPolicyScreenAddSomeoneLabel,
                icon: CupertinoIcons.person_2_fill,
                chevron: false,
                onTap: _addContactFromFriends,
              ),
              GroupedRow(
                title: l10n.childPolicyScreenAddByUsernameLabel,
                icon: CupertinoIcons.at,
                chevron: false,
                onTap: _addContactByUsername,
              ),
            ],
          ],
        ),

        GroupedSection(
          header: l10n.childPolicyScreenSectionRoomsAllowed,
          footer: l10n.childPolicyScreenGrantsFooterNote,
          children: [
            if (grants == null)
              EmptyLine(l10n.childPolicyScreenLoading)
            else ...[
              if (grants.rooms.isEmpty)
                EmptyLine(l10n.childPolicyScreenNoRoomsYet)
              else
                for (final r in grants.rooms)
                  PersonRow(
                    avatar: const _RoomGlyph(),
                    title: r.name,
                    subtitle:
                        l10n.childPolicyScreenRoomMemberCount(r.memberCount),
                    trailing: RowPillButton(
                      label: l10n.childPolicyScreenTakeBackLabel,
                      destructive: true,
                      onTap: () => _revokeRoom(r),
                    ),
                  ),
              // The section could only ever take rooms AWAY before this. See
              // [_addRoom].
              GroupedRow(
                title: l10n.childPolicyScreenAddRoomLabel,
                icon: CupertinoIcons.plus,
                chevron: false,
                onTap: _addRoom,
              ),
            ],
          ],
        ),

        GroupedSection(
          header: l10n.childPolicyScreenSectionGrownUps,
          footer: l10n.childPolicyScreenGrownUpsDesc,
          children: [
            for (final g in _child.guardians)
              PersonRow(
                avatar: UserAvatar(user: g, size: 40, api: widget.api),
                title: g.id == widget.guardianId
                    ? l10n.childPolicyScreenGuardianYouSuffix(g.displayName)
                    : g.displayName,
                subtitle: '@${g.username}',
                // The last grown-up standing can't step away — the account
                // would be stranded with nobody able to re-adopt or delete
                // it. Graduate or delete instead.
                trailing: _child.isSoleGuardian
                    ? null
                    : RowPillButton(
                        label: g.id == widget.guardianId
                            ? l10n.childPolicyScreenStepAwayLabel
                            : l10n.childPolicyScreenRemoveLabel,
                        destructive: true,
                        onTap: () => _removeGuardian(g),
                      ),
              ),
            GroupedRow(
              title: l10n.childPolicyScreenAddGuardianHeading,
              icon: CupertinoIcons.person_badge_plus_fill,
              chevron: false,
              onTap: _addGuardian,
            ),
          ],
        ),

        // Spelled out in full, with what each one costs underneath: these end
        // an account rather than trim a list, so they are heavier than the
        // inline "Take back" pills above.
        GroupedSection(
          header: l10n.childPolicyScreenSectionWhenDone,
          footer: _child.isSoleGuardian
              ? l10n.childPolicyScreenSoleGuardianNote(_child.user.displayName)
              : l10n.childPolicyScreenBothFinalNote,
          children: [
            GroupedRow(
              title: l10n.childPolicyScreenGraduateDangerLabel,
              subtitle: l10n.childPolicyScreenGraduateDangerDetail,
              destructive: true,
              onTap: _graduate,
            ),
            GroupedRow(
              title: l10n.childPolicyScreenDeleteDangerLabel(
                _child.user.displayName,
              ),
              subtitle: l10n.childPolicyScreenDeleteDangerDetail,
              destructive: true,
              onTap: _deleteChild,
            ),
          ],
        ),
      ],
    );
  }
}

/// What the add-by-username sheet hands back.
class _AddContactResult {
  const _AddContactResult(this.username, this.sendNow);
  final String username;
  final bool sendNow;
}

/// The trailing "🔒 Locked" of a rule that is stated rather than offered.
class _LockedTag extends StatelessWidget {
  const _LockedTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.lock_fill, size: 13, color: theme.inkMuted),
        const SizedBox(width: 3),
        Text(label, style: groupedMetaStyle(theme)),
      ],
    );
  }
}

/// A room's stand-in avatar: the # on a quiet rounded tile, at the 40pt a
/// [PersonRow] expects.
class _RoomGlyph extends StatelessWidget {
  const _RoomGlyph();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: quietFill(theme),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      alignment: Alignment.center,
      child: Icon(CupertinoIcons.number, size: 18, color: theme.accent),
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
  void initState() {
    super.initState();
    // The ✓ wakes up as soon as there is something to submit.
    _username.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  bool get _valid => _username.text.trim().isNotEmpty;

  void _submit() {
    final u = _username.text.trim();
    if (u.isEmpty) return;
    Navigator.of(context).pop(_AddContactResult(u, _sendNow));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SheetFrame(
      title: l10n.childPolicyScreenAllowSomeoneHeading,
      confirm: SheetConfirm(
        onTap: _valid ? _submit : null,
        label: l10n.childPolicyScreenAllowCta,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.childPolicyScreenAllowSomeoneBlurb(widget.childName),
            style: groupedFooterStyle(theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SheetTextField(
            controller: _username,
            hint: l10n.childPolicyScreenUsernameHint,
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          SheetGroup(
            children: [
              GroupedRow.toggle(
                title: l10n.childPolicyScreenSendRequestNowLabel,
                subtitle: _sendNow
                    ? l10n.childPolicyScreenSendNowOnDesc
                    : l10n.childPolicyScreenSendNowOffDesc,
                value: _sendNow,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _sendNow = v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One-field sheet: a title, a line of explanation, an input, the ✓.
///
/// Same chrome as [_AddContactSheet] above, which is the reason it exists —
/// adding a grown-up and setting a graduation password are both "type one
/// thing and confirm", and three near-identical copies of that layout would
/// drift.
///
/// Pops the trimmed value, or null on ×. [minLength] gates the ✓.
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
    return SheetFrame(
      title: widget.heading,
      confirm: SheetConfirm(
        onTap: _valid ? _submit : null,
        label: widget.ctaLabel,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.blurb,
            style: groupedFooterStyle(theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Obscured prompts are passwords (the graduate-child flow), so they
          // get the show/hide toggle; plain prompts stay a bare input.
          if (widget.obscure)
            PasswordField(
              controller: _value,
              hint: widget.hint,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            )
          else
            SheetTextField(
              controller: _value,
              hint: widget.hint,
              autofocus: true,
              keyboardType: TextInputType.visiblePassword,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
        ],
      ),
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

/// Chrome shared by both pickers: the standard sheet with its title in the
/// bar, a blurb, and a bounded body. Written once because the two sheets are
/// the same object with a different list in it.
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
    return SheetFrame(
      title: heading,
      maxHeightFraction: _pickerHeightFraction,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            blurb,
            style: groupedFooterStyle(theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          // The list takes what is left under the blurb. The sheet height
          // itself is fixed on purpose — see [_pickerHeightFraction].
          Expanded(child: child),
        ],
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
          ? Align(
              alignment: Alignment.topCenter,
              child: EmptyLine(l10n.childPolicyScreenLoading),
            )
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
    final l10n = AppLocalizations.of(context);
    final visible = _visible;
    final searching = _query.trim().isNotEmpty;
    return _PickerShell(
      heading: l10n.childPolicyScreenPickRoomHeading,
      blurb: l10n.childPolicyScreenPickRoomBlurb(widget.childName),
      child: widget.loading
          ? Align(
              alignment: Alignment.topCenter,
              child: EmptyLine(l10n.childPolicyScreenLoading),
            )
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
                      ? Align(
                          alignment: Alignment.topCenter,
                          child: EmptyLine(
                            searching
                                ? l10n.childPolicyScreenPickRoomNoMatch
                                : l10n.childPolicyScreenPickRoomEmpty,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 30,
                            ),
                          ),
                        )
                      // Bare rows, no plate: the person picker in this same
                      // shell is the shared PeoplePicker, which lists bare
                      // rows, and the two pickers should read as one.
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.zero,
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final r = visible[i];
                            return PersonRow(
                              key: ValueKey(r.id),
                              avatar: const _RoomGlyph(),
                              title: r.name,
                              subtitle: l10n.childPolicyScreenRoomMemberCount(
                                r.memberCount,
                              ),
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
