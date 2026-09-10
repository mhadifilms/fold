import AppKit
import ScreenCaptureKit
import CoreMedia

final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var configuration: SCStreamConfiguration?
    private let queue = DispatchQueue(label: "Macfold.frames", qos: .userInteractive)
    private let lock = NSLock()
    private var latestFrame: CIImage?
    private var activity: Date?
    var lastActivity: Date? { lock.withLock { activity } }
    var onFailure: ((String) -> Void)?

    func takeFrame() -> CIImage? {
        lock.lock(); defer { lock.unlock() }
        let frame = latestFrame; latestFrame = nil
        return frame
    }
    func start(displayID: CGDirectDisplayID, framesPerSecond: Int) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "Macfold", code: 1, userInfo: [NSLocalizedDescriptionKey: "The selected display is no longer available."])
        }
        // Exclude every Macfold window explicitly by app, so the overlay never captures itself.
        let ownApp = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        guard !ownApp.isEmpty else {
            throw NSError(domain: "Macfold", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not exclude the Macfold overlay from capture. Reopen Macfold and try again."])
        }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let scale = min(1.0, 2560.0 / Double(display.width))
        config.width = Int(Double(display.width) * scale)
        config.height = Int(Double(display.height) * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(framesPerSecond))
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.capturesAudio = false
        self.configuration = config
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
    }
    func setFrameRate(_ fps: Int) async throws {
        guard let stream else { return }
        let configuration = self.configuration!
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        try await stream.updateConfiguration(configuration)
    }
    func stop() async {
        let old = stream; stream = nil
        try? await old?.stopCapture()
        lock.withLock { latestFrame = nil; activity = nil }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onFailure?(error.localizedDescription) }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, let status = SCFrameStatus(rawValue: raw) else { return }
        if status == .idle { lock.withLock { activity = Date() }; return }
        guard status == .complete, let buffer = sampleBuffer.imageBuffer else { return }
        let frame = CIImage(cvPixelBuffer: buffer)
        lock.withLock { latestFrame = frame; activity = Date() }
    }
}
