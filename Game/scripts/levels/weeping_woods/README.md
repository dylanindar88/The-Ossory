# Weeping Woods Level

Weeping Woods follows the standard story-capable level shape:

- Scene: `res://scenes/levels/WeepingWoods.tscn`
- Coordinator: `res://scripts/levels/weeping_woods/WeepingWoodsFlowController.gd`
- Save wiring: `LevelSaveController` discovers the flow controller as a level-state provider.
- Interaction wiring: `LevelInteractionRouter.level_controller_path` points at `../WeepingWoodsFlowController`.

The current flow controller stores only a `state_version` placeholder. Keep it as the public place for future Weeping Woods state, including level-local NPCs, encounters, collectibles, traversal gates, boss setup, and route-specific presentation.

The scene is prepared for future knight camps with `PlayableWorld/Navigation/KnightNavigationRegions` and an empty `PlayableWorld/Environment/Characters/HostileNPCs/CampfireBases` organization node. Camp-specific navigation lives on each campfire layout variant's `CampNavigationRegion`. Once campfire bases are placed here, add a `KnightCampEncounterController` provider through the flow controller, following Starting Wilderness, so campfire/knight state stays level-local.

Use generic save and group names for reusable systems:

- `non_hostile_npcs` for friendly, neutral, merchant, quest, and civilian NPC systems.
- `hostile_npcs` or content-specific hostile groups for enemies.
- Content-specific groups, such as `celtic_villagers`, only when the behavior truly applies to that content type.

Unbuilt route exits should keep stable `route_id` values and explicit `missing_destination_message` text so players get a clear warning while the destination level is still pending.
