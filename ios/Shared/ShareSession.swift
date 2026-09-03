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
/// Every authenticated function on this backend takes a `sessionToken` — see
/// `withToken` in `backend/convex/functions.ts`, which injects it into all of
/// them — and `messages:send` takes the sender's user id as an ordinary
/// argument beside it. So the deployment URL, the user id and the token are the
/// whole of what a plain `URLSession` needs to do what the Dart client does.
///
/// It was not always three. The backend once authenticated nothing and the
/// user id alone was the credential, which is what this extension was written
/// against; when `functions.ts` gained the wrapper, every send from here
/// started failing with `ArgumentValidationError: Object is missing the
/// required field \`sessionToken\``. `share_contract_test.dart` now pins the
/// token's argument name against `SessionGuard.identityArg` so the two cannot
/// drift apart again silently.
///
/// ### What that means for privacy
///
/// This file is a live session token and a list of the user's most recent
/// chats, sitting in a container that survives the app being closed. Anything
/// that can read it can post as this account. It is inside the app group
/// (readable only by these two binaries, both signed by the same team), written
/// at the keychain's own protection class, excluded from backups, and
/// **deleted on sign-out** — which is what stops the account that left being
/// usable by whoever picks the handset up next.
struct ShareSession: Codable {
    let userId: String
    let deploymentUrl: String

    /// The credential every authenticated call carries, spelled exactly as
    /// `SessionGuard.identityArg` spells it. Non-optional on purpose: a cache
    /// written before this field existed fails to decode and reads as "no
    /// session", which is the honest answer — the sheet offers to open the app
    /// instead of a Send that could only fail.
    let sessionToken: String

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
            !session.deploymentUrl.isEmpty,
            !session.sessionToken.isEmpty
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
