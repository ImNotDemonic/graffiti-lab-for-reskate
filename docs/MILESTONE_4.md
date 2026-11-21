# Saved Blackbook drawing on two walls

**Passed offline on 21 November 2026.** Graffiti Lab 0.4.0 rendered the seven-stroke **ridge line** drawing from the local Blackbook. Both maps showed the orange peaks, white snowcap, yellow sun and cyan baseline. The drawing remained fixed from a second viewing angle and disappeared on removal.

| Surface | Preview and confirmation | Removal |
| --- | --- | --- |
| Turbo Token Arcade, dark green interior wall | Opened Ctrl+B and clicked **Place on wall**. The translucent drawing appeared. Ctrl+P confirmed all 112 rectangles at 11:13:05. The dark room visibly muted the colours. | Ctrl+R released the group beginning at handle 1. The bare wall returned and status reported an empty placement list. |
| San Vansterdam, Blue Light Beach kiosk | At the original kiosk camera position the full footprint did not fit. Moving the aim 8 cm left produced a preview on the metal panel beside the vent. Ctrl+P confirmed at 11:14:44. A second pass from the same position reproduced the result. | Ctrl+R released all 112 rectangles and the panel returned to its prior appearance. In a mixed test, removing the drawing left the independent Switchback handle 449 in place. |

After clearing both walls, the gallery reopened the same stored file with seven strokes and 13 points. Its SHA-256 remained `fe770fbd1724f9d262dcdb9b9308bf2e75277683595e252f97c5c3061eb167ac`, identical to the edited milestone 3 drawing. A temporary camera helper positioned the views. The shipping plugin handled selection, collision checks, projection and cleanup.

## Rendering and cost

ReSkate 20261116 with game build 20260929 rendered the drawing using resident, single-colour decals. The plugin composes the saved strokes on selection. Later strokes cover earlier ones. Unpainted pixels produce no geometry. A 1 × 0.5 m wall canvas preserves the 2:1 aspect ratio. Receiver lighting affects the colours, and diagonals show visible steps at close range.

- **Resolution and budgets.** Start at 128 × 64. If the drawing exceeds 256 rectangles, retry at half resolution down to 16 × 8. The original editable strokes retain their precision. The global mod budget is 768 decal handles, including the preview, with up to 16 confirmed marks. An offline pack can compile an individual drawing into a higher-resolution texture and use a single decal, but it requires external tools and a game restart for changed assets.
- **Measured preview creation.** With 112 rectangles at 128 × 64, the first wall probe and effect calls took 4.22 ms in Arcade and 5.10 ms on a repeated kiosk pass. Later kiosk samples took 2.14 and 2.03 ms. These timings exclude rasterisation, GPU work and subsequent frames.
- **Frame timing.** At the same kiosk camera position, ReSkate's performance HUD showed 60 frames/s and 16.65 ms with the drawing, and 60 frames/s and 16.63 ms after removal. These are two observations on one PC. They do not establish a frame-cost ceiling. The first plugin load also logged 55 ms against the host's 50 ms warning threshold and the plugin continued running.
- **Build and logic checks.** Six Luau modules compiled. ReSkate Studio compiled 211 resources into one bundle and one TOC. Headless Luau checks exercised empty drawings, edge pixels, overlap order, non-overlapping rectangles and wall transforms. A dense 96-stroke fixture reduced to 32 × 16 and 183 rectangles. Maximum-budget live performance remains unmeasured.

Additional Luau checks injected a failed decal allocation and verified cleanup of the partially created group, recovery on the next preview, clearing an invalid aim and preserving other marks on removal. All 20 ZIP entries matched the tested installation byte for byte. The tested ZIP SHA-256 is `3f9ac78bb15db2eda5c5d42aaf8d4fea8fa0fba9a4fff388b4e03a99aecc018c`.
