import 'package:flutter/foundation.dart';

import '../models/app_release.dart';
import 'release_channel.dart';

/// Whether a newer build than the one running has been published for this
/// device's channel.
///
/// Set the moment the launch check (`UpdateChecker.ensure`), a manual "Check
/// for Updates" tap (`UpdateChecker.checkNow`), or the live subscription
/// (`UpdateChecker.watch`) discovers one, and read by `HomeShell`'s nav badge
/// map and the settings row itself so both stay in sync without either one
/// re-deriving the answer.
///
/// Deliberately session-only: nothing here survives a restart, because a
/// fresh launch re-runs the check and rebuilds the same answer from the
/// backend.
///
/// It *is* cleared by [clear], but only by the live subscription and only on a
/// well-formed release row that isn't newer than the running build. The old
/// "never cleared" stance was right when the only source was a one-shot check
/// — a manual tap that failed to see an update shouldn't erase one we'd
/// already found. A subscription is authoritative, so it should be able to
/// retract a signal a rollback or an unpublish has made false. Nulls and
/// subscription errors still never clear anything: those are transport
/// states, not answers.
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

  /// Retracts a previously reported update. The early return keeps a stream of
  /// "still up to date" deliveries from rebuilding every nav chrome for nothing.
  void clear() {
    if (_release == null) return;
    _release = null;
    _channel = null;
    _currentVersion = null;
    _mandatory = false;
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
