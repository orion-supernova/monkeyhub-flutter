import Intents
import UIKit
import UserNotifications

/// Redraws an incoming banner as a COMMUNICATION notification: a face where
/// the app icon normally sits and a name as the title — the shape iMessage and
/// WhatsApp use, and the one people read as "a person is talking to me" rather
/// than "an app wants something". For a DM the face and the name are the
/// sender's. For a GROUP message they are the room's, and the sender moves in
/// front of the text: "Design Crew / Ayşe: on my way". A communication
/// notification is titled with its INPerson and draws nothing from
/// `aps.alert.subtitle`, which is where the backend puts the room — so a
/// group message titled with its sender looked exactly like a DM, and the only
/// way to keep the room on the banner is to make the room the person, the way
/// the group CALL banner already did. See `composed` and `displayName(in:)`.
///
/// It runs for every chat message (`buildApnsBody` sets `mutable-content` for
/// the kind, so the seed below always lands) and for a call banner that
/// carries a face.
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

    // FIRST, ahead of every guard and every network call below.
    //
    // This file's governing rule has always been that a face must never cost
    // the message; the seed now sits under the same rule. A `return` on the
    // guard below, an avatar host that hangs until
    // `serviceExtensionTimeWillExpire` fires, this process being killed
    // outright — none of them may cost the recipient the one thing that makes
    // the room open instantly. It is a small local write with no network in
    // it, so there is no reason for it to be anywhere else.
    //
    // The RAW payload, verbatim: this side does not know what a message is and
    // has no business learning. `ChatRepository.takePushedMessages` decides
    // what can honestly be drawn from it — text only, and only unformatted
    // text — and that judgement stays in one language.
    if kind == "message" {
      ShareGroup.stagePush(info.reduce(into: [String: String]()) { out, entry in
        guard let key = entry.key as? String, key != "aps" else { return }
        out[key] = "\(entry.value)"
      })
    }

    let personName = Self.displayName(in: info, fallback: original.title)
    let rawUrl = Self.avatarUrl(in: info)
    // The three lines settled once, up front, and BEFORE any intent touches
    // them: `updating(from:)` returns content that must not be mutated. The
    // no-face path below delivers this as is, so a group message reads the
    // same whether or not a picture was fetched — the same room must not
    // alternate between two layouts depending on who spoke.
    let content = Self.composed(original)
    pending = content

    guard
      Self.communicationKinds.contains(kind),
      !personName.isEmpty,
      let url = URL(string: rawUrl)
    else {
      deliver(content)
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
        self.deliver(content)
        return
      }
      self.deliver(
        self.decorate(content, image: Self.uprightAvatar(data),
                      personName: personName)
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

  /// Whether this banner belongs to a room full of people rather than to one
  /// person: a group chat message, or a group call. `isGroup` is a chat-payload
  /// key; a group call carries `roomName` and its kind, and nothing else says
  /// so.
  private static func isGroup(_ info: [AnyHashable: Any]) -> Bool {
    let kind = info["kind"] as? String ?? ""
    return kind == "group_call_invite"
      || (kind == "message" && (info["isGroup"] as? String) == "true")
  }

  /// Whose name this banner is titled with.
  ///
  /// A communication notification takes its title from the INPerson and
  /// discards whatever `aps.alert.title` said — so this is not a fallback
  /// chain for a missing field, it is the title, and every payload that gets
  /// decorated has to be able to answer it.
  ///
  /// For anything that belongs to a ROOM, the room is the person. The group
  /// call banner learned this first: `groupCalls.sendGroupInvitePush` titles
  /// that push with the room ("Design Crew") and puts the starter in the body,
  /// because a call belongs to the room rather than to whoever pressed the
  /// button, and naming the person after the starter overwrote that title and
  /// left the room named nowhere. A group MESSAGE had the same bug one layer
  /// down: its room rode in `aps.alert.subtitle`, which survives
  /// `updating(from:)` on the object and is not drawn by the communication
  /// layout — so a group banner titled with its sender read exactly like a DM.
  /// The sender still appears, in front of the text (`composed`).
  private static func displayName(
    in info: [AnyHashable: Any],
    fallback: String
  ) -> String {
    if isGroup(info),
       let roomName = info["roomName"] as? String,
       !roomName.isEmpty {
      return roomName
    }
    return (info["senderName"] as? String)
      ?? (info["callerName"] as? String)
      ?? (info["starterName"] as? String)
      ?? fallback
  }

  /// Which picture the banner is drawn with. A group chat draws the ROOM's own
  /// picture when it has one — a WhatsApp or Telegram group banner shows the
  /// group, not whoever spoke last — and the sender's face otherwise, which
  /// still beats the app icon. A room's picture is not privacy-gated (every
  /// member may see it), so the backend sends it in the shared payload; the
  /// sender's is per recipient, see push.ts.
  private static func avatarUrl(in info: [AnyHashable: Any]) -> String {
    if (info["kind"] as? String) == "message", isGroup(info),
       let room = info["roomAvatarUrl"] as? String, !room.isEmpty {
      return room
    }
    return (info["senderAvatarUrl"] as? String) ?? ""
  }

  /// The three lines of a chat banner as iOS should read them.
  ///
  /// A group message is titled with the ROOM and the sender moves in front of
  /// the text — "Design Crew / Ayşe: on my way" — the shape Android's
  /// MessagingStyle and the web worker already produce. The backend keeps
  /// sending `title=sender, subtitle=room` because those two read it that way
  /// and older builds of this extension did too; this is where iOS decides.
  /// The subtitle is cleared: the room is the title now, and the line is not
  /// part of the communication layout in any case.
  ///
  /// A mention lives in the body too. "X mentioned you" was the title, which
  /// the intent replaces; then the subtitle, which the intent leaves alone on
  /// the object and the layout never draws. The body is the one line certain
  /// to be shown. For a DM the title still says it on the undecorated path,
  /// and the body carries it on the decorated one.
  ///
  /// Anything that is not a chat message is returned untouched.
  static func composed(_ content: UNNotificationContent) -> UNNotificationContent {
    let info = content.userInfo
    guard (info["kind"] as? String) == "message",
          let mutable = content.mutableCopy() as? UNMutableNotificationContent
    else { return content }
    let sender = (info["senderName"] as? String) ?? ""
    let mentioned = (info["mention"] as? String) == "true"
    let roomName = (info["roomName"] as? String) ?? ""
    if isGroup(info), !roomName.isEmpty {
      mutable.title = roomName
      mutable.subtitle = ""
      if !sender.isEmpty {
        mutable.body = mentioned
          ? "\(sender) mentioned you: \(content.body)"
          : "\(sender): \(content.body)"
      }
      return mutable
    }
    if mentioned {
      mutable.body = "Mentioned you: \(content.body)"
      return mutable
    }
    return content
  }

  /// Longest edge the face is drawn at. The banner renders it at about 40pt;
  /// anything past this is pixels nobody sees, paid for in a redraw and in the
  /// bytes that cross into the Intents renderer.
  private static let avatarMaxEdge: CGFloat = 256

  /// `INImage(imageData:)` with an upright picture in it.
  ///
  /// A camera does not rotate what its sensor saw. It writes the frame in the
  /// sensor's own orientation and records how to turn it in an EXIF
  /// `Orientation` tag, and every decoder is expected to honour that tag.
  /// `INImage(imageData:)` keeps the bytes verbatim and its renderer draws the
  /// stored pixel grid — so a portrait photograph arrives on the banner lying
  /// on its side, a quarter turn out, while the very same file looks correct
  /// everywhere in the app (Flutter's decoder does read the tag). That is the
  /// whole of the "some people's avatars are rotated" report: not some people,
  /// but every avatar whose bytes still carry an orientation other than `.up`.
  ///
  /// `UIImage` reads the tag. Drawing through it into a fresh context bakes
  /// the rotation into the pixels, which is the only form Intents will handle
  /// correctly, and is the same normalisation `pickerImageQuality` performs on
  /// the way IN for anything uploaded since (lib/media/image_raster.dart) —
  /// this covers the pictures that predate it, and any that arrive by another
  /// road.
  ///
  /// Falls back to the raw bytes on every failure: a face drawn sideways beats
  /// no face, and both beat no notification.
  static func uprightAvatar(_ data: Data) -> INImage {
    guard let decoded = UIImage(data: data),
          decoded.size.width > 0, decoded.size.height > 0
    else {
      return INImage(imageData: data)
    }
    let longest = max(decoded.size.width, decoded.size.height)
    // Already upright and already small: re-encoding buys nothing, and PNG is
    // not free on a path a message is waiting behind.
    if decoded.imageOrientation == .up && longest <= Self.avatarMaxEdge {
      return INImage(imageData: data)
    }
    let k = longest > Self.avatarMaxEdge ? Self.avatarMaxEdge / longest : 1
    let target = CGSize(
      width: max(1, (decoded.size.width * k).rounded()),
      height: max(1, (decoded.size.height * k).rounded())
    )
    let format = UIGraphicsImageRendererFormat.default()
    // Points, not the device's scale factor: `target` is already the pixel
    // count we want, and letting this default to 3 would triple it back.
    format.scale = 1
    // The crop screen exports a CIRCLE (CropShape.circle), so an avatar
    // routinely has transparent corners. Flattening them here would put black
    // squares behind every face on the lock screen.
    format.opaque = false
    let upright = UIGraphicsImageRenderer(size: target, format: format).image { _ in
      decoded.draw(in: CGRect(origin: .zero, size: target))
    }
    guard let png = upright.pngData() else { return INImage(imageData: data) }
    return INImage(imageData: png)
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
  /// returns the updated content — or [content], unchanged, if anything about
  /// that fails. [content] has already been through `composed`.
  ///
  /// The outgoing twin of this lives in `donateSendMessage` in
  /// AppDelegate.swift, which donates a send to a room so the share sheet can
  /// suggest it. Same `INPerson`/`INImage` shape, same room-as-person rule for
  /// a group; the two should stay legible as siblings.
  private func decorate(
    _ content: UNNotificationContent,
    image: INImage,
    personName: String
  ) -> UNNotificationContent {
    let info = content.userInfo
    let roomId = info["roomId"] as? String ?? ""
    let roomName = info["roomName"] as? String ?? ""
    let isGroup = Self.isGroup(info)
    // Who the INPerson IS. A room's banners are one conversation with one
    // identity — the room — so a group message is keyed by its roomId rather
    // than by whoever sent it, the same as a group call (which names no single
    // person in its payload anyway). A DM is keyed by the sender: chat sends
    // `senderId`, a 1:1 call sends `callerId`.
    let personId = isGroup
      ? roomId
      : (info["senderId"] as? String) ?? (info["callerId"] as? String) ?? roomId

    let sender = INPerson(
      personHandle: INPersonHandle(
        value: personId.isEmpty ? personName : personId,
        type: .unknown
      ),
      nameComponents: nil,
      displayName: personName,
      image: image,
      contactIdentifier: nil,
      // A stable identity, so consecutive messages from the same sender — or
      // in the same room — are one conversation to the system rather than a
      // new stranger each time; the same job `customIdentifier` does in
      // donateSendMessage.
      customIdentifier: personId.isEmpty ? personName : personId
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
    // A group draws the group's picture — the room's own when it has one, the
    // sender's face standing in otherwise (`avatarUrl(in:)`). Without an image
    // on the group parameter iOS falls back to the app icon for every group
    // message, which is the exact thing being fixed here.
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
