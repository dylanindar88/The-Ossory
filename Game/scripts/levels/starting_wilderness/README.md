# Starting Wilderness Level

Starting Wilderness keeps `StartingWildernessFlowController.gd` as the scene-attached public coordinator and level-state provider.

The controller owns the level's story bridge into Banshee Village progression, the first villager/Banshee pairing, patrol wiring, local dialogue selection, and setup for the shared Banshee encounter helper.

Most multi-Banshee combat, save/restore, clear-state, world-rule, and respawn behavior is delegated to `res://scripts/levels/shared/BansheeEncounterController.gd`. Keep Starting Wilderness-specific story rules in the flow controller, and keep reusable hostile encounter behavior in the shared helper.

Patrol routes for this level live in the scene under `PlayableWorld/Markers/PatrolPaths`. Routes should expose editable `Stops` markers, and smooth loops should also include a `Path2D` child named `Path`.

Use generic group and save terminology for reusable systems:

- `hostile_npcs` for Banshees and other combat enemies.
- `non_hostile_npcs` for friendly, neutral, quest, merchant, dialogue, and civilian NPCs.

Future Starting Wilderness additions should keep one public flow controller for level-facing behavior, with small helpers only when they make the main story flow easier to read.
