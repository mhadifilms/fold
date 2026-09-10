# Motion reference and implementation

Reference review: September 10, 2026.

## References viewed

- [Apple iPhone Duo](https://www.apple.com/iphone-duo/), three-second hero film, sampled at 0.5-second intervals.
- [Close-up folding demonstration](https://www.reddit.com/r/UI_Design/comments/1wc0nut/cool_animations_on_the_new_iphone_duo/), 19.9 seconds at 30 fps, initially sampled at one-second intervals, then reexamined frame by frame at the native 30 fps. The second pass inspected all 90 frames from 2.000–4.967 seconds and all 60 frames from 7.000–8.967 seconds (150 consecutive frames across both sequences).

Reference videos remain in local research scratch space and are not redistributed in this repository. The sample artwork and demonstration video in this repo are original.

## Visual observations

At approximately 2–4 seconds of the close-up clip, the moving panel progressively defocuses toward its outer edge while the part nearer the hinge remains more legible. The screen remains filled to its bezel. Around 4–5 seconds, detail progressively returns across the newly revealed side. The physical display's changing perspective contributes heavily to the impression of bending; the software transition doesn't shrink the interface into a black trapezoid. At 7–9 seconds the same behavior reverses while closing. Fast reversals later in the clip remain tied to hand movement.

Apple's hero film at approximately 2 seconds likewise shows a blurred moving half next to a clear stationary half. Both sides remain filled with their interface/background.

## Frame-by-frame second pass

Times are relative to the close-up video; each row describes consecutive frames, read left-to-right at 30 fps. The video does not expose calibrated hinge-angle telemetry, so these observations cannot identify exact Apple shader constants.

| Frames / time | Observed change | Implementation implication |
|---|---|---|
| 60–65 / 2.000–2.167 s | The first softness appears in the outer widget and icon column while the inner column stays readable. | Earlier blur onset; a broad spatial gradient rather than uniform blur. |
| 66–89 / 2.200–2.967 s | Outer icons become broad color patches as more of the stationary panel appears. Content continues to the moving bezel. | Larger blur radius and a gradient reaching across most of the surface, with clamped full-screen sampling. |
| 90–110 / 3.000–3.667 s | The moving panel turns toward an edge-on view. Apparent darkness rises strongly and part of the panel is occluded. | Physical rotation/occlusion must not be confused with a software black gutter. Use directional shade and stretch on the single MacBook surface. |
| 111–149 / 3.700–4.967 s | The newly revealed panel unfolds; its outer area stays soft while the hinge side resolves. | Preserve the spatial focus gradient and angle-dependent progression. |
| 210–233 / 7.000–7.767 s | Closing reverses the transition. The rotating surface goes edge-on and comes toward the viewer; broad defocus covers the outer columns. | A reversible angle-driven curve, not a canned playback animation. |
| 234–257 / 7.800–8.567 s | Closing endpoint resolves from broad blur to a legible widget grid. | Restore an exact clear desktop at the endpoint, with velocity-preserving smoothing. |
| 258–269 / 8.600–8.967 s | Closed front display is sharp again. | Duo has two sharp endpoints across two displays. MacBook shutdown is different; a nearly-closed timeout clears the overlay instead of freezing it. |

The second pass exposed how restrained v2.0 was. v2.1 raises the reference blur coefficient from 68 to 190 pixels at a 1600-pixel source width, broadens the spatial exponent from 1.65 to 0.85, and increases inverse stretch. These are inspectable implementation choices fitted visually, not measurements of Apple's private compositor.

## Adaptation for a MacBook

A MacBook has one rigid display with a bottom hinge. This app adapts the observed appearance to that geometry; it does not reproduce the Duo's two-screen content handoff or claim to contain Apple's animation code.

- Keep the entire display filled at every angle.
- Preserve clarity nearest the bottom hinge; progressively defocus toward the moving top edge.
- Apply pronounced inverse projection/stretch to the interface without exposing a background outside it.
- Apply directional shade by default; avoid globally darkening the screen.
- Resolve the image back to an exact unmodified view as the effect clears.
- Track angles with a critically damped spring that retains velocity on reversals and behaves consistently at 60 and 120 Hz.

## Single effect, revised in 1.0.2

The open endpoint follows the observed lid position; the first detected closing degree starts the effect, without waiting to cross 100°. The style alternatives and tuning sliders are removed. Previously saved appearance settings no longer change the effect.

Reviewing the consecutive opening frames again showed a continuous focus gradient, without repeated horizontal copies of sharp content. Version 1.0.2 replaces the nine widely spaced fragment samples and box mipmaps with a Gaussian-prefiltered pyramid and one continuous variance-based sample. A single horizontal stripe at 50° produced secondary intensity rises with the previous shader; the new shader has none in the same fixture. The regression allows one 8-bit quantization step.

The projective vertical mapping now has a finite slope at both endpoints, avoiding the old power curve's compression of rows nearest the hinge. Blur remains pronounced toward the outer edge, with more clarity near the hinge and lighter shading. These remain hand-tuned approximations, not Apple's extracted shader parameters.

## Rendering

The input is a live ScreenCaptureKit frame, capped at 2560 pixels wide. Core Image uploads each new frame to a reusable Metal texture. A Gaussian pyramid is generated only for new input. A full-screen Metal fragment pass applies inverse projection, spatially varying blur and shade, using clamped texture sampling. It never renders a smaller quadrilateral over black.

MTKView presents at the screen's available refresh rate, capped at 120 Hz. A display link handles application state, and sensor reads run independently at 60 Hz. The renderer interpolates between readings. Capture stays alive while automatic folding is armed, drops to 1 fps when fully clear, and returns to the display's requested cadence while folding. Pausing, holding the lid still, or reaching the nearly-closed timeout releases capture completely. The next lid movement rearms it from any position.

A macOS overlay cannot move other apps' actual hit targets. Pause before clicking displaced controls. This is a visual utility, not a replacement window compositor.

## Side shading, 1.0.3

At the user's request, soft left and right shadows now give the single display more apparent curvature. Their width and depth grow continuously with folding and toward the outer edge. They multiply the live image instead of exposing empty borders, disappear at zero progress, and retain image content even near closure. This is an intentional expressive adaptation; it is not a claim that the Duo uses this exact shading. The Gaussian focus field and first-closing-degree onset are unchanged.

## Remembering the resting posture, 1.0.4

The open reference is scoped to the current fold. When the held-lid timeout clears the effect, the settled angle replaces the old reference. Starting or resuming automatic folding also samples the current position; sleep and sensor loss invalidate the previous reference. During closing and reversal, the endpoint remains fixed, so returning to the remembered posture clears the image. This replaces the previous lifetime maximum-angle behavior.
