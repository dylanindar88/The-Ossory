# Lightweight Level Template Checklist

Use for named levels that mainly support travel, exploration, optional encounters, collectibles, NPCs, or side content. Even lightweight levels should normally have a minimal flow controller so future save/provider needs have a stable home.

- Scene: `res://scenes/levels/<LevelName>.tscn`
- Root node: `Level-<LevelName>`
- Metadata: register the scene in `SaveManager.LEVEL_DISPLAY_REGISTRY` with a unique `level_index`, `display_name`, `category`, `is_boss_level`, and `map_region_id`.
- Coordinator: `res://scripts/levels/<level_name>/<LevelName>FlowController.gd`
- Save wiring: include `LevelSaveController` so the coordinator can act as a level-state provider.
- Entrances: `PlayableWorld/Markers/Entrances/<DirectionOrSource>Entrance`
- Exits: `PlayableWorld/Environment/Interactables/RouteExits/<DirectionOrDestination>Exit`
- Route exits use `RouteExitArea.gd` with stable `route_id` values.
- `destination_scene_path` points to the next level scene.
- `destination_entry_marker_path` points to the destination scene marker under `PlayableWorld/Markers/Entrances`.
- Unbuilt future exits may leave destination fields empty, but should still use `RouteExitArea.gd`, set `route_id`, and provide a clear missing-destination message.
- Optional shared banshee encounter controller for any level with banshees: `res://scripts/levels/shared/BansheeEncounterController.gd`

Validation:
- Route IDs are non-empty and unique within the scene.
- Assigned destination scenes exist.
- Assigned destination entry marker paths are not empty and use the entrances folder.
- Direct-load the level scene and every connected destination scene.
- Route travel saves, loads, and places the player at the correct destination marker.
