# Macfold 1.0 verification

The first stable release is numbered 1.0.0; the earlier 2.x labels were development iterations. Build 4 changes release metadata only and retains the verified implementation below.

September 10, 2026. M3 Max MacBook Pro, macOS 26.6.2, Apple silicon build targeting macOS 14+.

## Observed product behavior

- The user confirmed that the installed app worked with the physical lid, including the reset, then reported a jump at the start of each fold.
- Real HID observations showed automatic activation at launch, native login registration enabled, the overlay becoming visible as the physical lid crossed below 100°, and clearing on reopening. No desktop frames were saved in the physical observation log.
- After installing the handoff fix, the user repeated the physical fold and confirmed: “Yes, smooth now.”
- The startup handoff was subsequently changed: capture warms when the lid begins closing; the overlay prepares a current flat frame before fading in for 120 ms; spring progress resets to zero at the handoff. Old-window GPU callbacks cannot reveal a replacement window. Unchanged settings no longer trigger continuous hidden rendering.
- The logo was visually observed in the launched Settings window. The bundle contains both AppIcon.icns for Finder and Logo.png, explicitly loaded for the running app and Dock.
- Settings can close while folding stays enabled. There is no menu bar item by default. Reopening the app brings Settings back; native ServiceManagement registration is enabled on the local installation.

## Automated checks

37 graphics/logic checks passed: sensor decoding, once-per-launch permission requests, authorized startup without a request, smoothing at 60/120 Hz, reversal stability, startup while partly closed, stationary hold and jitter, nearly-closed timeout, rearming, missing sensor, eight-second ceiling, wake gating, upright images, every edge filled at three styles and five angles, and Reduced Motion.

The visible 20-second experience test passed 15 assertions against live ScreenCaptureKit and onscreen Metal presentation: logo resources, runtime icon, no menu bar, Dock removal, incoming frames, actual overlay with Settings closed, held-lid clear and capture release, continued automatic operation, rearming, nearly-closed clear, simulated sleep/wake recovery, sensor loss, reconnection, and pause cleanup. The handoff-fix run received 447 frames, presented 461, and independently recorded 896 screen frames. Static scenes produce fewer recorded frames because ScreenCaptureKit reports idle content.

The recording is a separate capture of what was displayed, not an offscreen shader movie. Its angle sequence is explicitly scripted. Local recordings may include personal desktop content and are not committed or published. The repository preview uses only original generated artwork.

## Performance

Shipping build: GPU command timing at 2560×1600, including upload and mip generation, 1.482 ms median and 2.685 ms p95. These are single-machine GPU timings, not end-to-end latency guarantees. Display-paced rendering requests up to 120 Hz where available. Hidden views no longer redraw simply because the model's display clock ticked.

## Boundaries

The visible test simulates sleep/wake callbacks and sensor disconnection; it does not physically put the computer to sleep. Login-item registration was checked, but a complete logout/login was not performed. Other Mac models and external-display configurations need broader testing. Reference footage has no calibrated hinge-angle data; visual matching is a hand-tuned single-display adaptation, not an exact reconstruction of Apple's two-screen compositor. macOS can independently show capture reminders. The release is Developer ID signed, not notarized.
