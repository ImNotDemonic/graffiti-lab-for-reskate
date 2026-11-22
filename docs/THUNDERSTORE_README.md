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

## How to use Public Artworks

Open **Graffiti Lab → Public Artworks**. Browse and preview work from other sessions. Download a static piece, then find it in **Premade Art → My imports**. It stays on this PC when the game restarts. Publisher and downloader can use separate gallery profiles without joining the same skate session.

To publish, choose a creator profile on the **Account** tab. Choose your import or saved Blackbook drawing on **Publish**, preview it, give it a title and confirm. Blackbook shares a flattened ink copy. Keep your editable original in Blackbook. Guests can browse and download. Creator keys belong in the private folder opened by **Account → Open creator key folder**. The plugin asks for HTTPS access to the gallery when you turn on this update.

## What's new in 0.6.12

Version 0.6.12 included these changes since 0.6.7.

- **Bring your own artwork.** Import a PNG, JPEG or WebP into **Premade Art → My imports**. Your designs stay on your PC and are available to place again after a restart.
- **Spray with a can in hand.** Your skater reaches toward the wall with a textured 3D can. The arm follows the brush during freehand painting and makes a quick sweep when you confirm a premade. The selector reopens on the same piece, search and page so you can place it again.
- **See where the spray lands.** A larger mist plume carries the paint colour out of the nozzle, and a pale puff appears where it hits the wall.
- **Hear each spray.** Freehand painting has a quiet, continuous hiss while the mouse is held or **Flow** is on. It cuts off when spraying stops. Placing a premade plays one short burst. Aiming and erasing are silent.
- **Set the paint and eraser sizes separately.** Click any of the three segments on the wall toolbar, or press **[** and **]**. Paint widths are **25, 40 and 65 mm**. Eraser diameters are **100, 160 and 260 mm**. Switching tools restores the size you last chose for that tool.

### Fixes

- **Older strokes stay visible longer as you paint.** Straight sections of a stroke now share a decal. At Tri-Towers in San Vansterdam, the original orange tag stayed visible while three more strokes went on the same wall. Each brush sample is still saved and can be erased individually. On heavily painted walls, the game prioritises nearby and recent ink when it reaches its display limit.
- **Corrected the sideways can grip.** The barrel sits upright against the right palm, with the nozzle above the fingers as the skater aims.
- **Reduced stalls during long strokes.** The brush limits how much work it does each frame and saves checkpoints separately from input. This addresses a case where ReSkate stopped the plugin mid-stroke. Existing wall-paint saves carry over.

## Install and open

With ReSkate closed, extract the ZIP into `Mods/GraffitiLab/` beside `Skate.exe`. The folder should directly contain `manifest.json`, `reskate-plugin.json`, `layout.toc` and `Win32/`. Launch ReSkate and choose **Turn on** if prompted. This build targets ReSkate **20261116** with skate. build **20260929**.

Press **Ctrl+L**, or choose **Insert → Plugins → Graffiti Lab → Open Graffiti Lab** and press **Insert** again to return to the game.

## Import your own art

1. In **Premade Art**, choose **Import Art**. Double-click **Import Artwork.html** in the folder that opens.
2. Choose a PNG, JPEG or WebP and check the preview. Crop or rotate as needed, trim transparent margins, or remove a border that touches the image edge. The importer fits it to the 16 wall inks and up to 256 shapes. Bold shapes and clear outlines work best.
3. Save the resulting `.graffiti` file beside the importer. Return to ReSkate and click **Refresh**.
4. Select the design under **My imports** and choose **Place on Wall**.

## Quick controls

| What you want to do | How |
| --- | --- |
| Place a premade | Select a thumbnail and choose **Place on Wall**. Aim at a flat wall within 8 m. When **Wall ready** appears, left-click, press **Ctrl+P**, or press **A** on a controller. |
| Resize or rotate a preview | While aiming, press **[** or **]** for size and **Q** or **E** for rotation. |
| Cancel or remove a placement | Press **Ctrl+R** to cancel a preview. With the menus closed and no preview active, **Ctrl+R** removes your latest mark. |
| Paint or erase directly | Open **Wall Paint** with **Ctrl+I**. Hold the left mouse button and drag, or toggle continuous spray with **Space** or **Flow**. Press **1–8** for colour, **E** to switch between Paint and Eraser, **Ctrl+Z** to undo your last stroke in Paint mode, and **Esc** to put the can away. |
| Draw and save to Blackbook | Press **Ctrl+E** to open the editor. Draw on the transparent canvas with Marker or Line, then press **Ctrl+S** to save. **Ctrl+B** opens your gallery. Click a drawing to edit it, or choose **Place on wall** below its thumbnail. |

Freehand wall paint saves automatically per map, including partial erasures, and returns after a restart. Offline premade, imported and Blackbook placements also return to their saved walls after map travel or restart. ReSkate displays up to 16 local artwork placements and one preview at a time. Your saved Blackbook originals and imported designs stay in your library.

## Multiplayer

Built-in premade placements support session sharing. Each player needs the same version installed under `Mods/GraffitiLab/` on the same map. Late joiners can receive existing placements while the artist is still in the session. Host-side and simulated two-player checks passed. A visual check with two signed-in players is still pending. Freehand painting, Blackbook artwork and imports are offline features.

## Source and artwork rights

The code is licensed under **GPL-3.0-only**. Included artwork is **all rights reserved** by its respective rights holders. Players retain the rights to their own original artwork. The ZIP includes `LICENSE` and `art/NOTICE.md`. [Source code](https://github.com/ImNotDemonic/graffiti-lab-for-reskate) · [Artwork notice](https://github.com/ImNotDemonic/graffiti-lab-for-reskate/blob/main/art/NOTICE.md)
