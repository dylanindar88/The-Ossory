# Content Authoring Guide

Use this as the quick checklist before adding new levels, NPCs, hostile entities, or bosses. Banshee Village is the concrete reference implementation.

## Storage Conventions

- Scenes use `PascalCase.tscn` and live under `res://scenes/`.
- Scripts use `PascalCase.gd` for controllers/resources and stay near their domain under `res://scripts/`.
- Resource files use `snake_case.tres` and live under `res://resources/`.
- Dialogue with multiple story states uses `*_story_profile.tres`.
- Character animation data should be external `SpriteFrames` resources under `res://resources/characters/...`, not embedded in character scenes.

## Folder Patterns

- Player scenes: `res://scenes/characters/saorise/`
- NPC scenes: `res://scenes/characters/npcs/<npc_group_or_name>/`
- Hostile scenes: `res://scenes/characters/hostile_npcs/<entity_group>/`
- Character resources: `res://resources/characters/<same_domain>/`
- Dialogue resources: `res://resources/dialogue/npcs/<npc_name>/` or `res://resources/dialogue/levels/<level_name>/`
- Level scenes: `res://scenes/levels/`
- Level scripts/helpers: `res://scripts/levels/<level_name>/`
- Shared level helpers: `res://scripts/levels/shared/`
- Global scripts only: autoloads, shared managers, or truly cross-level systems.

## Adding A Level

1. Create the level scene under `res://scenes/levels/`.
2. Register the scene in `SaveManager.LEVEL_DISPLAY_REGISTRY` with a unique `level_index`, `display_name`, `category`, `is_boss_level`, and `map_region_id`.
3. Add a scene-attached flow coordinator only if the level owns story progression, level-local state, or special route/interior behavior.
4. Put level-specific helpers under `res://scripts/levels/<level_name>/`.
5. Keep one public level-state provider unless there is an explicit save migration plan.
6. Keep save keys, quest stage strings, and route IDs stable once saves can reference them.

## Level Categories

- `town_city`: towns, cities, and settlements such as Banshee Village.
- `wilderness`: forests, fields, roads, and wild regions such as Weeping Woods.
- `large_interior`: major explorable interior locations such as castles or multi-room dungeons.
- `key_location`: misc important places that do not fit the other physical categories, such as Starting Wilderness.
- Boss levels use `is_boss_level = true` while keeping their physical category.

## Marker Ownership

- `PlayableWorld/Markers/Entrances`: player arrival, route entry, and interior return markers.
- `PlayableWorld/Markers/StoryPositions`: NPC and story staging markers.
- `PlayableWorld/Markers/PatrolPaths`: AI patrol movement, stops, and house stop markers.
- Duplicate coordinates are fine when two systems need the same physical spot for different reasons.

## Adding A Lightweight Level

1. Use `res://templates/lightweight_level/README.md` as the checklist.
2. Put directional arrival markers under `PlayableWorld/Markers/Entrances`.
3. Name route entry markers by where the player appears in the destination, such as `WestEntrance`, `EastEntrance`, or `SouthEntrance`.
4. Set each `RouteExitArea.destination_entry_marker_path` to the destination scene marker path, not to the current scene exit.
5. Keep `route_id` values stable because route saves use them in save reasons.
6. Future exits may be placed before their destination scene exists. They should still use `RouteExitArea.gd`, a stable `route_id`, and a clear missing-destination message while leaving destination fields empty.

## Adding An NPC

1. Add the scene under `res://scenes/characters/npcs/<npc_name_or_group>/`.
2. Add animation resources under `res://resources/characters/npcs/<npc_name_or_group>/`.
3. Use `DialogueBank` for simple default chatter.
4. Use `DialogueProfile` for story-state dialogue.
5. Keep dialogue completion signals separate from the dialogue text.

## Adding A Hostile Or Boss

1. Add scenes under `res://scenes/characters/hostile_npcs/<entity_group>/`.
2. Add animation/tuning resources under `res://resources/characters/hostile_npcs/<entity_group>/`.
3. Keep scene-facing methods on the actor coordinator/state machine.
4. Move private lifecycle, sensors, combat areas, or save adapters into helpers only when they reduce real complexity.
5. Bosses should start with the hostile pattern, then add boss-specific resources and level-flow hooks only where needed.

## Validation

Run `Game/tools/validate_project_structure.ps1` after structural changes. It should report no errors before building a new feature on top of the templates.
