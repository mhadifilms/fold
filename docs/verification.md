# Fold 1.0 build 17 — notarization preparation

The app's public version is now **1.0**. The internal build counter advances to 17; this is not a new animation revision. The bundle identifier, approved artwork, compact Settings and build 16 behavior are unchanged.

The fresh build passed all 102 graphics and recovery checks. It is Developer ID signed and timestamped, and strict signature verification passed. The 1.0 bundle is installed at `/Applications/Fold.app` and copied to the deliverables. Previous installations were preserved locally.

Notarization is not complete: neither `fold-notary` nor the earlier `macfold-notary` credential profile exists. The source includes a notarization helper that checks authentication before upload and requires Apple acceptance, ticket stapling and Gatekeeper validation before producing its final archive. The signed submission archive is prepared locally, but no submission or approval is claimed.

---

# Fold 1.0.7 build 16 candidate verification

Physical feedback on build 15 identified excessive vertical stretching. Build 16 retains the horizontal projection, side wedges, focus field and interaction, but uses 60% of the previous height compensation. Maximum hinge expansion drops from 3.24x to 1.71x; at 60 degrees it drops from 2.00x to 1.43x. This is a bounded visual approximation for an uncalibrated viewer, not an exact camera reconstruction.

All 102 graphics and recovery checks passed. A new rendered-square regression measures actual pixel bounds at 0, 20, 40, 60, 72 and 100 degrees of travel. Its height-to-width ratio is 1.00, 1.00, 1.09, 1.30, 1.49 and 1.49 respectively, with width remaining 96–100 pixels from a 100-pixel source. These are panel-space measurements, not proof of identical apparent dimensions from every viewing position. The existing smooth-blur, coordinates, hinge contrast, side coverage and recovery checks also pass.

The original-artwork preview was regenerated from 300 native Metal frames and inspected alongside the prior shader output. The simulation retains its existing physical-camera model; it demonstrates the changed render but cannot establish visual acceptance on the laptop. All gesture, reversal, hold and onset code is unchanged from build 15.

The signed installed app passed all 26 live assertions with scripted lid input, actual ScreenCaptureKit and onscreen Metal: 364 frames received and 552 presented. Bundled logo/preview assets, first-degree onset, continuous partial reversal, full undo, hold recovery, repeated gestures, sensor loss/wraparound, wake and pause passed. It was then relaunched in normal background mode. At that startup the physical sensor was returning its invalid 359-degree sentinel, so automatic folding remained configured but disarmed with no overlay or capture. The existing startup path activates on the next valid sensor sample; this final physical recovery has not been observed in this pass.

GPU timing at 2560×1600 including upload and prefiltering: 1.113 ms median, 3.164 ms p95. The installed candidate is Developer ID signed and timestamped with the existing bundle identity. Signature verification passed. No public binary release or notarization submission was made in this pass.

---

# Fold 1.0.7 build 15 verification (superseded)

Build 15 replaces both the panel-pinned texture and the earlier nonlinear stretch with inverse rigid-lid projection. The apparent image stays in the viewer's space while the physical panel crosses it. Opening uses the same position curve as closing; no first-opening-step dismissal or separate release animation remains. The 90-degree activation threshold is removed.

All 96 graphics and recovery checks passed. Rendered coordinate ramps are compared with the inverse of physical projection, replacing the mistaken panel-coordinate invariant. Horizontal stripe, hinge detail, edge coverage and progressive focus regressions pass. Gesture checks include first-degree onset at five starting postures, proportional partial reversal, full undo without extra travel, a complete nine-second closing/hold/reopening sequence, current-posture rearming and recovery.

The signed installation passed all 26 live assertions using scripted sensor input with real ScreenCaptureKit and onscreen Metal: 387 frames received, 556 presented. It showed a one-degree gesture within 180 ms and cleared its complete one-degree undo within 220 ms. A partial reopening of a deep fold explicitly retained the effect. Opening-pause recovery, short and long closing holds, near closure, simulated wake, sensor loss/wraparound, reconnection, pause, logo and preview assets all passed. A local screen recording contains 955 frames; it is private and is not published.

The Settings window was visually inspected with the bundled physical-lid preview, logo and compact controls. The app was relaunched in normal background mode with automatic folding, login registration, permission and shortcut all ready. A stable 104-degree reading had a clear desktop and a warm capture session; the rendered-frame counter remained unchanged while idle.

The new preview is made from 300 native Metal frames at 60 fps, projected onto a simulated moving lid with original artwork. It is not a camera recording of this MacBook. All 469 consecutive frames of the requested X example were separately inspected; the frame ledger and interpretation limits are documented in [the reference review](reference-frame-review.md). Passing graphics/lifecycle checks does not establish subjective visual acceptance on the physical laptop.

GPU timing at 2560×1600 including upload and prefiltering: 0.999 ms median, 2.609 ms p95. These are GPU measurements, not end-to-end latency guarantees. The installed candidate is Developer ID signed and timestamped with the existing bundle identity. Signature verification passed. No notarization submission was made in this pass.

---

# Fold 1.0.6 verification

Build 13 removes all geometric distortion. The desktop remains at fixed coordinates; the physical lid supplies perspective. Only progressive blur and edge shading change. The blur is clearer near the hinge and stronger toward the outer edge. A wider separable Gaussian with floating-point pyramid textures removes faint coarse-level blur bands.

All 65 graphics/recovery checks pass. The horizontal-stripe regression now covers every 5° from 95° to 5°. New rendered coordinate-ramp checks detect scaling, displacement or projection across nine points at three folding angles, independently of shading. Additional detail fixtures check clarity and anchoring near the hinge and strong defocus toward the outer edge. The fixed 90° trigger and all prompt-clearing checks still pass.

The Developer ID signed installation passed all 20 live assertions with actual ScreenCaptureKit and onscreen Metal presentation, using scripted sensor input. It received 183 desktop frames and presented 244 frames. Logo loading, hidden menu bar, Settings closure, entry, stationary clearing, reopening pauses, threshold clearing, simulated wake, sensor recovery and pause cleanup all passed. The app was then relaunched in normal background mode.

The cold-recovery portions of the live test now simulate continuous one-second closing gestures. The former instantaneous angle jump with a 300 ms visibility deadline intermittently raced capture startup; the revised test still requires a presented overlay before exercising loss and cleanup. Production recovery delays and thresholds were not lengthened.

GPU command timing at 2560×1600 including upload and prefiltering: 1.156 ms median, 3.854 ms p95 on this run. These are GPU timings, not end-to-end latency guarantees. A new 60 fps preview was rendered using original artwork. The launch, product demonstration and requested MacBook reference were inspected as documented in the motion study. This release remains a visual adaptation, not Apple's extracted compositor.

Developer ID signed and timestamped; signature verification passed. Notarization still awaits Apple service authentication: the `fold-notary` Keychain profile is absent.

---

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
