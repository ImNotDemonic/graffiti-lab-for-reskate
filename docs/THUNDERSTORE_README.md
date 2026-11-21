# Graffiti Lab

Put one of 46 premade pieces on a wall, draw a design in your Blackbook, or paint directly on the map. Open Graffiti Lab with **Ctrl+L** or **Back + Y**.

## 0.8.0 development build

**Public Artworks** uses the Graffiti Lab sidebar. Browse real thumbnails, select a piece for a larger preview, and download it to **Premade Art → My imports**. Animated pieces use their first frame on browse cards.

- **Premade Art → Artwork Library** brings together favourites, folders, search, recents, imports and saved drawings. Use **Edit placements on this map** to move, duplicate, resize or remove a saved offline placement.
- **Custom Editor → Tiles and symmetry** adds repeating tiles and mirrored or rotational strokes. **Frames and sound** edits short loops and sets a positional sound. Use **Ctrl+J** near interactive artwork.
- **Artwork Library → Take an in-game photo** captures the current view after four seconds. Open the local image preparer to crop, rotate, remove a border, reshape a piece or turn a photo into poster, stencil, comic or halftone art. Save the new file in imports and refresh My imports.
- Wall paint uses less memory for the same saved strokes. Older drawings and wall-paint pages still load. Advanced drawing edits preserve a recovery copy when upgrading the save format.

## Public Artworks in 0.7.0

Open **Graffiti Lab → Public Artworks**. Browse and preview work from other sessions. Download a static piece, then find it in **Premade Art → My imports**. It stays on this PC when the game restarts. Publisher and downloader can use separate gallery profiles without joining the same skate session.

To publish, choose a creator profile on the **Account** tab. Choose your import or saved Blackbook drawing on **Publish**, preview it, give it a title and confirm. Blackbook shares a flattened ink copy. Keep your editable original in Blackbook. Guests can browse and download. Creator keys belong in the private folder opened by **Account → Open creator key folder**. The plugin asks for HTTPS access to the gallery when you turn on this update.

## What's new in 0.6.12

This update includes the following changes since 0.6.7.

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
2. Choose a PNG, JPEG or WebP and check the preview. The importer fits it to the 16 wall inks and up to 256 shapes. Bold shapes and clear outlines work best.
3. Save the resulting `.graffiti` file beside the importer. Return to ReSkate and click **Refresh**.
4. Select the design under **My imports** and choose **Place on Wall**.

## Quick controls

| What you want to do | How |
| --- | --- |
| Place a premade | Select a thumbnail and choose **Place on Wall**. Aim at a flat wall within 8 m. When **Wall ready** appears, left-click, press **Ctrl+P**, or press **A** on a controller. |
| Cancel or remove a placement | Press **Ctrl+R** to cancel a preview. With the menus closed and no preview active, **Ctrl+R** removes your latest mark. |
| Paint or erase directly | Open **Wall Paint** with **Ctrl+I**. Hold the left mouse button and drag, or toggle continuous spray with **Space** or **Flow**. Press **1–8** for colour, **E** to switch between Paint and Eraser, **Ctrl+Z** to undo your last stroke in Paint mode, and **Esc** to put the can away. |
| Draw and save to Blackbook | Press **Ctrl+E** to open the editor. Draw on the transparent canvas with Marker or Line, then press **Ctrl+S** to save. **Ctrl+B** opens your gallery. Click a drawing to edit it, or choose **Place on wall** below its thumbnail. |

Freehand wall paint saves automatically per map, including partial erasures, and returns after a restart. Premade and Blackbook wall placements last up to ten minutes on the current map. Your saved Blackbook originals and imported designs stay in your library.

## Multiplayer

Built-in premade placements support session sharing. Each player needs the same version installed under `Mods/GraffitiLab/` on the same map. Late joiners can receive existing placements while the artist is still in the session. Host-side and simulated two-player checks passed. A visual check with two signed-in players is still pending. Freehand painting, Blackbook artwork and imports are offline features.

## Source and artwork rights

The code is licensed under **GPL-3.0-only**. Included artwork is **all rights reserved** by its respective rights holders. Players retain the rights to their own original artwork. The ZIP includes `LICENSE` and `art/NOTICE.md`. [Source code](https://github.com/ImNotDemonic/graffiti-lab-for-reskate) · [Artwork notice](https://github.com/ImNotDemonic/graffiti-lab-for-reskate/blob/main/art/NOTICE.md)
