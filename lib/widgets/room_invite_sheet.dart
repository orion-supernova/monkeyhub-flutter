import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/auth_errors.dart';
import '../invites/room_admin_errors.dart';
import '../data/chat_repository.dart';
import '../invites/invite_link.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/room_admin.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'destructive_sheet.dart';
import 'message_stamp.dart' show formatClockTime;
import 'number_stepper.dart';
import 'sheet_kit.dart';
import 'filter_capsule.dart';
import 'ios_kit.dart';
import '../l10n/text_case.dart';

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

/// The unit a custom expiry is dialled in.
enum _ExpiryUnit {
  hours,
  days;

  Duration of(int amount) =>
      this == hours ? Duration(hours: amount) : Duration(days: amount);

  /// The stepper's ceiling. Days stop at the backend's own
  /// `MAX_EXPIRY_MS` (a year); hours stop at three days, past which the days
  /// unit says the same thing without asking for seventy taps.
  int get max => this == hours ? 72 : 365;
}

/// The stepper's ceiling for a custom use count. The backend takes any whole
/// number from one up; a thousand is well past any real group, and a bound is
/// what lets a held arrow run to the end instead of forever.
const _maxCustomUses = 1000;

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

  /// A custom limit, when the presets were not enough. Kept apart from the
  /// preset values rather than written over them, so tapping a preset and
  /// then Custom again brings back what the admin had dialled in.
  bool _customExpiry = false;
  _ExpiryUnit _customUnit = _ExpiryUnit.days;
  int _customAmount = 3;
  bool _customUses = false;
  int _customUsesCount = 3;

  /// What the next link will actually be made with.
  Duration? get _nextExpiry =>
      _customExpiry ? _customUnit.of(_customAmount) : _pendingExpiry;
  int? get _nextMaxUses => _customUses ? _customUsesCount : _pendingMaxUses;

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
        expiresIn: _nextExpiry,
        maxUses: _nextMaxUses,
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

    // The bar stays put above the scroller — QR, code, limits and switches
    // overflow a phone, and a header that scrolls away takes the × with it.
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.roomInviteSheetTitle),
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sentenceCaseOf(context, l10n.roomInviteSheetBlurb),
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
            ),
            const SizedBox(height: 20),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CupertinoActivityIndicator(color: theme.inkMuted),
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
              // Stacked rather than side by side: in Turkish at 1.3× the
              // pair wrapped and squeezed. The renewal is the common act, so
              // it leads; revoking is the tonal red one under it.
              SheetActionButton(
                label: l10n.roomInviteRegenerateButton,
                onTap: _busy ? null : () => _rotate(hasExisting: true),
              ),
              const SizedBox(height: 10),
              SheetActionButton(
                label: l10n.roomInviteRevokeButton,
                tonal: true,
                destructive: true,
                onTap: _busy ? null : _revoke,
              ),
              const SizedBox(height: 22),
            ],
            if (!_loading) ...[
              GroupedHeader(l10n.roomInviteLimitsLabel),
              _ChoiceRow<Duration?>(
                label: l10n.roomInviteExpiryLabel,
                value: _pendingExpiry,
                choices: _expiryChoices,
                labelFor: (d) => _expiryLabel(l10n, d),
                onChanged: (d) => setState(() {
                  _pendingExpiry = d;
                  _customExpiry = false;
                }),
                customLabel: l10n.roomInviteCustom,
                customActive: _customExpiry,
                onCustom: _openCustomExpiry,
              ),
              _CustomPanel(
                open: _customExpiry,
                child: _customExpiryControls(theme, l10n),
              ),
              const SizedBox(height: 10),
              _ChoiceRow<int?>(
                label: l10n.roomInviteMaxUsesLabel,
                value: _pendingMaxUses,
                choices: _useChoices,
                labelFor: (n) =>
                    n == null ? l10n.roomInviteUnlimited : n.toString(),
                onChanged: (n) => setState(() {
                  _pendingMaxUses = n;
                  _customUses = false;
                }),
                customLabel: l10n.roomInviteCustom,
                customActive: _customUses,
                onCustom: _openCustomUses,
              ),
              _CustomPanel(
                open: _customUses,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: NumberStepper(
                    value: _customUsesCount,
                    min: 1,
                    max: _maxCustomUses,
                    display: l10n.roomInviteCustomUses,
                    semanticsLabel: l10n.roomInviteMaxUsesLabel,
                    increaseLabel: l10n.roomInviteStepperIncrease,
                    decreaseLabel: l10n.roomInviteStepperDecrease,
                    onChanged: (n) => setState(() => _customUsesCount = n),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                link == null
                    ? l10n.roomInviteLimitsApplyToNew
                    : l10n.roomInviteLimitsApplyOnRegenerate,
                style: _meta(theme),
              ),
              const SizedBox(height: 20),
              SheetGroup(
                header: l10n.roomInvitePermissionsLabel,
                children: [
                  GroupedRow.toggle(
                    title: l10n.roomInviteMembersCanInviteLabel,
                    subtitle: l10n.roomInviteMembersCanInviteSub,
                    value: _membersCanInvite,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      _setPolicy(membersCanInvite: v);
                    },
                  ),
                  GroupedRow.toggle(
                    title: l10n.roomInviteApprovalLabel,
                    subtitle: l10n.roomInviteApprovalSub,
                    value: _joinPolicy == RoomJoinPolicy.approval,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      _setPolicy(
                        policy:
                            v ? RoomJoinPolicy.approval : RoomJoinPolicy.open,
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Custom seeds itself from the preset it replaces, so the stepper starts
  /// where the admin already was — "24h" opens on 1 day, not on a default.
  void _openCustomExpiry() {
    final from = _pendingExpiry;
    setState(() {
      if (!_customExpiry && from != null) {
        if (from.inHours < 24) {
          _customUnit = _ExpiryUnit.hours;
          _customAmount = from.inHours.clamp(1, _ExpiryUnit.hours.max);
        } else {
          _customUnit = _ExpiryUnit.days;
          _customAmount = from.inDays.clamp(1, _ExpiryUnit.days.max);
        }
      }
      _customExpiry = true;
    });
    HapticFeedback.selectionClick();
  }

  void _openCustomUses() {
    setState(() {
      final from = _pendingMaxUses;
      if (!_customUses && from != null) {
        _customUsesCount = from.clamp(1, _maxCustomUses);
      }
      _customUses = true;
    });
    HapticFeedback.selectionClick();
  }

  /// Switching unit keeps the same span as nearly as the new unit can say it:
  /// 36 hours becomes 2 days (rounded up — an expiry should never come early),
  /// 5 days becomes the hours ceiling.
  void _setUnit(_ExpiryUnit unit) {
    if (unit == _customUnit) return;
    final span = _customUnit.of(_customAmount);
    setState(() {
      _customUnit = unit;
      _customAmount = (unit == _ExpiryUnit.hours
              ? span.inHours
              : (span.inHours / 24).ceil())
          .clamp(1, unit.max);
    });
    HapticFeedback.selectionClick();
  }

  Widget _customExpiryControls(AppTheme theme, AppLocalizations l10n) {
    final unit = _customUnit;
    final until = DateTime.now().add(unit.of(_customAmount));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NumberStepper(
              value: _customAmount,
              min: 1,
              max: unit.max,
              display: unit == _ExpiryUnit.hours
                  ? l10n.roomInviteCustomHours
                  : l10n.roomInviteCustomDays,
              semanticsLabel: l10n.roomInviteExpiryLabel,
              increaseLabel: l10n.roomInviteStepperIncrease,
              decreaseLabel: l10n.roomInviteStepperDecrease,
              onChanged: (n) => setState(() => _customAmount = n),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilterCapsule(
                  label: l10n.roomInviteUnitHours,
                  active: unit == _ExpiryUnit.hours,
                  onTap: () => _setUnit(_ExpiryUnit.hours),
                ),
                const SizedBox(width: 6),
                FilterCapsule(
                  label: l10n.roomInviteUnitDays,
                  active: unit == _ExpiryUnit.days,
                  onTap: () => _setUnit(_ExpiryUnit.days),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // The answer to the question the stepper is really asking — "until
        // when?" — so nobody has to count forward from today in their head.
        Text(
          l10n.roomInviteExpiresOn(
            '${_shortDate(context, until)} ${formatClockTime(until)}',
          ),
          style: _meta(theme).copyWith(color: theme.inkMuted),
        ),
      ],
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
            color: sheetGroupFill(theme),
            borderRadius: BorderRadius.circular(groupedRadius(theme)),
          ),
          child: Text(
            sentenceCaseOf(context, l10n.roomInviteNoLinkYet),
            style: groupedFooterStyle(theme),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 14),
        SheetActionButton(label: l10n.roomInviteCreateButton, onTap: onCreate),
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

    // A grouped block on the sheet, no outline — a dead link says so with a
    // faint red wash instead of a red border. The three actions sit under
    // it as the shared quick-action tiles: inside the block, a tile on the
    // block's own fill had no edge at all.
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dead
            ? Color.alphaBlend(
                theme.danger.withValues(alpha: 0.08),
                sheetGroupFill(theme),
              )
            : sheetGroupFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
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
                  borderRadius: BorderRadius.circular(14),
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
              fontSize: 26,
              color: dead ? theme.inkMuted : theme.ink,
              letterSpacing: 3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            url,
            style: _meta(theme).copyWith(
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
              style: _meta(theme).copyWith(color: theme.danger),
              textAlign: TextAlign.center,
            )
          else
            Text(
              _statusLine(context, l10n, link),
              style: _meta(theme),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const SizedBox(height: 10),
        SheetQuickActions(
          onSheet: true,
          actions: [
            QuickAction(
              icon: CupertinoIcons.link,
              label: l10n.roomInviteCopyLink,
              onTap: dead ? null : onCopyLink,
            ),
            QuickAction(
              icon: CupertinoIcons.number,
              label: l10n.roomInviteCopyCode,
              onTap: dead ? null : onCopyCode,
            ),
            QuickAction(
              icon: CupertinoIcons.square_arrow_up_fill,
              label: l10n.roomInviteShare,
              onTap: dead ? null : onShare,
            ),
          ],
        ),
      ],
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
  String _statusLine(
    BuildContext context,
    AppLocalizations l10n,
    RoomInviteLink link,
  ) {
    final uses = link.maxUses == null
        ? l10n.roomInviteUsesCount(link.useCount)
        : l10n.roomInviteUsesOfMax(link.maxUses!, link.useCount);
    if (link.expiresAt == null) return uses;
    final until = _shortDate(context, link.expiresAt!);
    return '$uses · ${l10n.roomInviteExpiresOn(until)}';
  }

}

/// The reader's own date format — "Oct 10, 2026", "10 Eki 2026" — not a
/// dotted day.month.year that reads as nonsense in an English locale.
String _shortDate(BuildContext context, DateTime d) =>
    MaterialLocalizations.of(context).formatMediumDate(d);

/// A horizontal strip of mutually-exclusive chips. Used for both limits, so
/// the two rows cannot drift apart visually the way two hand-built rows would.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.choices,
    required this.labelFor,
    required this.onChanged,
    required this.customLabel,
    required this.customActive,
    required this.onCustom,
  });

  final String label;
  final T value;
  final List<T> choices;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  /// The last chip, for a value the presets do not offer. While it is active
  /// no preset is, whatever [value] still holds.
  final String customLabel;
  final bool customActive;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A sub-label under the section's GroupedHeader, so one step
        // quieter than it — it used to out-shout "Limits" above it.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            sentenceCaseOf(context, label),
            style: groupedSubtitleStyle(theme),
          ),
        ),
        const SizedBox(height: 8),
        // Wrapped, not scrolled sideways: on a phone the last chips of a
        // scrolling row sat past the edge, and the last one is Custom — the
        // option least likely to be found by swiping for it.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in choices)
              FilterCapsule(
                label: labelFor(c),
                active: !customActive && c == value,
                onTap: () => onChanged(c),
              ),
            FilterCapsule(
              label: customLabel,
              leading: Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 14,
                color: customActive ? theme.accentInk : theme.inkSoft,
              ),
              active: customActive,
              onTap: onCustom,
            ),
          ],
        ),
      ],
    );
  }
}

/// Where a custom limit is dialled in, directly under the chips that opened
/// it. Grows open and closed rather than snapping, so the rest of the sheet
/// slides instead of jumping.
class _CustomPanel extends StatelessWidget {
  const _CustomPanel({required this.open, required this.child});
  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedSize(
      duration: theme.motionFast,
      curve: theme.motionEntrance,
      alignment: Alignment.topCenter,
      child: open
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: child,
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// Small meta text — statuses, limits, the link itself — in the theme's body
/// face at footnote size, never the tracked monospace.
TextStyle _meta(AppTheme theme) => theme.bodySoft.copyWith(
      fontSize: 13,
      color: theme.inkMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
