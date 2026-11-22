# Graffiti Lab

Paint walls in ReSkate with 46 premades, your own Blackbook drawings or a freehand spray can. Press **Ctrl+L** or **Back + Y** to open Graffiti Lab. Choose **Public Artworks** to share your designs and download other players’ pieces.

## What's included since 0.6.12

### 0.7.0 introduced Public Artworks

Open **Graffiti Lab → Public Artworks** to find pieces other players have shared. Guests can search by title, creator or tag, then download a piece to **Premade Art → My imports** and place it on a wall. The artist can be offline or skating in a different session. Once downloaded, the piece works offline too.

With a creator profile, you can publish an imported design or a saved Blackbook drawing with a title, description and tags. You can also unpublish your own pieces or report an entry. Publishing a drawing keeps the editable original in your Blackbook.

### 0.8.0 expanded the gallery, library and editor

- **See the art before downloading.** Public Artworks gained thumbnail cards showing the actual artwork and a larger preview when you select a card.
- **Find and organise your collection.** Artwork Library brought premades, imports and Blackbook drawings into one searchable view with favourites, folders and recently used pieces. You can import up to 12 prepared designs as a collection and undo that import as one action.
- **Edit art already on the wall.** Resize or rotate a premade while aiming. From the map placement list, move, stretch, rotate, duplicate or remove an individual piece. Offline placements keep their position and settings across map changes and restarts. Placement history lets you undo an edit to the wall without changing your drawing.
- **Prepare images and draw patterns.** Crop or rotate an image from disk, trim transparent margins, remove an edge border and check transparency before importing. In Blackbook, repeat a seamless tile or draw with left/right, four-way, radial or rotational symmetry.
- **Keep painting and keep your saves.** Large freehand paintings use less memory. Existing wall-paint saves still load, and saving advanced edits to an older Blackbook drawing keeps a recovery copy. The premade placement crash was fixed, and the selector returns to the same piece after you place it.

## What's new in 0.8.1

- **Reshape an artwork without losing the original.** Open **Premade Art → Artwork Library → Reshape artwork**. Choose **Arch** to bend a word, **Bulge** to push out its middle, **Corners** to pull individual corners, **Baseline** to curve the lettering along its base, or **Perspective** to taper it. Drag the handles or use the sliders. **Apply and save copy** puts the result in **My imports**, where you can reopen it and adjust the shape again.
- **Bubble Throw keeps its lettering when arched.** The preview and the wall now use the original artwork texture, including the outlines, dots and drips. An **81% arch** kept its shape after restarting ReSkate on the Blue Light Beach kiosk in **San Vansterdam** and the green wall in **Turbo Token Arcade**. Other reshapes and copies downloaded from the public gallery use 16 inks, which can simplify fine detail.
- **The editing screens now match the rest of Graffiti Lab.** The Artwork Library shows thumbnail cards. The map placement and reshape screens use the same black-and-orange sidebar, and the reshape preview shows the artwork against a checkerboard.
- **Fixed a crash during map travel.** The plugin now releases its artwork effects when leaving a level. This release also retires in-game photo capture and sounds attached to artwork. You can still import pictures from disk and adjust the volume of the spray can.

## Features

- **Browse 46 premades.** Choose from lettering, skate designs, characters, phrases, stencils and experimental pieces. Filter by category or search by title, lettering or pack number. After you place one, the selector reopens on the same design, search and page.
- **Place and edit pieces on walls.** Aim at a flat surface to preview size and rotation before placing. In **Artwork Library → Edit placements on this map**, select a saved piece to move, scale, stretch its width, rotate, duplicate, reset or remove it. Each offline placement keeps its own settings and returns when you revisit the map or restart.
- **Draw and save in Blackbook.** Use Marker, Line, Eraser and Picker on a transparent canvas with 16 inks and adjustable brush widths. Name a drawing, save it to your personal library, reopen it to edit, or place a copy on a wall.
- **Draw patterns and reshape finished art.** Draw a small tile that repeats across its edges. Mirror brush strokes left to right, use four-way or radial symmetry, or repeat strokes around a centre. The reshape editor works on premades, imports and Blackbook drawings.
- **Free-paint and erase.** Spray directly onto a wall in eight colours with a 3D can, an aiming arm, coloured mist and an adjustable hiss that follows the spray. Premade placement plays one short burst. Paint and Eraser each remember their own size. Wall paint and partial erasures save automatically per map. There is no fixed stroke-count limit. On heavily painted maps, ReSkate prioritises nearby and recent ink for display.
- **Import and organise your artwork.** Prepare PNG, JPEG or WebP files with crop, rotate, transparent-margin trim and border removal. Check the edges on a checkerboard, light or dark background before importing. Bring in one piece or a collection of up to 12. Use folders, favourites, search and recently used items across premades, imports and saved drawings.
- **Undo the edit you mean.** Editor Undo affects the current drawing. Reshape Undo affects the shape you are editing. The map placement history names the edit to undo or redo. Undoing a collection import changes library membership and keeps the source art.
- **Publish and download in Public Artworks.** Browse artwork thumbnails, open a larger preview and download a copy to **Premade Art → My imports**. With a creator profile you can publish your work, report an entry or unpublish your own. A published piece is available when its creator is offline. Once downloaded, it stays in your local library.
- **Share premades in a multiplayer session.** Players with the same mod version on the same map can receive built-in premade placements, including when they join after placement while the artist is still present. Freehand paint, imports and Blackbook wall placements are local.
- **Groundwork for moving graffiti.** The editor now has frame tools for future moving artwork. No moving graffiti designs are included in this release.

## Use the public gallery

Open **Graffiti Lab → Public Artworks** on a loaded map. Guests can browse and download. To publish an import or a Blackbook drawing, select your creator profile under **Account**, choose your piece under **Publish**, add a title and confirm. Downloads appear under **Premade Art → My imports**. [Service and creator account setup](service/gallery/README.md)

## Tested in ReSkate

- On the Blue Light Beach kiosk in San Vansterdam and an interior wall in Turbo Token Arcade, Switchback could be previewed, placed and removed. Choosing another premade left existing marks in place. A continuous wall gives the clearest result. The kiosk grille showed ink only on its bars. [Placement](docs/MILESTONE_1.md) · [Selector](docs/MILESTONE_2.md)
- A saved Blackbook drawing survived a restart, reopened for editing, and could be placed and removed on both maps. At Tri-Towers, an older orange freehand stroke stayed visible while three more were painted beside it. [Blackbook](docs/MILESTONE_3.md) · [Saved drawing placement](docs/MILESTONE_4.md) · [Freehand, erasing and spray effects](docs/MILESTONE_5.md)
- The Bubble Throw restart test covered an 81% arch on both maps. Static public artwork was exchanged between two gallery profiles on one PC. Session premade sharing passed host-side and simulated two-player checks. A visual check with two signed-in players is still pending. [Reshape and public gallery test records](docs/EXTENSION.md) · [Session sharing](docs/MILESTONE_6.md)

## Development setup

The plugin uses sandboxed **Luau** and ReSkate's `reskate.*` API. The tested build target is ReSkate `20261116` with game build `20260929`. [Plugin overview](https://docs.reskate.dev/plugins/overview) · [Runtime release](https://github.com/Dingo-Shenanigans/ReSkate/releases/tag/20261116)

1. For a fresh ReSkate setup, use the official launcher and a separate ReSkate folder. Let the launcher install its supported copy of `skate.` and start the game with **Play**. Keep the development checkout separate from the installed game. [ReSkate setup](https://docs.reskate.dev/quickstart)
2. To check an existing plugin installation, open the ReSkate console and run `plugin list`. The in-game **Insert → Plugins** menu manages approvals. [Plugin management](https://docs.reskate.dev/plugins/overview)
3. With the game closed, extract the release ZIP into `Mods/GraffitiLab/` beside the managed `Skate.exe`. The mod root should contain `layout.toc`, `Win32/`, `reskate-plugin.json` and `plugin/`. Start ReSkate and approve Graffiti Lab. Sign in through Steam to test multiplayer. Offline play supports the editor, Blackbook, Wall Paint and premades. [Plugin manifest](https://docs.reskate.dev/plugins/manifest)

## Controls

Open **Insert → Plugins → Graffiti Lab → Open Graffiti Lab**, then press **Insert** again to close the menu. The Graffiti Lab main menu opens over the current map. **Ctrl+L** or **Back + Y** opens it directly. Choose **Premade Art**, **Custom Editor**, **Wall Painting**, **Saved Gallery**, **Settings** or **Public Artworks**. Click a row, or use Up / Down and Enter (D-pad and A on a controller). Esc or B returns from a destination opened through the main menu.

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

ReSkate displays up to 16 local artwork placements and one preview at a time. The mod stores offline placements per map and restores them after travel or restart. Freehand strokes have a separate display pool. Freehand paint has its own map files under `Mods/.reskate_plugin_data/GraffitiLab/wall-paint/`. Back up this folder to keep a copy of your painted maps. The console accepts `graffiti library`, `graffiti aim`, `graffiti place`, `graffiti remove` and `graffiti status`. The actions can be reassigned in ReSkate's binds. The Settings screen shows the default controls, lets you change the can colour and width for this session, and displays local mark and decal counts.

The editor and Blackbook use mouse and keyboard. The editor’s Eraser removes a clicked stroke, and Picker samples its colour. The Saved Gallery’s **On this map** tab lists your current local marks. They are also reachable from the main menu or with `graffiti editor` and `graffiti blackbook`. Use **Save to Blackbook** before quitting. Each drawing is a versioned JSON file under `Mods/.reskate_plugin_data/GraffitiLab/`, separate from the installed mod. The editor allows up to 96 strokes and 448 sampled points per drawing.

For a saved drawing, aim at a continuous flat wall with room for a 1 × 0.5 m canvas. Ctrl+P confirms the preview. Ctrl+R cancels it or removes the most recent placement while idle. The saved strokes stay in Blackbook. Wall copies start at 128 × 64 pixels and step down in resolution for more complex artwork. The mod allows 256 decal rectangles per drawing and 768 live artwork decals across its placements and preview.

## Build the Thunderstore ZIP

On Windows x64, use Python 3.11+ with Pillow, a checkout of ReSkate at `8e4aefca153ce9cb622074ae4de05f81fa71d09c` and the x64 UCRT edition of LLVM-MinGW (`20261117` was used). The two commands below run from this checkout. Replace the external paths with your local folders.

```powershell
python tools/build_author.py --sdk "C:/dev/ReSkate" --llvm "C:/dev/llvm-mingw"
python tools/package_mod.py --game "C:/Games/ReSkate" --studio "C:/Tools/ReSkate Studio/reskate_cli.exe" --out outputs/GraffitiLab-0.8.1-Thunderstore.zip
```

For a documentation- or script-only rebuild, reuse the verified native assets from the same release. For example, run the following from the checkout. When changing native geometry, textures or shaders, run the full Studio build above.

```powershell
python tools/package_mod.py --native-from "C:/path/to/verified/GraffitiLab-0.8.1.zip" --out outputs/GraffitiLab-0.8.1-Thunderstore.zip
```

The packager uses [the Thunderstore README](docs/THUNDERSTORE_README.md) for the ZIP's root README and includes the code licence and artwork notice.

The catalogue in `art/catalogue.json` maps each design to a stable decal slot. The pack’s editable SVGs and transparent PNG masters are grouped by category in `art/premades/`. The builder fits the PNGs into transparent 512 × 512 wall textures at their original proportions and creates 480 × 480 thumbnail sheets for the selector. Slots 16–31 belong to the 16 Blackbook inks. Keep those slots, the palette order and existing artwork IDs stable. Studio compiles the 46 premades, 16 inks and 40 Bubble Throw arch strips alongside the spray can from `art/spray-can/`. The GPL offline tools derive from the gBGYo decal recipe and link ReSkate's resource readers. Their source and licence are under `tools/`. [Upstream decal author](https://github.com/gBGYo/ReSkate_blood) · [LLVM-MinGW release](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261117)

## License

Graffiti Lab's source code, including the Luau plugin, tests and build scripts, is licensed under the GNU General Public License, version 3 only (`GPL-3.0-only`). The adapted build tools retain their upstream notices. [Code license](LICENSE)

The bundled artwork is rights reserved. Players may use it in ReSkate as part of Graffiti Lab. Reusing or redistributing the artwork separately requires permission from the relevant rights holder. [Artwork notice](art/NOTICE.md)

## Project documents

- [Project specification](docs/PROJECT_SPEC.md) defines the player workflow, milestones and prototype acceptance tests.
- [API findings](docs/API_FINDINGS.md) records verified calls, example packages, runtime limits and open questions.
- [Development checklist](docs/TASKS.md) gives the order of work, starting with one original decal.
