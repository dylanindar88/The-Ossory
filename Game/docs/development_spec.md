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
- Environment structure scenes live under `res://scenes/environment/structures/<structure_name>/` when they are reusable gameplay objects rather than level-specific props.

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

## Hostile NPC Families

- Keep hostile families in their own scene, script, and resource folders under `hostile_npcs/<entity_group>`.
- Use separate tuning resources for variants that share code but need different health, speed, detection, attack, projectile, dialogue, or respawn values.
- Add hostile actors to `hostile_npcs`; add their hurt boxes to `enemies` so player attacks can hit them.
- Collision-aware hostiles should use normal physics collision plus `NavigationAgent2D`. Levels that use them must provide navigation regions/polygons for reliable obstacle-aware movement.
- Hostiles with hurt animations should enter a short non-lethal hurt state on damage. Cancel active melee hitboxes and pending damage windows, stop movement during the stun when tuning calls for it, and resume chase, return, or default behavior after the hurt timer. Lethal damage should go directly to death.
- Use `DialogueBank` or `DialogueSequence` resources for default first-encounter barks, with level flow controllers providing story or level-specific overrides.
- Do not add a generic enemy engine unless multiple hostile families prove they need the same abstraction.

## Attack Box Convention

- `AttackBox` `Area2D` nodes are stable signal and collision-mask owners.
- Runtime attack positioning should adjust the child `CollisionShape2D`, not the `AttackBox` node.
- Use `AttackHitboxShapeController` for melee hitbox enable/disable, editor-authored transform restore, facing flips, and temporary position/rotation/size profiles.
- When directional offsets need to track sprite or hitbox scaling, derive them from the cached editor-authored child shape dimensions instead of fixed pixels.
- Keep damage rules, combo rules, target filtering, and actor state in the owning actor or combat manager.
- Projectile attacks own their separate projectile hit boxes and do not use actor `AttackBox` conventions.
- Projectile-capable actors should expose an editable `ProjectileSpawn` `Marker2D`; melee-only actors should not carry projectile-only markers.

## Knight And Campfire Pattern

- Basic knights live under `hostile_npcs/knights` and use `basic_knight_melee` or `basic_knight_ranged` identity names.
- Melee and ranged knights share a controller foundation but keep distinct tuning resources.
- Knight hurt/stun timing belongs in each knight tuning resource. Basic Melee Knight has authored hurt animation; Basic Ranged Knight may fall back to idle until ranged hurt sprites are added.
- Knight attacks are one-stage by default; do not copy Banshee two-stage combo assumptions into knight scripts.
- Knight body collision should preserve the scene-authored `MovementBox.disabled` state. When the body shape is enabled, use the `HostileNPC` layer and collide with World, Player, and NPC bodies, but not other HostileNPC bodies; scripts may disable the body while dead/hidden, then must restore the authored alive state on respawn/reset.
- Saorise and collision-aware basic knights should use floating/top-down `CharacterBody2D` motion with enough slide iterations, a small safe margin, and `wall_min_slide_angle = 0` to resolve angled wall contacts consistently.
- Collision-aware actors should route movement through the shared top-down movement helper so static collision seams and corner normals get a short tangent-slide recovery before the actor is considered blocked.
- Knight movement must pass the active physics `delta` into the shared top-down movement helper, matching Saorise's movement path. Do not route normal knight movement through `NavigationAgent2D.velocity_computed` while actor avoidance is disabled.
- Collision-aware top-down actors should use compact circular movement footprints. Keep hurt/damage shapes separate, and avoid narrow rotated capsules for actor movement because they can catch on tile seams and polygon vertices.
- Knight `NavigationAgent2D` nodes provide path points around authored navigation polygons; do not use actor avoidance/RVO to keep distance from Saorise or other knights. Multiple melee knights may use small stable navigation target offsets while outside attack range so they do not visually stack on the exact same point, but those offsets must be dropped once the player is within effective melee range.
- Basic Melee Knight attack entry should use its tuning `attack_range` plus only a tiny contact tolerance. Large authored `AttackRange` helper shapes must not let melee attacks start from visibly distant positions.
- Keep the knight `MovementBox` as a compact foot/body footprint so it does not catch on static prop corners. Do not use a large sprite-sized body collider for top-down knight movement.
- Camp aggro should move linked knights through `NavigationAgent2D` path points only; do not add direct-chase launch windows, direct fallback timers, or side-step detours to knight aggro.
- Knight chase and return-home movement require authored navigation coverage. If the agent reports a stale, finished, or near-self path before the knight actually reaches its chase target or home position, refresh the navigation target and keep the current state instead of switching to direct player/home movement or idling early. Return-home may temporarily tighten `NavigationAgent2D` path/target distances to the knight's arrival distance, then restore the authored chase distances after the knight settles exactly on its home position.
- Campfire variant layouts own their own `CampNavigationRegion` with an assigned `NavigationPolygon`; the active `CampfireBase` exposes the region from its current layout.
- Tents, `Campfire`, and `MeleeBanner` should live under `CampNavigationRegion` so their collision shapes can be used as source geometry when baking or editing the camp navigation polygon.
- Linked camp knights use `NavigationAgent2D` for aggro and return-home movement. Banshee and other ghost-style entities may still use direct tracking, but knights should not.
- Author camp navigation polygons as walkable center-space for knight bodies. Leave generous margins around tents, tree trunks, campfire props, banners, buildings, logs, and other blockers.
- Static world blockers should use continuous flat edges where the visual reads flat. Avoid tiny sub-pixel offsets, overlapping tile seams, and jagged corner points that can catch top-down capsule bodies.
- Camp first-detection barks should be camp-coordinated from the campfire base's `CampAggroArea`: one readable bark per camp aggro event, auto-closing after a short delay. Longer conversation behavior is separate from first-detection barks.
- First-detection barks should not pause or gate aggro: when the camp base detects the player and the bark starts, linked live knights should immediately enter chase.
- `campfire_base` structures are wolf-vulnerable respawn anchors for linked knights.
- Destroying a campfire disables linked knight respawns only for the current level visit. Route travel out of the level should clear this temporary state so the campfire and respawns return on the next visit.
- Campfire base variants are gameplay/layout variants. A live base keeps its selected variant across level exits and save/load; only a destroyed base rerolls when it respawns.
- Campfire bases are composites: layouts contain normal/flipped `CampfireBaseTent`, `Campfire`, and `MeleeBanner` scene instances. The base is destroyed only when all tents are destroyed.
- Campfire layouts contain a `KnightRoster` `Node2D` for linked knight placements. The authored placed knights are the starting roster and respawn pool; do not spawn unplaced extras. At runtime, `CampfireBase` promotes rostered knights into `CampNavigationRegion` so each knight sorts individually against tents and props. Each variant's max knight count should match its tent count.
- A linked knight's editor-authored position is its home and respawn point. Layout `RespawnPoint` markers are not authoritative for knight respawns.
- Campfire layouts should not define shared return-home routes. Returning knights use navigation to reach their authored home positions.
- Before aggro, camp knights use an authored default behavior: idle, slow pace, or conversation. When camp aggro clears, they return home before resuming that behavior.
- Return-home should keep moving toward the authored home position until normal arrival distance is reached; do not time-snap knights home just because return is taking longer than expected. Pre-aggro tracking flags must not interrupt an active non-combat return or cause default idle to start at a route endpoint.
- Camp-wide aggro belongs in `KnightCampEncounterController`: the linked campfire base detecting the player wakes the camp, and the camp clears only after all live linked knights lose tracking.
- Non-damageable camp layout props such as `Campfire` and `MeleeBanner` are World-layer `StaticBody2D` scenes with editable body collisions and animated-ready `AnimatedSprite2D` children.
- Damageable tents remain tent-owned `StaticBody2D` scenes plus wolf-only `HurtBox` logic.
- Camp prop movement blockers should describe only the solid floor footprint, not the full visual silhouette. Use local, unskewed, lightly transformed collision children; avoid `top_level` movement blockers and heavily scaled or skewed capsules. Tent movement blockers should use dense segmented convex polygons with many shallow side/north points so `move_and_slide()` can slide actors around them like rounded building collision outlines. Keep tent hurt/damage polygons separate from movement blockers.
- Campfire weakness effects belong to individual damageable tents, not the aggregate campfire base root.
- Flipped tents should stay as real `CampfireBaseTentFlipped.tscn` instances, not normal tents with ad hoc node edits, so layout reloads and visual-state tests can preserve authoring intent.
- Aseprite campfire layout blueprints should use stable layer names such as `Tent1`, `campfire`, and `Banner`; Godot layout scenes place matching nodes from each visible layer center relative to the blueprint canvas center.
- Save active knight/campfire state through level-local providers inside `level_states_by_path`; do not add top-level save keys for knight camps.

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
