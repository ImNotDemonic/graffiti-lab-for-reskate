# Development checklist

The [specification](PROJECT_SPEC.md) defines the pass conditions. Update [API findings](API_FINDINGS.md) when a test confirms or changes an assumption.

1. [ ] **Place and remove one original image.** Build a single resident decal and a minimal client plugin. On a nearby static wall, detect a suitable footprint, preview the image, confirm it and remove it.
2. [ ] Repeat on San Vansterdam and Turbo Token Arcade. Record orientation, occlusion, thin-wall bleed, rejection of invalid targets, repeated removal and cleanup on level change, replay and reload. Record the working build procedure in the README.
3. [ ] Add a small premade artwork catalogue and selector. Verify that changing the selection leaves earlier placements intact.
4. [ ] Build the editor and personal library. Save, restart, reopen and edit one drawing within the documented quotas.
5. [ ] Prototype placing a library drawing. Compare brush stamps with offline art packs, measure frame cost and document map coverage.
6. [ ] Investigate direct wall painting and multiplayer sharing independently. Test joining late and missing artwork before defining a network feature.
