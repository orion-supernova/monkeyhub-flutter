import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/auth_errors.dart';
import '../invites/room_admin_errors.dart';
import '../data/chat_repository.dart';
import '../invites/invite_link.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/room_admin.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'sheet_surface.dart';
import 'destructive_sheet.dart';
import 'sheet_buttons.dart';

/// The admin's invite-link sheet: the room's one live link, the limits on it,
/// and the two switches that decide what it does.
///
/// The code and the URL are the SAME token — `K7M2-XQ94-RB` is the tail of
/// `.../j/K7M2XQ94RB`, spaced out for reading aloud. They are shown together
/// rather than as two features, because presenting them as separate things is
/// what leads to two things to revoke and a room that is still reachable
/// through the one somebody forgot about.
///
/// Regenerating is destructive and is worded that way. It is also the ONLY
/// revocation most people will ever want: every copy of the old link that has
/// been forwarded, screenshotted or pasted somewhere stops working the instant
/// the new one exists.
Future<void> showRoomInviteSheet(
  BuildContext context, {
  required ChatRepository repo,
  required String roomId,
  required RoomPermissions permissions,
}) {
  return showAdaptiveSheet<void>(
    context,
    // Bounded by the top safe area. `ModalBottomSheetRoute` strips the top
    // inset from everything inside it, so a `SafeArea` in the content is a
    // silent no-op — this flag is the only hook that applies it, from the
    // route, where the padding still exists. Without it a tall sheet runs
    // under the notch.
    useSafeArea: true,
    builder: (_) => _RoomInviteSheet(
      repo: repo,
      roomId: roomId,
      permissions: permissions,
    ),
  );
}

/// Expiry choices. Deliberately coarse — the useful question is "for tonight,
/// for this week, or forever", and a date picker for a share link is a lot of
/// ceremony for an answer nobody needs to the minute.
const _expiryChoices = <Duration?>[
  null,
  Duration(hours: 1),
  Duration(hours: 24),
  Duration(days: 7),
  Duration(days: 30),
];

/// Use caps, same reasoning. `null` is unlimited.
const _useChoices = <int?>[null, 1, 5, 10, 25, 100];

class _RoomInviteSheet extends StatefulWidget {
  const _RoomInviteSheet({
    required this.repo,
    required this.roomId,
    required this.permissions,
  });

  final ChatRepository repo;
  final String roomId;
  final RoomPermissions permissions;

  @override
  State<_RoomInviteSheet> createState() => _RoomInviteSheetState();
}

class _RoomInviteSheetState extends State<_RoomInviteSheet> {
  RoomInviteLink? _link;
  bool _loading = true;
  bool _busy = false;

  /// The limits that will apply to the NEXT link, not the current one. An
  /// existing link's limits are fixed at issue time — changing them would mean
  /// an admin could quietly extend a link they had told people was expiring,
  /// which is the opposite of what a limit is for.
  Duration? _pendingExpiry;
  int? _pendingMaxUses;

  late bool _membersCanInvite = widget.permissions.membersCanInvite;
  late RoomJoinPolicy _joinPolicy = widget.permissions.linkJoinPolicy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final link = await widget.repo.roomInviteLink(widget.roomId);
      if (!mounted) return;
      setState(() {
        _link = link;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _url => inviteUrlForCurrentServer(_link!.code);

  Future<void> _rotate({required bool hasExisting}) async {
    final l10n = AppLocalizations.of(context);
    if (hasExisting) {
      // The one confirmation in this sheet, because this is the one action
      // that breaks something already in the world.
      final ok = await showConfirmSheet(
        context,
        headline: l10n.roomInviteRegenerateHeadline,
        body: l10n.roomInviteRegenerateBody,
        confirmLabel: l10n.roomInviteRegenerateConfirm,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final link = await widget.repo.rotateRoomInviteLink(
        widget.roomId,
        expiresIn: _pendingExpiry,
        maxUses: _pendingMaxUses,
      );
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _link = link;
        _busy = false;
      });
      // Worth saying out loud: the old link just stopped working everywhere it
      // had been shared, and nothing else on screen announces that.
      _toast(AppLocalizations.of(context).roomInviteRotatedToast);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _reportError(e);
    }
  }

  Future<void> _revoke() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmSheet(
      context,
      headline: l10n.roomInviteRevokeHeadline,
      body: l10n.roomInviteRevokeBody,
      confirmLabel: l10n.roomInviteRevokeConfirm,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repo.revokeRoomInviteLink(widget.roomId);
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _link = null;
        _busy = false;
      });
      _toast(AppLocalizations.of(context).roomInviteRevokedToast);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _reportError(e);
    }
  }

  Future<void> _setPolicy({bool? membersCanInvite, RoomJoinPolicy? policy}) async {
    // Optimistic: these are two toggles in a settings list, and a switch that
    // waits for a round trip before moving reads as broken. Reverted below if
    // the server disagrees.
    final prevMembers = _membersCanInvite;
    final prevPolicy = _joinPolicy;
    setState(() {
      if (membersCanInvite != null) _membersCanInvite = membersCanInvite;
      if (policy != null) _joinPolicy = policy;
    });
    try {
      await widget.repo.setRoomPolicy(
        roomId: widget.roomId,
        membersCanInvite: membersCanInvite,
        linkJoinPolicy: policy,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _membersCanInvite = prevMembers;
        _joinPolicy = prevPolicy;
      });
      _reportError(e);
    }
  }

  void _reportError(Object e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    // Same overlay as the confirmations, for the same reason — a snackbar
    // raised from inside this sheet is invisible behind it.
    showAppToast(
      context,
      humanizeAuthError(
        e,
        l10n,
        fallback: l10n.roomAdminGenericError,
        overrides: roomAdminErrorMessages(l10n),
      ),
      tone: ToastTone.danger,
    );
  }

  /// Copy, buzz, say so.
  ///
  /// All three, because a copy is otherwise completely silent: the clipboard
  /// changes somewhere the user cannot see and the button looks identical
  /// afterwards. The buzz confirms the tap registered and the toast confirms
  /// WHICH thing was copied — the link and the code sit two taps apart and are
  /// easy to mix up.
  Future<void> _copy(String value, String toast) async {
    await Clipboard.setData(ClipboardData(text: value));
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    _toast(toast);
  }

  /// Hand the link to the system share sheet.
  ///
  /// No toast on the way out — the share sheet IS the feedback, and a toast
  /// would land underneath it. Just the buzz, so the tap is acknowledged
  /// before the OS takes a beat to open its sheet.
  Future<void> _share(String url) async {
    await HapticFeedback.selectionClick();
    await SharePlus.instance.share(ShareParams(uri: Uri.parse(url)));
  }

  /// One toast, over the sheet rather than behind it.
  ///
  /// This was `ScaffoldMessenger.showSnackBar`, which is why no confirmation
  /// ever appeared: a snackbar belongs to a Scaffold and a bottom sheet is a
  /// route stacked above one, so it was being shown correctly and rendered
  /// underneath. See [showAppToast].
  void _toast(String message) =>
      showAppToast(context, message, tone: ToastTone.success);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final link = _link;

    return SheetSurface(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.roomInviteSheetTitle, style: theme.displaySmall),
            const SizedBox(height: 6),
            Text(l10n.roomInviteSheetBlurb, style: theme.bodySoft),
            const SizedBox(height: 20),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.accent,
                    ),
                  ),
                ),
              )
            else if (link == null)
              _NoLinkYet(onCreate: _busy ? null : () => _rotate(hasExisting: false))
            else ...[
              _LinkCard(
                link: link,
                url: _url,
                onCopyLink: () => _copy(_url, l10n.roomInviteLinkCopied),
                onCopyCode: () => _copy(link.code, l10n.roomInviteCodeCopied),
                onShare: () => _share(_url),
              ),
              const SizedBox(height: 14),
              // Directly under the card, not at the far end of the sheet.
              // These two ACT ON the link above them — a revoke button parked
              // below the limits and the permission switches reads as a
              // footer, and on a phone it sat below the fold entirely, which
              // is why it was reported missing.
              Row(children: [
                Expanded(
                  child: SheetSecondaryButton(
                    label: l10n.roomInviteRevokeButton,
                    color: theme.danger,
                    onTap: _busy ? () {} : _revoke,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SheetPrimaryButton(
                    label: l10n.roomInviteRegenerateButton,
                    onTap: _busy ? null : () => _rotate(hasExisting: true),
                  ),
                ),
              ]),
              const SizedBox(height: 22),
            ],
            if (!_loading) ...[
              _SectionLabel(l10n.roomInviteLimitsLabel),
              const SizedBox(height: 8),
              _ChoiceRow<Duration?>(
                label: l10n.roomInviteExpiryLabel,
                value: _pendingExpiry,
                choices: _expiryChoices,
                labelFor: (d) => _expiryLabel(l10n, d),
                onChanged: (d) => setState(() => _pendingExpiry = d),
              ),
              const SizedBox(height: 10),
              _ChoiceRow<int?>(
                label: l10n.roomInviteMaxUsesLabel,
                value: _pendingMaxUses,
                choices: _useChoices,
                labelFor: (n) =>
                    n == null ? l10n.roomInviteUnlimited : n.toString(),
                onChanged: (n) => setState(() => _pendingMaxUses = n),
              ),
              const SizedBox(height: 6),
              Text(
                link == null
                    ? l10n.roomInviteLimitsApplyToNew
                    : l10n.roomInviteLimitsApplyOnRegenerate,
                style: theme.monoTiny,
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.roomInvitePermissionsLabel),
              const SizedBox(height: 8),
              _SwitchRow(
                label: l10n.roomInviteMembersCanInviteLabel,
                sub: l10n.roomInviteMembersCanInviteSub,
                value: _membersCanInvite,
                onChanged: (v) => _setPolicy(membersCanInvite: v),
              ),
              _SwitchRow(
                label: l10n.roomInviteApprovalLabel,
                sub: l10n.roomInviteApprovalSub,
                value: _joinPolicy == RoomJoinPolicy.approval,
                onChanged: (v) => _setPolicy(
                  policy: v ? RoomJoinPolicy.approval : RoomJoinPolicy.open,
                ),
              ),
            ],
          ],
      ),
    );
  }

  String _expiryLabel(AppLocalizations l10n, Duration? d) {
    if (d == null) return l10n.roomInviteNeverExpires;
    if (d.inHours < 24) return l10n.roomInviteExpiryHours(d.inHours);
    return l10n.roomInviteExpiryDays(d.inDays);
  }
}

class _NoLinkYet extends StatelessWidget {
  const _NoLinkYet({required this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            l10n.roomInviteNoLinkYet,
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 14),
        SheetPrimaryButton(label: l10n.roomInviteCreateButton, onTap: onCreate),
      ],
    );
  }
}

/// The link itself, and everything true about it right now.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.link,
    required this.url,
    required this.onCopyLink,
    required this.onCopyCode,
    required this.onShare,
  });

  final RoomInviteLink link;
  final String url;
  final VoidCallback onCopyLink;
  final VoidCallback onCopyCode;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final dead = !link.isUsable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(
          color: dead ? theme.danger.withValues(alpha: 0.5) : theme.divider,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The QR, for the case the code and the link both handle badly:
          // somebody sitting across a table. No app switch, no typing, no
          // reading a ten-character string aloud over music.
          //
          // Encodes the SAME url the copy and share buttons hand out, so a
          // scan and a paste are the same act — and it is hidden outright once
          // the link is dead, because a scannable code that resolves to
          // "expired" is worse than no code at all.
          if (!dead) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // Always white behind the modules, in every theme. A QR on a
                  // dark surface is a QR most scanners refuse — the contrast
                  // polarity is part of the format, not styling.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 150,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // The code, big. This is the half that gets read out over a call or
          // typed off someone else's screen, so it gets the typographic weight
          // rather than the URL, which is only ever copied.
          Text(
            link.formattedCode,
            style: theme.monoLarge.copyWith(
              color: dead ? theme.inkMuted : theme.ink,
              letterSpacing: 3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            url,
            style: theme.monoTiny.copyWith(
              color: dead ? theme.inkMuted : theme.inkSoft,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          if (dead)
            Text(
              _deadReason(l10n, link.problem),
              style: theme.monoTiny.copyWith(color: theme.danger),
              textAlign: TextAlign.center,
            )
          else
            Text(
              _statusLine(l10n, link),
              style: theme.monoTiny,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniButton(
                  icon: Icons.link,
                  label: l10n.roomInviteCopyLink,
                  onTap: dead ? null : onCopyLink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniButton(
                  icon: Icons.tag,
                  label: l10n.roomInviteCopyCode,
                  onTap: dead ? null : onCopyCode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniButton(
                  icon: Icons.ios_share,
                  label: l10n.roomInviteShare,
                  onTap: dead ? null : onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _deadReason(AppLocalizations l10n, InviteProblem p) => switch (p) {
        InviteProblem.expired => l10n.roomInviteDeadExpired,
        InviteProblem.exhausted => l10n.roomInviteDeadExhausted,
        InviteProblem.revoked => l10n.roomInviteDeadRevoked,
        _ => l10n.roomInviteDeadGeneric,
      };

  /// One line covering both limits, because they are almost always both
  /// absent and two separate "unlimited" rows would be noise.
  String _statusLine(AppLocalizations l10n, RoomInviteLink link) {
    final uses = link.maxUses == null
        ? l10n.roomInviteUsesCount(link.useCount)
        : l10n.roomInviteUsesOfMax(link.maxUses!, link.useCount);
    if (link.expiresAt == null) return uses;
    return '$uses · ${l10n.roomInviteExpiresOn(_shortDate(link.expiresAt!))}';
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    final tint = enabled ? theme.ink : theme.inkMuted;
    return FocusableTap(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: label,
      radius: theme.radiusSm,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: theme.divider, width: 1.2),
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.monoTiny.copyWith(color: tint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // NOT `.toUpperCase()`. Dart uppercases per the invariant locale, so a
    // Turkish "i" becomes "I" rather than "İ" — the same reason
    // `incoming_call_screen.dart` spells its labels out in caps in the ARB.
    // Every string that reaches here is already in its locale's final casing.
    return Text(
      text,
      style: theme.label.copyWith(color: theme.inkMuted, letterSpacing: 2),
    );
  }
}

/// A horizontal strip of mutually-exclusive chips. Used for both limits, so
/// the two rows cannot drift apart visually the way two hand-built rows would.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.choices,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> choices;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.bodySoft),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in choices) ...[
                _Chip(
                  label: labelFor(c),
                  active: c == value,
                  onTap: () => onChanged(c),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusSm,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? theme.accent : Colors.transparent,
            border: Border.all(
              color: active ? theme.accent : theme.divider,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          child: Text(
            label,
            style: theme.monoTiny.copyWith(
              color: active ? theme.accentInk : theme.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: () => onChanged(!value),
      semanticLabel: label,
      radius: theme.radiusSm,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.body),
                    const SizedBox(height: 2),
                    Text(sub, style: theme.monoTiny),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: theme.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
