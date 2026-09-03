import SwiftUI

/// What the user sees when they share into MonkeyHub from another app.
///
/// A real compose sheet — pick a chat, add a caption, send — rather than a
/// bounce into the app, because the app is the wrong place for this on iOS. The
/// user is in Photos and expects to stay there; every messaging app they
/// already use (Messages, WhatsApp, Telegram) sends from inside the share sheet
/// and never leaves. `ShareViewController` does the sending; this is only the
/// surface.
///
/// Deliberately system-native rather than a copy of the app's theme. An
/// extension is chrome the OS presents on another app's behalf, and the seven
/// hand-painted MonkeyHub themes belong to the app itself — a sheet that looked
/// like MonkeyHub here would look like MonkeyHub had taken over Photos.
struct ShareComposeView: View {

    let chats: [ShareChat]
    let attachmentCount: Int
    let previewImage: UIImage?
    /// Set when the share carries text or a link rather than files.
    let sharedText: String?

    @Binding var selectedChatId: String?
    @Binding var caption: String

    let state: SendState
    let onSend: () -> Void
    let onOpenApp: () -> Void
    let onCancel: () -> Void

    enum SendState: Equatable {
        case idle
        case sending
        case failed(String)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                preview
                Divider()
                chatList
                Divider()
                composer
            }
            .navigationTitle("Send to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(state == .sending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if state == .sending {
                        ProgressView()
                    } else {
                        // `.font(.body.weight(...))`, not `.fontWeight(...)`:
                        // the modifier is iOS 16 and this ships to 15.
                        Button("Send", action: onSend)
                            .font(.body.weight(.semibold))
                            .disabled(selectedChatId == nil)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - What is about to be sent

    @ViewBuilder
    private var preview: some View {
        HStack(spacing: 12) {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: sharedText == nil ? "doc" : "link")
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(previewTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                if case .failed(let message) = state {
                    // The failure sits with the content rather than in an alert:
                    // an alert would have to be dismissed before the user could
                    // see the Send button they need to press again.
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var previewTitle: String {
        if let sharedText, !sharedText.isEmpty { return sharedText }
        if attachmentCount == 1 { return "1 attachment" }
        return "\(attachmentCount) attachments"
    }

    // MARK: - Who it goes to

    @ViewBuilder
    private var chatList: some View {
        if chats.isEmpty {
            // No cache. Either nobody is signed in on this device, or the app
            // has not run since the group was provisioned. Sending is
            // impossible either way, so the only honest offer is the app.
            VStack(spacing: 12) {
                Text("Open MonkeyHub to choose a chat.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                // Disabled until staging finishes, exactly like the escape
                // hatch below it. Handing the app a manifest written while the
                // copies are still in flight is handing it a share with no
                // photos in it, which Dart drops on the floor as empty.
                Button("Open MonkeyHub", action: onOpenApp)
                    .buttonStyle(.borderedProminent)
                    .disabled(state == .sending)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            // A ScrollView of explicit rows rather than a `List`, for the
            // separators.
            //
            // A plain List derives each separator's inset from that row's own
            // content, and these rows do not agree about what their content
            // is: a chat with an avatar leads with an `AsyncImage` whose size
            // is unknown until it loads, one without leads with a `Text` in a
            // circle. The result is separators starting at three different
            // x positions down one list — visible, and the sort of thing that
            // reads as a broken sheet rather than a styled one.
            //
            // `alignmentGuide(.listRowSeparatorLeading)` is the supported way
            // to pin it and is iOS 16; this ships to 15. So the rows and their
            // rules are drawn here, off one set of metrics.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(chats.enumerated()), id: \.element.id) { index, chat in
                        Button { selectedChatId = chat.id } label: { row(chat) }
                            // Without this a Button tints its whole label with
                            // the accent colour, avatar included.
                            .buttonStyle(.plain)
                            .disabled(state == .sending)
                        if index < chats.count - 1 {
                            Divider().padding(.leading, RowMetrics.titleInset)
                        }
                    }
                }
            }
        }
    }

    private func row(_ chat: ShareChat) -> some View {
        let selected = selectedChatId == chat.id
        return HStack(spacing: RowMetrics.spacing) {
            ChatAvatar(chat: chat)
            Text(chat.title)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            // Always laid out, only sometimes visible: a checkmark that comes
            // and goes changes the row's width budget and shunts a long title's
            // truncation point as the selection moves.
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                .opacity(selected ? 1 : 0)
        }
        .padding(.horizontal, RowMetrics.inset)
        .padding(.vertical, 10)
        // 44pt is the floor for a touch target, and a row of one short line
        // would otherwise come in under it.
        .frame(minHeight: 44)
        .background(selected ? Color.accentColor.opacity(0.12) : Color.clear)
        // The whole row, not just the glyphs in it.
        .contentShape(Rectangle())
    }

    // MARK: - The caption, and the way out

    @ViewBuilder
    private var composer: some View {
        VStack(spacing: 10) {
            if !chats.isEmpty {
                // Single-line: the multi-line `axis:` initialiser is iOS 16.
                // A caption is a line anyway — the app's own composer is where
                // a paragraph belongs.
                TextField("Add a caption", text: $caption)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .disabled(state == .sending)

                // The escape hatch, and the only way to reach the photo editor
                // (crop, annotation, view-once) — none of which exists here, and
                // none of which is worth rebuilding inside an extension.
                Button("Open in MonkeyHub instead", action: onOpenApp)
                    .font(.footnote)
                    .disabled(state == .sending)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

/// One chat row's measurements, in one place.
///
/// The separator's inset is *derived* from the avatar and the gap rather than
/// written down beside them, because the two drifting apart is exactly the
/// defect this replaces — a rule that starts a few points off the title it is
/// meant to line up with.
private enum RowMetrics {
    static let avatar: CGFloat = 34
    static let spacing: CGFloat = 12
    static let inset: CGFloat = 16
    /// Where a row's title begins, and therefore where its separator does.
    static var titleInset: CGFloat { inset + avatar + spacing }
}

/// The avatar, or the app's own gradient-and-initial fallback.
///
/// Same two colours the app paints (`ShareTarget.gradientStart/End`, seeded
/// from the peer or room id), so a chat looks the same here as it does in the
/// app's own list.
private struct ChatAvatar: View {
    let chat: ShareChat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(argb: chat.gradientStart), Color(argb: chat.gradientEnd)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let raw = chat.avatarUrl, let url = URL(string: raw) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    // The gradient underneath IS the placeholder — a spinner
                    // here would flicker one per row on every appearance.
                    Color.clear
                }
            } else {
                Text(chat.initial)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: RowMetrics.avatar, height: RowMetrics.avatar)
        .clipShape(Circle())
    }
}

private extension Color {
    init(argb: Int) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}
