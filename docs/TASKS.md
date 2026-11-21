# Development checklist

The [specification](PROJECT_SPEC.md) defines the pass conditions. Update [API findings](API_FINDINGS.md) when a test confirms or changes an assumption.

1. [x] **Preview, place and remove Switchback on one solid wall in each test map.** Verified offline in San Vansterdam and Turbo Token Arcade, including orientation, camera movement and removal. Also checked rejection of an upward aim and cleanup on map travel. [Build and playtest record](MILESTONE_1.md)
2. [ ] Extend receiver and cleanup testing. Check rails, outside corners, occlusion by a foreground object, thin partitions, replay and plugin reload with an active mark. Record cases where the visible mesh differs from collision.
3. [ ] Add a small premade artwork catalogue and selector. Verify that changing the selection leaves earlier placements intact.
4. [ ] Build the editor and personal library. Save, restart, reopen and edit one drawing within the documented quotas.
5. [ ] Prototype placing a library drawing. Compare brush stamps with offline art packs, measure frame cost and document map coverage.
6. [ ] Investigate direct wall painting and multiplayer sharing independently. Test joining late and missing artwork before defining a network feature.
