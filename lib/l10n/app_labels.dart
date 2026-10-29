import 'dart:ui' show Locale;

import '../diagnostics/device_report.dart';
import 'generated/app_localizations.dart';

/// The app's strings in its settled language (recorded by the root builder),
/// English when it is not known yet — for code with no BuildContext to ask,
/// such as the native call notification and the Linux desktop banner.
AppLocalizations appLabels() {
  final tag = DeviceReport.appLocaleTag;
  if (tag != null) {
    final parts = tag.split('-');
    String? script;
    String? country;
    for (final p in parts.skip(1)) {
      if (p.length == 4) {
        script = p;
      } else {
        country = p;
      }
    }
    try {
      return lookupAppLocalizations(Locale.fromSubtags(
        languageCode: parts.first,
        scriptCode: script,
        countryCode: country,
      ));
    } catch (_) {}
  }
  return lookupAppLocalizations(const Locale('en'));
}
