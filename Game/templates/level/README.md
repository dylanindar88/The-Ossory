# Level Template Checklist

Use for story-heavy or progression-owning levels.

- Scene: `res://scenes/levels/<LevelName>.tscn`
- Coordinator: `res://scripts/levels/<level_name>/<LevelName>FlowController.gd`
- Helpers: progression, presentation, encounters, interiors, prompts, or dev presets only when needed.
- Dialogue: `res://resources/dialogue/levels/<level_name>/`
- Public save methods if the level owns local state: `collect_level_state`, `apply_level_state`, `validate_level_state`.
- Keep level scene paths stable once saves or dev starts reference them.

Validation:
- Headless project load passes.
- Direct-load the level scene.
- Save/load every major progression state.
- Route exits and interiors preserve player/actor positions.
