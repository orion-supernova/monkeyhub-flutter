import AVFoundation
import AVKit
import Flutter
import UIKit
import WebRTC

/// `monkeyhub/call_pip` on iOS, Dart's `CallPip`: the video call's Picture
/// in Picture window, FaceTime's shape.
///
/// While a video call is live, Dart keeps this armed. The moment the app
/// leaves the screen the system lifts the window out by itself
/// (`canStartPictureInPictureAutomaticallyFromInline` on a video-call
/// content source), showing the peer's picture, or their name while that
/// picture is off.
///
/// The window is also what keeps OUR camera going. iOS interrupts every
/// capture session of an app that leaves the screen
/// (`videoDeviceNotAvailableInBackground`) unless the app shows a
/// video-call PiP and the session opted into multitasking camera access
/// (flutter_webrtc patch W5). Without this window the peer saw our picture
/// stop the instant we went home. When the user stashes the window at the
/// screen's edge, iOS interrupts the camera again by design; Dart's
/// `CameraWatch` then tells the peer our picture is off, and it comes back
/// on its own when the window does.
///
/// Frames are only taken off the track while the window is up: a renderer
/// attached at `willStart`, detached at `didStop`. In the app the Flutter
/// call screen draws the call and this costs nothing.
///
/// The screen-share drawing board (`DrawPip`) is the other user of PiP.
/// Only one window can exist, and while this device presents, the board is
/// the one that matters, so the call's window yields to it.
final class CallPip: NSObject, AVPictureInPictureControllerDelegate {
  static let shared = CallPip()

  private var channel: FlutterMethodChannel?
  private var controller: AVPictureInPictureController?
  private var callVC: AVPictureInPictureVideoCallViewController?
  private var sourceView: UIView?
  private var stage: CallPipStageView?
  private var sink: RemoteFrameSink?

  private var trackId: String?
  private var videoOff = true
  private var title = ""

  /// The drawing board holds PiP (see DrawPip.arm).
  private var yielded = false

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "monkeyhub/call_pip", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "arm", "update":
        self.apply(
          title: args?["title"] as? String ?? "",
          trackId: args?["trackId"] as? String,
          videoOff: args?["videoOff"] as? Bool ?? true,
          fit: args?["fit"] as? Bool ?? false
        )
        result(nil)
      case "disarm":
        self.disarm()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// DrawPip takes PiP while a share is on the air, and gives it back.
  func setYielded(_ value: Bool) {
    if yielded == value { return }
    yielded = value
    guard let pip = controller else { return }
    pip.canStartPictureInPictureAutomaticallyFromInline = !value
    if value && pip.isPictureInPictureActive {
      pip.stopPictureInPicture()
    }
  }

  // MARK: - arming

  private func apply(title: String, trackId: String?, videoOff: Bool, fit: Bool) {
    self.title = title
    self.videoOff = videoOff || trackId == nil
    let trackChanged = trackId != self.trackId
    self.trackId = trackId
    if controller == nil {
      arm()
    }
    stage?.setTitle(title)
    stage?.setVideoOff(self.videoOff)
    stage?.videoView.displayLayer.videoGravity = fit ? .resizeAspect : .resizeAspectFill
    if trackChanged, controller?.isPictureInPictureActive == true {
      attachSink()
    }
  }

  private func arm() {
    guard AVPictureInPictureController.isPictureInPictureSupported(),
          let host = Self.hostView()
    else { return }

    let source = UIView(frame: host.bounds)
    source.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    source.isUserInteractionEnabled = false
    source.isAccessibilityElement = false
    source.backgroundColor = .clear
    host.addSubview(source)

    let vc = AVPictureInPictureVideoCallViewController()
    let stage = CallPipStageView()
    stage.frame = vc.view.bounds
    stage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    vc.view.addSubview(stage)
    vc.view.backgroundColor = CallPipStageView.stageColor
    // Portrait until the first frame says otherwise: the peer's phone.
    vc.preferredContentSize = Self.contentSize(aspect: 9.0 / 16.0)

    let pip = AVPictureInPictureController(
      contentSource: .init(activeVideoCallSourceView: source, contentViewController: vc)
    )
    pip.canStartPictureInPictureAutomaticallyFromInline = !yielded
    pip.delegate = self

    sourceView = source
    callVC = vc
    self.stage = stage
    controller = pip
  }

  private func disarm() {
    trackId = nil
    guard let pip = controller else { return }
    // Off first: a controller released with auto-start still on is the
    // "PiP started by itself as the call ended" Apple warns about.
    pip.canStartPictureInPictureAutomaticallyFromInline = false
    if pip.isPictureInPictureActive {
      pip.stopPictureInPicture()
    }
    detachSink()
    pip.delegate = nil
    controller = nil
    callVC = nil
    sourceView?.removeFromSuperview()
    sourceView = nil
    stage = nil
  }

  private static func hostView() -> UIView? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController?
      .view
  }

  /// PiP sizes the window itself; this only tells it the shape.
  private static func contentSize(aspect: CGFloat) -> CGSize {
    let a = max(0.3, min(aspect, 3.5))
    return a < 1 ? CGSize(width: 1080 * a, height: 1080) : CGSize(width: 1080, height: 1080 / a)
  }

  // MARK: - frames

  private func attachSink() {
    detachSink()
    guard let stage = stage, let id = trackId, let track = Self.remoteTrack(id) else {
      if let id = trackId { NSLog("[call_pip] no remote track \(id); showing the name card") }
      return
    }
    let sink = RemoteFrameSink(view: stage.videoView) { [weak self] aspect in
      self?.callVC?.preferredContentSize = Self.contentSize(aspect: aspect)
    }
    track.add(sink)
    sink.track = track
    self.sink = sink
  }

  private func detachSink() {
    guard let sink = sink else { return }
    sink.track?.remove(sink)
    sink.track = nil
    self.sink = nil
    stage?.videoView.flush()
  }

  /// The remote track flutter_webrtc holds under [id]. Reached through the
  /// runtime rather than the plugin's headers, which are not a module Swift
  /// can import (same as DrawPip's ScreenFrameGrabber).
  private static func remoteTrack(_ id: String) -> RTCVideoTrack? {
    let shared = NSSelectorFromString("sharedSingleton")
    let lookup = NSSelectorFromString("remoteTrackForId:")
    guard let cls = NSClassFromString("FlutterWebRTCPlugin"),
          (cls as AnyObject).responds(to: shared),
          let plugin = (cls as AnyObject).perform(shared)?.takeUnretainedValue() as? NSObject,
          plugin.responds(to: lookup),
          let track = plugin.perform(lookup, with: id)?.takeUnretainedValue() as? RTCVideoTrack
    else { return nil }
    return track
  }

  // MARK: - AVPictureInPictureControllerDelegate

  func pictureInPictureControllerWillStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    attachSink()
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    detachSink()
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    NSLog("[call_pip] failed to start: \(error)")
    detachSink()
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    // The user tapped the window: they want the call, whatever screen the
    // app was on. iOS grows the window back over the source view (the
    // whole app) and fades it once this completes, so Dart first puts the
    // call screen up with no slide (CallFloat.restoreFromSystemPip), and
    // only its reply lets the window go. Completing straight away showed
    // the picture filling the screen, then the chat it was minimized over
    // appearing from under it: two steps instead of one. A bound on the
    // wait, so a busy engine never leaves the window stuck mid-restore.
    var done = false
    let finish = {
      if done { return }
      done = true
      completionHandler(true)
    }
    guard let channel = channel else {
      finish()
      return
    }
    channel.invokeMethod("restore", arguments: nil) { _ in
      DispatchQueue.main.async(execute: finish)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: finish)
  }
}

// MARK: - The stage

/// What the window shows: the peer's picture, or their name on a quiet card
/// while it is off.
final class CallPipStageView: UIView {
  static let stageColor = UIColor(red: 0x0E / 255, green: 0x0F / 255, blue: 0x12 / 255, alpha: 1)

  let videoView = SampleBufferVideoView()
  private let card = UIStackView()
  private let initial = UILabel()
  private let badge = UIView()
  private let name = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = Self.stageColor
    isUserInteractionEnabled = false

    videoView.frame = bounds
    videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(videoView)

    badge.backgroundColor = UIColor.white.withAlphaComponent(0.12)
    badge.layer.cornerRadius = 32
    badge.translatesAutoresizingMaskIntoConstraints = false
    initial.font = .systemFont(ofSize: 28, weight: .semibold)
    initial.textColor = .white
    initial.textAlignment = .center
    initial.translatesAutoresizingMaskIntoConstraints = false
    badge.addSubview(initial)
    NSLayoutConstraint.activate([
      badge.widthAnchor.constraint(equalToConstant: 64),
      badge.heightAnchor.constraint(equalToConstant: 64),
      initial.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
      initial.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
    ])

    name.font = .systemFont(ofSize: 15, weight: .semibold)
    name.textColor = UIColor.white.withAlphaComponent(0.85)
    name.textAlignment = .center
    name.numberOfLines = 2
    name.adjustsFontSizeToFitWidth = true
    name.minimumScaleFactor = 0.7

    card.addArrangedSubview(badge)
    card.addArrangedSubview(name)
    card.axis = .vertical
    card.alignment = .center
    card.spacing = 10
    card.translatesAutoresizingMaskIntoConstraints = false
    addSubview(card)
    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: centerXAnchor),
      card.centerYAnchor.constraint(equalTo: centerYAnchor),
      card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
      card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
    ])
    setVideoOff(true)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  func setTitle(_ title: String) {
    name.text = title
    initial.text = title.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
  }

  func setVideoOff(_ off: Bool) {
    videoView.isHidden = off
    card.isHidden = !off
  }
}

/// An `AVSampleBufferDisplayLayer` that turns with the frame: WebRTC hands
/// over sensor-shaped buffers plus a rotation, and the layer is laid out
/// sideways and turned rather than every frame being rotated on the CPU.
final class SampleBufferVideoView: UIView {
  let displayLayer = AVSampleBufferDisplayLayer()
  private var rotation: RTCVideoRotation = ._0

  override init(frame: CGRect) {
    super.init(frame: frame)
    displayLayer.videoGravity = .resizeAspectFill
    displayLayer.backgroundColor = UIColor.clear.cgColor
    layer.addSublayer(displayLayer)
    clipsToBounds = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  func setRotation(_ r: RTCVideoRotation) {
    if r == rotation { return }
    rotation = r
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let b = bounds
    let turned = rotation == ._90 || rotation == ._270
    displayLayer.bounds = CGRect(
      x: 0, y: 0,
      width: turned ? b.height : b.width,
      height: turned ? b.width : b.height
    )
    displayLayer.position = CGPoint(x: b.midX, y: b.midY)
    let angle: CGFloat
    switch rotation {
    case ._90: angle = .pi / 2
    case ._180: angle = .pi
    case ._270: angle = -.pi / 2
    default: angle = 0
    }
    displayLayer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
    CATransaction.commit()
  }

  func enqueue(_ sample: CMSampleBuffer) {
    if #available(iOS 17.0, *) {
      let r = displayLayer.sampleBufferRenderer
      if r.status == .failed { r.flush() }
      r.enqueue(sample)
    } else {
      if displayLayer.status == .failed { displayLayer.flush() }
      displayLayer.enqueue(sample)
    }
  }

  func flush() {
    if #available(iOS 17.0, *) {
      displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
    } else {
      displayLayer.flushAndRemoveImage()
    }
  }
}

/// Takes the remote track's frames while the window is up and hands the
/// newest one to the layer. A frame is turned into a sample buffer on
/// WebRTC's thread (zero-copy for the decoder's own pixel buffers, one
/// I420-to-NV12 pass otherwise) and enqueued on the main thread; frames
/// that arrive while one is still on its way are dropped, never queued.
final class RemoteFrameSink: NSObject, RTCVideoRenderer {
  weak var view: SampleBufferVideoView?
  var track: RTCVideoTrack?
  private let onAspect: (CGFloat) -> Void
  private let lock = NSLock()
  private var pending = false
  private var lastAspect: CGFloat = 0
  private var lastRotation: RTCVideoRotation = ._0
  private var pool: CVPixelBufferPool?
  private var poolSize = CGSize.zero

  init(view: SampleBufferVideoView, onAspect: @escaping (CGFloat) -> Void) {
    self.view = view
    self.onAspect = onAspect
  }

  func setSize(_ size: CGSize) {}

  func renderFrame(_ frame: RTCVideoFrame?) {
    guard let frame = frame, frame.width > 0, frame.height > 0 else { return }
    lock.lock()
    if pending {
      lock.unlock()
      return
    }
    pending = true
    lock.unlock()

    guard let pixels = pixelBuffer(for: frame), let sample = Self.sample(pixels) else {
      lock.lock()
      pending = false
      lock.unlock()
      return
    }
    let rotation = frame.rotation
    let turned = rotation == ._90 || rotation == ._270
    let w = CGFloat(turned ? frame.height : frame.width)
    let h = CGFloat(turned ? frame.width : frame.height)
    let aspect = w / h
    let aspectChanged = abs(aspect - lastAspect) > 0.01
    let rotationChanged = rotation != lastRotation
    lastAspect = aspect
    lastRotation = rotation

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if rotationChanged { self.view?.setRotation(rotation) }
      if aspectChanged { self.onAspect(aspect) }
      self.view?.enqueue(sample)
      self.lock.lock()
      self.pending = false
      self.lock.unlock()
    }
  }

  private func pixelBuffer(for frame: RTCVideoFrame) -> CVPixelBuffer? {
    if let cv = frame.buffer as? RTCCVPixelBuffer, !cv.requiresCropping() {
      return cv.pixelBuffer
    }
    let i420 = frame.buffer.toI420()
    let w = Int(i420.width)
    let h = Int(i420.height)
    guard let pool = pixelPool(width: w, height: h) else { return nil }
    var out: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out) == kCVReturnSuccess,
          let buffer = out
    else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let dstY = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
          let dstUV = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)
    else { return nil }
    RTCYUVHelper.i420(
      toNV12: i420.dataY,
      srcStrideY: i420.strideY,
      srcU: i420.dataU,
      srcStrideU: i420.strideU,
      srcV: i420.dataV,
      srcStrideV: i420.strideV,
      dstY: dstY.assumingMemoryBound(to: UInt8.self),
      dstStrideY: Int32(CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)),
      dstUV: dstUV.assumingMemoryBound(to: UInt8.self),
      dstStrideUV: Int32(CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)),
      width: Int32(w),
      height: Int32(h)
    )
    return buffer
  }

  private func pixelPool(width: Int, height: Int) -> CVPixelBufferPool? {
    let size = CGSize(width: width, height: height)
    if let pool = pool, poolSize == size { return pool }
    let attrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      kCVPixelBufferWidthKey as String: width,
      kCVPixelBufferHeightKey as String: height,
      kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
    ]
    var created: CVPixelBufferPool?
    CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &created)
    pool = created
    poolSize = size
    return created
  }

  /// A sample to show the moment it lands: no timing, displayed at once.
  private static func sample(_ pixels: CVPixelBuffer) -> CMSampleBuffer? {
    var format: CMVideoFormatDescription?
    guard CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixels,
      formatDescriptionOut: &format
    ) == noErr, let format = format else { return nil }
    var timing = CMSampleTimingInfo(
      duration: .invalid,
      presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
      decodeTimeStamp: .invalid
    )
    var sample: CMSampleBuffer?
    guard CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixels,
      formatDescription: format,
      sampleTiming: &timing,
      sampleBufferOut: &sample
    ) == noErr, let sample = sample else { return nil }
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
       CFArrayGetCount(attachments) > 0 {
      let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
      CFDictionarySetValue(
        dict,
        Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
        Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
      )
    }
    return sample
  }
}
