# Campfire Base Scene

`CampfireBase.tscn` is the respawn anchor framework for basic knights.

- Campfire bases are destroyed by destroying all child `CampfireBaseTent` instances.
- Tents only take damage from wolf-form attacks and own their own health bars.
- Destroyed campfires disable linked knight respawns for the current level visit.
- Leaving and re-entering the level should reset campfire destruction, matching temporary Banshee wolf-clear behavior.
- A live campfire keeps its selected variant across level exits. A destroyed campfire rerolls its variant when it respawns.
- Variant layouts are instanced under `LayoutRoot` and contain `CampfireBaseTent`, `Campfire`, `MeleeBanner`, and optional spawn markers.
- `Campfire.tscn` and `MeleeBanner.tscn` are `StaticBody2D` world props with animated-ready `AnimatedSprite2D` children for future Aseprite imports.
- Non-damageable camp props use World layer `1` and mask `14`; tune their `BodyCollision` shapes in the editor.
- Movement blockers should cover only the solid floor footprint. Keep them local to the prop; do not use `top_level`, heavy scale, or skewed transforms. Tents use dense segmented rounded movement polygons so actors slide along many shallow edges, while tent hurt/damage polygons remain separate. Keep flat-looking edges continuous and aligned so top-down capsule bodies do not catch on tiny seams.
- Layout scenes may be blocked out from Aseprite blueprint files by placing each `Tent#`, `campfire`, and `Banner` layer at its visible center relative to the blueprint canvas center.
- Each damageable tent owns an `Effects` child that can show `weak_to_wolf` while that tent is wolf-damageable.

Use stable `campfire_id` values when a level flow controller needs to save active visit state.
