# Route Level Template Checklist

Use for lightweight travel areas between key locations.

- Scene: `res://scenes/levels/<RouteOrLocationName>.tscn`
- Root node: `Level-<RouteOrLocationName>`
- Entrances: `PlayableWorld/Markers/Entrances/<DirectionOrSource>Entrance`
- Exits: `PlayableWorld/Environment/Interactables/RouteExits/<DirectionOrDestination>Exit`
- Route exits use `RouteExitArea.gd` with stable `route_id` values.
- `destination_scene_path` points to the next level scene.
- `destination_entry_marker_path` points to the destination scene marker under `PlayableWorld/Markers/Entrances`.
- Unbuilt future routes may leave destination fields empty, but should still use `RouteExitArea.gd`, set `route_id`, and provide a clear missing-destination message.
- Optional shared banshee encounter controller for any level with banshees: `res://scripts/levels/shared/BansheeEncounterController.gd`

Validation:
- Route IDs are non-empty and unique within the scene.
- Assigned destination scenes exist.
- Assigned destination entry marker paths are not empty and use the entrances folder.
- Direct-load the route scene and every connected destination scene.
- Route travel saves, loads, and places the player at the correct destination marker.
