import AppKit

/// Explicit opt-in integration check. Does not synthesize input or change OS
/// permissions. Uses the same model actions as Settings, and saves no screen pixels.
enum IntegrationTest {
    static func start(_ model: AppModel) {
        guard CGPreflightScreenCaptureAccess() else { print("SKIP: Screen permission is not granted. No prompt was requested.");exit(2) }
        var failures=[String]()
        func check(_ condition:Bool,_ label:String) {
            print("\(condition ? "PASS" : "FAIL"): \(label)")
            if !condition { failures.append(label) }
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+1) {
            model.angle=50;model.previewDesktop()
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+3) {
            check(model.receivedFrames>0,"ScreenCaptureKit delivers desktop frames")
            check(model.presentedFrames>0 && model.overlayIsVisible,"Metal presents the desktop overlay")
            model.angle=100
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+4) {
            check(!model.overlayIsVisible,"Open angle clears overlay after smoothing")
            check(model.captureIsRunning,"Capture remains ready between folds")
            model.angle=35
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+6) {
            check(model.overlayIsVisible,"Second fold restores overlay")
            check(model.captureStarts==1,"Repeated folds reuse a single capture session")
            print("Frames received: \(model.receivedFrames), presented: \(model.presentedFrames)")
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+9.7) {
            check(!model.demo && !model.overlayIsVisible && !model.captureIsRunning,"Timed preview stops and releases capture")
            model.previewDesktop();model.pause()
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+12) {
            check(!model.overlayIsVisible && !model.captureIsRunning,"Pause during async startup cannot resurrect overlay")
            model.shutdown()
            print("INTEGRATION: \(failures.isEmpty ? "passed" : "failed")")
            fflush(stdout)
            exit(failures.isEmpty ? 0 : 1)
        }
    }
}
