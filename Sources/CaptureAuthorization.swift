import Foundation

/// All prompting goes through startup. Buttons may refresh permission status,
/// but never ask again, even after a denial or stream error.
struct CaptureAuthorization {
    private(set) var checkedStartup = false
    mutating func startup(preflight: () -> Bool, request: () -> Bool) -> Bool {
        guard !checkedStartup else { return preflight() }
        checkedStartup = true
        return preflight() || request()
    }
}
