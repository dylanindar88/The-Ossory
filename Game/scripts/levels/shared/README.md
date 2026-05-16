# Shared Level Helpers

This folder contains reusable level helpers. These scripts are not scene-attached public coordinators by default; story-capable levels should still expose one `<LevelName>FlowController.gd` as the public coordinator and save provider.

Current helpers:

- `BansheeEncounterController.gd` owns reusable Banshee encounter behavior: save/restore, world rules, respawn timing, clear-state handling, combat variants, and hidden defeated-state restore.
- `KnightCampEncounterController.gd` owns reusable knight/campfire encounter state for future levels: temporary campfire destruction, linked knight respawn enablement, and level-visit reset behavior.
- `LevelInteractionRouter.gd` forwards scene interactions to the level coordinator named by `level_controller_path`.

Shared helpers should stay focused on reusable mechanics. They should not own global progression, quest stages, save schema changes, or cross-level unlocks unless those changes are routed through a level coordinator or `SaveManager`.

Use repo-wide generic naming in reusable helpers:

- `hostile_npcs` for combat enemies.
- `non_hostile_npcs` for friendly, neutral, quest, merchant, dialogue, and civilian NPCs.

Keep content-specific names, such as Celtic villagers or Banshee Village story terms, inside content-specific level folders unless the behavior is truly reusable.
