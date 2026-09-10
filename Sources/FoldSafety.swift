import Foundation

/// A fixed-angle effect that only starts while closing. Reopening can unwind
/// an active fold, but cannot resurrect one after it has already cleared.
struct FoldSafety {
    private(set) var waitingForMotion = true
    private var lastAngle: Double?
    private var restAngle: Double?
    private var beganAt: Double?
    private var lastMotionAt: Double?
    private var motionAnchor: Double?
    private var opening = false
    private var closedSince: Double?

    mutating func suspend() {
        waitingForMotion = true; restAngle = lastAngle; beganAt = nil
        lastMotionAt = nil; motionAnchor = nil; closedSince = nil; opening = false
    }
    mutating func permitsEffect(angle: Double?, clearAngle: Double, now: Double) -> Bool {
        guard let angle, angle.isFinite, (0...180).contains(angle), clearAngle.isFinite else {
            lastAngle = nil; suspend(); return false
        }
        lastAngle = angle
        if angle >= clearAngle { suspend(); return false }
        if waitingForMotion {
            guard let restAngle else { self.restAngle = angle; return false }
            if angle >= restAngle { self.restAngle = angle; return false }
            guard restAngle-angle >= 0.75 else { return false }
            waitingForMotion = false; self.restAngle = nil
        }
        if beganAt == nil { beganAt = now; lastMotionAt = now; motionAnchor = angle }
        let delta = angle-(motionAnchor ?? angle)
        if abs(delta) >= 0.75 {
            lastMotionAt = now; motionAnchor = angle; opening = delta > 0
        }
        if angle <= 8 {
            if closedSince == nil { closedSince = now }
        } else { closedSince = nil }
        let holdLimit = opening ? 0.12 : 0.45
        if now-beganAt! >= 8 || now-lastMotionAt! >= holdLimit || closedSince.map({ now-$0 >= 0.10 }) == true {
            suspend(); return false
        }
        return true
    }
}
