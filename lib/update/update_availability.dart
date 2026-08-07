import 'package:flutter/foundation.dart';

import '../models/app_release.dart';
import 'release_channel.dart';

/// Whether a newer build than the one running has been published for this
/// device's channel.
///
/// Set the moment either the launch check (`UpdateChecker.ensure`) or a
/// manual "Check for Updates" tap (`UpdateChecker.checkNow`) discovers one,
/// and read by `HomeShell`'s nav badge map and the settings row itself so
/// both stay in sync without either one re-deriving the answer.
///
/// Deliberately session-only: nothing here survives a restart, because a
/// fresh launch re-runs the check and rebuilds the same answer from the
/// backend. It is also never cleared by an "up to date" result — a stale
/// "there's an update" signal only self-corrects on the next cold start,
/// which matches `UpdateChecker`'s existing "LATER is a 'not now', not a
/// 'stop asking'" stance.
class UpdateAvailability extends ChangeNotifier {
  UpdateAvailability._();
  static final UpdateAvailability instance = UpdateAvailability._();

  AppRelease? _release;
  ReleaseChannel? _channel;
  String? _currentVersion;
  bool _mandatory = false;

  bool get available => _release != null;
  AppRelease? get release => _release;
  ReleaseChannel? get channel => _channel;
  String? get currentVersion => _currentVersion;
  bool get mandatory => _mandatory;

  void report({
    required AppRelease release,
    required ReleaseChannel channel,
    required String currentVersion,
    required bool mandatory,
  }) {
    _release = release;
    _channel = channel;
    _currentVersion = currentVersion;
    _mandatory = mandatory;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _release = null;
    _channel = null;
    _currentVersion = null;
    _mandatory = false;
  }
}
