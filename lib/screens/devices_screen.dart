import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/user_device.dart';
import '../push/device_identity.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/destructive_sheet.dart';

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
          _error = AppLocalizations.of(context).devicesScreenLoadFailed;
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
      headline: l10n.devicesScreenRemoveTitle,
      body: l10n.devicesScreenRemoveBody(_label(context, device)),
      confirmLabel: l10n.devicesScreenRemoveConfirm,
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
      headline: l10n.devicesScreenRemoveAllTitle,
      body: l10n.devicesScreenRemoveAllBody,
      confirmLabel: l10n.devicesScreenRemoveAllConfirm,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).devicesScreenRemovedCount(removed),
            ),
          ),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.inkSoft,
                          size: 18,
                        ),
                      ),
                      Text(
                        l10n.devicesScreenTitle,
                        style: theme.label.copyWith(letterSpacing: 2.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.devicesScreenSubtitle, style: theme.bodySoft),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: theme.body.copyWith(color: theme.danger),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (devices == null)
                    Text(l10n.devicesScreenLoading, style: theme.bodySoft)
                  else
                    for (final device in devices) ...[
                      _DeviceCard(
                        label: _label(context, device),
                        device: device,
                        busy: _busyDeviceId == device.deviceId,
                        enabled: _busyDeviceId == null && !_busyAll,
                        onRemove: () => _remove(device),
                      ),
                      const SizedBox(height: 10),
                    ],
                  if (others > 0) ...[
                    const SizedBox(height: 14),
                    _RemoveAllRow(
                      busy: _busyAll,
                      enabled: _busyDeviceId == null && !_busyAll,
                      onTap: _removeOthers,
                    ),
                  ],
                  const SizedBox(height: 20),
                  // The honest footnote. See the class doc: this screen must
                  // not read as a remote kill switch while it isn't one.
                  Text(
                    l10n.devicesScreenFootnote,
                    style: theme.bodySoft.copyWith(color: theme.inkMuted),
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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: theme.inputDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.body.copyWith(color: theme.ink),
                      ),
                    ),
                    if (device.isThis) ...[
                      const SizedBox(width: 8),
                      Text(
                        l10n.devicesScreenThisDevice,
                        style: theme.label.copyWith(color: theme.accent),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${device.platform} · ${_seen(context, device)}',
                  style: theme.bodySoft.copyWith(color: theme.inkMuted),
                ),
                // Said out loud rather than left to be inferred from silence:
                // a device that cannot be reached still belongs on this list,
                // and "why didn't my iPad buzz" is answered here.
                if (!device.reachable) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.devicesScreenNoNotifications,
                    style: theme.bodySoft.copyWith(color: theme.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          // No Remove on this device: signing yourself out lives on the
          // profile screen, and offering it here would make the row that says
          // "this device" the easiest one to destroy by accident.
          if (!device.isThis)
            busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.inkMuted,
                    ),
                  )
                : FocusableTap(
                    onTap: enabled ? onRemove : null,
                    semanticLabel: l10n.devicesScreenRemove,
                    child: GestureDetector(
                      onTap: enabled ? onRemove : null,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          l10n.devicesScreenRemove,
                          style: theme.label.copyWith(
                            color: enabled ? theme.danger : theme.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  /// Coarse on purpose. A device seen four minutes ago and one seen six are
  /// the same fact to the person reading, and a precise timestamp would only
  /// invite them to reason about a clock they cannot see.
  static String _seen(BuildContext context, UserDevice d) {
    final l10n = AppLocalizations.of(context);
    final delta = DateTime.now().difference(d.lastSeenAt);
    if (delta.inMinutes < 2) return l10n.devicesScreenActiveNow;
    if (delta.inHours < 1) return l10n.devicesScreenMinutesAgo(delta.inMinutes);
    if (delta.inDays < 1) return l10n.devicesScreenHoursAgo(delta.inHours);
    return l10n.devicesScreenDaysAgo(delta.inDays);
  }
}

class _RemoveAllRow extends StatelessWidget {
  const _RemoveAllRow({
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: enabled ? onTap : null,
      semanticLabel: l10n.devicesScreenRemoveAll,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              if (busy) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.inkMuted,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Flexible, not bare: this label is a full sentence, and it is
              // the longest string on the screen in several languages
              // ("Diğer tüm cihazları kaldır", "Quitar todos los demás
              // dispositivos"). Unconstrained in a Row it overflowed the width
              // outright — caught by rendering the screen, not by the tests,
              // which all passed while it was broken.
              Flexible(
                child: Text(
                  l10n.devicesScreenRemoveAll,
                  style: theme.body.copyWith(
                    color: enabled ? theme.danger : theme.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
