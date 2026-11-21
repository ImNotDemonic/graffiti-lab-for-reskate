# Switchback offline playtest

Built on 21 November 2026 for ReSkate `20261116` and the supported `Skate.exe`. Switchback is an original 512 × 512 transparent stencil. The arrow points toward the top right, two short ticks sit on the left, and one drip hangs below. These details make it easy to spot a flipped or opaque projection.

## Build verification

| Check | Recorded result |
| --- | --- |
| Game executable | Local SHA-256 matched `fbce74d5e28ef525dbba2cb4adbebc13405bdbd88f31bc940bca45e4ae88b8f9`. |
| Offline author | Built with LLVM-MinGW `20261117` against ReSkate commit `8e4aefca153ce9cb622074ae4de05f81fa71d09c`. Both the native author and Studio CLI run only during the build. |
| Decal resources | Author produced 13 payloads. The colour, flat normal and opacity textures decoded back to their source pixels. The template, texture identities and CAS payloads passed round-trip checks. |
| Studio compiler | Local `reskate_cli.exe` SHA-256 `001f613310e263f06b3479129e0e314d71be703989d2a84178332bf4f43b1248`. `compile-mod` reported 13 resources, one bundle and one TOC. |
| Plugin and package | Both Luau files compiled with `luau-compile --null`. The packager checked the declared template, shader, root TOC, CAS, game-build stamp and ZIP CRC. |
| Installation | Graffiti Lab ran under `Mods/GraffitiLab` in ReSkate `20261116`, game build `20260929`. The game loaded the compiled decal on both maps. |
| Final package | Every file in `GraffitiLab-0.1.0.zip` matched the tested installation byte for byte. ZIP SHA-256 `892d993bb2ca465178784f47b80efbc503e3044b013c8fe815d11a4b77313b41`. |

## In-game results

| Map | Preview | Place and inspect | Remove |
| --- | --- | --- | --- |
| San Vansterdam, Blue Light Beach | Translucent arrow appeared on the kiosk's metal panel to the left of the upper vent. | The arrow pointed up and right, had a transparent surround, and stayed aligned with the panel seams from a second angle. | Ctrl+R restored the bare panel. The final run logged placement at 09:52:10 and removal at 09:52:21. |
| Turbo Token Arcade, interior | Translucent arrow appeared on the dark green wall beside the neon-patterned room. | The confirmed arrow became solid and remained on the same wall when viewed from the side. The room lighting made it visibly darker than the kiosk decal. | Ctrl+R restored the bare wall. The final run logged placement at 09:53:41 and removal at 09:53:59. |

Both final runs used the installed mod's Ctrl+G, Ctrl+P and Ctrl+R actions. A temporary offline camera helper held the views and moved the camera laterally. Graffiti Lab performed all collision validation, rendering and removal. The screenshots show actual game frames. The times above are from the local ReSkate log on 21 November 2026.

## Controls and map travel

- On the Arcade map, aiming at the ceiling produced no valid preview. A placement attempt logged `Switchback placement needs a valid preview` and status showed `handle nil`.
- With a second mark still placed in Arcade, travel to San Vansterdam reset the mod to idle with no handle. Revisiting the original Arcade wall showed a clean surface before aiming again.
- Issuing Remove again after clearing the Arcade wall left the mod idle with no handle. Replay, plugin disable and hot reload with a live mark still need separate checks.
- F7 triggered ReSkate's bug-report marker during testing and F8 opened Animation Studio. The shipping defaults use Ctrl+G for aim, Ctrl+P for place and Ctrl+R for remove.

## Receiver evidence and limitations

| Map | Reproduction view | Collision identified by the game |
| --- | --- | --- |
| `levels/game/BAM_LevelRoot/BAM_LevelRoot` | Camera at `605.84, 201.78, 1047.14`, facing approximately `-0.939, 0, -0.346`. | After returning to the map, the same kiosk returned `World/Plots/Downtown/DTN_PLT_14/DTN_PLT_14_Base_C_Arch_Foot_Mid_01`. Allowing that fixed plot on this level restored the preview. |
| `levels/game/dingolevel_reskate_turbo_token_arcade/dingolevel_reskate_turbo_token_arcade` | Wall hit at `4.7714, 2.7914, -42.4000`. Camera faces negative Z from about 2.35 m away. | `world/custom/dingolevel_reskate_turbo_token_arcade/collision/0562_str_roof_281_0.physics_bp`. The map author's normalized `map.json` identifies the source as `STR_Roof` with triangle-mesh collision and a baked world transform. |

The footprint probes also accepted the San Vansterdam grille beside the tested panel. The decal appeared only on the metal bars. Choose a continuous, opaque surface for a complete image. Other named receivers, outside corners, thin partitions and occlusion by a foreground object remain unverified.
