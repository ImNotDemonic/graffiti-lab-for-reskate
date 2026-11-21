# Blackbook restart playtest

**Passed on 21 November 2026.** Graffiti Lab 0.3.0 saved a named, three-colour drawing in Turbo Token Arcade. After ReSkate closed completely, a new offline game process reopened the piece in the editor. Saving a seventh stroke updated the original gallery entry.

| Step | Observed result |
| --- | --- |
| Draw and save | Created **ridge line** with two blaze-orange peaks, a yellow sun and a cyan baseline. Ctrl+S saved `blackbook-0001.json` at 10:53:56. ReSkate process 48576 recorded six strokes and 11 points. |
| Restart | Closed the editor and exited ReSkate. Launched the same installed package in process 28912, opened Blackbook with Ctrl+B and saw one named thumbnail. Clicking it loaded six strokes and 11 points at 10:54:58. |
| Edit and save again | Added a chalk-white snowcap to the left peak. At 10:55:22 the game saved seven strokes and 13 points to the same file. The gallery still contained one entry and its thumbnail showed the edit. |
| Reopen the revision | At 10:55:41 the game loaded seven strokes and 13 points. A comparison of the files preserved the title, format version, stroke order and every original colour, size and coordinate. The new seventh stroke had colour index 1, size 28 and points `[615,354,796,354]`. |

ReSkate 20261116 ran game build 20260929. All five Luau modules compiled. ReSkate Studio built the existing decal pack as 35 resources, one bundle and one TOC. All 18 ZIP entries passed CRC checks and matched the installed files byte for byte. Package SHA-256 is `075410da27efab624f03e3e5b853beb274130cfbbb73f2b38ac493ce905c9fa0`.

The original drawing file had SHA-256 `4f80f7bb9b2b01af71468d9c29596618750d265c5c16a125c6b03268e727934b`. The edited file had SHA-256 `fe770fbd1724f9d262dcdb9b9308bf2e75277683595e252f97c5c3061eb167ac`. The test drawing remains in the local Blackbook.

## Repeat the test

1. Start ReSkate offline and approve Graffiti Lab's private file access. Press Ctrl+E, draw on the canvas, and use **Rename drawing** to give the piece a recognisable name.
2. Save with Ctrl+S, press Esc, and fully exit the game.
3. Relaunch, press Ctrl+B and click the thumbnail. Check the name, colours, geometry and stroke count. Add a stroke in another colour and save.
4. Open Blackbook again. Verify the same entry has an updated thumbnail and opens with the additional stroke.

The playtest used mouse and keyboard. Separate Luau checks exercised freehand sampling, undo/redo, leaving the canvas mid-stroke, stable file IDs, malformed records, write failures and stale-file protection. The checks used an in-memory host for those cases. Gallery performance at the maximum drawing size and physical controller drawing were outside the live test.
