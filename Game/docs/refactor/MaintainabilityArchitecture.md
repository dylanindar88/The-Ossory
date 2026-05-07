# Maintainability Refactor Architecture

This refactor keeps public scene/autoload APIs stable while moving dense internal responsibilities into focused helpers. The goal is easier future development for levels, quests, bosses, and actors without changing game behavior or save compatibility.

For concrete content setup checklists, use `res://docs/content_authoring.md` and the README files under `res://templates/`.

## Public Entry Points

- `BansheeVillageFlowController.gd` remains the public Banshee Village coordinator and level-state provider.
- Saorise and Banshee `stateMachine.gd` scripts remain the public actor APIs used by scenes, health, combat, save/load, and flow controllers.
- `SaveManager.gd` remains the autoload API and save schema owner.

Helpers are internal delegates. External callers should continue using the coordinator, actor state machine, or `SaveManager` wrapper methods.

## Helper Ownership

- Banshee Village helpers own stage rules, dev presets, progression, presentation, encounters, interior travel, and story transformation prompts.
- Banshee actor helpers own story/save lifecycle, combat-area toggling, and aggro/detection sensor handling.
- Saorise's transformation helper owns wolf timing, cooldown, story/dev locks, and autosave blocking while the state machine keeps form application and movement/combat coordination.
- SaveManager helpers own settings IO, upgrade/lives state, quest/story flags, file IO, actor adapters, and level-state provider orchestration.

## Compatibility Rules

- Do not rename quest stage strings, save keys, signals, input actions, scene node paths, or public wrapper methods without a separate migration plan.
- Keep existing save schema keys stable, including `level_state`, `level_states_by_path`, `_providers`, `player`, `defeated_banshees`, `villagers`, `story_flags`, `quest_states`, and `upgrade_state`.
- Keep Banshee Village as one public level-state provider until a future migration explicitly proves multi-provider ownership is safe for existing saves.
- Keep scene-load, new-game, respawn, and dev-start orchestration in `SaveManager.gd` unless a later pass scopes that migration.

## Future Development Pattern

For future story-heavy levels, use one scene-attached coordinator with focused internal helpers for progression, presentation, encounters, travel, and prompts. The coordinator should own save compatibility and expose a single stable level-state dictionary unless the migration plan explicitly defines otherwise.

For future actors or bosses, keep scene-facing methods on the actor coordinator/state machine and move only private lifecycle, sensor, combat-area, or save details into helpers. This keeps existing callers stable while allowing behavior to grow in smaller files.
