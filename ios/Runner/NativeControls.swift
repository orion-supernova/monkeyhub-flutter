import Flutter
import SwiftUI
import UIKit

// The Liquid Glass kit's real controls: SwiftUI views hosted one per Flutter
// platform view (`UiKitView`, view type `monkeyhub/native_control`).
//
// Dart owns all state (`lib/ui/native/native_control.dart`). It creates a view
// with a spec — a plain map: `kind` plus that kind's fields — pushes a new spec
// over `monkeyhub/native_control/<id>` whenever it changes (`update`), and
// hears back what the person did (`tap`, `changed`, `submitted`, `select`,
// `size`). This side never decides anything; it renders the spec it was last
// given, so a hot restart or a rebuilt widget resyncs by sending it again.
//
// Cost, read before using one in a list: any platform view on screen drops
// every Flutter list from 120 Hz to bursts of 60 (flutter/flutter#190815) and
// doubles the cost of a BackdropFilter beside it (flutter/flutter#138656). See
// `NativeChrome.swift` for the sibling-view alternative fixed chrome can use,
// and docs/architecture/ui-architecture.html §4 for when each is right.
//
// Lessons carried over from the React Native port (docs/native-ui.md there):
// - every host ignores the safe area, or SwiftUI offsets its content by the
//   safe-area overlap and the control draws and hit-tests apart;
// - a Slider is never given a zero step (SwiftUI traps);
// - a Menu's label takes `buttonStyle(.glass)`, never `glassEffect()`;
// - chrome buttons are 44 pt with a 17 pt semibold symbol: SwiftUI's own
//   control sizes are far smaller.

// MARK: - Factory

final class NativeControlFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "monkeyhub/native_control"

  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeControlPlatformView(
      frame: frame,
      viewId: viewId,
      spec: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  /// Registers the factory. Call once per engine, beside the app's channels.
  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeControlFactory(messenger: registrar.messenger()),
      withId: viewType
    )
  }
}

// MARK: - Platform view

final class NativeControlPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let channel: FlutterMethodChannel
  private let model: NativeControlModel
  private var host: UIHostingController<NativeControlRoot>?
  private var lastReported: CGSize = .zero

  init(
    frame: CGRect,
    viewId: Int64,
    spec: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    container = UIView(frame: frame)
    container.backgroundColor = .clear
    channel = FlutterMethodChannel(
      name: "monkeyhub/native_control/\(viewId)",
      binaryMessenger: messenger
    )
    model = NativeControlModel(spec: NativeControlSpec(spec))
    super.init()

    let emit: (String, Any?) -> Void = { [weak self] event, value in
      self?.channel.invokeMethod(event, arguments: value)
    }
    let host = UIHostingController(
      rootView: NativeControlRoot(model: model, emit: emit)
    )
    host.view.backgroundColor = .clear
    host.view.frame = container.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    if #available(iOS 16.4, *) {
      host.safeAreaRegions = []
    }
    container.addSubview(host.view)
    self.host = host

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "update":
        self.model.spec = NativeControlSpec(call.arguments as? [String: Any] ?? [:])
        self.reportSize()
        result(nil)
      case "measure":
        self.reportSize(force: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    DispatchQueue.main.async { [weak self] in self?.reportSize(force: true) }
  }

  func view() -> UIView { container }

  /// The size the control wants, for a Dart wrapper that sizes to its content
  /// (a text button, a menu label). Fixed-size controls ignore it.
  private func reportSize(force: Bool = false) {
    guard let host else { return }
    let fit = host.sizeThatFits(
      in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    )
    guard force || fit != lastReported else { return }
    lastReported = fit
    channel.invokeMethod("size", arguments: ["width": fit.width, "height": fit.height])
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }
}

// MARK: - Spec

/// The Dart spec, decoded once per update. Every field has a safe default, so
/// an older Dart talking to a newer native side (or the reverse) still draws.
struct NativeControlSpec {
  let kind: String
  let dark: Bool
  let tint: Color?
  let enabled: Bool
  let label: String
  let symbol: String?
  let prominent: Bool
  let destructive: Bool
  let size: CGFloat
  let symbolSize: CGFloat
  let boolValue: Bool
  let doubleValue: Double
  let min: Double
  let max: Double
  let step: Double
  let selected: String?
  let options: [NativeOption]
  let items: [NativeMenuItem]
  let placeholder: String
  let text: String
  let secure: Bool
  let contentType: String?
  let keyboard: String?
  let cornerRadius: CGFloat
  let fill: Bool

  init(_ map: [String: Any]) {
    kind = map["kind"] as? String ?? "symbolButton"
    dark = map["dark"] as? Bool ?? false
    tint = (map["tint"] as? Int).map(Color.init(argb:))
    enabled = map["enabled"] as? Bool ?? true
    label = map["label"] as? String ?? ""
    symbol = map["symbol"] as? String
    prominent = map["prominent"] as? Bool ?? false
    destructive = map["destructive"] as? Bool ?? false
    size = CGFloat(map["size"] as? Double ?? 44)
    symbolSize = CGFloat(map["symbolSize"] as? Double ?? 17)
    boolValue = map["value"] as? Bool ?? false
    doubleValue = map["doubleValue"] as? Double ?? 0
    min = map["min"] as? Double ?? 0
    max = map["max"] as? Double ?? 1
    step = map["step"] as? Double ?? 0
    selected = map["selected"] as? String
    options = (map["options"] as? [[String: Any]] ?? []).map(NativeOption.init)
    items = (map["items"] as? [[String: Any]] ?? []).map(NativeMenuItem.init)
    placeholder = map["placeholder"] as? String ?? ""
    text = map["text"] as? String ?? ""
    secure = map["secure"] as? Bool ?? false
    contentType = map["contentType"] as? String
    keyboard = map["keyboard"] as? String
    cornerRadius = CGFloat(map["cornerRadius"] as? Double ?? 22)
    fill = map["fill"] as? Bool ?? false
  }
}

struct NativeOption: Identifiable {
  let id: String
  let label: String
  let symbol: String?

  init(_ map: [String: Any]) {
    id = map["value"] as? String ?? ""
    label = map["label"] as? String ?? ""
    symbol = map["symbol"] as? String
  }
}

struct NativeMenuItem: Identifiable {
  let id: String
  let label: String
  let symbol: String?
  let destructive: Bool
  let disabled: Bool
  let checked: Bool?
  let divider: Bool

  init(_ map: [String: Any]) {
    id = map["id"] as? String ?? UUID().uuidString
    label = map["label"] as? String ?? ""
    symbol = map["symbol"] as? String
    destructive = map["destructive"] as? Bool ?? false
    disabled = map["disabled"] as? Bool ?? false
    checked = map["checked"] as? Bool
    divider = map["divider"] as? Bool ?? false
  }
}

final class NativeControlModel: ObservableObject {
  @Published var spec: NativeControlSpec

  init(spec: NativeControlSpec) {
    self.spec = spec
  }
}

extension Color {
  /// A Flutter `Color.value` (0xAARRGGBB).
  init(argb: Int) {
    let v = UInt32(truncatingIfNeeded: argb)
    self.init(
      .sRGB,
      red: Double((v >> 16) & 0xFF) / 255,
      green: Double((v >> 8) & 0xFF) / 255,
      blue: Double(v & 0xFF) / 255,
      opacity: Double((v >> 24) & 0xFF) / 255
    )
  }
}

// MARK: - Views

struct NativeControlRoot: View {
  @ObservedObject var model: NativeControlModel
  let emit: (String, Any?) -> Void

  var body: some View {
    let spec = model.spec
    content(spec)
      .tint(spec.tint)
      .disabled(!spec.enabled)
      .environment(\.colorScheme, spec.dark ? .dark : .light)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea()
  }

  @ViewBuilder
  private func content(_ spec: NativeControlSpec) -> some View {
    switch spec.kind {
    case "button": NativeTextButton(spec: spec, emit: emit)
    case "toggle": NativeToggle(spec: spec, emit: emit)
    case "segmented": NativeSegmented(spec: spec, emit: emit)
    case "slider": NativeSlider(spec: spec, emit: emit)
    case "menu": NativeMenu(spec: spec, emit: emit)
    case "textField": NativeTextField(spec: spec, emit: emit)
    case "toolbar": NativeToolbar(spec: spec, emit: emit)
    default: NativeSymbolButton(spec: spec, emit: emit)
    }
  }
}

/// The round chrome button: back, close, more, compose. A 44 pt glass circle
/// with a 17 pt semibold SF Symbol, the iOS 26 navigation-bar button.
struct NativeSymbolButton: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let glyph = Image(systemName: spec.symbol ?? "circle")
      .font(.system(size: spec.symbolSize, weight: .semibold))
      .frame(width: spec.size, height: spec.size)
      .contentShape(Circle())
    let button = Button { emit("tap", nil) } label: { glyph }
      .accessibilityLabel(Text(spec.label))
    if #available(iOS 26.0, *) {
      if spec.prominent {
        button.buttonStyle(.glassProminent).buttonBorderShape(.circle)
      } else {
        button.buttonStyle(.plain)
          .foregroundStyle(spec.destructive ? Color.red : Color.primary)
          .glassEffect(.regular.interactive(), in: Circle())
      }
    } else {
      // Below iOS 26 this kit is never resolved; the capsule is only a
      // safe fallback (.circle needs iOS 17).
      button.buttonStyle(.bordered).buttonBorderShape(.capsule)
    }
  }
}

/// A labelled button: the primary action of a sheet, a row's pill.
struct NativeTextButton: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let label = HStack(spacing: 6) {
      if let s = spec.symbol { Image(systemName: s) }
      Text(spec.label).lineLimit(1)
    }
    .font(.system(size: 17, weight: .semibold))
    .frame(maxWidth: spec.fill ? .infinity : nil)
    .frame(minHeight: spec.size - 16)
    let button = Button(role: spec.destructive ? .destructive : nil) {
      emit("tap", nil)
    } label: { label }
      .controlSize(.large)
    if #available(iOS 26.0, *) {
      if spec.prominent {
        button.buttonStyle(.glassProminent)
      } else {
        button.buttonStyle(.glass)
      }
    } else {
      if spec.prominent {
        button.buttonStyle(.borderedProminent)
      } else {
        button.buttonStyle(.bordered)
      }
    }
  }
}

/// The system switch (a UISwitch underneath), with the app's tint.
struct NativeToggle: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var on: Bool

  init(spec: NativeControlSpec, emit: @escaping (String, Any?) -> Void) {
    self.spec = spec
    self.emit = emit
    _on = State(initialValue: spec.boolValue)
  }

  var body: some View {
    Toggle(spec.label, isOn: $on)
      .labelsHidden()
      .accessibilityLabel(Text(spec.label))
      .onChange(of: spec.boolValue) { on = $0 }
      .onChange(of: on) { value in
        if value != spec.boolValue { emit("changed", value) }
      }
  }
}

/// The system segmented control.
struct NativeSegmented: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var selection: String

  init(spec: NativeControlSpec, emit: @escaping (String, Any?) -> Void) {
    self.spec = spec
    self.emit = emit
    _selection = State(initialValue: spec.selected ?? spec.options.first?.id ?? "")
  }

  var body: some View {
    Picker(spec.label, selection: $selection) {
      ForEach(spec.options) { option in
        if let s = option.symbol {
          Label(option.label, systemImage: s).tag(option.id)
        } else {
          Text(option.label).tag(option.id)
        }
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .onChange(of: spec.selected) { if let v = $0 { selection = v } }
    .onChange(of: selection) { value in
      if value != spec.selected { emit("changed", value) }
    }
  }
}

/// The system slider. Never handed a zero step: SwiftUI traps on one.
struct NativeSlider: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var value: Double

  init(spec: NativeControlSpec, emit: @escaping (String, Any?) -> Void) {
    self.spec = spec
    self.emit = emit
    _value = State(initialValue: spec.doubleValue)
  }

  var body: some View {
    let range = spec.min...Swift.max(spec.max, spec.min + 0.0001)
    let onEditing: (Bool) -> Void = { editing in
      if !editing { emit("changeEnd", value) }
    }
    Group {
      if spec.step > 0 {
        Slider(value: $value, in: range, step: spec.step, onEditingChanged: onEditing)
      } else {
        Slider(value: $value, in: range, onEditingChanged: onEditing)
      }
    }
    .labelsHidden()
    .accessibilityLabel(Text(spec.label))
    .onChange(of: spec.doubleValue) { value = $0 }
    .onChange(of: value) { v in
      if v != spec.doubleValue { emit("changed", v) }
    }
  }
}

/// A pull-down menu from a glass button; on iOS 26 the button morphs into the
/// menu. Items report their `id` back as `select`.
struct NativeMenu: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let menu = Menu {
      ForEach(spec.items) { item in
        if item.divider {
          Divider()
        } else if let checked = item.checked {
          Toggle(isOn: Binding(get: { checked }, set: { _ in emit("select", item.id) })) {
            itemLabel(item)
          }
          .disabled(item.disabled)
        } else {
          Button(role: item.destructive ? .destructive : nil) {
            emit("select", item.id)
          } label: {
            itemLabel(item)
          }
          .disabled(item.disabled)
        }
      }
    } label: {
      if let s = spec.symbol, spec.label.isEmpty {
        Image(systemName: s)
          .font(.system(size: spec.symbolSize, weight: .semibold))
          .frame(width: spec.size, height: spec.size)
      } else {
        HStack(spacing: 4) {
          if let s = spec.symbol { Image(systemName: s) }
          Text(spec.label)
          Image(systemName: "chevron.up.chevron.down").font(.caption)
        }
      }
    }
    .accessibilityLabel(Text(spec.label))
    if #available(iOS 26.0, *) {
      if spec.label.isEmpty {
        menu.buttonStyle(.glass).buttonBorderShape(.circle)
      } else {
        menu.buttonStyle(.glass)
      }
    } else {
      menu
    }
  }

  @ViewBuilder
  private func itemLabel(_ item: NativeMenuItem) -> some View {
    if let s = item.symbol {
      Label(item.label, systemImage: s)
    } else {
      Text(item.label)
    }
  }
}

/// A single- or one-line text field in a glass rounded rect. Text flows back
/// as `changed`; return as `submitted`.
struct NativeTextField: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var text: String
  @FocusState private var focused: Bool

  init(spec: NativeControlSpec, emit: @escaping (String, Any?) -> Void) {
    self.spec = spec
    self.emit = emit
    _text = State(initialValue: spec.text)
  }

  var body: some View {
    let field = Group {
      if spec.secure {
        SecureField(spec.placeholder, text: $text)
      } else {
        TextField(spec.placeholder, text: $text)
      }
    }
    .textFieldStyle(.plain)
    .font(.system(size: 17))
    .focused($focused)
    .textContentType(contentType)
    .keyboardType(keyboardType)
    .autocorrectionDisabled(spec.contentType != nil)
    .submitLabel(.done)
    .onSubmit { emit("submitted", text) }
    .onChange(of: spec.text) { if $0 != text { text = $0 } }
    .onChange(of: text) { if $0 != spec.text { emit("changed", $0) } }
    .onChange(of: focused) { emit("focus", $0) }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, minHeight: spec.size, maxHeight: .infinity)
    if #available(iOS 26.0, *) {
      field.glassEffect(.regular, in: RoundedRectangle(cornerRadius: spec.cornerRadius))
    } else {
      field.background(
        RoundedRectangle(cornerRadius: spec.cornerRadius).fill(.thinMaterial)
      )
    }
  }

  private var contentType: UITextContentType? {
    switch spec.contentType {
    case "username": return .username
    case "password": return .password
    case "newPassword": return .newPassword
    case "oneTimeCode": return .oneTimeCode
    case "emailAddress": return .emailAddress
    case "url": return .URL
    default: return nil
    }
  }

  private var keyboardType: UIKeyboardType {
    switch spec.keyboard {
    case "email": return .emailAddress
    case "url": return .URL
    case "number": return .numberPad
    case "phone": return .phonePad
    default: return .default
    }
  }
}

/// A row of glass actions that blend and morph together, the iOS 26 toolbar.
/// Each option is an action; a tap reports its `value` as `select`.
struct NativeToolbar: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: 8) {
        HStack(spacing: 8) {
          ForEach(spec.options) { option in
            Button { emit("select", option.id) } label: {
              Image(systemName: option.symbol ?? "circle")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: spec.size, height: spec.size)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(option.label))
            .glassEffect(.regular.interactive(), in: Circle())
          }
        }
      }
    } else {
      HStack(spacing: 8) {
        ForEach(spec.options) { option in
          Button { emit("select", option.id) } label: {
            Image(systemName: option.symbol ?? "circle")
              .frame(width: spec.size, height: spec.size)
          }
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .accessibilityLabel(Text(option.label))
        }
      }
    }
  }
}
