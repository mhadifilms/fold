# Fold 1.0.5 verification

Build 11 removes remembered angles. Closing below 90° starts the effect; opening to 90° removes the overlay immediately, including any pending reveal or spring tail. Pausing while reopening below the threshold clears after 120 ms and cannot rearm on further opening. A new closing movement rearms. Closing holds clear after 450 ms, nearly-closed holds after 100 ms.

All 43 current graphics/recovery checks pass, including fixed-angle entry, prompt exit, reopening pauses, continued-opening suppression, direction reversal, tiny jitter, sensor loss, wraparound and bounded transitions. Tests for the removed adaptive-angle behavior were replaced with the fixed-angle lifecycle cases.

The installed app passed all 20 live assertions through normal LaunchServices launch with scripted sensor input and real ScreenCaptureKit/Metal. A visible fold was reopened to 45° and held; its overlay and capture were gone at the check 250 ms later. Further opening to 60° remained clear. Closing to 58° restarted the effect; opening to 90° cleared before the check 100 ms later. The run received 132 frames and presented 179. All remaining logo, capture and recovery checks passed.

Developer ID signed and timestamped. Notarization remains pending Apple service authentication.

---

# Fold 1.0.4 verification

Build 10 resets the return point to the settled posture when the held-lid recovery clears the effect. It also resets on activation, sleep and sensor loss, keeping a fixed endpoint during the next fold.

All 58 graphics/recovery checks pass. The new regressions start at 140°, settle at 110°, 95° or 70°, close from that posture, and verify that returning there produces zero effect progress. These also verify that closing does not move the reference downward. Previous onset, shading, horizontal-band and recovery checks continue to pass.

The installed LaunchServices app passed all 17 live assertions with actual ScreenCaptureKit/Metal and scripted lid input. After settling at 30°, it folded at 29° and cleared when returned to 30°, without reopening to the earlier 112°. The run received 446 frames and presented 546; all prior live recovery checks also passed.

Developer ID signed and timestamped. Notarization remains pending Apple service authentication.

---

# Fold 1.0.3 verification

Build 9 adds soft left/right shading and removes the Settings slogan. Side shadows increase continuously with fold progress and toward the outer edge; their maximum opacity is bounded so the desktop remains present beneath them. Zero progress has no added shading.

All 46 graphics/recovery checks pass, including visible side depth, left/right symmetry, complete clearing at rest, horizontal-band regression and immediate onset from multiple starting angles. The installed app passed all 15 live assertions through normal LaunchServices launch with real capture and Metal presentation, using scripted sensor input: 375 frames received, 438 presented. The single effect, immediate onset, fresh-frame entrance and safety resets remain intact.

The new preview was rendered at 60 fps using original artwork. GPU command timing at 2560×1600 including upload and prefiltering: 0.779 ms median, 0.953 ms p95 on this run; these are not end-to-end latency guarantees. Developer ID signed and timestamped; notarization still awaits Apple service authentication.

---

# Fold 1.0.2 verification

One effect replaces the three style variants and appearance sliders. The compact native Settings window has an in-window preview and three behavior switches; saved legacy appearance values are ignored. The installed window was visually inspected in dark mode with the bundled logo, clear preview, readable controls and no scrolling.

The new Gaussian pyramid and projective mapping were compared against the prior renderer using original sample artwork. The horizontal-stripe regression passes at 80°, 50° and 20° with no secondary intensity rises. The previous renderer fails the 50° case (two 8-bit steps of secondary rise; tolerance is one step). All 43 current graphics/recovery checks pass, including nine checks for onset from different open positions and closed-sensor wraparound, plus three band regressions. A new 60 fps preview was rendered with the shipping shader.

The signed build's GPU command timing at 2560×1600 including upload and prefiltering was 2.563 ms median and 3.759 ms p95. These are single-machine GPU measurements, not end-to-end latency guarantees.

Build 8 removes the fixed 100° activation cutoff. The observed open position becomes the clear endpoint, and the first closing degree starts blur. Safety now evaluates each 60 Hz sensor sample, while the independent watchdog still clears stale or held input. The 120 ms fresh-frame handoff remains.

After the physical lid reopened, the normal LaunchServices installation passed all 15 live assertions with scripted sensor input, actual ScreenCaptureKit frames and onscreen Metal presentation. This explicitly includes visible effect onset from 112° to 111°, above the former threshold. The run received 418 frames and presented 493. Held-lid reset, nearly-closed reset, wake and sensor recovery all passed. The earlier closed-lid run produced no display frames and was not counted as successful.

Notarization is still awaiting the user's Apple authentication setup. The build is Developer ID signed and timestamped, not notarized.

---

# Fold 1.0.1 verification

Build 6 renames the app, cover and repository to Fold while retaining the existing bundle identifier and Developer ID identity. The installed app is `/Applications/Fold.app`; its login registration was refreshed to the new path.

A normal macOS LaunchServices launch confirmed screen access granted, automatic folding enabled, the emergency shortcut available and native login registration enabled. The installed app then passed all 15 visible lifecycle assertions using actual ScreenCaptureKit frames and onscreen Metal presentation, with scripted lid input: 406 frames received, 424 presented. Logo loading, hidden Dock after Settings closes, held-lid reset, nearly-closed reset, wake/sensor recovery and pause cleanup passed. No desktop recording was made. After the test the app was relaunched normally in background mode.

All 41 graphics and recovery checks passed. GPU timing at 2560×1600 including upload and mip generation: 1.429 ms median, 2.504 ms p95 on this Mac. These are GPU timings, not end-to-end latency guarantees. This build is Developer ID signed and timestamped. Notarization is awaiting Apple service authentication; it is not yet notarized.

---

# Recovery correction

An earlier installed LaunchServices process was alive but lacked Screen Recording permission. Developer-launched runs did not establish standalone permission. This gap was resolved and verified in the Fold build 6 installation below.

Removed the requirement to open above 103 degrees. Startup, stationary reset, nearly-closed recovery and wake now resume on meaningful movement from any position, in either direction. Tiny sensor jitter is ignored. The stationary and maximum-duration protections remain.

41 automated checks pass, including starting at 70 degrees, closing to 68, clearing while held, moving farther closed to 66 to resume, reopening slightly to 69 to resume, and recovery without opening fully.

---

# Fold 1.0 verification

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
