# Level Template Checklist

Use for story-heavy or progression-owning levels.

- Scene: `res://scenes/levels/<LevelName>.tscn`
- Metadata: register the scene in `SaveManager.LEVEL_DISPLAY_REGISTRY` with a unique `level_index`, `display_name`, `category`, `is_boss_level`, and `map_region_id`.
- Coordinator: `res://scripts/levels/<level_name>/<LevelName>FlowController.gd`
- Helpers: progression, presentation, encounters, interiors, prompts, or dev presets only when needed.
- Dialogue: `res://resources/dialogue/levels/<level_name>/`
- Public save methods if the level owns local state: `collect_level_state`, `apply_level_state`, `validate_level_state`.
- Route entry markers: `PlayableWorld/Markers/Entrances/<Name>Entrance`.
- Story staging markers: `PlayableWorld/Markers/StoryPositions/<StoryBeatOrActorName>`.
- Patrol markers: `PlayableWorld/Markers/PatrolPaths/<PatrolName>`.
- Route exits: `PlayableWorld/Environment/Interactables/RouteExits/<Name>Exit`.
- Use `res://templates/lightweight_level/README.md` for lightweight travel/exploration levels.
- Keep level scene paths stable once saves or dev starts reference them.
- It is okay for different marker types to share coordinates when they serve different systems.

Validation:
- Headless project load passes.
- Direct-load the level scene.
- Save/load every major progression state.
- Route exits and interiors preserve player/actor positions.
