# Verification

September 10, 2026. Local M3 Max MacBook Pro, macOS 26.6.2, Swift 6.2.4. Build targets Apple silicon macOS 14+.

## Passed

- Builds without compiler warnings.
- 28 automated graphics/logic checks: HID decoding, invalid input, once-per-launch authorization behavior, no prompt when authorized, consistent 60/120 Hz motion, convergence, reversal stability, upright image orientation, three styles at five angles, every perimeter pixel at nearly closed angle, and Reduced Motion rendering.
- Local sensor readings around 110°.
- Eight live integration assertions: ScreenCaptureKit delivers frames; Metal presents an overlay; opening clears after smoothing; capture stays ready; a second fold displays; only one capture session is started across folds; timed completion releases the overlay and stream; pausing during async startup cannot resurrect an overlay.
- Integration observed 210 incoming frames and 217 rendered presentations across its active/clear/active sequence. No desktop pixels were saved.
- The previous version's global Command-Shift-Escape was directly tested through native UI control. This version retains the same Carbon hotkey implementation.
- Source/build excludes research footage and machine-specific paths or credentials.

## Performance

Generated artwork, GPU command timing including upload and mipmap generation:

| Resolution | Median | 95th percentile |
|---|---:|---:|
| 2560 × 1600 | 1.221 ms | 1.635 ms |

At 1280 × 800, the median was 0.464 ms and maximum 0.794 ms over the rendered angle/style samples. These are GPU work measurements on one machine, not promises of end-to-end latency or frame cadence on every Mac. Display settings, power mode, capture content, and OS scheduling affect the actual frame rate. Up to 120 Hz is requested where the screen supports it.

## Boundaries

- The integration test drove the actual capture/presentation model with a manual angle sequence. It did not physically move the lid.
- Visual reference matching is a hand-tuned MacBook adaptation, not a measured pixel-perfect reconstruction of Apple's private compositor.
- Native app-control tooling disconnected; the final controls were not inspected through that tool. The compiled app lifecycle and desktop effect were tested through the app's explicit integration entry point.
- Other Mac models, external-display transitions, and sleep/wake paths need broader device testing.
- macOS owns capture reminders and authorization storage; the app cannot promise to suppress OS security prompts. The app itself only requests at startup if needed.
