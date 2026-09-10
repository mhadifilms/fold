import Foundation

/// Travel relative to this gesture only. Closing and opening use the same
/// position curve; a reversal never triggers a separate release animation.
struct FoldSafety {
    private(set) var waitingForMotion = true
    private(set) var poseProgress = 0.0
    private(set) var opacity = 0.0
    var progress: Double { poseProgress * opacity }
    private var anchor: Double?
    private var reference: Double?
    private var beganAt: Double?
    private var lastMotionAt: Double?
    private var closedSince: Double?
    private var opening = false

    mutating func suspend() { self = FoldSafety() }
    private mutating func finish(at angle: Double, keepPose: Bool = false) {
        let pose = poseProgress
        suspend(); anchor = angle
        if keepPose { poseProgress = pose }
    }
    mutating func permitsEffect(angle: Double?, now: Double) -> Bool {
        guard let angle, angle.isFinite, (0...180).contains(angle) else {
            suspend(); return false
        }
        guard let anchor else { self.anchor = angle; return false }
        let closing = anchor-angle
        if waitingForMotion {
            guard closing >= 0.75 else {
                if closing < 0 { self.anchor = angle }
                return false
            }
            reference = anchor; beganAt = now; lastMotionAt = now
            waitingForMotion = false
        }
        if abs(closing) >= 0.75 {
            self.anchor = angle; lastMotionAt = now; opening = closing < 0
        }
        guard let reference, let beganAt, let lastMotionAt else { return false }
        let travel = max(0,reference-angle)
        if travel < 0.25 { finish(at: angle); return false }
        poseProgress = 1-exp(-travel/40)
        if angle <= 8 {
            if closedSince == nil { closedSince = now }
        } else { closedSince = nil }
        if now-beganAt >= 20 || closedSince.map({ now-$0 >= 0.10 }) == true {
            finish(at: angle,keepPose:true); return false
        }
        // Recovery is independent of reversal. A low-lid pause in the reference
        // lasts about a second; allow it without interrupting the fold. Opening
        // and then settling still clears promptly instead of leaving blur behind.
        let hold = opening ? 0.22 : 1.25
        let rest = min(1,max(0,(now-lastMotionAt-hold)/0.18))
        if rest >= 1 { finish(at: angle,keepPose:true); return false }
        opacity = 1-rest*rest*(3-2*rest)
        return true
    }
}

/// The settings and public preview use the same gestures as the live effect.
/// A closing movement and reopening, shown with physical panel projection.
enum FoldPreview {
    static func angle(at time: Double) -> Double {
        if time < 0.5 { return 112 }
        if time < 2.5 { return 112-60*(time-0.5)/2 }
        if time < 4.5 { return 52+60*(time-2.5)/2 }
        return 112
    }
}
