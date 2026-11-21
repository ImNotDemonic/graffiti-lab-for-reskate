# Milestone 5 — direct wall painting

Build 0.5.0 adds an offline freehand brush to Graffiti Lab. Open Wall Paint with Ctrl+I, the Premade Art menu or `graffiti paint`. Point at a nearby flat wall, then hold the left mouse button and move. Space toggles continuous flow. Lift the brush to change colour (1–8) or width ([ and ]). Ctrl+Z removes the latest brush stroke. Esc puts the brush away and keeps the mark on the wall.

## Test record

| Check | Result |
| --- | --- |
| Build | Seven shipping Luau modules compiled. ReSkate Studio packaged the three premade and 16 ink materials for game build 20260929. The test installation matches the 0.5.0 ZIP. |
| Stroke geometry and input | An isolated Luau test ran the shipping paint, surface and placement modules against a synthetic flat wall. A curved mouse drag produced 20 decals with upward and downward segments. Undo preserved a separate premade mark. |
| Gaps and limits | The same test rejected an unapproved prop, broke the stroke at a collision gap and a jump, and exercised Space flow, the 192-decal stroke cap, the 16-mark cap, effects-epoch cleanup and the offline guard. |
| Turbo Token Arcade, dark interior wall | Passed. An orange 40 mm wave followed the cursor for 1.017 m across 40 samples. It remained visible with the brush closed and after shifting the camera. Removing the mark released all 40 decals and the status returned to an empty placement list. |
| San Vansterdam, Blue Light Beach kiosk | Passed. A white 40 mm wave ran for 0.804 m across 32 samples below existing orange and white strokes. Closing the brush preserved the wave. Removing its 32 decals cleared the lower wave and preserved the separate artwork above it. |

Both runs used ReSkate 20261116 offline on 21 November 2026. The camera helper positioned each view. The installed plugin handled cursor input, wall queries, stroke generation and removal. The two measured waves used Space to keep ink flowing while the cursor traced the path. With Space off, a very fast two-position drag on the arcade wall produced two isolated dabs. Ctrl+Z removed that test stroke. The kiosk session also recorded independent strokes of 0.598, 0.419 and 1.405 m and one that reached the 192-decal cap.

The arcade receiver was `0562_str_roof_281_0.physics_bp`. The kiosk returned `Levels/Game/BAM_LevelRoot/generated/StairsLitePG_AGAsset_B8E7EE88`. The ZIP passed CRC verification and all 21 entries matched the installed build byte for byte. ZIP SHA-256 is `4603763c72a88e84e96cab85fbaedd60d06c7f6282a659cfd1aa5bf59da91625`. The existing Blackbook drawing retained its milestone 4 SHA-256 after both tests.

## Surface and performance limits

The brush samples up to six positions per tick. Each sample needs at most seven probes and one pick. Nearby samples on a nearly coplanar receiver form overlapping rectangular decals. Invalid footprints and large input jumps start a new run. This prevents long streaks across openings but can leave gaps during fast sweeps. The square brush has three widths from 25 to 65 mm.

Each stroke shares the placement lifetime and counts as one of the 16 marks on the current map. A stroke can use at most 192 decal handles. All marks and the preview share a 768-handle budget. A saturated stroke stops adding paint until the next stroke. Replay handling, very thin walls, frame cost at capacity and additional receiver materials still need playtesting. [Placement limits](MILESTONE_4.md) · [Runtime evidence](API_FINDINGS.md)

On the kiosk pass the host logged one 51 ms tick in the brush's wall checks, above its 50 ms warning threshold. The plugin continued running and completed the stroke and removal checks. A frame-time profile on both maps is still needed before increasing brush density.
