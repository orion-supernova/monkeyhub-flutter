import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart' show GroupedFooter;
import '../widgets/sheet_kit.dart';
import 'call_audio_devices.dart';
import 'call_media.dart' show isMobileCallPlatform;
import 'widgets/call_chrome.dart';

/// The audio control in both call trays, and the sheets behind it.
///
/// On a phone it is the speaker button: a toggle while only the earpiece
/// and the loudspeaker exist, the route sheet once a headset is a choice,
/// showing the route the sound is really on either way. On desktop and web
/// it opens the microphone and speaker picker.
///
/// [speakerOn] is the call's flag (the fallback look before the platform
/// reports a route), [onToggleSpeaker] the services' `toggleSpeaker`,
/// [selectSpeaker] their `selectSpeaker`, and [switchWebMic] the web call's
/// microphone swap ([switchWebMicrophone] over its stream and connections).
CallTrayAction callAudioTrayAction(
  BuildContext context, {
  required bool speakerOn,
  required VoidCallback onToggleSpeaker,
  required Future<void> Function(bool on) selectSpeaker,
  required Future<bool> Function(String deviceId) switchWebMic,
  Key? key,
}) {
  final l10n = AppLocalizations.of(context);
  final devices = CallAudioDevices.instance;
  if (!isMobileCallPlatform) {
    return CallTrayAction(
      key: key,
      icon: CallGlyphs.audioDevices,
      label: l10n.callAudioControlLabel,
      onTap: () => unawaited(showAdaptiveSheet<void>(
        context,
        builder: (_) => CallAudioDevicesSheet(switchWebMic: switchWebMic),
      )),
    );
  }
  final output = devices.output;
  final look = callAudioButtonLook(
    output: output,
    speakerOn: speakerOn,
    name: devices.outputName,
  );
  final picker = devices.needsPicker;
  final headset = isHeadsetOutput(output);
  final routeLabel = headset
      ? callAudioRouteLabel(l10n, output!, devices.outputName)
      : null;
  return CallTrayAction(
    key: key,
    icon: look.icon,
    glyph: look.glyph,
    active: look.active,
    // On a headset the button names it; with a choice to make and the
    // sound on the phone it is "Audio", since a tap no longer just toggles.
    label: headset
        ? callAudioRouteLabel(l10n, output!, null)
        : picker
            ? l10n.callAudioControlLabel
            : l10n.callScreenControlSpeaker,
    semanticLabel: routeLabel == null
        ? null
        : '${l10n.callAudioControlLabel}: $routeLabel',
    onTap: picker
        ? () => unawaited(showAdaptiveSheet<void>(
              context,
              builder: (_) => CallAudioRouteSheet(selectSpeaker: selectSpeaker),
            ))
        : onToggleSpeaker,
  );
}

/// A route's name in the sheet and under the button: the device's own name
/// where it has one worth reading (AirPods, a car, "iPhone"), else the
/// kind's.
String callAudioRouteLabel(
  AppLocalizations l10n,
  CallAudioOutputKind kind,
  String? name,
) {
  switch (kind) {
    case CallAudioOutputKind.speaker:
      return l10n.callScreenControlSpeaker;
    case CallAudioOutputKind.headphones:
      return l10n.callAudioRouteHeadphones;
    case CallAudioOutputKind.earpiece:
      return name ?? l10n.callAudioRoutePhone;
    case CallAudioOutputKind.bluetooth:
      return name ?? l10n.callAudioRouteBluetooth;
    case CallAudioOutputKind.car:
      return name ?? l10n.callAudioRouteCar;
    case CallAudioOutputKind.airplay:
      return name ?? 'AirPlay';
    case CallAudioOutputKind.other:
      return name ?? l10n.callAudioRouteOther;
  }
}

/// The phone route sheet, FaceTime's audio menu: every route, the current
/// one checked, and a note that the microphone moves with it.
class CallAudioRouteSheet extends StatelessWidget {
  const CallAudioRouteSheet({super.key, required this.selectSpeaker});

  final Future<void> Function(bool on) selectSpeaker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final devices = CallAudioDevices.instance;
    return ListenableBuilder(
      listenable: devices,
      builder: (context, _) {
        final routes = devices.routes;
        return SheetFrame(
          title: l10n.callAudioSheetTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetGroup(
                children: [
                  for (final r in routes)
                    GroupedRow.choice(
                      key: ValueKey('route-${r.kind.name}-${r.id}'),
                      icon: callAudioRouteGlyph(r.kind),
                      tone: r.isHeadset ? TileTone.blue : TileTone.gray,
                      title: callAudioRouteLabel(l10n, r.kind, r.name),
                      selected: r.selected,
                      onTap: () {
                        Navigator.of(context).maybePop();
                        if (r.selected) return;
                        unawaited(devices.selectRoute(
                          r,
                          setSpeaker: selectSpeaker,
                        ));
                      },
                    ),
                ],
              ),
              GroupedFooter(l10n.callAudioMicFollowsNote),
            ],
          ),
        );
      },
    );
  }
}

/// Desktop and web: the microphone and the speaker, from the system's
/// devices, the session's pick checked. The speaker section is left out
/// where the browser cannot route output (no devices listed).
class CallAudioDevicesSheet extends StatelessWidget {
  const CallAudioDevicesSheet({super.key, required this.switchWebMic});

  final Future<bool> Function(String deviceId) switchWebMic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final devices = CallAudioDevices.instance;
    return ListenableBuilder(
      listenable: devices,
      builder: (context, _) {
        final inChecked = checkedDeviceId(devices.inputs, devices.chosenInputId);
        final outChecked =
            checkedDeviceId(devices.outputs, devices.chosenOutputId);
        String name(String label) =>
            label.isEmpty ? l10n.callAudioUnknownDevice : label;
        void failed() => AppToast.of(context)
            .show(l10n.callAudioSwitchFailed, tone: ToastTone.danger);
        return SheetFrame(
          title: l10n.callAudioSheetTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetGroup(
                header: l10n.callAudioMicrophoneHeader,
                children: [
                  for (final d in devices.inputs)
                    GroupedRow.choice(
                      key: ValueKey('mic-${d.deviceId}'),
                      title: name(d.label),
                      selected: d.deviceId == inChecked,
                      onTap: () async {
                        if (d.deviceId == inChecked) return;
                        final ok = await devices.selectInput(
                          d.deviceId,
                          switchWeb: switchWebMic,
                        );
                        if (!ok && context.mounted) failed();
                      },
                    ),
                ],
              ),
              if (devices.inputs.isEmpty)
                GroupedFooter(l10n.callAudioNoDevices),
              if (devices.outputSelectable) ...[
                const SizedBox(height: 22),
                SheetGroup(
                  header: l10n.callScreenControlSpeaker,
                  children: [
                    for (final d in devices.outputs)
                      GroupedRow.choice(
                        key: ValueKey('out-${d.deviceId}'),
                        title: name(d.label),
                        selected: d.deviceId == outChecked,
                        onTap: () async {
                          if (d.deviceId == outChecked) return;
                          final ok = await devices.selectOutput(d.deviceId);
                          if (!ok && context.mounted) failed();
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}
