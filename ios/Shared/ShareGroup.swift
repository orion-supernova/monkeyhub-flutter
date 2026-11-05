import Foundation

/// The one place the app and its Share Extension agree.
///
/// Compiled into BOTH targets (see `tool/setup_ios_share_extension.rb`) rather
/// than duplicated, because every constant here is one half of a handshake
/// between two separately-signed binaries — and the failure mode of a
/// disagreement is silence, not an error. A container path that does not match
/// is an empty directory; a URL scheme that does not match is a share sheet
/// that dismisses and does nothing.
enum ShareGroup {

  /// The App Group both binaries read and write.
  ///
  /// **This is a provisioning fact, not just a string.** It has to be enabled
  /// on BOTH App IDs in the Apple Developer portal — the app's and the
  /// extension's — and listed in both `.entitlements` files. If it is missing
  /// from either, `containerURL` returns nil at runtime and no error is raised
  /// anywhere. See SHARE_SHEET.md.
  static let identifier = "group.com.walhallaa.monkeyhub"

  /// Where the extension stages what it was handed. One sub-directory per
  /// share, named with a UUID, so a second share arriving while the first is
  /// still being placed cannot overwrite it.
  static let inboxName = "SharedInbox"

  /// The JSON the extension writes last, and the app looks for first.
  ///
  /// Written AFTER the attachments and by an atomic move, so its presence is
  /// what makes a directory ready — the app can never find a manifest that
  /// describes files which are still being copied.
  static let manifestName = "payload.json"

  /// What the app leaves behind so the extension can send WITHOUT the app.
  ///
  /// The deployment URL, the signed-in user id, and the same recent-chat list
  /// the share sheet's top row is built from. Refreshed by the app whenever
  /// that list changes and deleted on sign-out.
  ///
  /// This is the whole reason the extension needs no Flutter engine, no Convex
  /// client and no login of its own: `messages:send` takes the user id as an
  /// ordinary argument, so with these three facts a plain `URLSession` can do
  /// the entire job. See `ConvexHTTP.swift`.
  static let sessionName = "session.json"

  static var sessionURL: URL? {
    containerURL?.appendingPathComponent(sessionName)
  }

  /// Wakes the app. Shares the invite link's scheme (already registered on
  /// every platform) with a path the invite parser explicitly refuses —
  /// `kSharePathSegment` in lib/invites/invite_link.dart, which is the other
  /// half of this constant.
  static let hostURL = URL(string: "monkeyhub://share/open")!

  /// Mirrors `kMaxFileUploadBytes` (lib/media/file_meta.dart) and
  /// `ShareIntake.MAX_UPLOAD_BYTES` on Android.
  ///
  /// Enforced here so the extension does not spend its (small) memory and time
  /// budget copying a two-gigabyte video the composer would refuse anyway.
  static let maxUploadBytes: Int64 = 20 * 1024 * 1024

  /// Mirrors `kMaxMediaIntakeBytes` (lib/media/file_meta.dart) and
  /// `ShareIntake.MAX_MEDIA_INTAKE_BYTES` on Android: the cap for a photo or
  /// video, which is compressed down to [maxUploadBytes] before it goes. Past
  /// it the copy alone outlasts anyone's patience for a clip too long to fit
  /// at any quality.
  static let maxMediaIntakeBytes: Int64 = 500 * 1024 * 1024

  /// Which cap applies to [mimeType]. Mirrors `intakeCapFor` in Dart.
  static func intakeCap(for mimeType: String) -> Int64 {
    mimeType.hasPrefix("image/") || mimeType.hasPrefix("video/")
      ? maxMediaIntakeBytes
      : maxUploadBytes
  }

  /// Where the Notification Service Extension parks an arriving chat message
  /// for the app to pick up — one file per message, named by its id.
  ///
  /// A second, unrelated inbox alongside [inboxName], and deliberately so: that
  /// one carries shares INTO the app and is a multi-file staging area with a
  /// manifest; this one carries a single small JSON per message and is read and
  /// emptied in one pass.
  ///
  /// One file per message rather than one appended log, because iOS can run
  /// several extension instances at once for a burst and a read-modify-write
  /// would race itself. Naming by message id makes a repeat delivery idempotent
  /// for free.
  static let pushInboxName = "PushInbox"

  /// Ceiling on parked files, oldest dropped first — a device that never opens
  /// the app again must not accumulate these forever.
  static let pushInboxMax = 100

  static var containerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
  }

  /// The push inbox, created if it does not exist. Nil only when the App Group
  /// is missing from this binary's entitlements or its provisioning profile.
  static func pushInboxURL(create: Bool = false) -> URL? {
    guard let container = containerURL else { return nil }
    let url = container.appendingPathComponent(pushInboxName, isDirectory: true)
    if create {
      try? FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: true
      )
    }
    return url
  }

  /// Park one push's own `data` map, verbatim.
  ///
  /// The RAW map and nothing else: this side does not know what a message is,
  /// and should not — `ChatRepository.takePushedMessages` owns that, in one
  /// language. Best-effort in the strongest sense, since the caller is on its
  /// way to showing a notification and nothing here may prevent or delay that.
  static func stagePush(_ data: [String: String]) {
    guard let messageId = data["messageId"], !messageId.isEmpty else { return }
    guard let dir = pushInboxURL(create: true) else {
      NSLog("[push] no App Group container — is \(identifier) provisioned on this target?")
      return
    }
    let fm = FileManager.default
    if let existing = try? fm.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
    ), existing.count >= pushInboxMax {
      let oldest = existing.sorted {
        let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
          .contentModificationDate ?? .distantPast
        let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?
          .contentModificationDate ?? .distantPast
        return a < b
      }
      for url in oldest.prefix(existing.count - pushInboxMax + 1) {
        try? fm.removeItem(at: url)
      }
    }
    guard let json = try? JSONSerialization.data(withJSONObject: data) else { return }
    try? json.write(
      to: dir.appendingPathComponent("\(messageId).json"), options: .atomic
    )
  }

  /// Hand the app everything parked since it last asked, and empty the inbox.
  ///
  /// Destructive: a stub stands in for a round trip that is about to happen,
  /// not for the transcript. If the process dies before the live data lands,
  /// these should die with it rather than come back on the next launch as
  /// something indistinguishable from server truth.
  static func takePushInbox() -> [[String: String]] {
    guard let dir = pushInboxURL() else { return [] }
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
    ) else { return [] }
    let ordered = files.sorted {
      let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      return a < b
    }
    var out: [[String: String]] = []
    for url in ordered {
      if let data = try? Data(contentsOf: url),
         let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        out.append(obj.compactMapValues { "\($0)" })
      }
      try? fm.removeItem(at: url)
    }
    return out
  }

  /// Empty the push inbox without handing it to anyone.
  ///
  /// For a sign-out. The inbox can only ever hold pushes addressed to the
  /// session that was live when they arrived, which is the whole of the
  /// account-safety story — no recipient id has to travel in the payload,
  /// because ending the session empties the box.
  static func clearPushInbox() {
    guard let dir = pushInboxURL() else { return }
    try? FileManager.default.removeItem(at: dir)
  }

  /// The inbox, created if it does not exist. Nil only when the App Group is
  /// missing from this binary's entitlements or its provisioning profile.
  static func inboxURL(create: Bool = false) -> URL? {
    guard let container = containerURL else { return nil }
    let url = container.appendingPathComponent(inboxName, isDirectory: true)
    if create {
      try? FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: true
      )
    }
    return url
  }
}

/// Whether a chat message should make a sound, per room — the same rule with
/// the same two numbers as lib/push/alert_burst.dart (desktop) and
/// ChatNotifications.kt (Android); keep them in step.
///
/// A message within `gap` of the room's previous one is the same burst and
/// arrives quietly; however long a burst runs, it alerts again after
/// `reminder`; a mention always alerts.
///
/// Kept in the App Group's defaults because every push may be a fresh
/// extension process, so nothing in memory survives from one to the next.
///
/// Here rather than in NotificationService.swift because the APP has to be
/// able to end a burst too ([forget]). The extension runs for every push,
/// including the ones `willPresent` then swallows because the room is on
/// screen, so counting alone it took a live conversation for one long burst:
/// you put the phone down mid-chat and the next replies all landed silent,
/// with no banner, because the lines you had just read on screen were still
/// "the room's previous one". Android never had this: its suppression
/// returns before it reaches the burst rule.
enum AlertBurst {
  static let gap: TimeInterval = 45
  static let reminder: TimeInterval = 180
  private static let key = "mh.alertBurst"

  private static let lock = NSLock()

  /// Ends [roomId]'s burst, so its next push alerts. Called by the app when
  /// the person has seen the room: a push it hid because the room was on
  /// screen, or the room being read. Neither is a line that went unheard,
  /// and a burst is a run of lines that did.
  static func forget(roomId: String) {
    lock.lock()
    defer { lock.unlock() }
    let defaults = UserDefaults(suiteName: ShareGroup.identifier) ?? .standard
    guard var rooms = defaults.dictionary(forKey: key) as? [String: [Double]],
          rooms.removeValue(forKey: roomId) != nil
    else { return }
    defaults.set(rooms, forKey: key)
  }

  static func shouldAlert(roomId: String, mention: Bool, now: Date = Date()) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    let defaults = UserDefaults(suiteName: ShareGroup.identifier) ?? .standard
    var rooms = defaults.dictionary(forKey: key) as? [String: [Double]] ?? [:]
    let t = now.timeIntervalSince1970
    // Rooms quiet for longer than the reminder can only alert next time, so
    // forgetting them changes nothing and keeps this from growing per room.
    rooms = rooms.filter { t - ($0.value.first ?? 0) < reminder }
    let prev = rooms[roomId]
    let alert: Bool
    if let prev, prev.count == 2, !mention,
       t - prev[0] < gap, t - prev[1] < reminder {
      alert = false
      rooms[roomId] = [t, prev[1]]
    } else {
      alert = true
      rooms[roomId] = [t, t]
    }
    defaults.set(rooms, forKey: key)
    return alert
  }
}
