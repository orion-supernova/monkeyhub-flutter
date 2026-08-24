import Foundation

/// The app's half of the App Group handoff.
///
/// The Share Extension writes one directory per share into the group container
/// and then tries to open the app. This reads them back, in arrival order, and
/// turns each into the channel map Dart parses.
///
/// **The container is the delivery mechanism, not the URL.** `extensionContext
/// .open` is allowed to fail from a share extension, and on some iOS releases
/// it simply does. So nothing here depends on the wake-up URL arriving: the app
/// drains the inbox on every launch and on every return to the foreground, and
/// a share whose URL was swallowed is delivered the next time the user opens
/// the app by hand. The URL is an optimisation.
enum ShareInbox {

    /// How long a staged share may sit unclaimed before a later launch sweeps
    /// it.
    ///
    /// Only ever reached by a directory the app never managed to drain — the
    /// extension was killed mid-write, or the user shared and then deleted the
    /// app's data. Long enough that no live share is inside it; short enough
    /// that somebody's photos are not still in a container next week.
    private static let ttl: TimeInterval = 24 * 60 * 60

    /// Everything the extension has staged and the app has not yet taken,
    /// oldest first.
    ///
    /// Taking removes the manifest, so the same share is never delivered twice
    /// — but leaves the ATTACHMENTS, because Dart is about to read them by
    /// path. Dart releases them (`ShareIntake.disposeItems`) once they are in
    /// the send queue, and [sweep] catches whatever it never got to.
    static func drain() -> [[String: Any]] {
        guard let inbox = inboxIfPresent() else { return [] }
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let ordered = dirs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da < db
        }

        var payloads: [[String: Any]] = []
        for dir in ordered {
            let manifest = dir.appendingPathComponent(ShareGroup.manifestName)
            // A directory with no manifest is one the extension is still
            // writing, or one it died in the middle of. Either way it is not
            // ours to read — see the atomic move in ShareViewController.
            guard fm.fileExists(atPath: manifest.path) else { continue }
            guard
                let data = try? Data(contentsOf: manifest),
                let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else {
                // Unreadable. Delete the whole directory rather than leave it
                // to be retried on every foreground for the next day.
                try? fm.removeItem(at: dir)
                continue
            }
            // Consumed BEFORE handing it over: if Dart never gets it (the
            // isolate is not up yet) the queue in AppDelegate holds it, and a
            // manifest left on disk would deliver the same photos a second time
            // on the next foreground.
            try? fm.removeItem(at: manifest)
            payloads.append(payload)
        }
        return payloads
    }

    /// Deletes staged directories older than [ttl], and any that have no
    /// manifest and no recent writes.
    ///
    /// Cheap and safe to call on every launch: it only looks at modification
    /// dates, and the window is a day.
    static func sweep() {
        guard let inbox = inboxIfPresent() else { return }
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-ttl)
        for dir in dirs {
            let modified = (try? dir.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            if modified < cutoff {
                try? fm.removeItem(at: dir)
            }
        }
    }

    /// The inbox, only if it already exists.
    ///
    /// Deliberately does NOT create it: this runs on every foreground, and an
    /// install whose App Group is misprovisioned would otherwise be indexing a
    /// directory it just made in a container nothing else can see.
    private static func inboxIfPresent() -> URL? {
        guard let url = ShareGroup.inboxURL() else {
            NSLog("[share] no App Group container — is \(ShareGroup.identifier) provisioned?")
            return nil
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
