# Content Authoring Guide

Use this as the quick checklist before adding new levels, NPCs, hostile entities, or bosses. `res://docs/development_spec.md` is the repo-wide source for naming, save, and development etiquette. Banshee Village is the concrete reference implementation.

## Storage Conventions

- Scenes use `PascalCase.tscn` and live under `res://scenes/`.
- Scripts use `PascalCase.gd` for controllers/resources and stay near their domain under `res://scripts/`.
- Resource files use `snake_case.tres` and live under `res://resources/`.
- Dialogue with multiple story states uses `*_story_profile.tres`.
- Character animation data should be external `SpriteFrames` resources under `res://resources/characters/...`, not embedded in character scenes.
- UI menus, HUD panels, debug views, dev-tool views, gauge rows, and stock icon layouts should have their editable layout shell and preview rows authored in `.tscn` scenes first. Runtime scripts may replace preview content with data-driven rows, but should bind existing containers instead of creating the layout structure from scratch. Repeated runtime rows should duplicate an authored preview/template row so edits made in the Godot 2D editor are reflected in game. When rows need to fit a specific background image, use fixed `Control` blocks with anchored child controls instead of container rows that can expand from dynamic labels or dropdown text.
- HUD and Saorise under-player stamina/transformation gauges should instance the shared `PlayerGaugeStack.tscn` and use the shared preview settings resource. Tune shared gauge shape and stock cluster layouts in the editor; scripts should only drive live values, visibility, and active-row ordering.

## Folder Patterns

- Player scenes: `res://scenes/characters/saorise/`
- NPC scenes: `res://scenes/characters/npcs/<npc_group_or_name>/`
- Hostile scenes: `res://scenes/characters/hostile_npcs/<entity_group>/`
- Reusable structure scenes: `res://scenes/environment/structures/<structure_name>/`
- Character resources: `res://resources/characters/<same_domain>/`
- Dialogue resources: `res://resources/dialogue/npcs/<npc_name>/` or `res://resources/dialogue/levels/<level_name>/`
- Level scenes: `res://scenes/levels/`
- Level scripts/helpers: `res://scripts/levels/<level_name>/`
- Shared level helpers: `res://scripts/levels/shared/`
- Global scripts only: autoloads, shared managers, or truly cross-level systems.

## Adding A Level

1. Create the level scene under `res://scenes/levels/`.
2. Register the scene in `SaveManager.LEVEL_DISPLAY_REGISTRY` with a unique `level_index`, `display_name`, `category`, `is_boss_level`, and `map_region_id`.
3. Add a scene-attached flow coordinator under `res://scripts/levels/<level_name>/`. It can be minimal for now, but future levels are expected to need at least a small save provider.
4. Put level-specific helpers under `res://scripts/levels/<level_name>/`.
5. Keep one public level-state provider unless multiple providers are clearly needed; multi-provider state is packed under `_providers`.
6. Keep save keys, quest stage strings, and route IDs stable within a save schema version. Schema breaks require a `SaveManager.SAVE_VERSION` bump.

## Story Progression State

- Use global story flags for facts that other levels need to ask as simple yes/no questions, such as a character reveal, a power unlock, or a metroidvania gate being opened.
- Use quest stages for ordered cross-level progression where more than one level, boss, route, or UI surface needs to know the current step.
- Use level-local state for scene-owned details such as active interiors, local encounter waves, local NPC positions, temporary clears, local prompts, and save restoration snapshots.
- Keep local level state behind the level coordinator's `collect_level_state`, `apply_level_state`, and `validate_level_state` methods.
- Do not promote a level-local field into a global flag until another level or global UI actually needs it.
- Store level-local data through `level_states_by_path`; do not add a top-level `level_state` save key.

## Story-Heavy Level Pattern

- Coordinator: one scene-attached public API that owns exported node paths, save-provider methods, signal wiring, and helper dispatch.
- Stage rules: constants and pure predicates for valid stages, compatibility aliases, and stage-derived defaults.
- Progression helper: quest transitions, story reactions, and save triggers.
- Presentation helper: route gates, flags, visibility, counters, and other level feedback.
- Encounter or boss helper: wave state, actor reveal/clear behavior, boss phase handoff, and level-owned actor state.
- Save adapter: local save collection, normalization, validation, and apply-time restoration.

## Boss And Gate Pattern

- A boss level owns arena locks, boss phase state, local actor snapshots, and reward handoff timing.
- Global quest state or story flags own cross-level unlocks, opened routes, defeated-boss facts, and ability gates.
- Route exits should check stable quest stages or story flags, not temporary encounter state.
- Boss actors keep scene-facing methods on their controller/state machine while private phase, arena, sensor, combat-area, and save behavior may live in helpers.

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
6. Add generic friendly, neutral, quest, merchant, and civilian NPCs to `non_hostile_npcs`.
7. Add Celtic villagers to both `non_hostile_npcs` and `celtic_villagers`.

## Adding A Hostile Or Boss

1. Add scenes under `res://scenes/characters/hostile_npcs/<entity_group>/`.
2. Add animation/tuning resources under `res://resources/characters/hostile_npcs/<entity_group>/`.
3. Add hostile actors to `hostile_npcs` and their hurt boxes to `enemies`.
4. Use separate tuning resources for variants that share code but need different stats.
5. Keep `AttackBox` as the stable `Area2D` owner and tune attackbox profiles with `AttackHitboxProfileAuthoring` in the scene. Select the form/variant, direction, and combo/profile slot in the inspector, then edit the visible child `CollisionShape2D`; scripts should apply those authored profiles through `AttackHitboxShapeController` instead of hardcoded hitbox dimensions.
6. If the hostile has a hurt animation, route non-lethal damage through a short hurt/stun state that cancels active attack hitboxes and resumes normal behavior afterward. Lethal damage should go directly to death.
7. Keep scene-facing methods on the actor coordinator/state machine.
8. Move private lifecycle, sensors, combat areas, or save adapters into helpers only when they reduce real complexity.
9. Bosses should start with the hostile pattern, then add boss-specific resources and level-flow hooks only where needed.

## Basic Knight Camps

Basic knights use `campfire_base` structures as temporary respawn anchors. Campfire bases are built from normal/flipped `CampfireBaseTent`, `Campfire`, and `MeleeBanner` scene instances. Tents are the damageable components; destroying every tent destroys the base and disables linked knight respawns for the current level visit. `Campfire` and `MeleeBanner` are non-damageable World-layer props with editable body collisions and animated child sprites. Each live tent owns its own `weak_to_wolf` effect while wolf damage is available. Live bases keep their selected layout variant across exits, while destroyed bases reroll their variant when they respawn. Aseprite layout blueprints should use stable `Tent#`, `campfire`, and `Banner` layers so Godot layout nodes can be placed from visible layer centers. Keep flipped tents as `CampfireBaseTentFlipped.tscn` instances.

Camp knights should be hand placed under each layout's `KnightRoster` node as the authored roster for that layout. At runtime, `CampfireBase` promotes those knights into the layout's `CampNavigationRegion` so they render individually in front of or behind each tent. The starting and maximum active roster count is `tent_count`, and each placed knight's editor position is its home and respawn point. Layout `RespawnPoint` markers are not authoritative for knight respawns. Do not add `ReturnPaths`; returning knights use `NavigationAgent2D` path points to reach their own home positions. Link knights to the owning campfire with `campfire_base_path`. Use `idle`, `pace`, or `conversation` as the default behavior before aggro; camp-wide aggro and return-home behavior should be coordinated by `KnightCampEncounterController`. Save active knight/campfire state through the owning level's `level_states_by_path` provider, not through new top-level save keys.

Knight camp movement is collision-aware but still depends on authored navigation. Knight scripts preserve the scene-authored `MovementBox.disabled` setting; the current Basic Knight scenes are authored with live body collision enabled, using the `HostileNPC` body layer and colliding with World, Player, and NPC bodies, but not other HostileNPC bodies. Saorise and collision-aware basic knights should use compact circular movement footprints, floating/top-down `CharacterBody2D` motion with enough slide iterations, a small safe margin, `wall_min_slide_angle = 0`, and the shared top-down movement helper so static collision seams can resolve into a tangent slide before movement is considered blocked. Knight movement should pass real physics `delta` into that helper just like Saorise; do not use `NavigationAgent2D.velocity_computed` as a normal movement path while actor avoidance is disabled. Keep hurt/damage shapes separate from movement footprints, and avoid narrow rotated movement capsules for world-navigation actors because they can catch on tile seams and polygon vertices. `NavigationAgent2D` provides path points around authored camp navigation polygons, but actor avoidance/RVO should not be used to keep distance from Saorise or other knights. Camp aggro and return-home should use navigation path points only; do not add direct-chase fallback, launch windows, or side-step detours to knight movement. Small stable melee chase offsets are allowed outside attack range to prevent perfect visual stacking, but melee knights should drop those offsets and attack directly once they are close enough; melee attack entry should use the tuning `attack_range` plus only a tiny contact tolerance. Each campfire layout variant owns its own `CampNavigationRegion`; place tents, `Campfire`, and `MeleeBanner` under it so Godot can use their collision shapes as source geometry when baking or editing the region. Draw navigation polygons as walkable center-space for knight bodies, with generous margins around solid props. Runtime movement blockers should represent only solid floor footprints, not the full visual silhouette: use local unskewed collision children, dense segmented tent movement polygons with many shallow rounded edges, and compact rounded blockers for campfires. Static blockers and tiles should use continuous aligned edges where the visual reads flat; avoid tiny sub-pixel offsets, overlapping seams, `top_level`, or heavily scaled/skewed movement blockers. Keep tent hurt/damage polygons separate. First-detection barks are camp-managed from the campfire base `CampAggroArea`, short-lived, and should not delay aggro state changes; use conversation defaults for idle chatter between knights. Return-home should keep running until normal arrival distance is reached, temporarily tightening navigation completion distances if needed, refreshing stale navigation paths instead of idling early, then settle exactly on the authored home position and restore the authored chase navigation distances.

## Validation

Run `Game/tools/validate_project_structure.ps1` after structural changes. It should report no errors before building a new feature on top of the templates.
