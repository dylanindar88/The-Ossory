# Level Template Checklist

Use for story-heavy or progression-owning levels.

- Scene: `res://scenes/levels/<LevelName>.tscn`
- Metadata: register the scene in `SaveManager.LEVEL_DISPLAY_REGISTRY` with a unique `level_index`, `display_name`, `category`, `is_boss_level`, and `map_region_id`.
- Coordinator: `res://scripts/levels/<level_name>/<LevelName>FlowController.gd`
- Scene wiring: include `LevelSaveController`; point `LevelInteractionRouter.level_controller_path` at the flow controller when the level routes interactions through it.
- Helpers: progression, presentation, encounters, interiors, prompts, or dev presets only when needed.
- Dialogue: `res://resources/dialogue/levels/<level_name>/`
- Public save methods: `collect_level_state`, `apply_level_state`, `validate_level_state`.
- Route entry markers: `PlayableWorld/Markers/Entrances/<Name>Entrance`.
- Story staging markers: `PlayableWorld/Markers/StoryPositions/<StoryBeatOrActorName>`.
- Patrol markers: `PlayableWorld/Markers/PatrolPaths/<PatrolName>`.
- Route exits: `PlayableWorld/Environment/Interactables/RouteExits/<Name>Exit`.
- Use `res://templates/lightweight_level/README.md` for lightweight travel/exploration levels.
- Keep level scene paths stable once saves or dev starts reference them.
- Store level-local data through `level_states_by_path`; do not add a top-level `level_state` save key.
- Schema breaks require a `SaveManager.SAVE_VERSION` bump and explicit approval to delete old saves.
- It is okay for different marker types to share coordinates when they serve different systems.

Validation:
- Headless project load passes.
- Direct-load the level scene.
- Save/load every major progression state.
- Route exits and interiors preserve player/actor positions.
