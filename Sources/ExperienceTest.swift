import AppKit
import ScreenCaptureKit
import AVFoundation

/// Explicit visible proof: scripted sensor input, real live capture and on-screen presentation.
/// Only --proof-video records a movie; ordinary operation never saves frames.
enum ExperienceTest {
    static var recorder: ProofRecorder?
    static var labelWindow: NSWindow?
    static var status: NSTextField?
    static func start(_ model: AppModel, delegate: AppDelegate) {
        guard CGPreflightScreenCaptureAccess() else { print("FAIL: Screen permission missing; no prompt requested."); exit(2) }
        var failures = 0
        func check(_ value: Bool, _ label: String) { print("\(value ? "PASS" : "FAIL"): \(label)"); if !value { failures += 1 }; fflush(stdout) }
        guard let screen = NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) ?? NSScreen.main else { exit(2) }
        let banner = NSWindow(contentRect: NSRect(x:screen.frame.minX+24,y:screen.frame.maxY-96,width:740,height:56),styleMask:[.borderless],backing:.buffered,defer:false)
        banner.level = .screenSaver; banner.isReleasedWhenClosed = false; banner.backgroundColor = NSColor.black.withAlphaComponent(0.82); banner.ignoresMouseEvents = true
        let text = NSTextField(labelWithString:"Fold · live desktop run · scripted lid input")
        text.textColor = .white; text.font = .systemFont(ofSize:20,weight:.medium); text.frame = NSRect(x:18,y:17,width:704,height:26)
        banner.contentView?.addSubview(text); banner.orderFrontRegardless(); labelWindow = banner; status = text
        func phase(_ value: String) { text.stringValue = value; print(value); fflush(stdout) }
        model.testUsesSensor = true; model.testSensorAngle = 112; model.showMenuBar = false
        let args = CommandLine.arguments
        if let i = args.firstIndex(of:"--proof-video"), i+1 < args.count {
            let r = ProofRecorder(); recorder = r
            Task { @MainActor in
                do { try await r.start(url:URL(fileURLWithPath:args[i+1]),displayID:screen.displayID) }
                catch { print("FAIL recording: \(error)"); failures += 1 }
            }
        }
        func after(_ t: Double,_ body: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline:.now()+t,execute:body) }
        after(1) {
            check(Bundle.main.url(forResource:"Logo",withExtension:"png") != nil,"Generated logo is bundled at launch")
            check(NSApp.applicationIconImage.size.width > 100,"Launch icon uses full-resolution artwork")
            check(Bundle.main.url(forResource:"Preview",withExtension:"mp4") != nil && Bundle.main.url(forResource:"PreviewPoster",withExtension:"png") != nil,"Physical-lid preview and poster are bundled")
            check(!model.menuBarIsVisible,"No menu bar control is required")
            delegate.window?.close()
            check(NSApp.activationPolicy() == .accessory,"Closing Settings removes Dock icon")
            model.activate(); phase("Settings closed · ready at 112°")
        }
        after(1.8) { check(model.captureIsRunning && !model.overlayIsVisible,"Capture is warm with the desktop clear") }
        after(2) { model.testSensorAngle = 111; phase("One degree of closing from 112°") }
        after(2.18) { check(model.overlayIsVisible,"One degree of movement displays the warm overlay within 180 ms"); model.testSensorAngle = 112 }
        after(2.4) { check(!model.overlayIsVisible,"One degree of opening clears within 220 ms") }
        after(2.5) { check(model.captureStarts == 1,"Reversal reuses capture instead of restarting it") }
        for frame in 0...120 {
            let t=Double(frame)/60
            after(3+t) { model.testSensorAngle=112-82*(0.5-0.5*cos(t/2 * .pi)); phaseText(model,prefix:"Closing") }
        }
        after(4.5) {
            check(model.receivedFrames>0,"Live desktop frames arrive")
            check(model.overlayIsVisible && model.presentedFrames>0,"Actual overlay follows a closing gesture")
        }
        for frame in 0...18 {
            after(5.1+Double(frame)/60) { model.testSensorAngle=30+Double(frame)*15/18 }
        }
        after(5.35) { check(model.overlayIsVisible && model.settings.progress>0.5,"Partial reopening retains and reverses the active fold") }
        after(6.05) {
            check(!model.overlayIsVisible && model.captureIsRunning,"Opening and pausing clears while capture remains ready")
            check(model.enabled,"Automatic folding remains enabled after reset")
        }
        after(6.2) { model.testSensorAngle=60 }
        after(6.5) { check(!model.overlayIsVisible,"Continuing to reopen does not bring blur back") }
        after(6.6) { model.testSensorAngle=59 }
        after(6.85) { check(model.overlayIsVisible,"A new one-degree closing gesture starts at the new posture"); model.testSensorAngle=60 }
        after(7.1) { check(!model.overlayIsVisible,"Undoing that one-degree gesture clears at 60 degrees") }
        after(7.8) { model.testSensorAngle=112 }
        for frame in 0...90 {
            let t=Double(frame)/60
            after(8+t) { model.testSensorAngle=112-107*(0.5-0.5*cos(t/1.5 * .pi)); phaseText(model,prefix:"Closing nearly shut") }
        }
        after(9) { check(model.overlayIsVisible,"Another closing fold works") }
        after(9.8) { check(!model.overlayIsVisible,"Nearly closed clears promptly") }
        after(10) { model.suspendForSystem(); model.resumeAfterSystem(); model.testSensorAngle=112 }
        // Model a real closing movement after cold recovery. A single angle
        // jump followed by a 300 ms check races ScreenCaptureKit startup.
        for frame in 0...60 {
            let t=Double(frame)/60
            after(11+t) { model.testSensorAngle=112-62*t }
            after(13+t) { model.testSensorAngle=112-67*t }
        }
        after(12.2) { check(model.overlayIsVisible,"Effect resumes after simulated sleep/wake"); model.testSensorAngle=nil }
        after(12.4) { check(!model.overlayIsVisible,"Lost sensor fails clear"); model.testSensorAngle=359 }
        after(12.6) { check(!model.captureIsRunning && model.sensorAngle == nil,"Wrapped sensor reading cannot restart capture"); model.testSensorAngle=112 }
        after(14.2) { check(model.overlayIsVisible,"Sensor reconnection rearms on closing") }
        after(15) { check(model.overlayIsVisible,"A short closing hold does not dismiss the fold") }
        after(15.9) { check(!model.overlayIsVisible,"A longer stationary hold recovers to a usable desktop"); model.pause() }
        after(16.1) {
            check(!model.captureIsRunning && !model.overlayIsVisible,"Pause releases every effect surface")
            delegate.showSettings(); phase("Fold · run complete · \(failures == 0 ? "all checks passed" : "failures detected")")
            print("FRAMES received=\(model.receivedFrames) presented=\(model.presentedFrames)")
        }
        after(17.5) {
            Task { @MainActor in
                do { try await recorder?.finish() } catch { print("FAIL recording finish: \(error)"); failures += 1 }
                labelWindow?.close(); model.shutdown(); print("EXPERIENCE: \(failures == 0 ? "passed" : "failed")"); fflush(stdout)
                exit(failures == 0 ? 0 : 1)
            }
        }
    }
    private static func phaseText(_ model:AppModel,prefix:String) { status?.stringValue = "\(prefix) · \(Int(model.testSensorAngle ?? 0))° · live desktop overlay" }
}

final class ProofRecorder: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var started = false
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let context = CIContext()
    private var frameCount = 0
    private let queue = DispatchQueue(label:"Fold.proof-recorder")
    func start(url:URL,displayID:CGDirectDisplayID) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true)
        guard let display = content.displays.first(where:{ $0.displayID == displayID }) else { throw NSError(domain:"ProofRecorder",code:1) }
        let width = 1440, height = Int((Double(display.height)/Double(display.width)*1440)/2)*2
        let writer = try AVAssetWriter(outputURL:url,fileType:.mov)
        let input = AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:8_000_000]])
        input.expectsMediaDataInRealTime = true; writer.add(input); self.writer = writer; self.input = input
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferIOSurfacePropertiesKey as String:[:] ])
        let config = SCStreamConfiguration(); config.width = width; config.height = height
        config.minimumFrameInterval = CMTime(value:1,timescale:60); config.queueDepth = 3; config.showsCursor = false
        let stream = SCStream(filter:SCContentFilter(display:display,excludingWindows:[]),configuration:config,delegate:nil)
        try stream.addStreamOutput(self,type:.screen,sampleHandlerQueue:queue); self.stream = stream
        try await stream.startCapture()
    }
    func stream(_ stream:SCStream,didOutputSampleBuffer sample:CMSampleBuffer,of type:SCStreamOutputType) {
        guard type == .screen,sample.isValid,let writer,let input,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sample,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],
              attachments.first?[.status] as? Int == SCFrameStatus.complete.rawValue else { return }
        if !started { writer.startWriting(); writer.startSession(atSourceTime:sample.presentationTimeStamp); started = true }
        guard input.isReadyForMoreMediaData, let source = sample.imageBuffer, let adaptor, let pool = adaptor.pixelBufferPool else { return }
        // Copy into the writer's pool. Retaining SCK's IOSurfaces starves its small queue.
        var target: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil,pool,&target) == kCVReturnSuccess, let target else { return }
        context.render(CIImage(cvPixelBuffer:source),to:target)
        if adaptor.append(target,withPresentationTime:sample.presentationTimeStamp) { frameCount += 1 }
    }
    func finish() async throws {
        try await stream?.stopCapture()
        await withCheckedContinuation { (c:CheckedContinuation<Void,Never>) in queue.async { c.resume() } }
        guard started,let writer else { throw NSError(domain:"ProofRecorder",code:2,userInfo:[NSLocalizedDescriptionKey:"No video frames recorded"]) }
        input?.markAsFinished(); await writer.finishWriting(); if let error = writer.error { throw error }
        print("RECORDED FRAMES: \(frameCount)")
        if frameCount < 60 { throw NSError(domain:"ProofRecorder",code:3,userInfo:[NSLocalizedDescriptionKey:"Too few recorded frames"]) }
    }
}
