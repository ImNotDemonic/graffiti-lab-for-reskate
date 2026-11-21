# Premade Art selector playtest

**Passed offline on 21 November 2026.** On both target maps, the first Switchback stayed at the same spot with the same artwork and effect handle while another design was selected, previewed, placed and removed.

## Tested build

Graffiti Lab 0.2.0 uses ReSkate 20261116 and game build 20260929. Milestone 1 is recorded in commit `69d7b85`. The new catalogue contains Switchback, Birds and Bonehead. All three thumbnails and world decals derive from the same three transparent PNGs.

The offline author produced 35 resources including both shared shader lookup tables. ReSkate Studio compiled one bundle and one TOC. All three Luau modules compiled. All 15 ZIP entries passed CRC verification and matched the installed mod byte for byte. The final ZIP SHA-256 is `655987676a2ec98153eccce31e96039ae3da3245fcff6dc8b603f3aa1c1a1123`.

## In-game evidence

| Map and surface | Actions and observed result |
| --- | --- |
| Turbo Token Arcade, dark green interior wall | Placed Switchback. Opened Premade Art with Ctrl+L and switched the live preview from Birds to Bonehead and back. Only the ghost changed. Placed Birds beside Switchback, then placed Bonehead above them. All three retained their own artwork. |
| Turbo Token Arcade, removal | Status at 10:33:10 showed `[switchback#3, birds#10, bonehead#11]`. Removing Bonehead kept the first two. Removing Birds left `[switchback#3]` at 10:33:31. Removing Switchback emptied the list. |
| San Vansterdam, Blue Light Beach kiosk | Placed Switchback on the metal panel. Selected Birds, pressed Enter to aim, and placed Birds below it. Status at 10:38:08 showed `[switchback#12, birds#13]`. Removing Birds left `[switchback#12]` at 10:38:23. The arrow still lined up with the original panel ridges. Removing it restored the bare panel. |

The Arcade pass used mouse thumbnails and **Place on Wall**. The runs exercised keyboard and console placement controls. A temporary camera helper held repeatable views. Graffiti Lab handled surface checks, preview, placement and removal. The helper was removed after the test.

The kiosk initially rejected both aims. The game reported the same generated collision identifier at both heights, different from the plot identifier seen in milestone 1. The final build accepts that exact identifier on San Vansterdam and the kiosk test was rerun. This change affects the San Vansterdam receiver list. The Arcade test used the same artwork, selector, placement code and Arcade receiver check as the final package.

## Repeat the check

1. Start offline, face a broad wall, press Ctrl+L and choose Switchback. Select **Place on Wall** and confirm the wall preview with Ctrl+P.
2. Aim beside the first mark. Use the selector to preview Birds, reopen it and preview Bonehead. Watch the first mark and the translucent ghost.
3. Confirm the second mark. Run `graffiti status` in the console to inspect both artwork IDs and handles.
4. Press Ctrl+R once while idle. The second mark should disappear and Switchback should keep its artwork, position and handle. Press Ctrl+R again to clear the wall.

Coverage is limited to the two surfaces above. Physical gamepad navigation, other named receivers and performance at the 16-mark limit remain untested.

## Expanded catalogue in 0.6.6

ReSkate Studio compiled the 43 supplied designs, the three existing premades and the 16 Blackbook inks for game build `20260929`. The new designs retain the pack numbers, names and aspect ratios. The selector shows nine tiles per page.

The release check compared all 46 packaged thumbnails with their PNG sources and checked their shader bindings. A Luau host exercised every category and page, searched by lettering and pack number, then previewed each design while retaining a confirmed Rail Sigil placement. The host verified that removing the preview left Rail Sigil on the wall. Run `python tests/test_premades.py PATH_TO_LUAU PATH_TO_MOD_ZIP` to repeat it.

On 21 November 2026, the project owner tested the new premade artwork in ReSkate and confirmed it worked.
