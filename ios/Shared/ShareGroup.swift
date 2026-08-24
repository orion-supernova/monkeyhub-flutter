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

  static var containerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
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
