import AVKit
import Flutter
import UIKit
import WebRTC

/// `monkeyhub/draw_mirror` on iOS — Dart's `DrawMirror`: the strokes the
/// others draw over this device's shared screen, for when the presenter has
/// left the app.
///
/// iOS has no way to draw over another app. The one surface an app may keep
/// on screen once it has left is Picture in Picture, and a call may start
/// it by itself as the app goes (`canStartPictureInPictureAutomaticallyFromInline`
/// on a video-call content source — the FaceTime shape). So while a share is
/// on the air a PiP controller is armed and waiting; the moment the app
/// leaves the screen the system lifts a small board out of it, and that is
/// where the drawing goes:
///
///  * idle, a quiet card saying drawings will appear there;
///  * once someone draws, a dimmed still of the shared screen — taken from
///    the share's own video track, not a second capture — with the strokes
///    live over it, in each author's colour, fading on the same clock the
///    in-app layer keeps.
///
/// The board is UIKit and Core Animation only: every stroke a pair of shape
/// layers, every fade a CA animation scheduled ahead of time, so nothing in
/// this process ticks per frame while the app is in the background. The
/// still is converted from one retained frame, at thumbnail size, only when
/// a stroke begins (at most once a second).
///
/// The source view the PiP grows out of is a transparent, non-interactive
/// sheet over the Flutter view; PiP needs one in the window to start from.
final class DrawPip: NSObject, AVPictureInPictureControllerDelegate {
  static let shared = DrawPip()

  private static let msgReset: UInt8 = 0x01
  private static let msgOps: UInt8 = 0x02
  private static let msgStroke: UInt8 = 0x03
  private static let msgVisible: UInt8 = 0x04

  private var controller: AVPictureInPictureController?
  private var callVC: AVPictureInPictureVideoCallViewController?
  private var sourceView: UIView?
  private var board: DrawBoardView?
  private let grabber = ScreenFrameGrabber()
  private var lastStill: CFTimeInterval = 0

  func register(messenger: FlutterBinaryMessenger) {
    let control = FlutterMethodChannel(name: "monkeyhub/draw_mirror", binaryMessenger: messenger)
    control.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "arm":
        let args = call.arguments as? [String: Any]
        result(self.arm(
          trackId: args?["trackId"] as? String,
          idleText: args?["idleText"] as? String ?? ""
        ))
      case "disarm":
        self.disarm()
        result(nil)
      case "overlayPermission", "requestOverlayPermission":
        // Android's "display over other apps"; nothing to grant here.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let ops = FlutterBasicMessageChannel(
      name: "monkeyhub/draw_mirror/ops",
      binaryMessenger: messenger,
      codec: FlutterBinaryCodec.sharedInstance()
    )
    ops.setMessageHandler { [weak self] message, reply in
      if let data = message as? Data { self?.handle(data) }
      reply(nil)
    }
  }

  // MARK: - arming

  private func arm(trackId: String?, idleText: String) -> Bool {
    disarm()
    guard AVPictureInPictureController.isPictureInPictureSupported(),
          let host = Self.hostView()
    else { return false }

    let source = UIView(frame: host.bounds)
    source.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    source.isUserInteractionEnabled = false
    source.isAccessibilityElement = false
    source.backgroundColor = .clear
    host.addSubview(source)

    let vc = AVPictureInPictureVideoCallViewController()
    let board = DrawBoardView(idleText: idleText)
    board.frame = vc.view.bounds
    board.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    vc.view.addSubview(board)
    vc.view.backgroundColor = DrawBoardView.stage

    if let trackId = trackId { grabber.attach(trackId: trackId) }
    let aspect = grabber.aspect ?? Self.screenAspect()
    board.frameAspect = aspect
    vc.preferredContentSize = Self.contentSize(aspect: aspect)

    let pip = AVPictureInPictureController(
      contentSource: .init(activeVideoCallSourceView: source, contentViewController: vc)
    )
    pip.canStartPictureInPictureAutomaticallyFromInline = true
    pip.delegate = self

    sourceView = source
    callVC = vc
    self.board = board
    controller = pip
    return true
  }

  private func disarm() {
    if let pip = controller, pip.isPictureInPictureActive {
      pip.stopPictureInPicture()
    }
    controller?.delegate = nil
    controller = nil
    callVC = nil
    sourceView?.removeFromSuperview()
    sourceView = nil
    board?.reset()
    board = nil
    grabber.detach()
    lastStill = 0
  }

  private static func hostView() -> UIView? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController?
      .view
  }

  /// Width over height of the display as it stands now.
  private static func screenAspect() -> CGFloat {
    let b = UIScreen.main.bounds
    return b.height > 0 ? b.width / b.height : 9.0 / 19.5
  }

  /// PiP sizes the window itself; this only tells it the shape.
  private static func contentSize(aspect: CGFloat) -> CGSize {
    let a = max(0.3, min(aspect, 3.5))
    return a < 1 ? CGSize(width: 360 * a, height: 360) : CGSize(width: 360, height: 360 / a)
  }

  // MARK: - AVPictureInPictureControllerDelegate

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    NSLog("[draw_pip] failed to start: \(error)")
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    // The call screen is still where the user left it; nothing to rebuild.
    completionHandler(true)
  }

  // MARK: - drawing

  private func handle(_ data: Data) {
    guard let board = board else { return }
    var r = ByteReader(data)
    guard let kind = r.u8() else { return }
    switch kind {
    case Self.msgReset:
      board.reset()
    case Self.msgVisible:
      // Back in front: Flutter has the drawing again.
      if r.u8() == 0 { board.reset() }
    case Self.msgOps:
      guard let author = r.author() else { return }
      apply(DrawWireReader.decode(&r), author: author, endedAgo: nil, board: board)
    case Self.msgStroke:
      guard let author = r.author(), let ago = r.i32() else { return }
      apply(DrawWireReader.decode(&r), author: author, endedAgo: Int(ago), board: board)
    default:
      break
    }
  }

  private func apply(_ ops: [DrawWireOp], author: String, endedAgo: Int?, board: DrawBoardView) {
    var began = false
    for op in ops {
      switch op {
      case let .begin(id, argb, width, points):
        board.begin(key: "\(author)/\(id)", argb: argb, width: CGFloat(width), points: points)
        began = true
        // A stroke handed over mid-life carries its age.
        if let ago = endedAgo, ago >= 0 {
          board.end(key: "\(author)/\(id)", endedAgo: Double(ago) / 1000)
        }
      case let .append(id, points):
        board.append(key: "\(author)/\(id)", points: points)
      case let .end(id):
        board.end(key: "\(author)/\(id)", endedAgo: 0)
      case .clear:
        board.reset()
      }
    }
    if began { refreshStill() }
  }

  /// A fresh still of the shared screen under the strokes, at most once a
  /// second: what the others are drawing on.
  private func refreshStill() {
    let now = CACurrentMediaTime()
    if board?.hasStill == true && now - lastStill < 1 { return }
    lastStill = now
    grabber.snapshot(maxDimension: 540) { [weak self] image in
      guard let self = self, let image = image, let board = self.board else { return }
      let aspect = CGFloat(image.width) / CGFloat(max(1, image.height))
      if abs(aspect - board.frameAspect) > 0.01 {
        board.frameAspect = aspect
        self.callVC?.preferredContentSize = Self.contentSize(aspect: aspect)
      }
      board.setStill(image)
    }
  }
}

// MARK: - The board

/// What PiP shows: a stage in the shared frame's shape, the still, the
/// strokes. See [DrawPip].
final class DrawBoardView: UIView {
  static let stage = UIColor(red: 0x0E / 255, green: 0x0F / 255, blue: 0x12 / 255, alpha: 1)

  /// Same as `DrawModel.lifetime` / `dissolve` in Dart.
  private static let lifetime: CFTimeInterval = 2.5
  private static let dissolve: CFTimeInterval = 0.65

  private final class Stroke {
    let container = CALayer()
    let halo = CAShapeLayer()
    let ink = CAShapeLayer()
    let width: CGFloat
    var points: [Float] = []
    var ended = false
    var removal: DispatchWorkItem?

    init(color: UIColor, width: CGFloat) {
      self.width = width
      for l in [halo, ink] {
        l.fillColor = nil
        l.lineCap = .round
        l.lineJoin = .round
        l.contentsScale = UIScreen.main.scale
      }
      halo.strokeColor = color.withAlphaComponent(0.3).cgColor
      ink.strokeColor = color.cgColor
      container.addSublayer(halo)
      container.addSublayer(ink)
    }
  }

  private let stillLayer = CALayer()
  private let strokesLayer = CALayer()
  private let idleStack: UIStackView
  private var strokes: [String: Stroke] = [:]

  /// The shared frame's width over its height.
  var frameAspect: CGFloat = 9.0 / 19.5 {
    didSet { if frameAspect != oldValue { setNeedsLayout() } }
  }

  init(idleText: String) {
    let icon = UIImageView(image: UIImage(systemName: "scribble.variable"))
    icon.tintColor = UIColor.white.withAlphaComponent(0.55)
    icon.preferredSymbolConfiguration = .init(pointSize: 22, weight: .medium)
    let label = UILabel()
    label.text = idleText
    label.textColor = UIColor.white.withAlphaComponent(0.7)
    label.font = .systemFont(ofSize: 13, weight: .medium)
    label.textAlignment = .center
    label.numberOfLines = 3
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.7
    idleStack = UIStackView(arrangedSubviews: [icon, label])
    idleStack.axis = .vertical
    idleStack.alignment = .center
    idleStack.spacing = 8
    super.init(frame: .zero)
    backgroundColor = Self.stage
    isUserInteractionEnabled = false
    stillLayer.contentsGravity = .resize
    stillLayer.opacity = 0
    stillLayer.minificationFilter = .trilinear
    layer.addSublayer(stillLayer)
    layer.addSublayer(strokesLayer)
    idleStack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(idleStack)
    NSLayoutConstraint.activate([
      idleStack.centerXAnchor.constraint(equalTo: centerXAnchor),
      idleStack.centerYAnchor.constraint(equalTo: centerYAnchor),
      idleStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
      idleStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  /// The frame's rect inside the board, aspect-fit.
  private var frameRect: CGRect {
    let b = bounds
    guard b.width > 0, b.height > 0, frameAspect > 0 else { return b }
    if b.width / b.height > frameAspect {
      let w = b.height * frameAspect
      return CGRect(x: (b.width - w) / 2, y: 0, width: w, height: b.height)
    }
    let h = b.width / frameAspect
    return CGRect(x: 0, y: (b.height - h) / 2, width: b.width, height: h)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let r = frameRect
    stillLayer.frame = r
    strokesLayer.frame = r
    for s in strokes.values { rebuild(s) }
    CATransaction.commit()
  }

  func begin(key: String, argb: UInt32, width: CGFloat, points: [Float]) {
    remove(key: key)
    let color = UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
    let s = Stroke(color: color, width: width)
    s.points = points
    strokes[key] = s
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    strokesLayer.addSublayer(s.container)
    rebuild(s)
    CATransaction.commit()
    setIdle(false)
  }

  func append(key: String, points: [Float]) {
    guard let s = strokes[key], !points.isEmpty else { return }
    s.points.append(contentsOf: points)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    rebuild(s)
    CATransaction.commit()
  }

  /// The finger lifted [endedAgo] seconds ago: schedule the fade and the
  /// removal now, so nothing has to wake for either.
  func end(key: String, endedAgo: CFTimeInterval) {
    guard let s = strokes[key], !s.ended else { return }
    s.ended = true
    let wait = max(0, Self.lifetime - endedAgo)
    let into = max(0, endedAgo - Self.lifetime)
    let left = Self.dissolve - into
    if left <= 0 {
      remove(key: key)
      return
    }
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = 1 - into / Self.dissolve
    fade.toValue = 0
    fade.duration = left
    fade.beginTime = s.container.convertTime(CACurrentMediaTime(), from: nil) + wait
    fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
    fade.fillMode = .both
    fade.isRemovedOnCompletion = false
    s.container.add(fade, forKey: "dissolve")
    let item = DispatchWorkItem { [weak self] in self?.remove(key: key) }
    s.removal = item
    DispatchQueue.main.asyncAfter(deadline: .now() + wait + left, execute: item)
  }

  var hasStill: Bool { stillLayer.contents != nil }

  func setStill(_ image: CGImage) {
    stillLayer.contents = image
    guard !strokes.isEmpty else { return }
    CATransaction.begin()
    CATransaction.setAnimationDuration(0.2)
    stillLayer.opacity = 0.5
    CATransaction.commit()
  }

  func reset() {
    for key in Array(strokes.keys) { remove(key: key, settle: false) }
    setIdle(true)
  }

  private func remove(key: String, settle: Bool = true) {
    guard let s = strokes.removeValue(forKey: key) else { return }
    s.removal?.cancel()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    s.container.removeFromSuperlayer()
    CATransaction.commit()
    if settle && strokes.isEmpty { setIdle(true) }
  }

  private func setIdle(_ idle: Bool) {
    if idleStack.isHidden == !idle { return }
    idleStack.isHidden = !idle
    CATransaction.begin()
    CATransaction.setAnimationDuration(idle ? 0.35 : 0.2)
    // The still goes with the last stroke; the next drawing takes a new one.
    stillLayer.opacity = idle ? 0 : (stillLayer.contents == nil ? 0 : 0.5)
    CATransaction.commit()
    // A still is about the drawing it came with: once that has faded it
    // goes, so the next drawing never opens on an old screen.
    if idle {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard let self = self, !self.idleStack.isHidden else { return }
        self.stillLayer.contents = nil
      }
    }
  }

  /// Midpoint quadratics, as the Flutter painter draws them. A stroke's
  /// width is a fraction of the frame's, floored for a window this small.
  private func rebuild(_ s: Stroke) {
    let r = strokesLayer.bounds
    let w = r.width
    let h = r.height
    let pts = s.points
    let n = pts.count / 2
    let path = CGMutablePath()
    if n > 0 && w > 0 && h > 0 {
      func p(_ i: Int) -> CGPoint { CGPoint(x: CGFloat(pts[2 * i]) * w, y: CGFloat(pts[2 * i + 1]) * h) }
      path.move(to: p(0))
      if n == 1 {
        path.addLine(to: CGPoint(x: p(0).x + 0.01, y: p(0).y))
      } else if n == 2 {
        path.addLine(to: p(1))
      } else {
        for i in 1..<(n - 1) {
          let c = p(i)
          let next = p(i + 1)
          path.addQuadCurve(to: CGPoint(x: (c.x + next.x) / 2, y: (c.y + next.y) / 2), control: c)
        }
        path.addLine(to: p(n - 1))
      }
    }
    let lw = max(2.5, s.width * w * 1.5)
    s.container.frame = CGRect(origin: .zero, size: r.size)
    s.halo.path = path
    s.halo.lineWidth = lw * 2.2
    s.ink.path = path
    s.ink.lineWidth = lw
  }
}

// MARK: - The still

/// Keeps the newest frame of the share's own video track and, on request,
/// turns it into a small upright image. Rendering is a pointer swap per
/// frame; the conversion runs only when asked, at thumbnail size, off the
/// main thread.
final class ScreenFrameGrabber: NSObject, RTCVideoRenderer {
  private let lock = NSLock()
  private var latest: RTCVideoFrame?
  private var track: RTCVideoTrack?
  private let queue = DispatchQueue(label: "monkeyhub.draw_pip.still", qos: .utility)

  /// The newest frame's upright width over height, if one has come.
  var aspect: CGFloat? {
    lock.lock()
    defer { lock.unlock() }
    guard let f = latest, f.width > 0, f.height > 0 else { return nil }
    let turned = f.rotation == ._90 || f.rotation == ._270
    let w = CGFloat(turned ? f.height : f.width)
    let h = CGFloat(turned ? f.width : f.height)
    return w / h
  }

  /// Finds the local track flutter_webrtc holds under [trackId]. Reached
  /// through the runtime rather than the plugin's headers, which are not a
  /// module Swift can import.
  func attach(trackId: String) {
    detach()
    let sel = NSSelectorFromString("sharedSingleton")
    guard let cls = NSClassFromString("FlutterWebRTCPlugin"),
          (cls as AnyObject).responds(to: sel),
          let plugin = (cls as AnyObject).perform(sel)?.takeUnretainedValue() as? NSObject,
          let tracks = plugin.value(forKey: "localTracks") as? NSDictionary,
          let local = tracks[trackId] as? NSObject,
          local.responds(to: NSSelectorFromString("videoTrack")),
          let video = local.value(forKey: "videoTrack") as? RTCVideoTrack
    else {
      NSLog("[draw_pip] no local track \(trackId); the board will have no still")
      return
    }
    track = video
    video.add(self)
  }

  func detach() {
    track?.remove(self)
    track = nil
    lock.lock()
    latest = nil
    lock.unlock()
  }

  func setSize(_ size: CGSize) {}

  func renderFrame(_ frame: RTCVideoFrame?) {
    guard let frame = frame else { return }
    lock.lock()
    latest = frame
    lock.unlock()
  }

  func snapshot(maxDimension: Int, completion: @escaping (CGImage?) -> Void) {
    lock.lock()
    let frame = latest
    lock.unlock()
    guard let frame = frame else {
      completion(nil)
      return
    }
    queue.async {
      let image = Self.render(frame, maxDimension: maxDimension)
      DispatchQueue.main.async { completion(image) }
    }
  }

  /// I420 to RGB, nearest-neighbour, rotated upright, in one pass over the
  /// output's pixels only — a few hundred thousand at most.
  private static func render(_ frame: RTCVideoFrame, maxDimension: Int) -> CGImage? {
    let buf = frame.buffer.toI420()
    let sw = Int(buf.width)
    let sh = Int(buf.height)
    guard sw > 1, sh > 1 else { return nil }
    let rotation = frame.rotation
    let turned = rotation == ._90 || rotation == ._270
    let uw = turned ? sh : sw
    let uh = turned ? sw : sh
    let scale = min(1.0, Double(maxDimension) / Double(max(uw, uh)))
    let ow = max(1, Int(Double(uw) * scale))
    let oh = max(1, Int(Double(uh) * scale))

    let dy = buf.dataY
    let du = buf.dataU
    let dv = buf.dataV
    let sy = Int(buf.strideY)
    let su = Int(buf.strideU)
    let sv = Int(buf.strideV)

    var pixels = [UInt8](repeating: 255, count: ow * oh * 4)
    pixels.withUnsafeMutableBufferPointer { out in
      for oy in 0..<oh {
        let uy = min(uh - 1, Int(Double(oy) / scale))
        for ox in 0..<ow {
          let ux = min(uw - 1, Int(Double(ox) / scale))
          // Upright (ux, uy) back to the sensor's (x, y).
          let x: Int
          let y: Int
          switch rotation {
          case ._90:
            x = uy
            y = sh - 1 - ux
          case ._180:
            x = sw - 1 - ux
            y = sh - 1 - uy
          case ._270:
            x = sw - 1 - uy
            y = ux
          default:
            x = ux
            y = uy
          }
          let c = Int(dy[y * sy + x]) - 16
          let d = Int(du[(y >> 1) * su + (x >> 1)]) - 128
          let e = Int(dv[(y >> 1) * sv + (x >> 1)]) - 128
          let r = (298 * c + 409 * e + 128) >> 8
          let g = (298 * c - 100 * d - 208 * e + 128) >> 8
          let b = (298 * c + 516 * d + 128) >> 8
          let o = (oy * ow + ox) * 4
          out[o] = UInt8(clamping: r)
          out[o + 1] = UInt8(clamping: g)
          out[o + 2] = UInt8(clamping: b)
        }
      }
    }
    let data = Data(pixels) as CFData
    guard let provider = CGDataProvider(data: data) else { return nil }
    return CGImage(
      width: ow,
      height: oh,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: ow * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: .defaultIntent
    )
  }
}

// MARK: - Wire

/// The decoder half of `draw_wire.dart`, version 1. Never throws: whatever
/// parsed before the first truncated or unknown op is what comes back.
enum DrawWireOp {
  case begin(id: UInt32, argb: UInt32, width: Float, points: [Float])
  case append(id: UInt32, points: [Float])
  case end(id: UInt32)
  case clear
}

struct ByteReader {
  private let bytes: [UInt8]
  private(set) var offset = 0

  init(_ data: Data) { bytes = [UInt8](data) }

  var remaining: Int { bytes.count - offset }

  mutating func u8() -> UInt8? {
    guard remaining >= 1 else { return nil }
    defer { offset += 1 }
    return bytes[offset]
  }

  mutating func u16() -> UInt16? {
    guard remaining >= 2 else { return nil }
    defer { offset += 2 }
    return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
  }

  mutating func u32() -> UInt32? {
    guard remaining >= 4 else { return nil }
    defer { offset += 4 }
    return UInt32(bytes[offset])
      | UInt32(bytes[offset + 1]) << 8
      | UInt32(bytes[offset + 2]) << 16
      | UInt32(bytes[offset + 3]) << 24
  }

  mutating func i32() -> Int32? { u32().map { Int32(bitPattern: $0) } }

  mutating func f32() -> Float? { u32().map { Float(bitPattern: $0) } }

  mutating func author() -> String? {
    guard let n = u8(), remaining >= Int(n) else { return nil }
    defer { offset += Int(n) }
    return String(decoding: bytes[offset..<(offset + Int(n))], as: UTF8.self)
  }
}

enum DrawWireReader {
  static func decode(_ r: inout ByteReader) -> [DrawWireOp] {
    var out: [DrawWireOp] = []
    while r.remaining >= 2 {
      guard r.u8() == 1, let count = r.u8() else { return out }
      for _ in 0..<Int(count) {
        guard let tag = r.u8() else { return out }
        switch tag {
        case 0x01:
          guard let id = r.u32(), let argb = r.u32(), let width = r.f32(),
                let pts = points(&r) else { return out }
          out.append(.begin(id: id, argb: argb, width: width, points: pts))
        case 0x02:
          guard let id = r.u32(), let pts = points(&r) else { return out }
          out.append(.append(id: id, points: pts))
        case 0x03:
          guard let id = r.u32() else { return out }
          out.append(.end(id: id))
        case 0x04:
          out.append(.clear)
        default:
          return out
        }
      }
    }
    return out
  }

  private static func points(_ r: inout ByteReader) -> [Float]? {
    guard let n = r.u16(), r.remaining >= Int(n) * 8 else { return nil }
    var pts = [Float]()
    pts.reserveCapacity(Int(n) * 2)
    for _ in 0..<(Int(n) * 2) {
      guard let f = r.f32() else { return nil }
      pts.append(f)
    }
    return pts
  }
}
