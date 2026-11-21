# Milestone 5 â€” direct wall painting

Build 0.5.0 adds an offline freehand brush to Graffiti Lab. Open Wall Paint with Ctrl+I, the Premade Art menu or `graffiti paint`. Point at a nearby flat wall, then hold the left mouse button and move. Space toggles continuous flow. Lift the brush to change colour (1â€“8) or width ([ and ]). Ctrl+Z removes the latest brush stroke. Esc puts the brush away and keeps the mark on the wall.

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

## Continuous painting in 0.6.4

Freehand sampling is independent from artwork placements and renderer handles. The brush stores wall transforms and ink colours for each stroke. The display cache prioritises the area under the brush, then nearby eight-metre cells, and shows the newest samples in a crowded cell. A delayed or failed allocation leaves the sample in the stroke for retry. Undo, expiry, map travel and multiplayer transitions clean up both visible and hidden ink.

An automated Luau run drove the shipping brush through 3,424 samples in 26 strokes with a simulated 2,048-decal renderer. It verified that moving back to the first wall restored its ink, undo removed hidden samples, a premade survived, and shrinking and freeing the shared renderer pool did not interrupt recording. A held stroke crossed ten minutes and the finished stroke expired after inactivity. Run `python tests/test_wall_paint.py <path-to-luau>` to repeat this check.

In a live offline run on Turbo Token Arcade with 0.6.4, the toolbar showed 787 visible brush samples on the purple exterior wall. The ReSkate log recorded nine completed strokes, including one with 254 samples over 5.909 m. This crossed both the old 192-sample limit for one stroke and the old 768-decal total.

## Persistent paint and eraser in 0.6.5

Offline freehand strokes save to the plugin's private `wall-paint/` folder. Opening the same map restores the paint automatically. Each page carries its full map name, stroke IDs, colours and decal transforms. A finished gesture requests a save, held gestures checkpoint periodically, and level or plugin unload flushes pending changes. Storage failures show an in-game warning and retry while the plugin is running. ReSkate's file quota still applies.

Click **Eraser** or press **E**, then drag across the unwanted section. The circle shows the eraser footprint. The three eraser diameters are 100, 160 and 260 mm. The eraser tests the wall face and each intersecting ink stamp, including stamps currently outside the renderer budget. Select **Paint** or press **E** again to resume spraying. Ctrl+Z in Paint mode removes the last freehand stroke, including strokes restored from disk.

`python tests/test_wall_save.py <path-to-luau>` transfers the saved bytes through three independent plugin runs. It checks a gap erased in a stroke, an entirely erased stroke, surrounding ink, another map with the same basename, a neighbouring premade, a failed write and a damaged file. The renderer stress test also checks that paint outlasts native handle expiry and returns after map travel. These checks use a simulated host.

Live restart check on ReSkate 20261116, 21 November 2026: spray two dots on the green wall by the concession stand in Turbo Token Arcade. The Eraser removed the orange dot and the native visible count fell from two to one. The private map file contained only the chalk stroke at (4.8412, 1.3226, âˆ’42.3940). After quitting and launching a fresh ReSkate process, San Vansterdam reported zero strokes. Returning to Turbo Token Arcade restored one recorded sample and one live decal before any brush input. The surviving chalk dot was left on the wall.

## Spray arm, can and mist in 0.6.9

The local skater aims the right hand while previewing a valid premade. Confirmation triggers a 360 ms wrist sweep while the selector reopens on the same piece. A held or latched freehand brush tracks its wall hit. The arm blends out over 140 ms. Hovering with a freehand brush or using the eraser leaves it idle.

The stock aerosol can attaches to the drawn hand when its mesh is loaded. A portable 19 cm can model follows the same hand on other receivers. Spray starts at the nozzle, with a second small puff at the hit. Both dissipate in under a third of a second. The effects are local and independent of saved marks.

Run `python tests/test_spray_arm.py <path-to-luau>` to exercise both recorded map receiver identifiers with a simulated host. It checks the native attachment, fallback geometry, bounded mist, blocked hits, erasing, holding and releasing, premade selection and cleanup on unload. Visual checks of the can and mist in the 0.6.9 game build are pending for San Vansterdam and Turbo Token Arcade.

## Surface and performance limits

### Wall Paint watchdog in 0.6.10

On San Vansterdam, ReSkate stopped 0.6.9 at 18:00:14 on 21 November 2026 after its paint callback exceeded 1,000 ms. The stop followed a 203-sample, 4.490 m stroke. The map save contained all 203 samples. The trace points to the mist update where Luau noticed the overdue callback. It does not isolate the slow operation.

0.6.10 schedules checkpoint writes separately from brush input. The brush stops interpolating extra samples once a tick has spent 8 ms on them and skips a redundant wall query on release. The spray can uses a measured transform for build 20260929, so holding the brush no longer scans the asset registry for mesh dimensions. The original wall-paint save format is unchanged. The slow-query regression exercises a delayed receiver lookup, release and resumed hover.

The brush samples up to six positions per tick. Each sample needs at most seven probes and one pick. Nearby samples on a nearly coplanar receiver form overlapping rectangular decals. Invalid footprints and large input jumps start a new run. This prevents long streaks across openings but can leave gaps during fast sweeps. The square brush has three widths from 25 to 65 mm.

In the original 0.5.0 build, each stroke shared the placement lifetime and counted as one of the 16 marks on the current map. That build allowed 192 decals per stroke and 768 handles across marks and preview. The brush stopped drawing once it reached a cap. Replay handling, very thin walls, frame cost at capacity and additional receiver materials still need playtesting. [Placement limits](MILESTONE_4.md) Â· [Runtime evidence](API_FINDINGS.md)

On the kiosk pass the host logged one 51 ms tick in the brush's wall checks, above its 50 ms warning threshold. The plugin continued running and completed the stroke and removal checks. A frame-time profile on both maps is still needed before increasing brush density.

## Tri-Towers wall and spray can in 0.6.11

On 21 November 2026 the offline San Vansterdam test returned to the concrete wall beside the green bin at Tri-Towers. ReSkate loaded 823 existing paint samples using 171 visible decals. The orange tag had 203 samples. Three new strokes were drawn with continuous flow beside the tag.

| Brush | Recorded samples | Travel logged by the brush |
| --- | ---: | ---: |
| Cobalt lightning | 136 | 3.066 m |
| Lime crown | 117 | 2.326 m |
| Pink crown | 80 | 3.248 m |

The orange outline remained visible during the three strokes and after holstering. The city then had 1,156 samples and 189 visible decals. Its save contained all 203 samples from the original tag. The orange-labelled can tilted with the right hand and emitted a visible coloured plume. ReSkate reported zero physics bodies for the attached model. Placing Birds displayed the spray and reopened Premade Art with Birds selected. This build's live visual check covered this city wall.

Adjacent coplanar stamps of one colour and width share a render decal when their endpoints follow a straight line within the brush tolerance. Erasing still operates on individual saved stamps. Sharp corners, gaps and separate strokes retain separate decals. The renderer still has a finite pool. The Luau tests also cover uncompressible marks at host capacity, partial erasure, undo, and restart.

## Tri-Towers grip, sound and size meters in 0.6.12

The San Vansterdam test used the concrete wall beside the green bin. The final can stood upright with the barrel meeting the right palm and the nozzle above the fingers while paint flowed. The freehand and placement gains are 0.32 and 0.37, each half the first 0.6.12 setting. The audio regression checks a single looping voice, release, latched flow, silence while erasing or aiming, and a single 0.29-second burst upon placement. In-game loudness is subjective.

The toolbar retained a 65 mm paint width when switching from a 100 mm eraser. A local browser converted a transparent orange and blue PNG. Refresh showed it under My imports, the wall preview used both ink shapes, and confirming returned to the selected design. The imported design remained available after restarting. Confirming the stock Birds design also reopened its selector. Live checks for this revision covered San Vansterdam. Automated brush and spray checks exercised the San Vansterdam and Turbo Token Arcade receiver fixtures.

The release ZIP uses the native payload from the tested 0.6.11 build. One fresh Studio compilation spawned a native entity but the barrel was invisible in the game. Loading the earlier native payload in a fresh game session restored the visible mesh.
