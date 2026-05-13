# Development Spec

Use this file as the quick repo-wide context before planning or implementing new gameplay. It captures the patterns that should be assumed without rescanning the entire project.

## Project Layout

- Level scenes live in `res://scenes/levels/` with root nodes named `Level-<LevelName>`.
- Level scripts live in `res://scripts/levels/<level_name>/`.
- Shared level helpers live in `res://scripts/levels/shared/`.
- Player scripts and scenes live under `characters/saorise`.
- NPC scenes live under `res://scenes/characters/npcs/<npc_group_or_name>/`.
- Hostile scenes live under `res://scenes/characters/hostile_npcs/<entity_group>/`.
- Character animation resources live under `res://resources/characters/...`.
- Dialogue resources live under `res://resources/dialogue/npcs/...` or `res://resources/dialogue/levels/...`.

## Level Pattern

Every story-capable level should have:

- A scene registered in `SaveManager.LEVEL_DISPLAY_REGISTRY`.
- A folder under `res://scripts/levels/<level_name>/`.
- A scene-attached `<LevelName>FlowController.gd`.
- `LevelSaveController` in the scene so save providers are discovered.
- `LevelInteractionRouter` wired to the flow controller when level interactions need a coordinator.
- Stable entrance markers under `PlayableWorld/Markers/Entrances`.
- Stable route exits under `PlayableWorld/Environment/Interactables/RouteExits`.

Lightweight exploration levels may keep the flow controller minimal, but future levels are expected to need at least a small save provider. Prefer adding the structure early.

## Save Schema

`SaveManager.gd` owns the public save API and the save schema version. Current schema version: `2`.

Canonical top-level save keys include:

- `version`
- `slot`
- `reason`
- `saved_at`
- `level_path`
- `player`
- `player_lives`
- `upgrade_state`
- `story_flags`
- `quest_states`
- `defeated_hostiles`
- `non_hostile_npcs`
- `level_states_by_path`

Rules:

- `level_states_by_path` is the canonical store for level-local state.
- `_providers` is only the internal multi-provider shape inside a level-state dictionary.
- Do not add a top-level `level_state` key.
- Schema breaks require a `SAVE_VERSION` bump.
- Old local save files may be deleted only when that is explicitly approved for the change.
- Delete old-version local saves before validating a planned schema break.
- Keep `SaveManager` public wrapper methods stable unless the change explicitly updates all call sites.

## Naming

Use generic names for generic systems:

- `non_hostile_npcs`: friendly, neutral, quest, merchant, dialogue, and civilian NPCs.
- `hostile_npcs`: hostile actors and combat enemies.
- `defeated_hostiles`: generic saved defeated-hostile state.

Use content-specific names only for content-specific rules:

- `celtic_villagers`: Celtic villager ambient and social behavior.
- Banshee Village story systems may keep Banshee, Dulluhan, Vincent, and assigned villager names where the content requires them.

Avoid generic `villager` wording in reusable collision, save, route, or actor APIs. Villager wording is fine for Celtic villager content.

## Story And Progression

- Use global story flags for simple cross-level facts, unlocks, reveals, and gates.
- Use quest stages for ordered cross-level progression.
- Use level-local state for actor snapshots, local encounters, prompts, interiors, collectibles, and temporary clears.
- Route exits and metroidvania gates should check stable story flags or quest stages, not temporary local encounter details.
- Boss levels own arena locks, boss phase state, local actor snapshots, and reward handoff timing. Global state owns cross-level unlocks and defeated-boss facts.

## Implementation Etiquette

- Preserve scene paths, node paths, route IDs, input actions, resource paths, and public APIs unless the change explicitly includes migration or call-site updates.
- Prefer small helpers near the owning domain over broad generic engines.
- Keep public coordinators scene-facing and move private details only when it makes the main flow easier to read.
- Update templates and validation rules with structural changes.
- Run `Game/tools/validate_project_structure.ps1` and `git diff --check` before considering structural work done.

## Testing

- Use `Game/tools/run_tests.ps1` as the standard local regression command before commits that touch gameplay, saves, scenes, UI slots, routes, or level structure.
- The runner combines project-structure validation, Godot headless tests, and `git diff --check`.
- Godot tests live under `res://tests/` and should stay dependency-free unless a future test framework is explicitly adopted.
- Save/load tests must use isolated `user://test_saves/...` paths and must never delete or overwrite normal player save slots.
- Add focused tests for new story-heavy level contracts, save schema changes, route travel behavior, boss gates, and UI save-slot behavior as those systems grow.
