# Milestone 6 — multiplayer premade sharing

Build 0.6.0 shares confirmed Switchback, Birds and Bonehead placements between copies of Graffiti Lab. Both players need the same build, mod folder name and map. The artist can place before the first visitor connects. Sharing lasts while the artist and mark remain in the world.

## Test record

| Check | Result |
| --- | --- |
| Package | All eight shipping Luau modules compiled. Studio built 211 payloads in one bundle and TOC. All 22 ZIP entries matched the installed mod. |
| Real host | ReSkate 20261116 hosted a code-only, two-slot Steam lobby on Turbo Token Arcade. At 11:51:45 on 21 November 2026 the final build confirmed Switchback as handle 3 on the dark interior wall. The game still reported 1/2 players at 11:51:48. The temporary camera helper positioned the view. The shipping mod handled placement. |
| Late-join regression | Two separate Luau processes ran the shipping placement, surface and sharing modules. The artist placed while the session API reported no connected peer. The test discarded the initial transmission and started the visitor with a later snapshot. Its decal service received one Switchback at the expected coordinates, size and orientation. |
| Removal and recovery | The visitor retained its own mark when the artist removed theirs. Duplicate and older snapshots created no extra decals. A later update retried a failed allocation. Unknown designs, wrong maps and wrong worlds were ignored. Disconnect, stale expiry, world reuse and the 64-remote-decal limit were exercised. |
| Second player's screen | Pending. The live lobby reached 1/2. The Luau test used adapters for transport and rendering. A second signed-in Steam client is needed to confirm network delivery and visible artwork in that game. |

Run the regression from the checkout with `python tests/test_sharing.py path/to/luau`. The test uses the standalone Luau interpreter.

The verified 0.6.0 ZIP has SHA-256 `6c068ded1fd108015989cf4f4fccbb130ab74baa1e1fa2190f4136bf3f70199c`.

## What goes across the session

Each artist sends up to 16 entries containing a placement key, catalogue ID, position and wall normal. The receiver reconstructs the 0.65 m square from its own compiled material. The snapshot includes a protocol version, map, world ID and per-sender sequence. A repeated update preserves matching handles. An empty list removes that artist's marks. New snapshots follow edits and refresh every three seconds, with edits coalesced to at most one send per 400 ms. A departed artist's copies are released on the leave event or after 12 seconds without a refresh. Up to 64 remote handles may be displayed. [ReSkate session and message API](https://docs.reskate.dev/plugins/api/session)

The host can be alone in a lobby with a valid world before the plugin session becomes active. Graffiti Lab tags each premade at placement, keeps matching marks across the first handshake and compares the map as well as the world ID. Player identity comes from ReSkate's message event. No Blackbook files, thumbnails or brush strokes enter the packet. [World binding](https://github.com/Dingo-Shenanigans/ReSkate/blob/8e4aefca153ce9cb622074ae4de05f81fa71d09c/Extension/Plugins/plugin_api_services.cpp#L328-L340) · [Transport binding](https://github.com/Dingo-Shenanigans/ReSkate/blob/8e4aefca153ce9cb622074ae4de05f81fa71d09c/Extension/Plugins/plugin_api_ui.cpp#L842-L882)

## Two-player acceptance test

1. Install the ZIP under `Mods/GraffitiLab/` on both PCs, approve the plugin and use distinct signed-in Steam accounts. Load the same map.
2. Have the artist host a code-only lobby, confirm Switchback on a recognisable wall with Ctrl+P and keep the game running. Record the mark before the visitor joins.
3. Join the lobby on the second client. After the map and collision load, look at the same wall. Run `graffiti status` in the visitor's console. The acceptance evidence is a screenshot of the mark on that client, its remote decal count and a log line beginning `Rendered shared`.
4. Have the artist remove the mark with Ctrl+R. Verify that it disappears on the visitor's screen and their own placements remain.
