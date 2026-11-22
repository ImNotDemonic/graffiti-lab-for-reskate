# Graffiti Lab

A ReSkate graffiti mod with premade artwork, custom drawing and surface placement.

Graffiti Lab places saved Blackbook drawings and premade graffiti on walls in offline ReSkate. The premade library contains 46 designs. The supplied pack adds 12 ReSkate lettering pieces, 12 skate culture designs, five characters, eight skate phrases and six experimental works. Bonehead joins the Characters filter. Switchback and Birds are under Stencils.

## 0.8.1 development build

**Public Artworks** uses the Graffiti Lab sidebar. Browse real thumbnails, select a piece for a larger preview, and download it to **Premade Art → My imports**. Animated pieces use their first frame on browse cards.

- **Premade Art → Artwork Library** shows premades, imports and saved drawings as thumbnail cards. Search the library or browse by folder, favourite or recent use. Use **Edit placements on this map** to move, duplicate, resize or remove a saved offline placement.
- **Premade Art → Artwork Library → Reshape artwork** edits a copy of a premade, an import or a saved Blackbook drawing. Choose Arch, Bulge, Corners, Baseline or Perspective. Drag a handle on the checkerboard or use the sidebar sliders. Undo, Redo and Reset apply to this edit.
- **Apply and save copy** adds the result to **My imports**. Reopen it to adjust the saved shape or recover its original outline. The Bubble Throw arch keeps its original textured lettering in the menu and on the wall. Other reshapes and gallery downloads use 16 inks, so fine details can simplify.
- **Custom Editor → Animation frames** makes silent loops. **Tiles and symmetry** adds repeating tiles and mirrored or rotational strokes. Freehand and placement spray sounds follow the spray volume control.
- **Import Art** accepts images from disk. The in-game photo capture has been retired.
- Wall paint uses less memory for the same saved strokes. Older drawings and wall-paint pages still load. Advanced drawing edits preserve a recovery copy when upgrading the save format.

## Public gallery test build

Open **Graffiti Lab → Public Artworks** on a loaded map. Browse, preview and download static art. The Publish tab accepts a selected local GLART1 import or saved Blackbook drawing. A creator key enables publishing, authenticated downloads, reports and owner unpublishing. Downloaded copies remain available through Premade Art offline. [Service and account setup](service/gallery/README.md)

## Current status

Switchback passed the preview, placement and removal playtest on the metal kiosk at Blue Light Beach in San Vansterdam and on an interior wall in Turbo Token Arcade. Both marks stayed fixed as the camera moved. A grille at the kiosk accepted the preview but displayed the artwork only on its bars. [Playtest record](docs/MILESTONE_1.md)

The Premade Art selector shows a thumbnail and larger preview of each design. Picking a new design leaves confirmed marks in place. [Selector playtest](docs/MILESTONE_2.md)

**0.6.12** adds a spray hiss that follows freehand flow and a short burst on confirmed premade placements. Paint and Eraser each remember their size. Click a segment on the wall toolbar or press the bracket keys to change it. Paint widths are 25, 40 and 65 mm. Eraser diameters are 100, 160 and 260 mm. The can follows the right middle knuckle with an upright barrel.

To use your own artwork offline, open **Premade Art → Import Art**. Double-click **Import Artwork.html** in the folder that opens, choose a PNG, JPEG or WebP and check its preview. Save the resulting **.graffiti** file beside the importer. Back in ReSkate, click **Refresh**, select the design under **My imports** and choose **Place on Wall**. The importer preserves the image proportions and converts visible pixels into up to 256 shapes using the 16 available wall inks. Detailed artwork may lose fine lines. Personal designs remain available after restarting the game.

In **0.6.11**, the skater holds a textured 3D spray can. Freehand painting sends a coloured plume from the nozzle and a pale puff from the wall. Placing a premade plays a short spray and returns to the selected design. Straight portions of older and newer wall strokes can share a decal. At Tri-Towers the original orange tag stayed visible through three more strokes. [Playtest record](docs/MILESTONE_5.md#tri-towers-wall-and-spray-can-in-0611)

The **Custom Editor** has a transparent 2:1 canvas, a freehand marker, straight lines, 16 colours, adjustable brush width and stroke undo/redo. **Blackbook** is the personal gallery for named, editable drawings. The saved piece **ridge line** survived a restart and edit, then passed preview, placement and removal on both test maps. [Editor playtest](docs/MILESTONE_3.md) · [Wall playtest](docs/MILESTONE_4.md)

**Wall Paint** lets you draw directly where the cursor meets a suitable wall. Freehand strokes passed in-game tests on the Blue Light Beach kiosk and a Turbo Token Arcade interior wall. A held stroke and the number of strokes have no fixed count limit. The brush records each accepted sample even when ReSkate runs out of live decals. At capacity, the latest ink under the brush and ink near the camera get display priority. Returning to an area can bring its paint back into view. Wall Paint saves automatically on this PC. Returning to the same map offline restores your strokes, including after a game restart. Click **Eraser** and drag across the part you want to remove. Click **Paint** to resume, or use Ctrl+Z in Paint mode to remove the most recent stroke. [Wall Paint playtest](docs/MILESTONE_5.md)

**Premade sharing** is available for playtesting in 0.6.0. Install and approve the same build under `Mods/GraffitiLab/` on each player's PC. Start a multiplayer session, choose a premade and confirm it with Ctrl+P. While the artist remains in the world, late joiners receive the current placements. Ctrl+R removes the artist's newest placement. A host-side in-game test and a two-process Luau test passed. The visual check on a second signed-in game client is still open. [Multiplayer test record](docs/MILESTONE_6.md)

## Development setup

The plugin uses sandboxed **Luau** and ReSkate's `reskate.*` API. The tested build target is ReSkate `20261116` with game build `20260929`. [Plugin overview](https://docs.reskate.dev/plugins/overview) · [Runtime release](https://github.com/Dingo-Shenanigans/ReSkate/releases/tag/20261116)

1. For a fresh ReSkate setup, use the official launcher and a separate ReSkate folder. Let the launcher install its supported copy of `skate.` and start the game with **Play**. Keep the development checkout separate from the installed game. [ReSkate setup](https://docs.reskate.dev/quickstart)
2. To check an existing plugin installation, open the ReSkate console and run `plugin list`. The in-game **Insert → Plugins** menu manages approvals. [Plugin management](https://docs.reskate.dev/plugins/overview)
3. With the game closed, extract the prototype ZIP into `Mods/GraffitiLab/` beside the managed `Skate.exe`. The mod root should contain `layout.toc`, `Win32/`, `reskate-plugin.json` and `plugin/`. Start ReSkate and approve Graffiti Lab. Sign in through Steam to test multiplayer. Offline play supports the editor, Blackbook, Wall Paint and premades. [Plugin manifest](https://docs.reskate.dev/plugins/manifest)

## Controls

Open **Insert → Plugins → Graffiti Lab → Open Graffiti Lab**, then press **Insert** again to close the menu. The Graffiti Lab main menu opens over the current map. **Ctrl+L** or **Back + Y** opens it directly. Choose **Premade Art**, **Custom Editor**, **Wall Painting**, **Saved Gallery** or **Settings**. Click a row, or use Up / Down and Enter (D-pad and A on a controller). Esc or B returns from a destination opened through the main menu.

| Key | Action |
| --- | --- |
| Ctrl+E | Open the Custom Editor. Drag with Marker or click two endpoints with Line. Click a swatch or the size controls to change the brush. |
| Ctrl+S | Save the current drawing to Blackbook. **Rename drawing** changes its title. A later save updates the same entry. |
| Ctrl+B | Open Blackbook. Click a thumbnail to edit, **Place on wall** below it to preview, or **New drawing** for a blank canvas. |
| Ctrl+Z / Ctrl+Y | Undo or redo a stroke in the editor. Esc closes the screen and keeps the current draft for this session. |
| Ctrl+L | Open the main menu. In **Premade Art**, search by title, lettering or the pack’s three-digit number. Click a category or cycle with Q/E or LB/RB. Browse nine pieces per page with the page buttons, arrow keys or D-pad. Select a thumbnail and choose **Place on Wall** or press Enter to aim. |
| Ctrl+G | Enter or cancel aim mode using the current design. A translucent preview appears on a suitable wall within eight metres. |
| Left click / Ctrl+P / controller A | Centre the ring on a flat wall within 8 m. When **Wall ready** appears, confirm to place the artwork. Premade Art returns to the same selection, search and page. Blackbook returns to the same gallery page. Choose another piece or press Esc / B to go back. |
| Ctrl+R | Cancel an active preview. When idle, remove the newest confirmed mark. |
| Ctrl+I | Open Wall Paint. Hold the left mouse button and move to draw, or tap Space to toggle paint flow. |
| E | Switch between Paint and Eraser. Drag the eraser over unwanted ink. Use [ / ] for a smaller or larger eraser. Erased sections are saved automatically. |
| 1–8, [ / ] | With the brush up, choose a paint colour or change the width (25, 40 or 65 mm). |
| Ctrl+Z, Esc | In Wall Paint, undo the last freehand stroke or close the brush. Closing leaves the paint on the wall. |

The local artwork limit is 16 premade or Blackbook placements and one preview. Freehand strokes have a separate display pool. Premade and Blackbook wall placements clear on level change and expire just before ten minutes. Freehand paint has its own map files under `Mods/.reskate_plugin_data/GraffitiLab/wall-paint/`. Back up this folder to keep a copy of your painted maps. The console accepts `graffiti library`, `graffiti aim`, `graffiti place`, `graffiti remove` and `graffiti status`. The actions can be reassigned in ReSkate's binds. The Settings screen shows the default controls, lets you change the can colour and width for this session, and displays local mark and decal counts.

The editor and Blackbook use mouse and keyboard. The editor’s Eraser removes a clicked stroke, and Picker samples its colour. The Saved Gallery’s **On this map** tab lists your current local marks. They are also reachable from the main menu or with `graffiti editor` and `graffiti blackbook`. Use **Save to Blackbook** before quitting. Each drawing is a versioned JSON file under `Mods/.reskate_plugin_data/GraffitiLab/`, separate from the installed mod. The editor allows up to 96 strokes and 448 sampled points per drawing.

For a saved drawing, aim at a continuous flat wall with room for a 1 × 0.5 m canvas. Ctrl+P confirms the preview. Ctrl+R cancels it or removes the most recent placement while idle. The saved strokes stay in Blackbook. Wall copies start at 128 × 64 pixels and step down in resolution for more complex artwork. The mod allows 256 decal rectangles per drawing and 768 live artwork decals across its placements and preview.

## Build the test ZIP

On Windows x64, use Python 3.11+ with Pillow, a checkout of ReSkate at `8e4aefca153ce9cb622074ae4de05f81fa71d09c` and the x64 UCRT edition of LLVM-MinGW (`20261117` was used). The two commands below run from this checkout. Replace the external paths with your local folders.

```powershell
python tools/build_author.py --sdk "C:/dev/ReSkate" --llvm "C:/dev/llvm-mingw"
python tools/package_mod.py --game "C:/Games/ReSkate" --studio "C:/Tools/ReSkate Studio/reskate_cli.exe"
```

For 0.6.12, the tested package reuses the native mesh, decals and shaders from the verified 0.6.11 ZIP. To reproduce it, run `python tools/package_mod.py --native-from path/to/GraffitiLab-0.6.11.zip`. Use a full Studio build when editing native geometry, textures or shaders.

The catalogue in `art/catalogue.json` maps each design to a stable decal slot. The pack’s editable SVGs and transparent PNG masters are grouped by category in `art/premades/`. The builder fits the PNGs into transparent 512 × 512 wall textures at their original proportions and creates 480 × 480 thumbnail sheets for the selector. Slots 16–31 belong to the 16 Blackbook inks. Keep those slots, the palette order and existing artwork IDs stable. Studio compiles the 46 premades and 16 inks with the spray can from `art/spray-can/` into `outputs/GraffitiLab-0.6.12.zip`. The GPL offline tools derive from the gBGYo decal recipe and link ReSkate's resource readers. Their source and licence are under `tools/`. [Upstream decal author](https://github.com/gBGYo/ReSkate_blood) · [LLVM-MinGW release](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261117)

## License

Graffiti Lab's source code, including the Luau plugin, tests and build scripts, is licensed under the GNU General Public License, version 3 only (`GPL-3.0-only`). The adapted build tools retain their upstream notices. [Code license](LICENSE)

The bundled artwork is rights reserved. Players may use it in ReSkate as part of Graffiti Lab. Reusing or redistributing the artwork separately requires permission from the relevant rights holder. [Artwork notice](art/NOTICE.md)

## Project documents

- [Project specification](docs/PROJECT_SPEC.md) defines the player workflow, milestones and prototype acceptance tests.
- [API findings](docs/API_FINDINGS.md) records verified calls, example packages, runtime limits and open questions.
- [Development checklist](docs/TASKS.md) gives the order of work, starting with one original decal.
