/// What the store this copy was installed from says about updating it.
///
/// The backend's release row says what deploy.sh *uploaded*, which for a store
/// is not what anyone can install: an App Store build sits in review for days,
/// a Microsoft Store submission in certification, a Play upload on the
/// internal track. Where the platform can ask its own store, that answer wins
/// and the row is reduced to what only we can decide (`minSupported`, notes).
enum StoreVerdict {
  /// No store can answer for this channel (TestFlight, web, Linux, the
  /// retired APK). The release row decides, as it always has.
  notApplicable,

  /// The store should have answered and didn't: offline, rate-limited, a
  /// listing not live yet. A transport state, not an answer, so it must never
  /// clear a badge or raise a prompt.
  noAnswer,

  /// The store has nothing newer for this install.
  upToDate,

  /// The store can install a newer build right now.
  available,
}

class StoreAnswer {
  const StoreAnswer(this.verdict, {this.version});

  static const notApplicable = StoreAnswer(StoreVerdict.notApplicable);
  static const noAnswer = StoreAnswer(StoreVerdict.noAnswer);
  static const upToDate = StoreAnswer(StoreVerdict.upToDate);

  final StoreVerdict verdict;

  /// The version the store would install, when it says. The App Store lookup
  /// and the Microsoft Store both do; Play reports only a version code, so for
  /// Play this is null and the row's version stands in for display.
  final String? version;
}
