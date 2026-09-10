# Motion reference and implementation

Reference review: September 10, 2026.

## References viewed

- [Apple iPhone Duo](https://www.apple.com/iphone-duo/), three-second hero film, sampled at 0.5-second intervals.
- [Close-up folding demonstration](https://www.reddit.com/r/UI_Design/comments/1wc0nut/cool_animations_on_the_new_iphone_duo/), 19.9 seconds at 30 fps, sampled at one-second intervals and inspected during opening/closing.

Reference videos remain in local research scratch space and are not redistributed in this repository. The sample artwork and demonstration video in this repo are original.

## Visual observations

At approximately 2–4 seconds of the close-up clip, the moving panel progressively defocuses toward its outer edge while the part nearer the hinge remains more legible. The screen remains filled to its bezel. Around 4–5 seconds, detail progressively returns across the newly revealed side. The physical display's changing perspective contributes heavily to the impression of bending; the software transition doesn't shrink the interface into a black trapezoid. At 7–9 seconds the same behavior reverses while closing. Fast reversals later in the clip remain tied to hand movement.

Apple's hero film at approximately 2 seconds likewise shows a blurred moving half next to a clear stationary half. Both sides remain filled with their interface/background.

## Adaptation for a MacBook

A MacBook has one rigid display with a bottom hinge. This app adapts the observed appearance to that geometry; it does not reproduce the Duo's two-screen content handoff or claim to contain Apple's animation code.

- Keep the entire display filled at every angle.
- Preserve clarity nearest the bottom hinge; progressively defocus toward the moving top edge.
- Apply gentle inverse projection/stretch to the interface without exposing a background outside it.
- Apply only a subtle directional shade by default; avoid globally darkening the screen.
- Resolve the image back to an exact unmodified view as the effect clears.
- Track angles with a critically damped spring that retains velocity on reversals and behaves consistently at 60 and 120 Hz.

## Original preset

Effect begins below 100°. Stretch 55%, blur 72%, shade 18%. These are hand-tuned approximation values, not extracted Apple parameters. The user can restore this preset with one button.

## Rendering

The input is a live ScreenCaptureKit frame, capped at 2560 pixels wide. Core Image uploads each new frame to a reusable Metal texture. A mip pyramid is generated only for new input. A full-screen Metal fragment pass applies inverse projection, spatially varying blur and shade, using clamped texture sampling. It never renders a smaller quadrilateral over black.

MTKView presents at the screen's available refresh rate, capped at 120 Hz. A display link handles application state, and sensor reads run independently at 60 Hz. The renderer interpolates between readings. Capture stays alive while Follow lid is enabled, drops to 1 fps when fully clear, and returns to the display's requested cadence while folding. Pausing releases capture completely.

A macOS overlay cannot move other apps' actual hit targets. Pause before clicking displaced controls. This is a visual utility, not a replacement window compositor.
