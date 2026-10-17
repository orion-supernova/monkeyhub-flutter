import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/recovery_phrase.dart';
import '../auth/social_sign_in.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/username_availability_controller.dart';
import '../family/family_service.dart';
import '../models/family.dart' show RequestStage;
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/file_url_cache.dart';
import '../media/image_raster.dart';
import '../media/photo_picking.dart';
import '../media/upload_service.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../platform.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/block_choice_sheet.dart';
import '../widgets/destructive_sheet.dart' show showConfirmSheet;
import '../widgets/ios_kit.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_prompt_sheet.dart';
import '../widgets/recovery_banner.dart';
import '../widgets/sheet_kit.dart';
import '../widgets/social_sign_in_buttons.dart';
import '../widgets/report_sheet.dart';
import '../widgets/steady_hero.dart';
import '../widgets/user_avatar.dart';
import '../widgets/username_status_label.dart';
import 'approvals_screen.dart';
import 'blocked_users_screen.dart';
import 'recovery_phrase_screen.dart';
import 'camera_screen.dart';
import 'device_login_scan_screen.dart';
import 'devices_screen.dart';
import 'family_screen.dart';
import 'friend_request_draft_screen.dart';
import 'fullscreen_image_viewer.dart';
import 'image_crop_screen.dart';
import 'profile_visibility_screen.dart';
import 'release_device_screen.dart';
import 'linked_accounts_screen.dart';
import 'navigation/open_room.dart';
import '../backend/server_limits.dart';

/// Profile screen.
///
/// Pass [repo] + [api] to enable interactive actions (edit own profile,
/// send/cancel friend requests, open DM). If both are null this renders a
/// read-only view (used as a Phase-1 fallback).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    this.repo,
    this.api,
    this.auth,
    this.family,
  });
  final ChatUser user;
  final ChatRepository? repo;
  final ChatApi? api;

  /// When provided AND viewing one's own profile, an ACCOUNT section
  /// (family / linked accounts / recovery phrase / sign out / delete) is
  /// exposed at the bottom.
  final AuthService? auth;

  /// Enables the family rows inside that ACCOUNT section. Who looks after whom
  /// is an account fact, not a preference, so it lives here rather than up in
  /// Settings among the themes and bubble shapes. Passed by the two entry
  /// points that open your OWN profile — the Settings card and the chat list's
  /// header avatar. Every other one opens somebody else's, which has no ACCOUNT
  /// section at all.
  final FamilyService? family;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _avatarSize = 104;

  /// How far the camera badge used to poke past the avatar's edge. Kept so the
  /// badge lands on the same pixels now that it is positioned from a box that
  /// is [_badgeOverhang] larger instead of at a negative offset.
  static const double _badgeOverhang = 2;

  ChatUser? _user;
  bool _loading = false;
  bool _busy = false;
  bool _changingAvatar = false;
  bool _signingOut = false;
  bool _deletingAccount = false;

  bool get _isMe => widget.repo?.userId == widget.user.id;
  ChatUser get _u => _user ?? widget.user;

  /// When the handle comes out of its cooldown, or null when it is free now.
  ///
  /// Derived rather than stored so it stays honest across a screen left open
  /// overnight, and computed from the same thirty days the backend enforces —
  /// this is a courtesy, not the rule.
  DateTime? get _usernameUnlocksAt {
    final changed = _u.usernameChangedAt;
    if (changed == null) return null;
    final unlocks = changed.add(const Duration(days: 30));
    return unlocks.isAfter(DateTime.now()) ? unlocks : null;
  }

  /// Whether this profile is one whose handle its owner may change — ignoring,
  /// for the moment, whether the cooldown happens to be running.
  ///
  /// A child is excluded here as well as server-side: their handle is how a
  /// guardian finds them, and an affordance that always throws is worse than
  /// no affordance.
  bool get _usernameIsMineToChange =>
      _isMe &&
      widget.api != null &&
      widget.repo != null &&
      widget.auth != null &&
      !_u.isChild;

  /// Whether to offer the rename right now.
  bool get _canRenameUsername =>
      _usernameIsMineToChange && _usernameUnlocksAt == null;

  /// Whether to explain why it is not being offered.
  ///
  /// Gated on [_usernameIsMineToChange] rather than on the date alone: the
  /// backend only ever sends `usernameChangedAt` on a self-view, but a lock
  /// notice hanging under a STRANGER'S handle would be nonsense if it ever did
  /// arrive, and a child would be told to wait for something they are never
  /// going to be offered.
  bool get _showsUsernameLock =>
      _usernameIsMineToChange && _usernameUnlocksAt != null;

  @override
  void initState() {
    super.initState();
    // Eagerly resolve friendship from the repo so the first frame is correct
    // (chat-context entry points like getMembers don't compute it).
    final resolved = _resolveFriendship(widget.user.id);
    _user = widget.user.copyWith(
      friendshipStatus: resolved.status,
      requestId: resolved.requestId,
      awaitingGuardian: resolved.held,
    );
    // The account type can change underneath an open profile: a guardian
    // graduating this child from their own phone lands over the live family
    // subscription. Everything on the me-view keys off it — the ACCOUNT
    // section, whether visibility is read-only, whether "hand this phone back"
    // is offered — so repaint rather than leaving the supervised UI up.
    widget.auth?.addListener(_onAuth);
    // The friendship itself can change underneath an open profile too, and
    // from the other person's phone: they accept, they decline, they withdraw.
    // All three land over the repository's live request/friend subscriptions,
    // so re-resolve rather than leaving "REQUEST PENDING" up forever.
    widget.repo?.addListener(_onFriendship);
    // The family rows carry a live pending-approvals count, and approvals land
    // from the child's phone while this screen is open.
    widget.family?.addListener(_onAuth);
    widget.family?.refresh();
    _refresh();
    // Separate from _refresh: that one runs for anyone's profile, while linked
    // providers only exist on your own. It no-ops for a child or a stranger.
    _refreshLinkedProviders();
  }

  @override
  void dispose() {
    widget.auth?.removeListener(_onAuth);
    widget.family?.removeListener(_onAuth);
    widget.repo?.removeListener(_onFriendship);
    super.dispose();
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  void _onFriendship() {
    if (!mounted) return;
    final resolved = _resolveFriendship(widget.user.id);
    // The hold is compared too, not just the status. A guardian releasing a
    // request changes only the stage — the status stays `outgoingPending` —
    // and bailing out on an unchanged status left the button inert until the
    // screen was reopened.
    final held = resolved.held ?? _u.awaitingGuardian;
    if (resolved.status == _u.friendshipStatus && held == _u.awaitingGuardian) {
      return;
    }
    setState(() {
      _user = _u.copyWith(
        friendshipStatus: resolved.status,
        requestId: resolved.requestId,
        awaitingGuardian: held,
      );
    });
  }

  Future<void> _refresh() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final fresh = await api.getProfile(widget.user.id, viewerUserId: widget.repo?.userId);
      if (!mounted || fresh == null) return;
      // users.getProfile doesn't include friendshipStatus. Resolve it from
      // the repo's live caches (friends + pending requests) instead of
      // trusting the passed-in widget.user — that value is stale when the
      // profile is opened from a chat context (member list, message bubble,
      // DM header) where getMembers didn't compute it.
      final resolved = _resolveFriendship(widget.user.id);
      setState(() {
        _user = fresh.copyWith(
          friendshipStatus: resolved.status,
          requestId: resolved.requestId,
          // Null keeps what the fetch said — the only source that can see an
          // unreleased incoming request. See [_resolveFriendship].
          awaitingGuardian: resolved.held,
        );
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Friendship as the repository's live lists see it, plus whether the
  /// viewer's own grown-up is still holding it.
  ///
  /// `held` is null for "the lists can't say" — which is the `none` case, and
  /// exactly the case that matters: an unreleased INCOMING request is filtered
  /// out server-side, so the repo reports `none` for a relationship that very
  /// much exists. The caller keeps whatever `users:getProfile` said there,
  /// since that is the only source that can see it.
  ///
  /// Everywhere else the lists are authoritative and beat the fetched flag,
  /// which is what lets the button come alive the moment a guardian releases
  /// the request — the release arrives on these subscriptions, not on a
  /// re-fetch of the profile.
  ({FriendshipStatus status, String? requestId, bool? held})
      _resolveFriendship(String userId) {
    final repo = widget.repo;
    if (repo == null) {
      return (
        status: widget.user.friendshipStatus,
        requestId: widget.user.requestId,
        held: null,
      );
    }
    if (repo.friends.any((f) => f.id == userId)) {
      return (status: FriendshipStatus.friend, requestId: null, held: false);
    }
    final outgoing = repo.outgoingRequests.where((r) => r.user.id == userId).firstOrNull;
    if (outgoing != null) {
      // `listOutgoingDirectRequests` does NOT filter by stage — a child sees
      // their own request while their grown-up still has it — so the stage on
      // the row is what decides, not the row's presence.
      return (
        status: FriendshipStatus.outgoingPending,
        requestId: outgoing.id,
        held: outgoing.stage == RequestStage.senderGuardian,
      );
    }
    final incoming = repo.incomingRequests.where((r) => r.user.id == userId).firstOrNull;
    if (incoming != null) {
      // Released by construction: `listIncomingDirectRequests` drops anything
      // a guardian still holds.
      return (
        status: FriendshipStatus.incomingPending,
        requestId: incoming.id,
        held: false,
      );
    }
    return (status: FriendshipStatus.none, requestId: null, held: null);
  }

  Future<void> _updateName(String next) async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo == null) return;
    final id = repo.userId;
    if (id == null) return;
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await api.updateProfile(
        userId: id,
        name: next.trim().isEmpty ? widget.user.username : next.trim(),
        // Deliberately omitted, NOT echoed back. `email` is now stripped from
        // friend lists and room member lists, so a self-profile opened from
        // one of those has `_u.email == null` until _refresh() lands — and
        // sending an empty string is how the backend is told to DELETE it.
        // An absent email leaves the stored one untouched.
      );
      await _refresh();
    } catch (e) {
      // This used to swallow everything, which was survivable while the only
      // failure was a dropped connection: _refresh() puts the old name back and
      // the user retries. It stopped being survivable when the name could be
      // REFUSED — a reserved brand term now returns DISPLAY_NAME_RESERVED, and
      // silently reverting the field tells the user their typing did not
      // register rather than that the name is not allowed.
      toast.show(
        humanizeAuthError(e, l10n, fallback: l10n.profileScreenNameNotSaved),
        tone: ToastTone.danger,
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Changes the handle, after proving the account belongs to whoever is
  /// holding the phone.
  ///
  /// The proof is collected BEFORE anything is sent, and which proof depends on
  /// how this account signs in: a password if it has one, a fresh run of the
  /// Apple/Google sheet if it does not. `hasPassword == null` means the backend
  /// did not say — an older deploy, or a fetch that was not a self-view — and
  /// that is treated as "has one", because a password prompt the user cannot
  /// satisfy is a far better failure than a rename attempted with no proof.
  Future<void> _updateUsername(String next) async {
    // `auth` owns the call and the session write; `api` and `repo` are what
    // `_refresh` needs afterwards, so all three have to be here before starting.
    final auth = widget.auth;
    if (auth == null || widget.api == null || widget.repo == null) return;

    final trimmed = next.trim();
    // Unchanged is not an error and must not reach the server: the backend
    // treats it as a no-op precisely so it doesn't spend the thirty days, and
    // there is nothing to tell the user about either way.
    if (trimmed.isEmpty || trimmed == _u.username) return;

    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);

    SocialCredential? credential;
    String? password;
    if (_u.hasPassword == false) {
      final provider = await _pickRenameProvider();
      if (provider == null || !mounted) return;
      try {
        // Without this the SDK hands back the last account silently, and the
        // "proof" becomes a token the user never re-authorised.
        await SocialSignIn.forgetProviders();
        credential = await SocialSignIn.forProvider(provider);
      } on SocialSignInCancelled {
        // Backing out of the provider sheet is a decision, not a failure.
        return;
      } catch (e) {
        if (!mounted) return;
        toast.show(
          humanizeAuthError(
            e,
            l10n,
            fallback: l10n.profileScreenUsernameNotSaved,
          ),
          tone: ToastTone.danger,
        );
        return;
      }
    } else {
      password = await askPassword(
        context,
        title: l10n.profileScreenUsernamePasswordTitle,
        actionLabel: l10n.profileScreenUsernamePasswordAction,
      );
      if (password == null || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      // The server's normalisation wins — it is what the session and the
      // keychain now hold, so it is what the confirmation should say.
      final settled = credential != null
          ? await auth.changeUsernameWithProvider(
              credential: credential, username: trimmed)
          : await auth.changeUsername(password: password!, username: trimmed);
      await _refresh();
      if (!mounted) return;
      toast.show(
        l10n.profileScreenUsernameChanged(settled),
        tone: ToastTone.success,
      );
    } catch (e) {
      // Never swallowed. Every refusal here — taken, reserved, too soon, wrong
      // password — is something the user can act on, and a silent revert would
      // read as "your typing didn't register".
      toast.show(
        humanizeAuthError(e, l10n, fallback: l10n.profileScreenUsernameNotSaved),
        tone: ToastTone.danger,
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Which provider to re-authorise with.
  ///
  /// Skips the sheet entirely at one linked provider, which is the ordinary
  /// case — asking someone to choose from a list of one is a tap for nothing.
  /// Except where that one provider can only start from its own button (Google
  /// on the web), when the sheet is the only place the sign-in can begin.
  /// Falls back to whatever the platform offers if the linked list hasn't
  /// landed yet; the backend checks the resolved identity against this account
  /// regardless, so a wrong guess here is refused rather than obeyed.
  Future<SocialProvider?> _pickRenameProvider() async {
    final linked = _linkedProviders?.isNotEmpty == true
        ? _linkedProviders!
        : SocialSignInButtons.available;
    if (linked.isEmpty) return null;
    if (linked.length == 1 && !SocialSignIn.needsButtonTap(linked.first)) {
      return linked.first;
    }
    return showAdaptiveSheet<SocialProvider>(
      context,
      builder: (_) => _RenameProviderSheet(providers: linked),
    );
  }

  /// Mints a new recovery phrase and, if the user saves it, replaces the one
  /// on the account.
  ///
  /// Dismissible: the existing phrase stays valid right up until the commit
  /// succeeds, so backing out costs the user nothing. The screen collects the
  /// password itself — `auth.setRecoveryKey` requires it, because planting a
  /// phrase on an account is a takeover primitive.
  Future<void> _openRecoveryPhrase() async {
    final auth = widget.auth;
    if (auth == null || auth.isChild) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecoveryPhraseScreen(
          phrase: RecoveryPhrase.generate(),
          mode: RecoveryGateMode.rotate,
          dismissible: true,
          onCommit: (password, hash) =>
              auth.setRecoveryKey(password: password, recoveryKeyHash: hash),
        ),
      ),
    );
    // Refresh so hasRecoveryKey flips and the banner clears.
    if (saved == true && mounted) await _refresh();
  }

  /// Providers currently attached to this account. Only ever used to summarise
  /// the LINKED ACCOUNTS row — the linking itself lives on
  /// [LinkedAccountsScreen]. Null while unknown, so the row can say nothing
  /// rather than claim "nothing linked" before the first answer arrives.
  List<SocialProvider>? _linkedProviders;

  /// What the LINKED ACCOUNTS row shows on the right.
  String get _linkedAccountsLabel {
    final linked = _linkedProviders;
    if (linked == null) return '';
    if (linked.isEmpty) return AppLocalizations.of(context).profileScreenLinkedAccountsNone;
    // Brand names as the brands write them — "Apple · Google", never
    // lowercased for the sake of a quiet value.
    return linked.map((p) => p.label).join(' · ');
  }

  String get _familyLabel {
    final n = widget.family?.context.children.length ?? 0;
    if (n == 0) return AppLocalizations.of(context).profileScreenFamilyAddChild;
    return AppLocalizations.of(context).profileScreenFamilyChildCount(n);
  }

  void _openFamily() {
    final family = widget.family;
    final id = widget.api == null ? null : widget.repo?.userId;
    if (family == null || id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyScreen(api: widget.api!, userId: id, family: family),
      ),
    );
  }

  void _openApprovals() {
    final family = widget.family;
    final id = widget.api == null ? null : widget.repo?.userId;
    if (family == null || id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ApprovalsScreen(api: widget.api!, guardianId: id, family: family),
      ),
    );
  }

  Future<void> _refreshLinkedProviders() async {
    final auth = widget.auth;
    // `_isMe` matters as much as the auth checks: this screen also renders other
    // people's profiles, and linked providers are only ever your own — fetching
    // there would be a pointless round trip behind a section that never draws.
    if (!_isMe || auth == null || auth.isChild || !auth.isSignedIn) return;
    try {
      final linked = await auth.linkedProviders();
      if (mounted) setState(() => _linkedProviders = linked);
    } catch (_) {
      // Offline or an older backend. Leaving it null keeps the section hidden,
      // which is the right failure: an empty list would claim "nothing linked"
      // and invite a duplicate link attempt that the backend would reject.
    }
  }

  /// Opens the linked-accounts screen, then re-reads what came back from it.
  /// That screen owns the linking; this row only ever summarises it.
  Future<void> _openLinkedAccounts() async {
    final auth = widget.auth;
    if (auth == null || auth.isChild) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LinkedAccountsScreen(auth: auth)),
    );
    await _refreshLinkedProviders();
  }

  /// Opens the list of devices this account has signed in on.
  ///
  /// Above the scan row on purpose: "what is signed in?" is the question
  /// someone arrives with, and "approve another device" is the one they leave
  /// with. A child device is excluded for the same reason it cannot approve a
  /// sign-in — it does not administer the account supervising it.
  void _openDevices() {
    final auth = widget.auth;
    final api = widget.api;
    if (auth == null || api == null || auth.isChild) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DevicesScreen(auth: auth, api: api)),
    );
  }

  /// Opens the phone-side scan-and-approve screen for a desktop/web
  /// device-login request. Nothing to refresh afterwards — approving one
  /// signs in a DIFFERENT device, not this one.
  void _openDeviceLoginScan() {
    final auth = widget.auth;
    if (auth == null || auth.isChild) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DeviceLoginScanScreen(auth: auth)),
    );
  }

  Future<void> _updateEmail(String next) async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo == null) return;
    final id = repo.userId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await api.updateProfile(userId: id, name: _u.name, email: next.trim());
      await _refresh();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the edit sheet — behind a warning first only when [confirmBody]
  /// has something to warn about.
  ///
  /// Only the username has one. Name and email are reversible in one tap and
  /// need no explanation, so they go straight to the sheet: a bare "Edit
  /// name? / Not now / Change" gate in front of them made every edit a
  /// double confirmation for nothing. A handle change moves the login
  /// credential, releases the old name and locks the field for a month, and
  /// none of that is guessable from a title reading "change username?".
  Future<void> _confirmAndEdit({
    required String title,
    required String currentValue,
    required String hint,
    required Future<void> Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
    String? confirmBody,
    bool checksAvailability = false,
  }) async {
    if (confirmBody != null) {
      final l10n = AppLocalizations.of(context);
      final ok = await showIosAlert<bool>(
        context,
        title: title,
        message: confirmBody,
        actions: [
          IosAlertAction(label: l10n.acctNotNow, value: false, cancel: true),
          IosAlertAction(label: l10n.acctChange, value: true, preferred: true),
        ],
      );
      if (ok != true || !mounted) return;
    }
    await _editFieldSheet(
      title: title,
      currentValue: currentValue,
      hint: hint,
      onSave: onSave,
      keyboardType: keyboardType,
      checksAvailability: checksAvailability,
    );
  }

  Future<void> _editFieldSheet({
    required String title,
    required String currentValue,
    required String hint,
    required Future<void> Function(String) onSave,
    required TextInputType keyboardType,
    bool checksAvailability = false,
  }) async {
    final api = widget.api;
    final next = await showAdaptiveSheet<String>(
      context,
      builder: (ctx) => _EditFieldSheet(
        title: title,
        currentValue: currentValue,
        hint: hint,
        keyboardType: keyboardType,
        // Seeded with the handle the field opens with, so the sheet does not
        // greet the user by calling their own name taken; and excluding their
        // own row, so typing a case variant of it comes back free.
        availability: checksAvailability && api != null
            ? UsernameAvailabilityController(
                api: api,
                excludeUserId: widget.repo?.userId,
                initialValue: currentValue,
              )
            : null,
      ),
    );
    if (next == null) return;
    await onSave(next);
  }

  Future<void> _signOut() async {
    final auth = widget.auth;
    if (auth == null || _busy) return;
    // Asked first, as iOS does: one stray tap at the bottom of a long page
    // shouldn't cost someone their session on this device.
    final l10n = AppLocalizations.of(context);
    final go = await showIosActionSheet<bool>(
      context,
      title: l10n.profileScreenSignOutConfirmTitle,
      actions: [
        IosSheetAction(label: l10n.acctSignOut, value: true, destructive: true),
      ],
    );
    if (go != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _signingOut = true;
    });
    final nav = Navigator.of(context);
    try {
      await auth.signOut();
      if (!mounted) return;
      // Pop everything stacked above the home route. The home route is the
      // auth-reactive `_AppHome` in app.dart — once `auth.signOut()` flips
      // `isSignedIn` to false, that home rebuilds to `LoginScreen` on its
      // own. Pushing a fresh `LoginScreen` here would stack a second copy
      // on top of `_AppHome`, so the next `signIn` swap (which happens
      // inside `_AppHome`) would be hidden under that stacked route.
      nav.popUntil((r) => r.isFirst);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _signingOut = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    final auth = widget.auth;
    if (auth == null || _busy) return;
    // The shared destructive confirm, which also says it cannot be undone.
    // It replaced a "tap again within 4s" label swap that no other screen
    // used and that a second accidental tap could satisfy.
    final confirmL10n = AppLocalizations.of(context);
    final ok = await showConfirmSheet(
      context,
      headline: confirmL10n.profileScreenDeleteAccountConfirmTitle,
      body: confirmL10n.profileScreenDeleteAccountConfirmBody,
      confirmLabel: confirmL10n.acctDeleteAccount,
    );
    if (!ok || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _deletingAccount = true;
    });
    final nav = Navigator.of(context);
    // Both captured before the await: the toast because `AppToast.of` wants a
    // context that is still mounted, and l10n for the same reason.
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await auth.deleteAccount();
      if (!mounted) return;
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      // The local teardown ran regardless — `deleteAccount` does it in a
      // `finally` — so this device is signed out whatever happened. What is
      // genuinely unknown is the SERVER's half: the mutation may have
      // committed before the connection died, or never run at all. Saying so
      // beats the silence this used to keep, which let someone walk away
      // believing an account was deleted when it might not have been.
      debugPrint('[profile] deleteAccount failed: $e');
      if (!mounted) return;
      toast.show(l10n.profileScreenDeleteAccountFailed, tone: ToastTone.danger);
      nav.popUntil((r) => r.isFirst);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _deletingAccount = false;
        });
      }
    }
  }

  Future<void> _friendshipAction() async {
    final repo = widget.repo;
    final api = widget.api;
    if (repo == null || api == null) return;
    final nav = Navigator.of(context);
    final toast = AppToast.of(context);
    setState(() => _busy = true);
    try {
      if (_heldByGrownUp) return;
      switch (_u.friendshipStatus) {
        case FriendshipStatus.none:
          if (!mounted) return;
          nav.push(
            MaterialPageRoute(
              builder: (_) => FriendRequestDraftScreen(repo: repo, api: api, target: _u),
            ),
          );
          break;
        case FriendshipStatus.outgoingPending:
          await repo.cancelDirectRequest(_u.id);
          break;
        case FriendshipStatus.incomingPending:
          final roomId = await repo.approveDirectRequest(_u.id);
          if (!mounted) return;
          if (roomId != null) {
            openRoom(context, roomId: roomId, repo: repo, api: api);
          }
          break;
        case FriendshipStatus.friend:
          final roomId = await repo.openDmWith(_u);
          if (!mounted) return;
          openRoom(context, roomId: roomId, repo: repo, api: api);
          break;
      }
    } catch (e) {
      toast.show(_humanizeAction(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Surfaces a friendly, privacy-preserving message for the actions on this
  /// screen. Critically: never reveals that the *other* user has blocked us
  /// (block stays under USER_NOT_FOUND). Not-accepting-requests IS its own
  /// honest code — it's a global toggle, not a personal judgment, and the
  /// SEND REQUEST button is already pre-disabled when we know about it.
  String _humanizeAction(Object e) {
    final l10n = AppLocalizations.of(context);
    final s = e.toString();
    if (s.contains('UNBLOCK_FIRST')) {
      return l10n.profileScreenErrorUnblockFirst;
    }
    if (s.contains('NOT_ACCEPTING_REQUESTS')) {
      return l10n.profileScreenErrorNotAccepting;
    }
    if (s.contains('USER_NOT_FOUND')) return l10n.profileScreenErrorUserNotFound;
    if (s.contains('ALREADY_FRIENDS')) return l10n.profileScreenErrorAlreadyFriends;
    if (s.contains('REQUEST_ALREADY_PENDING')) return l10n.profileScreenErrorRequestAlreadySent;
    if (s.contains('REQUEST_ALREADY_RECEIVED')) {
      return l10n.profileScreenErrorRequestAlreadyReceived;
    }
    return l10n.profileScreenErrorGeneric;
  }

  /// A gradient-initials placeholder is not worth a fullscreen route, so the
  /// tap only arms once there is a real image behind it.
  bool get _canViewAvatar =>
      widget.api != null &&
      _u.avatarStorageId != null &&
      _u.avatarStorageId!.isNotEmpty;

  /// Tag shared with the [Hero] around the avatar below. Keyed on the user, not
  /// the storage id, so replacing your picture mid-session doesn't orphan it.
  String get _avatarHeroTag => 'profile-avatar-${_u.id}';

  void _openAvatarFullscreen() {
    if (!_canViewAvatar) return;
    FullscreenImageViewer.openAvatar(
      context,
      storageId: _u.avatarStorageId!,
      api: widget.api!,
      heroTag: _avatarHeroTag,
      sourceSize: _avatarSize,
    );
  }

  Future<void> _openAvatarSheet() async {
    final action = await showAvatarActionSheet(
      context,
      hasAvatar: _u.avatarStorageId != null && _u.avatarStorageId!.isNotEmpty,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case AvatarAction.download:
        await _downloadAvatar();
        break;
      case AvatarAction.capture:
        await _captureAndUploadAvatar();
        break;
      case AvatarAction.library:
        await _pickAndUploadAvatarFromLibrary();
        break;
    }
  }

  /// Take a new one. Opens on the front lens — you are photographing yourself —
  /// and the shutter goes straight to the circle crop.
  ///
  /// This used to go through `ImagePicker(source: camera)`, which presents
  /// iOS's own camera and its unskippable Retake / Use Photo step, so the user
  /// confirmed the same photograph twice: once for iOS, then again on the crop
  /// screen. Owning the preview removes the first of those, and lets the
  /// selfie be mirrored to match what the user was actually looking at.
  Future<void> _captureAndUploadAvatar() async {
    if (widget.api == null || widget.repo?.userId == null) return;
    setState(() {
      _busy = true;
      _changingAvatar = true;
    });
    final result = await CameraScreen.open<CroppedImage>(
      context,
      initialLens: CameraLensDirection.front,
      // The crop opens over the camera, so the shutter reads as the preview
      // becoming the picture rather than one screen dismissing and another
      // presenting. Never a retake: the cropper has no such button, and its
      // X means the same thing here as the editor's does in a chat — the user
      // is done, not asking for another go.
      review: (context, photo) async {
        final cropped = await ImageCropScreen.open(
          context,
          source: photo.bytes,
          shape: CropShape.circle,
          mirrored: photo.mirrored,
          overCamera: true,
        );
        return ReviewDone(cropped);
      },
    );
    if (!mounted) return;

    switch (result) {
      case CameraReviewed(:final value):
        await _uploadAvatar(value);
      case CameraRecorded():
      // Unreachable: this call site opens the camera with `allowVideo` left
      // off, so the VIDEO position never appears and nothing can record.
      // Named rather than defaulted so that turning video on here becomes a
      // compile error to answer rather than a clip silently dropped.
      break;
    case CameraPickLibrary():
        // The camera's own shortcut into the photo library. `_busy` is already
        // raised, and the library path re-raises it harmlessly.
        await _pickAndUploadAvatarFromLibrary();
      case CameraUnavailable():
        // The in-app camera could not start. Fall back to the system camera so
        // there is still a way to set a picture. Not mirrored: `image_picker`
        // never reports which lens fired, and we ask for the front one but
        // cannot stop the user flipping inside a UI we don't control.
        final picked = (await pickPhoto(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
        )).file;
        await _cropAndUploadAvatar(await picked?.readAsBytes());
      case null:
        await _uploadAvatar(null); // cancelled — clears the spinner
    }
  }

  Future<void> _pickAndUploadAvatarFromLibrary() async {
    if (widget.api == null || widget.repo?.userId == null) return;
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    // Spinner covers BOTH phases: picker spin-up (the native UI can take a beat
    // to appear on cold launch) and the upload itself. Clear it on cancel so
    // the avatar returns to normal immediately.
    setState(() {
      _busy = true;
      _changingAvatar = true;
    });
    // `pickerImageQuality`, which [pickPhoto] passes for us, also normalizes
    // EXIF orientation on Android, which the crop screen relies on — it stays
    // even though the crop re-encodes anyway.
    final pick = await pickPhoto(source: ImageSource.gallery);
    // A refusal is not a cancel, and the difference matters more here than
    // anywhere: the avatar has been spinning since the tap, and clearing it
    // with no word would read as "your picture was rejected".
    if (pick.unreadable && mounted) {
      toast.show(
        l10n.mediaPickFailedMessage,
        tone: ToastTone.danger,
      );
    }
    // Null on every path but a chosen photo, which `_cropAndUploadAvatar`
    // already treats as a cancel — and owns clearing the spinner for.
    await _cropAndUploadAvatar(await pick.file?.readAsBytes());
  }

  /// Frame [source] into a circle and upload it. Null means the user backed out
  /// before there was a picture, which is a cancel, not a failure.
  ///
  /// Assumes `_busy`/`_changingAvatar` are already set by the caller and owns
  /// clearing them on every path out.
  Future<void> _cropAndUploadAvatar(
    Uint8List? source, {
    bool mirrored = false,
  }) async {
    if (source == null || !mounted) {
      await _uploadAvatar(null);
      return;
    }
    // _busy/_changingAvatar stay set across the crop screen: the avatar keeps
    // its spinner underneath and the sheet can't be reopened behind it.
    await _uploadAvatar(
      await ImageCropScreen.open(
        context,
        source: source,
        shape: CropShape.circle,
        mirrored: mirrored,
      ),
    );
  }

  /// Puts [cropped] on the account. Null is a cancel — the crop was backed out
  /// of, or there was never a picture — which clears the spinner and nothing
  /// else.
  ///
  /// Split out from [_cropAndUploadAvatar] because the camera path crops
  /// *inside* the camera route now, and lands here with the framed picture
  /// already in hand.
  Future<void> _uploadAvatar(CroppedImage? cropped) async {
    final api = widget.api;
    final repo = widget.repo;
    if (cropped == null || api == null || repo?.userId == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _changingAvatar = false;
        });
      }
      return;
    }
    try {
      final uploader = UploadService(api);
      final storageId = await uploader.uploadFile(
        bytes: cropped.bytes,
        contentType: cropped.contentType,
      );
      await api.updateAvatar(userId: repo!.userId!, storageId: storageId);
      await _refresh();
    } catch (e) {
      // Silent unless a server limit refused it (file too large, storage
      // full, too many uploads): that the user can't fix by retrying.
      if (mounted) {
        final limit = serverLimitMessage(e, AppLocalizations.of(context));
        if (limit != null) showAppToast(context, limit);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _changingAvatar = false;
        });
      }
    }
  }

  Future<void> _downloadAvatar() async {
    final api = widget.api;
    final storageId = _u.avatarStorageId;
    if (api == null || storageId == null || storageId.isEmpty) return;
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          toast.show(l10n.profileScreenPhotoPermissionDenied);
          return;
        }
      }
      final url = await api.getFileUrl(storageId);
      // No URL to fetch — falls into the catch below and its "couldn't save
      // image." snackbar, rather than GETting the string "null".
      if (url == null) throw const FileUnavailable();
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        throw Exception('status ${resp.statusCode}');
      }
      await Gal.putImageBytes(resp.bodyBytes, name: 'avatar-${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;
      toast.show(
        l10n.profileScreenSavedToPhotos,
        tone: ToastTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      toast.show(
        l10n.profileScreenCouldNotSaveImage,
        tone: ToastTone.danger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmBlock() async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo?.userId == null) return;
    final toast = AppToast.of(context);

    // Fetch shared-room context so the confirm sheet can tailor copy.
    setState(() => _busy = true);
    SharedRoomsInfo info;
    try {
      info = await api.listSharedRooms(userId: repo!.userId!, otherUserId: _u.id);
    } catch (_) {
      info = SharedRoomsInfo(groupRooms: const [], hasDm: false);
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final choice = await showBlockChoiceSheet(
      context,
      displayName: _u.displayName,
      isFriend: _u.friendshipStatus == FriendshipStatus.friend,
      sharedGroupRooms: info.groupRooms,
      hasDm: info.hasDm,
      api: api,
    );
    if (choice == BlockChoice.cancel || !mounted) return;
    final myId = repo!.userId;
    if (myId == null) return;
    setState(() => _busy = true);
    try {
      await api.blockUser(userId: myId, targetUserId: _u.id, deleteDm: choice == BlockChoice.blockAndDelete);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      toast.show(
        choice == BlockChoice.blockAndDelete
            ? l10n.profileScreenBlockedDmWiped
            : l10n.profileScreenBlockedOnly,
      );
      Navigator.of(context).maybePop();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReport() async {
    final api = widget.api;
    final myId = widget.repo?.userId;
    if (api == null || myId == null) return;
    setState(() => _busy = true);
    try {
      // The sheet, the call and the 24-hour confirmation, shared with every
      // other report entry point (`report_sheet.dart`).
      await fileReport(
        context,
        api: api,
        reporterId: myId,
        target: ReportTarget.user,
        targetId: _u.id,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFriend() async {
    final repo = widget.repo;
    if (repo == null) return;
    setState(() => _busy = true);
    try {
      await repo.removeFriend(_u.id);
      if (mounted) {
        setState(() {
          _user = _u.copyWith(friendshipStatus: FriendshipStatus.none);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// True when the viewer's OWN grown-up is still holding a request between
  /// these two. See `ChatUser.awaitingGuardian`.
  ///
  /// This screen cannot work it out for itself: it resolves friendship from
  /// the repository's live request lists, and those carry only rows a guardian
  /// has already released. So an unreleased request looked like no request at
  /// all, and the button offered to send one that the backend would refuse
  /// with REQUEST_ALREADY_RECEIVED. `users:getProfile` supplies the flag.
  bool get _heldByGrownUp => _u.awaitingGuardian;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return HeroPage(
      title: _u.displayName,
      hero: _hero(theme),
      children: [
        if (!_isMe && _u.isRedacted) ...[
          SoftNote(
            icon: CupertinoIcons.eye_slash,
            text: _u.friendshipStatus == FriendshipStatus.friend
                ? AppLocalizations.of(context).profileScreenRedactedFriend
                : AppLocalizations.of(context).profileScreenRedactedStranger,
          ),
          const SizedBox(height: 20),
        ],
        if (_isMe) ..._meSections(theme) else ..._readSections(theme),
        if (_loading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: CupertinoActivityIndicator(color: theme.inkMuted),
            ),
          ),
      ],
    );
  }

  /// The Contacts-style head of the page: the face, the name, the handle and
  /// presence under it, and — on someone else's profile — the action tiles.
  Widget _hero(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final canEditMe = _isMe && widget.api != null && widget.repo != null;
    return Padding(
      padding: readableInset(context, top: 6, bottom: 24),
      child: Column(
        children: [
          AvatarPop(child: _avatarWithBadge(theme)),
          const SizedBox(height: 14),
          RiseIn(
            index: 1,
            // A spring under the finger is the only sign these lines are
            // editable, so they get the same press as every other control.
            child: SpringPress(
              onTap: canEditMe
                  ? () => _confirmAndEdit(
                      title: _u.name.trim().isNotEmpty
                          ? l10n.acctEditNameTitle
                          : l10n.acctAddNameTitle,
                      currentValue: _u.name,
                      hint: l10n.profileScreenNameHint,
                      onSave: _updateName,
                    )
                  : null,
              scale: 0.97,
              haptic: false,
              child: Text(
                _u.displayName,
                textAlign: TextAlign.center,
                style: theme.displayMedium,
              ),
            ),
          ),
          const SizedBox(height: 4),
          RiseIn(
            index: 2,
            child: Column(
              children: [
                SpringPress(
                  onTap: _canRenameUsername
                      ? () => _confirmAndEdit(
                          title: l10n.acctChangeUsernameTitle,
                          confirmBody: l10n.profileScreenChangeUsernameWarning,
                          currentValue: _u.username,
                          hint: l10n.profileScreenUsernameHint,
                          checksAvailability: true,
                          onSave: _updateUsername,
                        )
                      : null,
                  scale: 0.97,
                  haptic: false,
                  child: Text(
                    '@${_u.username}',
                    style: groupedValueStyle(theme),
                  ),
                ),
                // Only while the handle is actually locked. Saying "changeable
                // again on…" to someone who could change it right now would
                // read as a restriction, the opposite of the truth.
                if (_showsUsernameLock) ...[
                  const SizedBox(height: 3),
                  Text(
                    l10n.profileScreenUsernameLockedUntil(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(_usernameUnlocksAt!),
                    ),
                    style: groupedMetaStyle(theme),
                  ),
                ],
                if (canEditMe) ...[
                  const SizedBox(height: 8),
                  _emailLine(theme),
                ],
                if (!_isMe) ...[
                  const SizedBox(height: 8),
                  _relationLine(theme),
                ],
              ],
            ),
          ),
          if (!_isMe && widget.repo != null) ...[
            const SizedBox(height: 20),
            RiseIn(index: 3, child: _actionBar(theme)),
          ],
        ],
      ),
    );
  }

  Widget _avatarWithBadge(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    // Sized to _avatarSize + _badgeOverhang rather than letting the Stack take
    // the avatar's own size: RenderBox.hitTest bails before descending when
    // the point is outside `size`, and Clip.none only affects painting.
    return SizedBox(
      width: _avatarSize + _badgeOverhang,
      height: _avatarSize + _badgeOverhang,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: _avatarSize,
            height: _avatarSize,
            child: FocusableTap(
              onTap: _canViewAvatar ? _openAvatarFullscreen : null,
              shape: FocusRingShape.circle,
              semanticLabel: l10n.profileScreenViewProfilePictureSemantic,
              child: GestureDetector(
                onTap: _canViewAvatar ? _openAvatarFullscreen : null,
                child: Builder(builder: (context) {
                  final avatar = UserAvatar(
                    user: _u,
                    size: _avatarSize,
                    api: widget.api,
                    // Own presence is never news, and the dot sits exactly
                    // where the camera badge goes.
                    showStatus: false,
                  );
                  // Only the real-image case flies — a lettered placeholder
                  // has nothing to fly to, and a Hero for it would leave a tag
                  // with no counterpart.
                  if (!_canViewAvatar) return avatar;
                  return SteadyHero(tag: _avatarHeroTag, child: avatar);
                }),
              ),
            ),
          ),
          if (_changingAvatar)
            Positioned(
              left: 0,
              top: 0,
              width: _avatarSize,
              height: _avatarSize,
              // Must not swallow taps meant for the badge.
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CupertinoActivityIndicator(
                      radius: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (_isMe)
            Positioned(
              right: 0,
              bottom: 0,
              child: SpringPress(
                onTap: _busy ? null : _openAvatarSheet,
                semanticLabel: l10n.profileScreenChangeProfilePictureSemantic,
                scale: 0.88,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.background, width: 3),
                  ),
                  child: Icon(
                    CupertinoIcons.camera_fill,
                    size: 14,
                    color: theme.accentInk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Your saved email under your handle, or an invitation to add one. Tapping
  /// either edits it.
  Widget _emailLine(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final has = _u.email?.isNotEmpty ?? false;
    return SpringPress(
      onTap: () => _confirmAndEdit(
        title: has ? l10n.acctEditEmailTitle : l10n.acctAddEmail,
        currentValue: _u.email ?? '',
        // An optional contact note: this app sends no mail, and recovery is
        // the 12-word phrase.
        hint: l10n.profileScreenEmailHint,
        keyboardType: TextInputType.emailAddress,
        onSave: _updateEmail,
      ),
      scale: 0.97,
      haptic: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            has ? CupertinoIcons.envelope : CupertinoIcons.plus_circle,
            size: 15,
            color: has ? theme.inkMuted : theme.accent,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              has ? _u.email! : l10n.acctAddEmail,
              style: groupedSubtitleStyle(theme).copyWith(
                color: has ? theme.inkSoft : theme.accent,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Where you stand with this person, and whether they're around.
  Widget _relationLine(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final relation = switch (_u.friendshipStatus) {
      FriendshipStatus.friend => l10n.acctStatusFriends,
      FriendshipStatus.outgoingPending => l10n.acctStatusRequestSent,
      FriendshipStatus.incomingPending => l10n.acctStatusWantsToConnect,
      FriendshipStatus.none => l10n.acctStatusNotConnected,
    };
    final presence = switch (_u.status) {
      'online' => (theme.success, l10n.acctPresenceOnline),
      'away' => (const Color(0xFFE0A33C), l10n.acctPresenceAway),
      'offline' => (theme.inkMuted, l10n.acctPresenceOffline),
      _ => null,
    };
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        if (presence != null)
          StatusDotLine(color: presence.$1, label: presence.$2),
        if (presence != null)
          Text('·', style: groupedSubtitleStyle(theme)),
        Text(
          relation,
          style: groupedSubtitleStyle(theme).copyWith(
            color: _u.friendshipStatus == FriendshipStatus.incomingPending
                ? theme.accent
                : theme.inkMuted,
          ),
        ),
      ],
    );
  }

  /// Someone else's profile: what you can do about them, as tiles.
  Widget _actionBar(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final status = _u.friendshipStatus;
    final closed = !_heldByGrownUp &&
        status == FriendshipStatus.none &&
        !_u.acceptsFriendRequests;
    final primaryBlocked = _busy || _heldByGrownUp || closed;
    // Waiting on a guardian outranks every friendship state: the request
    // exists, it just hasn't been released, and offering to send one would
    // only bounce off REQUEST_ALREADY_RECEIVED.
    final (IconData icon, String label) = _heldByGrownUp
        ? (CupertinoIcons.hourglass, l10n.acctActionPending)
        : closed
        ? (
            CupertinoIcons.person_crop_circle_fill_badge_xmark,
            l10n.acctActionNotAccepting,
          )
        : switch (status) {
            FriendshipStatus.none => (
              CupertinoIcons.person_badge_plus_fill,
              l10n.acctActionAddFriend,
            ),
            FriendshipStatus.outgoingPending => (
              CupertinoIcons.clock_fill,
              l10n.acctActionRequested,
            ),
            FriendshipStatus.incomingPending => (
              CupertinoIcons.checkmark_alt_circle_fill,
              l10n.acctActionAccept,
            ),
            FriendshipStatus.friend => (
              CupertinoIcons.chat_bubble_fill,
              l10n.acctActionMessage,
            ),
          };
    // One tint rule, filled glyphs. Block and Report are not tiles: they
    // sit in their own red section below, the iOS Contacts arrangement —
    // a row of red tiles beside Message read as the page's main actions.
    return SheetQuickActions(
      actions: [
        QuickAction(
          icon: icon,
          label: label,
          busy: _busy,
          onTap: primaryBlocked ? null : _friendshipAction,
        ),
        if (status == FriendshipStatus.friend)
          QuickAction(
            icon: CupertinoIcons.person_badge_minus_fill,
            label: l10n.acctActionUnfriend,
            onTap: _busy ? null : _removeFriend,
          ),
      ],
    );
  }

  List<Widget> _readSections(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final email = _u.email;
    return [
      if (email != null && email.isNotEmpty)
        GroupedSection(
          children: [
            GroupedRow(
              title: email,
              icon: CupertinoIcons.envelope_fill,
              tone: TileTone.blue,
            ),
          ],
        ),
      if (widget.repo != null)
        GroupedSection(
          children: [
            GroupedRow(
              title: l10n.acctActionBlock,
              destructive: true,
              onTap: _busy ? null : _confirmBlock,
            ),
            GroupedRow(
              title: l10n.acctActionReport,
              destructive: true,
              onTap: _busy ? null : _confirmReport,
            ),
          ],
        ),
    ];
  }

  List<Widget> _meSections(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final repo = widget.repo;
    final api = widget.api;
    final canPrivacy = repo != null && api != null;
    // A child has no way out of their own account — no sign out, no delete.
    // That's the point of a supervised device, so the section is absent
    // rather than disabled. What a child DOES get is "hand this phone back",
    // gated by a grown-up's release code or password rather than by hiding.
    final canAccount = widget.auth != null && !widget.auth!.isChild;
    final isChildAccount = widget.auth != null && widget.auth!.isChild;
    final family = widget.family;

    return [
      // Explicitly `== false`: null means the backend didn't say, which must
      // never be read as "no phrase set".
      if (canAccount && _u.hasRecoveryKey == false) ...[
        RecoveryPhraseBanner(onTap: _openRecoveryPhrase),
        const SizedBox(height: 20),
      ],
      if (canPrivacy)
        GroupedSection(
          header: l10n.acctSectionPrivacy,
          children: [
            // Not the eye: Screen capture just below wears that one.
            GroupedRow(
              icon: CupertinoIcons.person_crop_circle_fill,
              tone: TileTone.blue,
              title: l10n.acctRowVisibility,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileVisibilityScreen(
                    repo: repo,
                    api: api,
                    readOnly: widget.auth?.isChild ?? false,
                  ),
                ),
              ),
            ),
            GroupedRow(
              icon: CupertinoIcons.hand_raised_fill,
              tone: TileTone.red,
              title: l10n.acctRowBlocked,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlockedUsersScreen(repo: repo, api: api),
                ),
              ),
            ),
          ],
        ),
      if (canAccount)
        GroupedSection(
          header: l10n.acctSectionAccount,
          children: [
            if (family != null) ...[
              GroupedRow(
                icon: CupertinoIcons.person_3_fill,
                tone: TileTone.green,
                title: l10n.acctSectionFamily,
                value: _familyLabel,
                // No badge here: the count belongs to Approvals, right
                // below — the same "2" on both rows read as four requests.
                // Without children there is no Approvals row, and nothing
                // can be pending either.
                onTap: _openFamily,
              ),
              // No children, nothing to approve — the row would be a
              // permanent "nothing waiting" for everyone who never adds one.
              if (family.context.children.isNotEmpty)
                GroupedRow(
                  icon: CupertinoIcons.checkmark_seal_fill,
                  tone: TileTone.orange,
                  title: l10n.acctRowApprovals,
                  value: family.pendingCount == 0
                      ? l10n.acctNothingWaiting
                      : null,
                  badge: family.pendingCount,
                  onTap: _openApprovals,
                ),
            ],
            // Hidden where neither provider is offered — a row promising a
            // screen that would open empty is worse than no row.
            if (SocialSignInButtons.available.isNotEmpty)
              GroupedRow(
                icon: CupertinoIcons.link,
                tone: TileTone.indigo,
                title: l10n.acctRowLinked,
                value: _linkedAccountsLabel,
                onTap: _openLinkedAccounts,
              ),
            GroupedRow(
              icon: CupertinoIcons.device_laptop,
              tone: TileTone.gray,
              title: l10n.acctRowDevices,
              onTap: _openDevices,
            ),
            // Mobile only — approving a desktop/web sign-in needs a camera,
            // and the QR it scans only ever shows on desktop/web.
            if (!isWebOrDesktop)
              GroupedRow(
                icon: CupertinoIcons.qrcode_viewfinder,
                tone: TileTone.teal,
                title: l10n.acctRowScanToSignIn,
                onTap: _openDeviceLoginScan,
              ),
            GroupedRow(
              icon: CupertinoIcons.lock_shield_fill,
              tone: TileTone.purple,
              title: _u.hasRecoveryKey == true
                  ? l10n.acctRowChangeRecovery
                  : l10n.acctRowSetUpRecovery,
              onTap: _openRecoveryPhrase,
            ),
          ],
        ),
      if (canAccount)
        GroupedSection(
          children: [
            // Red, as iOS's own Sign Out is: it ends something.
            GroupedRow(
              title: l10n.acctSignOut,
              destructive: true,
              trailing: _signingOut ? _spinner(theme) : null,
              chevron: false,
              onTap: _busy ? null : _signOut,
            ),
            GroupedRow(
              title: l10n.acctDeleteAccount,
              destructive: true,
              trailing: _deletingAccount ? _spinner(theme) : null,
              onTap: _deletingAccount ? null : _deleteAccount,
            ),
          ],
        ),
      // A child's half of the same idea. Read-only — there's nothing here for
      // them to change, and pretending otherwise would be worse than saying so.
      if (isChildAccount && family != null)
        GroupedSection(
          header: l10n.acctSectionFamily,
          footer: l10n.profileScreenGuardiansCanSee,
          children: [_GuardiansRow(family: family)],
        ),
      if (isChildAccount)
        GroupedSection(
          header: l10n.acctSectionThisPhone,
          footer: l10n.profileScreenGrownUpOnlyNote,
          children: [
            GroupedRow(
              icon: CupertinoIcons.arrow_turn_up_left,
              tone: TileTone.gray,
              title: l10n.acctHandPhoneBack,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReleaseDeviceScreen(auth: widget.auth!),
                ),
              ),
            ),
          ],
        ),
      // Legal lives in Settings: the privacy policy, terms and licence say
      // nothing about *this* account. Settings is reachable by every account,
      // children included, which is what the store requirement needs.
    ];
  }

  Widget _spinner(AppTheme theme) => SizedBox(
        width: 16,
        height: 16,
        child: CupertinoActivityIndicator(radius: 8, color: theme.inkMuted),
      );
}

/// Who looks after this child, stated plainly. Moved here from Settings when
/// family became an account fact rather than a preference.
class _GuardiansRow extends StatelessWidget {
  const _GuardiansRow({required this.family});
  final FamilyService family;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final guardians = family.context.guardians;
    return GroupedRow(
      icon: CupertinoIcons.shield_lefthalf_fill,
      tone: TileTone.green,
      title: l10n.acctMyGrownUps,
      subtitle: guardians.isEmpty
          ? l10n.profileScreenNobodyLookingAfter
          : guardians.map((g) => g.displayName).join(' · '),
    );
  }
}

/// The body of [_ProfileScreenState._editFieldSheet].
///
/// Owns its [TextEditingController] as `State`, not as a local in the
/// function that pushes the sheet — `showAdaptiveSheet`'s future resolves the
/// instant `Navigator.pop()` is called, before the sheet's close animation
/// finishes, so a controller disposed right after that await would still be
/// attached to a `TextField` that's mid-exit-transition. Tying it to `State.
/// dispose()` instead means Flutter only tears it down once the widget is
/// actually unmounted.
/// Asks which sign-in to re-authorise with, for an account that has both linked.
///
/// Carries no button copy of its own: the Apple and Google buttons are
/// vendor-branded down to the hex and supply their own titles — Apple's comes
/// from AuthenticationServices, never from an ARB key — so this contributes a
/// heading and nothing else.
class _RenameProviderSheet extends StatelessWidget {
  const _RenameProviderSheet({required this.providers});

  final List<SocialProvider> providers;

  @override
  Widget build(BuildContext context) => SheetFrame(
        title: AppLocalizations.of(context).profileScreenUsernameProviderTitle,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SocialSignInButtons(
          only: providers,
          dividerLabel: null,
          onProvider: (p) => Navigator.of(context).pop(p),
        ),
      );
}

class _EditFieldSheet extends StatefulWidget {
  const _EditFieldSheet({
    required this.title,
    required this.currentValue,
    required this.hint,
    required this.keyboardType,
    this.availability,
  });

  final String title;
  final String currentValue;
  final String hint;
  final TextInputType keyboardType;

  /// Set for the username only.
  ///
  /// This sheet also edits the display name and the email, and neither has an
  /// availability question to ask — a live verdict under those would be a line
  /// of empty space at best. Owned here rather than by the screen because the
  /// sheet's lifetime is what the controller's should match.
  final UsernameAvailabilityController? availability;

  @override
  State<_EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<_EditFieldSheet> {
  late final _controller = TextEditingController(text: widget.currentValue);

  @override
  void dispose() {
    widget.availability?.dispose();
    _controller.dispose();
    super.dispose();
  }

  // The × (leading) cancels and the ✓ (trailing) saves — the iOS 26 sheet
  // bar, which also lifts the sheet over the keyboard itself.
  @override
  Widget build(BuildContext context) => SheetFrame(
        title: widget.title,
        confirm: SheetConfirm(
          onTap: () => Navigator.of(context).pop(_controller.text),
          label: AppLocalizations.of(context).acctSave,
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ThemedInput(
              controller: _controller,
              hint: widget.hint,
              keyboardType: widget.keyboardType,
              autofocus: true,
              onChanged: widget.availability?.onChanged,
            ),
            if (widget.availability != null)
              UsernameStatusLabel(controller: widget.availability!),
          ],
        ),
      );
}

enum AvatarAction { download, capture, library }

Future<AvatarAction?> showAvatarActionSheet(
  BuildContext context, {
  required bool hasAvatar,
}) {
  final l10n = AppLocalizations.of(context);
  // The iOS action sheet: three choices, Cancel apart below them.
  return showIosActionSheet<AvatarAction>(
    context,
    title: l10n.acctProfilePhoto,
    actions: [
      // Not in a browser: `gal` writes to the system photo library and ships
      // no web implementation, so the choice would throw
      // MissingPluginException the moment it was tapped.
      if (hasAvatar && !kIsWeb)
        IosSheetAction(
          label: l10n.acctSaveToPhotos,
          value: AvatarAction.download,
          icon: CupertinoIcons.arrow_down_to_line,
        ),
      IosSheetAction(
        label: l10n.acctTakeSelfie,
        value: AvatarAction.capture,
        icon: CupertinoIcons.camera_fill,
      ),
      IosSheetAction(
        label: l10n.acctChooseFromLibrary,
        value: AvatarAction.library,
        icon: CupertinoIcons.photo_fill_on_rectangle_fill,
      ),
    ],
    cancelLabel: l10n.acctCancel,
  );
}
