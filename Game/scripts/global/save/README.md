# SaveManager Helpers

`SaveManager.gd` remains the public autoload API and save schema owner. Helpers in this folder are internal delegates; callers should continue using `SaveManager` methods.

- `SaveSettingsController.gd` owns gauge display and camera zoom settings IO.
- `SaveUpgradeController.gd` owns upgrade unlocks, stat levels, max lives, current lives, and related signal emission.
- `SaveQuestController.gd` owns story flags, quest states, Banshee world rules, and quest-stage helpers.
- `SaveFileController.gd` owns save path validation, JSON read/write, summaries, existence checks, and deletion.
- `SaveActorStateController.gd` owns player, hostile, non-hostile NPC, and generic story-actor save/apply adapters.
- `SaveLevelStateController.gd` owns level-state memory, provider discovery, provider packing, route-exit preparation, and debug verification.
- `SaveLevelMetadataController.gd` owns level display labels, save-slot display names, and title-screen dev level entries.

Do not let helpers invent new public save keys or become scene dependencies without an explicit schema-version plan. `SaveManager` wrappers should remain stable even when they delegate to helpers. In v2, `level_states_by_path` is canonical and `_providers` is only the internal multi-provider shape.
