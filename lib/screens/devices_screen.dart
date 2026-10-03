import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/user_device.dart';
import '../push/device_identity.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/app_toast.dart';
import '../widgets/destructive_sheet.dart';
import '../widgets/ios_kit.dart';

/// Every device this account has signed in on.
///
/// ## What "remove" means here, precisely
///
/// It deletes the device's `userDevices` row: notifications stop reaching it,
/// it disappears from this list, and it stops being offered as a "Move call
/// here" target. It does **not** sign that device out — this backend has no
/// sessions to revoke, so a removed device whose app is still open keeps
/// working until someone signs it out from the device itself.
///
/// The copy on this screen says exactly that, and the button is labelled
/// "remove" rather than "sign out" or "terminate" for the same reason. A
/// control that reads like a remote kill switch and isn't one is worse than no
/// control at all: it is the screen someone opens *because* they think a phone
/// was stolen, and it must not send them away reassured. When sessions land,
/// this screen's promise gets stronger and its copy changes with it — see
/// `devicesScreenFootnote`.
///
/// ## Why a one-shot read
///
/// `listDevices` is fetched on open and after each change rather than
/// subscribed. The list only moves when the user signs in somewhere or removes
/// a row — neither of which happens while they are looking at this screen —
/// and a live subscription would be one more fan-out on a table every push
/// registration writes to.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, required this.auth, required this.api});

  final AuthService auth;
  final ChatApi api;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  /// Null while unknown — the body renders a quiet loading state rather than
  /// an empty list, which would read as "you have no devices" on a screen
  /// whose whole job is to be believed.
  List<UserDevice>? _devices;

  /// The row currently being removed, so only its own control shows a spinner.
  String? _busyDeviceId;
  bool _busyAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final userId = widget.auth.session?.userId;
    if (userId == null) return;
    try {
      final deviceId = await DeviceIdentity.ensure();
      final devices = await widget.api.listDevices(
        userId: userId,
        deviceId: deviceId,
      );
      if (mounted) setState(() => _devices = devices);
    } catch (_) {
      // Offline, or a backend without these functions yet. Null keeps the
      // screen honest about not knowing instead of claiming an empty list.
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).acctDevicesLoadFailed;
        });
      }
    }
  }

  Future<void> _remove(UserDevice device) async {
    final userId = widget.auth.session?.userId;
    if (userId == null || _busyDeviceId != null || _busyAll) return;
    final l10n = AppLocalizations.of(context);
    final go = await showConfirmSheet(
      context,
      headline: l10n.acctRemoveDeviceTitle,
      body: l10n.devicesScreenRemoveBody(_label(context, device)),
      confirmLabel: l10n.acctRemove,
    );
    if (!go || !mounted) return;
    setState(() {
      _busyDeviceId = device.deviceId;
      _error = null;
    });
    try {
      await widget.api.clearDeviceToken(
        userId: userId,
        deviceId: device.deviceId,
      );
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).devicesScreenRemoveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busyDeviceId = null);
    }
  }

  Future<void> _removeOthers() async {
    final userId = widget.auth.session?.userId;
    if (userId == null || _busyDeviceId != null || _busyAll) return;
    final l10n = AppLocalizations.of(context);
    final go = await showConfirmSheet(
      context,
      headline: l10n.acctRemoveAllTitle,
      body: l10n.devicesScreenRemoveAllBody,
      confirmLabel: l10n.acctRemoveAll,
    );
    if (!go || !mounted) return;
    setState(() {
      _busyAll = true;
      _error = null;
    });
    try {
      final deviceId = await DeviceIdentity.ensure();
      final removed = await widget.api.removeOtherDevices(
        userId: userId,
        deviceId: deviceId,
      );
      await _refresh();
      if (mounted) {
        showAppToast(
          context,
          AppLocalizations.of(context).devicesScreenRemovedCount(removed),
        
          tone: ToastTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).devicesScreenRemoveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busyAll = false);
    }
  }

  /// What to call a device: whatever its OS calls itself, or the friendly
  /// platform name. Never the raw deviceId — a UUID identifies nothing to a
  /// reader trying to spot the phone they lost.
  static String _label(BuildContext context, UserDevice d) {
    final name = d.deviceName;
    if (name != null && name.isNotEmpty) return name;
    return DeviceIdentity.friendlyPlatformLabelFor(d.platform);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final devices = _devices;
    final others = devices?.where((d) => !d.isThis).length ?? 0;
    return IosPage(
      title: l10n.acctRowDevices,
      subtitle: l10n.devicesScreenSubtitle,
      slivers: readableSlivers(context, [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: SoftNote(
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              text: _error!,
              tone: theme.danger,
            ),
          ),
        if (devices == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: CupertinoActivityIndicator(color: theme.inkMuted),
            ),
          )
        else
          GroupedSection(
            footer: others > 0 ? null : l10n.devicesScreenFootnote,
            children: [
              for (final device in devices)
                _DeviceRow(
                  label: _label(context, device),
                  device: device,
                  busy: _busyDeviceId == device.deviceId,
                  enabled: _busyDeviceId == null && !_busyAll,
                  onRemove: () => _remove(device),
                ),
            ],
          ),
        if (others > 0)
          GroupedSection(
            footer: l10n.devicesScreenFootnote,
            children: [
              GroupedRow(
                title: l10n.devicesScreenRemoveAll,
                destructive: true,
                trailing: _busyAll
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(
                          radius: 8,
                          color: theme.inkMuted,
                        ),
                      )
                    : null,
                onTap: (_busyDeviceId == null && !_busyAll)
                    ? _removeOthers
                    : null,
              ),
            ],
          ),
      ]),
    );
  }
}

/// One signed-in device: a platform glyph on a tile, its name, where and when
/// it was last seen, and — for anything but this phone — a way to sign it out.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.label,
    required this.device,
    required this.busy,
    required this.enabled,
    required this.onRemove,
  });

  final String label;
  final UserDevice device;
  final bool busy;
  final bool enabled;
  final VoidCallback onRemove;

  IconData get _glyph {
    final p = device.platform.toLowerCase();
    if (p.contains('ios') || p.contains('iphone')) {
      return CupertinoIcons.device_phone_portrait;
    }
    if (p.contains('android')) return CupertinoIcons.device_phone_portrait;
    if (p.contains('ipad')) return CupertinoIcons.device_laptop;
    if (p.contains('web') || p.contains('browser')) return CupertinoIcons.globe;
    return CupertinoIcons.device_desktop;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final seen = _seen(context, device);
    return GroupedRow(
      icon: _glyph,
      tone: device.isThis ? TileTone.accent : TileTone.gray,
      title: label,
      subtitle: [
        device.isThis ? l10n.acctThisDevice : seen,
        if (!device.reachable) l10n.acctNoNotifications,
      ].join(' · '),
      chevron: false,
      trailing: device.isThis
          ? null
          : busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CupertinoActivityIndicator(
                    radius: 9,
                    color: theme.inkMuted,
                  ),
                )
              : FocusableTap(
                  onTap: enabled ? onRemove : null,
                  semanticLabel: l10n.acctRemove,
                  radius: 999,
                  child: GestureDetector(
                    onTap: enabled ? onRemove : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.danger.withValues(
                          alpha: enabled ? 0.12 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.acctRemove,
                        style: theme.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: enabled ? theme.danger : theme.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  static String _seen(BuildContext context, UserDevice d) {
    final l10n = AppLocalizations.of(context);
    final delta = DateTime.now().difference(d.lastSeenAt);
    if (delta.inMinutes < 2) return l10n.acctActiveNow;
    if (delta.inHours < 1) return l10n.devicesScreenMinutesAgo(delta.inMinutes);
    if (delta.inDays < 1) return l10n.devicesScreenHoursAgo(delta.inHours);
    return l10n.devicesScreenDaysAgo(delta.inDays);
  }
}
