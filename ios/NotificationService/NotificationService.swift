import Intents
import UserNotifications

/// Redraws an incoming banner as a COMMUNICATION notification: the sender's
/// face where the app icon normally sits, their name as the title, the room
/// beneath it — the shape iMessage and WhatsApp use, and the one people read as
/// "a person is talking to me" rather than "an app wants something".
///
/// It runs only for a push the backend marked `mutable-content: 1`, which
/// `buildApnsBody` in backend/convex/push.ts sets only when that recipient is
/// actually allowed to see the sender's avatar. So this process starting at all
/// already means there is a face to draw.
///
/// The payload keys are a cross-language contract shared with push.ts,
/// ChatNotifications.kt and web/mh-push-sw.js. Renaming one here breaks a
/// platform you are not looking at; test/push_payload_contract_test.dart pins
/// them.
///
/// The governing rule in every branch below: **a face must never cost the
/// message.** Every failure — no URL, a dead host, a slow host, a missing
/// entitlement, a throw from `updating(from:)` — ends with the original banner
/// delivered unchanged, on time.
class NotificationService: UNNotificationServiceExtension {

  private var contentHandler: ((UNNotificationContent) -> Void)?
  /// The best content built so far. `serviceExtensionTimeWillExpire` delivers
  /// whatever this holds, which is why it is assigned to before any awaiting
  /// rather than at the end.
  private var pending: UNNotificationContent?
  private var avatarTask: URLSessionDataTask?
  /// The avatar fetch racing the extension's deadline is the normal case, not
  /// an edge one, so both finish lines have to be safe to cross second.
  private var delivered = false

  /// Matches Android's patience for the same picture (`AVATAR_FETCH_TIMEOUT_MS`
  /// in ChatNotifications.kt), and for the same reason. The extension's own
  /// budget is far larger — roughly 30s before iOS delivers the original
  /// anyway — so this bound is not about being killed. It is about a banner
  /// arriving when the message did.
  private static let avatarTimeout: TimeInterval = 2.5

  /// The kinds drawn as a conversation. `daily_games` and `approval` are
  /// deliberately absent: nobody is talking in either, and giving a broadcast a
  /// human face is how a notification learns to be ignored. `dismiss` never
  /// arrives here at all — it is a content-available push, and those do not
  /// wake an extension.
  private static let communicationKinds: Set<String> = [
    "message", "call_invite", "group_call_invite",
  ]

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    let original = request.content
    pending = original

    let info = original.userInfo
    let kind = info["kind"] as? String ?? ""
    let senderName = (info["senderName"] as? String)
      ?? (info["callerName"] as? String)
      ?? (info["starterName"] as? String)
      ?? original.title
    let rawUrl = info["senderAvatarUrl"] as? String ?? ""

    guard
      Self.communicationKinds.contains(kind),
      !senderName.isEmpty,
      let url = URL(string: rawUrl)
    else {
      deliver(original)
      return
    }

    // `URLSession.shared` rather than a session of our own: a session is only
    // released when it is invalidated, and one built per push in a process this
    // short-lived would never be. Shared also carries the default URLCache, so
    // a burst from one sender can be served without a second round trip —
    // which is the only reuse available when each push is its own process.
    var avatarRequest = URLRequest(url: url)
    avatarRequest.timeoutInterval = Self.avatarTimeout

    let task = URLSession.shared.dataTask(with: avatarRequest) {
      [weak self] data, response, error in
      guard let self else {
        // Nothing left to decorate with, but the notification still has to be
        // handed over — dropping it here would lose the message outright.
        contentHandler(original)
        return
      }
      let ok = (response as? HTTPURLResponse)?.statusCode == 200
      guard ok, let data, !data.isEmpty, error == nil else {
        // The face did not load. That is the ordinary outcome on a flaky
        // network and not worth a log line per push.
        self.deliver(original)
        return
      }
      self.deliver(
        self.decorate(original, image: INImage(imageData: data),
                      senderName: senderName)
      )
    }
    avatarTask = task
    task.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    avatarTask?.cancel()
    // iOS is about to show something regardless; hand it the best we have
    // rather than letting it fall back to the unmodified payload.
    if let pending { deliver(pending) }
  }

  /// Hands the notification over exactly once. The download and the deadline
  /// race by design, and whichever loses must not deliver a second time.
  private func deliver(_ content: UNNotificationContent) {
    guard !delivered, let handler = contentHandler else { return }
    delivered = true
    pending = content
    handler(content)
  }

  /// Builds the intent that turns a notification into a conversation, and
  /// returns the updated content — or the original, unchanged, if anything
  /// about that fails.
  ///
  /// The outgoing twin of this lives in `donateSendMessage` in
  /// AppDelegate.swift, which donates a send to a room so the share sheet can
  /// suggest it. Same `INPerson`/`INImage` shape, same reason for the group
  /// branch; the two should stay legible as siblings.
  private func decorate(
    _ content: UNNotificationContent,
    image: INImage,
    senderName: String
  ) -> UNNotificationContent {
    let info = content.userInfo
    let roomId = info["roomId"] as? String ?? ""
    let roomName = info["roomName"] as? String ?? ""
    // `isGroup` is a chat-payload key; a group call carries `roomName` and its
    // kind, and nothing else says the banner belongs to a room full of people.
    // Without this the starter's name would replace the room's in the title and
    // the room would be named nowhere at all.
    let isGroup = (info["isGroup"] as? String) == "true"
      || (info["kind"] as? String) == "group_call_invite"
    // Chat sends `senderId`; a 1:1 call sends `callerId`. Falling back to the
    // room keeps the identity stable for a group call, which names no single
    // person in its payload.
    let senderId = (info["senderId"] as? String)
      ?? (info["callerId"] as? String)
      ?? roomId

    let sender = INPerson(
      personHandle: INPersonHandle(
        value: senderId.isEmpty ? senderName : senderId,
        type: .unknown
      ),
      nameComponents: nil,
      displayName: senderName,
      image: image,
      contactIdentifier: nil,
      // A stable identity per person, so consecutive messages from the same
      // sender are one conversation to the system rather than a new stranger
      // each time — the same job `customIdentifier` does in donateSendMessage.
      customIdentifier: senderId.isEmpty ? senderName : senderId
    )

    let intent = INSendMessageIntent(
      recipients: nil,
      outgoingMessageType: .outgoingMessageText,
      content: nil,
      speakableGroupName: isGroup && !roomName.isEmpty
        ? INSpeakableString(spokenPhrase: roomName)
        : nil,
      // Groups this banner with the room it belongs to, which is what lets iOS
      // stack a conversation instead of a pile of unrelated alerts.
      conversationIdentifier: roomId.isEmpty ? nil : roomId,
      serviceName: nil,
      sender: sender,
      attachments: nil
    )
    // A group draws the group's picture, not one member's — but this app has no
    // room avatar in the push payload, so the sender's face stands in. Setting
    // it is still right: without an image on the group parameter iOS falls back
    // to the app icon for every group message, which is the exact thing being
    // fixed here.
    if isGroup {
      intent.setImage(image, forParameterNamed: \.speakableGroupName)
    }

    let interaction = INInteraction(intent: intent, response: nil)
    // INCOMING. The default is outgoing, and an outgoing donation would teach
    // the share sheet that this person is somebody the user messages a lot —
    // from nothing more than receiving from them.
    interaction.direction = .incoming
    interaction.donate(completion: nil)

    do {
      return try content.updating(from: intent)
    } catch {
      // Almost always the missing
      // com.apple.developer.usernotifications.communication entitlement, or a
      // capability absent from the App ID's provisioning profile — neither of
      // which signing complains about. Worth a log, because the alternative
      // symptom is a feature that appears never to have been built.
      NSLog("[push] communication notification refused: \(error.localizedDescription)")
      return content
    }
  }
}
