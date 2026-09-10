import Foundation

/// A bounded transition that rearms on movement from any lid position.
/// No startup, wake, or recovery path requires opening to a particular angle.
struct FoldSafety {
    private(set) var waitingForMotion = true
    private var lastAngle: Double?
    private var restAngle: Double?
    private var beganAt: Double?
    private var lastMotionAt: Double?
    private var motionAnchor: Double?
    private var closedSince: Double?

    mutating func suspend() {
        waitingForMotion = true; restAngle = lastAngle; beganAt = nil
        lastMotionAt = nil; motionAnchor = nil; closedSince = nil
    }
    mutating func permitsEffect(angle: Double?, clearAngle: Double, now: Double) -> Bool {
        guard let angle, angle.isFinite, clearAngle.isFinite else {
            lastAngle = nil; suspend(); return false
        }
        lastAngle = angle
        if waitingForMotion {
            guard let restAngle else { self.restAngle = angle; return false }
            // Reject tiny HID jitter while accepting a natural movement in either direction.
            guard abs(angle-restAngle) >= 0.75 else { return false }
            waitingForMotion = false; self.restAngle = nil
        }
        if angle >= clearAngle {
            beganAt = nil; lastMotionAt = nil; motionAnchor = nil; closedSince = nil
            return false
        }
        if beganAt == nil { beganAt = now; lastMotionAt = now; motionAnchor = angle }
        if abs(angle - (motionAnchor ?? angle)) >= 0.75 { lastMotionAt = now; motionAnchor = angle }
        if angle <= 8 {
            if closedSince == nil { closedSince = now }
        } else { closedSince = nil }
        if now - beganAt! >= 8 || now - lastMotionAt! >= 2.5 || closedSince.map({ now - $0 >= 0.35 }) == true {
            suspend(); return false
        }
        return true
    }
}

/// Track the open endpoint instead of assuming every desk posture is 100°.
struct LidReference {
    private(set) var openingAngle: Double?
    var clearAngle: Double { max(1, openingAngle ?? 100) }
    mutating func observe(_ angle: Double?) {
        // Some sensors report 359/360 while closed; this is not an open posture.
        guard let angle, angle.isFinite, (0...180).contains(angle) else { return }
        openingAngle = max(openingAngle ?? angle, angle)
    }
}
