import Foundation

/// One chat the extension can send to, as the app last knew it.
///
/// Deliberately the same shape the share sheet's suggestions are built from
/// (`ShareTarget` in lib/share/share_targets.dart) — it is the same list, and
/// keeping one shape means the picker inside the extension and the row of faces
/// above it can never disagree about which chats exist.
struct ShareChat: Codable {
    let id: String
    let title: String
    let initial: String
    let gradientStart: Int
    let gradientEnd: Int
    let avatarUrl: String?
    let isGroup: Bool
}

/// Everything the extension needs in order to send without the app.
///
/// Written by the app (see `ShareCache` in the Runner target) whenever the chat
/// list changes, and deleted on sign-out. Read by the extension, which has no
/// other way to know any of it — a separate binary in a separate sandbox with no
/// Flutter engine, no Convex client, and no session of its own.
///
/// ### Why this is enough to send
///
/// `messages:send` takes the user id as an ordinary argument and there is no
/// bearer token anywhere in this app's Convex calls. So `userId` plus
/// `deploymentUrl` is the entire credential, and a plain `URLSession` against
/// Convex's HTTP API can do what the Dart client does. That is a property of
/// the backend's design rather than a trick — see `ConvexHTTP.swift`.
///
/// ### What that means for privacy
///
/// This file is a list of the user's most recent chats sitting in a container
/// that survives the app being closed. It is inside the app group (readable
/// only by these two binaries, both signed by the same team) and it is
/// **deleted on sign-out**, which is what stops the previous account's chats
/// being offered to whoever signs in next on a shared handset.
struct ShareSession: Codable {
    let userId: String
    let deploymentUrl: String
    let chats: [ShareChat]

    /// The app's own display name, sent as `senderName` so a push from a
    /// message composed in the extension reads like every other one.
    let senderName: String?

    static func load() -> ShareSession? {
        guard
            let url = ShareGroup.sessionURL,
            let data = try? Data(contentsOf: url),
            let session = try? JSONDecoder().decode(ShareSession.self, from: data),
            !session.userId.isEmpty,
            !session.deploymentUrl.isEmpty
        else { return nil }
        return session
    }

    /// Writes atomically, protected, and out of backups.
    ///
    /// Three deliberate choices, because this file is the one place a user id
    /// and a list of their chats sit on DISK rather than in the keychain:
    ///
    ///  * `.atomic` — a half-written session read by an extension launching at
    ///    the same moment decodes to nil and silently disables sending.
    ///  * `.completeFileProtectionUntilFirstUserAuthentication` — matches the
    ///    keychain accessibility the app already stores its session under
    ///    (`first_unlock_this_device`, see SessionStore). Unreadable before the
    ///    first unlock after a boot, which is the same bar the session itself
    ///    is held to. NOT `.complete`: a share can arrive while the phone is
    ///    locked, and a file nothing can read then is a feature that fails.
    ///  * excluded from backups — a device backup restored onto another handset
    ///    must not carry a signed-in user id into it. The keychain half already
    ///    behaves this way (`ThisDeviceOnly`); this makes the two agree.
    func save() {
        guard let url = ShareGroup.sessionURL else { return }
        guard let data = try? JSONEncoder().encode(self) else { return }
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var resource = URLResourceValues()
            resource.isExcludedFromBackup = true
            var mutableURL = url
            try? mutableURL.setResourceValues(resource)
        } catch {
            NSLog("[share] could not write the session cache: \(error.localizedDescription)")
        }
    }

    static func clear() {
        guard let url = ShareGroup.sessionURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
