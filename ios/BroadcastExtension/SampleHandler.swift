//
//  SampleHandler.swift
//  Broadcast Extension
//
//  Created by Alex-Dan Bumbu on 04.06.2021.
//
//  Vendored from LiveKit's Flutter SDK example (Apache-2.0), itself derived
//  from Jitsi's react-native-webrtc broadcast extension (Atlassian / 8x8).
//  The wire format — a CFHTTPMessage per frame with Buffer-Width/Height/
//  Orientation headers and a JPEG body over a unix socket in the app-group
//  container — is what flutter_webrtc's FlutterBroadcastScreenCapturer
//  reads on the app side; the two halves must not drift apart.
//

import ReplayKit
import OSLog

let broadcastLogger = OSLog(subsystem: "com.walhallaa.monkeyhub", category: "Broadcast")
private enum Constants {
    // The App Group both halves of the share meet in. Read from this
    // extension's Info.plist (RTCAppGroupIdentifier) so it is written down in
    // exactly one place per target; the constant is the last resort.
    static let appGroupIdentifier: String =
        (Bundle.main.object(forInfoDictionaryKey: "RTCAppGroupIdentifier") as? String)
            ?? "group.com.walhallaa.monkeyhub"
}

class SampleHandler: RPBroadcastSampleHandler {

    private var clientConnection: SocketConnection?
    private var uploader: SampleUploader?

    private var frameCount: Int = 0
    /// Set once we asked ReplayKit to end; the stop request and the socket
    /// closing usually both arrive.
    fileprivate var finishing = false

    var socketFilePath: String {
      let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier)
        return sharedContainer?.appendingPathComponent("rtc_SSFD").path ?? ""
    }

    override init() {
      super.init()
        if let connection = SocketConnection(filePath: socketFilePath) {
          clientConnection = connection
          setupConnection()

          uploader = SampleUploader(connection: connection)
        }
        os_log(.debug, log: broadcastLogger, "%{public}s", socketFilePath)
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    /// The app asks us to end: the user stopped sharing in MonkeyHub (or
    /// the call ended). The socket closing says the same, but only once we
    /// had connected, and only after the app tore its capture down.
    private func observeStopRequest() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer = observer else { return }
            let me = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async { me.finishBroadcastSilently() }
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            callback,
            DarwinNotification.broadcastStopRequested.rawValue as CFString,
            nil,
            .deliverImmediately
        )
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        frameCount = 0

        DarwinNotificationCenter.shared.postNotification(.broadcastStarted)
        observeStopRequest()
        openConnection()
    }

    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }

    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }

    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            uploader?.send(sample: sampleBuffer)
        default:
            break
        }
    }
}

private extension SampleHandler {

    func setupConnection() {
        clientConnection?.didClose = { [weak self] error in
            os_log(.debug, log: broadcastLogger, "client connection did close \(String(describing: error))")

            if let error = error {
                self?.finishBroadcastWithError(error)
            } else {
                // The app closed its end: the user stopped sharing (or left
                // the call) from inside MonkeyHub. End quietly, right now:
                // `finishBroadcastWithError` with an error makes iOS put up
                // a "Screen sharing stopped" alert for something the user
                // just did themselves. A nil error ends the broadcast with
                // no alert; Swift will not pass nil, so go through the
                // selector (undocumented but long-standing behaviour).
                DispatchQueue.main.async { self?.finishBroadcastSilently() }
            }
        }
    }

    func finishBroadcastSilently() {
        guard !finishing else { return }
        finishing = true
        let selector = NSSelectorFromString("finishBroadcastWithError:")
        guard responds(to: selector) else {
            let JMScreenSharingStopped = 10001
            finishBroadcastWithError(NSError(domain: RPRecordingErrorDomain, code: JMScreenSharingStopped, userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped"]))
            return
        }
        perform(selector, with: nil)
    }

    func openConnection() {
        let queue = DispatchQueue(label: "broadcast.connectTimer")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard self?.clientConnection?.open() == true else {
                return
            }

            timer.cancel()
        }

        timer.resume()
    }
}
