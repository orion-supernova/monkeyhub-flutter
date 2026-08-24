import Foundation

/// The app's half of "the Share Extension can send on its own".
///
/// The extension is a separate binary with no Flutter engine, no Convex client
/// and no session — it cannot ask the app anything, and the app is usually not
/// running when it is. So the app leaves what it needs in the App Group: the
/// deployment URL, the signed-in user id, and the same recent-chat list the
/// share sheet's top row is built from.
///
/// Refreshed on the same trigger the suggestions are (`publishTargets`, driven
/// by `ShareTargetsSync` in Dart), and **deleted on sign-out** — the list names
/// people, and it must not outlive the session that could see it.
enum ShareCache {

    /// Stores the session, or clears it when [userId] is empty.
    ///
    /// Called with the chat list the app just published to the OS, so the two
    /// can never disagree about which chats exist. An empty `deploymentUrl` or
    /// `userId` clears rather than writes a half-usable file: an extension that
    /// found one would offer a picker whose Send button could only fail.
    static func store(_ args: [String: Any]) {
        let userId = (args["userId"] as? String) ?? ""
        let deploymentUrl = (args["deploymentUrl"] as? String) ?? ""
        guard !userId.isEmpty, !deploymentUrl.isEmpty else {
            ShareSession.clear()
            return
        }
        let raw = (args["targets"] as? [[String: Any]]) ?? []
        let chats: [ShareChat] = raw.compactMap { entry in
            guard
                let id = entry["id"] as? String, !id.isEmpty,
                let title = entry["title"] as? String
            else { return nil }
            return ShareChat(
                id: id,
                title: title,
                initial: (entry["initial"] as? String) ?? "",
                gradientStart: (entry["gradientStart"] as? Int) ?? 0xFF3A3A3C,
                gradientEnd: (entry["gradientEnd"] as? Int) ?? 0xFF5A5A5E,
                avatarUrl: entry["avatarUrl"] as? String,
                isGroup: (entry["isGroup"] as? Bool) ?? false
            )
        }
        ShareSession(
            userId: userId,
            deploymentUrl: deploymentUrl,
            chats: chats,
            senderName: args["senderName"] as? String
        ).save()
    }

    /// Sign-out. Takes the chat list AND the credential with it, so a share
    /// composed after signing out cannot be sent as the account that left.
    static func clear() {
        ShareSession.clear()
    }
}
