# Studio lettering fonts

The Studio uses 20 open fonts. The 19 display faces supply antialiased glyph sheets, baseline and advance metrics, and matching wall masks. Pixel and the Unicode fallback use GNU Unifont. The original font authors retain their rights. These packaged font files and their notices are separate from the Graffiti Lab artwork licence.

| In-game preset | Source | Licence supplied here |
| --- | --- | --- |
| Poster | [Bangers by the Bangers Project Authors](https://github.com/google/fonts/tree/main/ofl/bangers) | [SIL Open Font License 1.1](Poster-LICENSE.txt) |
| Script | [Lobster by the Lobster Project Authors](https://github.com/google/fonts/tree/main/ofl/lobster) | [SIL Open Font License 1.1](Script-LICENSE.txt) |
| Slab | [Bree Serif by TypeTogether](https://github.com/google/fonts/tree/main/ofl/breeserif) | [SIL Open Font License 1.1](Slab-LICENSE.txt) |
| Pixel and coverage fallback | [GNU Unifont 17.0.03 by the GNU Unifont contributors](https://unifoundry.com/pub/unifont/unifont-17.0.03/font-builds/) | [Upstream notice and SIL Open Font License 1.1](Pixel-LICENSE.txt) |
| Brush | [Sedgwick Ave Display](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/sedgwickavedisplay) | [SIL Open Font License 1.1](Brush-LICENSE.txt) |
| Daub | [Finger Paint](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/fingerpaint) | [SIL Open Font License 1.1](Daub-LICENSE.txt) |
| Drippy | [Rubik Wet Paint](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/rubikwetpaint) | [SIL Open Font License 1.1](Drippy-LICENSE.txt) |
| Flow | [Pacifico](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/pacifico) | [SIL Open Font License 1.1](Flow-LICENSE.txt) |
| Arcade | [Press Start 2P](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/pressstart2p) | [SIL Open Font License 1.1](Arcade-LICENSE.txt) |
| Terminal | [VT323](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/vt323) | [SIL Open Font License 1.1](Terminal-LICENSE.txt) |
| Circuit | [Audiowide](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/audiowide) | [SIL Open Font License 1.1](Circuit-LICENSE.txt) |
| Speedway | [Faster One](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/fasterone) | [SIL Open Font License 1.1](Speedway-LICENSE.txt) |
| Stack | [Bungee](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/bungee) | [SIL Open Font License 1.1](Stack-LICENSE.txt) |
| Varsity | [Graduate](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/graduate) | [SIL Open Font License 1.1](Varsity-LICENSE.txt) |
| Gothic | [UnifrakturMaguntia](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/unifrakturmaguntia) | [SIL Open Font License 1.1](Gothic-LICENSE.txt) |
| Western | [Rye](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/rye) | [SIL Open Font License 1.1](Western-LICENSE.txt) |
| Neon | [Monoton](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/monoton) | [SIL Open Font License 1.1](Neon-LICENSE.txt) |
| Shade | [Bungee Shade](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/bungeeshade) | [SIL Open Font License 1.1](Shade-LICENSE.txt) |
| Horror | [Creepster](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/creepster) | [SIL Open Font License 1.1](Horror-LICENSE.txt) |
| Deco | [Righteous](https://github.com/google/fonts/tree/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/righteous) | [SIL Open Font License 1.1](Deco-LICENSE.txt) |

To regenerate the packed files, download the inputs identified in `tools/build_lettering_fonts.py` into one directory using the names in its `SOURCES` map. Run `python tools/build_lettering_fonts.py <directory>` with Pillow installed. The script verifies every input against its SHA-256. The game reads the resulting glyphs locally.
