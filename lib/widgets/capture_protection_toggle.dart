import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../privacy/capture_protection.dart';
import 'ios_kit.dart';

class CaptureProtectionToggle extends StatefulWidget {
  const CaptureProtectionToggle({super.key});

  @override
  State<CaptureProtectionToggle> createState() => _CaptureProtectionToggleState();
}

class _CaptureProtectionToggleState extends State<CaptureProtectionToggle> {
  Future<void> _toggle(bool v) async {
    HapticFeedback.lightImpact();
    await SettingsStore.instance.setCaptureProtection(v);
    await CaptureProtection.instance.setUserEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final on = SettingsStore.instance.captureProtection;
        return GroupedRow.toggle(
          icon: on ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
          tone: TileTone.indigo,
          title: l10n.acctCaptureTitle,
          subtitle: on
              ? (!kIsWeb && Platform.isAndroid)
                  ? l10n.acctCaptureOnAndroid
                  : l10n.acctCaptureOnIos
              : l10n.acctCaptureOff,
          value: on,
          onChanged: _toggle,
        );
      },
    );
  }
}
