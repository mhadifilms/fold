import Foundation

/// A fold is a bounded transition, never a permanent desktop mode.
struct FoldSafety {
    private(set) var waitingForOpen = true
    private var openSince: Double?
    private var beganAt: Double?
    private var lastMotionAt: Double?
    private var motionAnchor: Double?
    private var closedSince: Double?

    mutating func suspend() {
        waitingForOpen = true; openSince = nil; beganAt = nil
        lastMotionAt = nil; motionAnchor = nil; closedSince = nil
    }
    mutating func permitsEffect(angle: Double?, clearAngle: Double, now: Double) -> Bool {
        guard let angle, angle.isFinite, clearAngle.isFinite else { suspend(); return false }
        if angle >= clearAngle + 3 {
            if openSince == nil { openSince = now }
            if now - openSince! >= 0.20 {
                waitingForOpen = false; beganAt = nil; lastMotionAt = nil; motionAnchor = nil; closedSince = nil
            }
            return false
        }
        openSince = nil
        guard !waitingForOpen else { return false }
        guard angle < clearAngle else { return false }
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
