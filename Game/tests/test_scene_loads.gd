extends RefCounted

const LEVEL_INTERACTION_ROUTER_SCRIPT := preload("res://scripts/levels/shared/LevelInteractionRouter.gd")
const CAMPFIRE_BASE_SCENE := "res://scenes/environment/structures/campfire_base/CampfireBase.tscn"
const STARTING_WILDERNESS_SCENE := "res://scenes/levels/StartingWilderness.tscn"
const WEEPING_WOODS_SCENE := "res://scenes/levels/WeepingWoods.tscn"
const BANSHEE_VILLAGE_SCENE := "res://scenes/levels/BansheeVillage.tscn"
const BANSHEE_SCENE := "res://scenes/characters/hostile_npcs/banshees/Banshee.tscn"
const MALE_VILLAGER_SCENE := "res://scenes/characters/npcs/celtic_villagers/MaleVillager.tscn"
const FEMALE_VILLAGER_SCENE := "res://scenes/characters/npcs/celtic_villagers/FemaleVillager.tscn"
const VILLAGER_TUNING: VillagerTuning = preload("res://resources/characters/npcs/celtic_villagers/celtic_villager_tuning.tres")
const SCENE_PATHS := [
	"res://scenes/ui/TitleScreen.tscn",
	"res://scenes/ui/PauseMenu.tscn",
	"res://scenes/characters/saorise/Saorise.tscn",
	BANSHEE_SCENE,
	"res://scenes/characters/hostile_npcs/knights/BasicKnightMelee.tscn",
	"res://scenes/characters/hostile_npcs/knights/BasicKnightRanged.tscn",
	"res://scenes/characters/hostile_npcs/knights/KnightArrowProjectile.tscn",
	"res://scenes/characters/npcs/celtic_villagers/ElderVillager.tscn",
	FEMALE_VILLAGER_SCENE,
	MALE_VILLAGER_SCENE,
	"res://scenes/characters/npcs/dulluhan/Dulluhan.tscn",
	"res://scenes/characters/npcs/vincent/Vincent.tscn",
	"res://scenes/environment/structures/campfire_base/CampfireBase.tscn",
]


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var paths: Array[String] = []
	for level_path in save_manager.LEVEL_DISPLAY_REGISTRY.keys():
		paths.append(str(level_path))
	for scene_path in SCENE_PATHS:
		paths.append(scene_path)

	for scene_path in paths:
		await assert_scene_loads(assertions, tree, save_manager, scene_path)
	await assert_detached_interaction_router_refresh_is_safe(assertions, tree)
	await assert_detached_campfire_refresh_is_safe(assertions, tree)
	await assert_level_replacement_with_pending_router_refresh_is_safe(assertions, tree, save_manager)
	assert_no_removed_tuning_fields_are_serialized(assertions)
	await assert_villagers_use_shared_tuning(assertions, tree)


func assert_scene_loads(assertions: TestAssertions, tree: SceneTree, save_manager: Node, scene_path: String):
	var packed: PackedScene = load(scene_path)
	assertions.assert_true(packed != null, "Scene should load as PackedScene: %s" % scene_path)
	if packed == null:
		return

	var instance: Node = packed.instantiate()
	assertions.assert_true(instance != null, "Scene should instantiate: %s" % scene_path)
	if instance == null:
		return

	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	assertions.assert_true(instance.is_inside_tree(), "Scene should enter tree: %s" % scene_path)
	instance.queue_free()
	if save_manager != null and save_manager.has_method("set_current_level"):
		save_manager.call("set_current_level", null)
	await tree.process_frame


func assert_no_removed_tuning_fields_are_serialized(assertions: TestAssertions):
	var scene_paths := [
		STARTING_WILDERNESS_SCENE,
		BANSHEE_VILLAGE_SCENE,
		BANSHEE_SCENE,
		MALE_VILLAGER_SCENE,
		FEMALE_VILLAGER_SCENE,
	]
	var removed_fields := [
		"undetected_alpha",
		"banshee_story_visibility_tuning",
		"banshee_story_tuning",
		"BansheeStoryTuning",
		"story_visibility_tuning",
		"respawn_delay_seconds",
		"ambient_enabled =",
	]

	for scene_path in scene_paths:
		var file := FileAccess.open(scene_path, FileAccess.READ)
		assertions.assert_true(file != null, "Scene serialization should be readable: %s" % scene_path)
		if file == null:
			continue

		var contents := file.get_as_text()
		for field in removed_fields:
			assertions.assert_false(contents.contains(field), "%s should not serialize removed tuning field %s." % [scene_path, field])


func assert_villagers_use_shared_tuning(assertions: TestAssertions, tree: SceneTree):
	var original_walk_speed: float = VILLAGER_TUNING.walk_speed
	var original_arrival_distance: float = VILLAGER_TUNING.arrival_distance
	var original_ambient_enabled: bool = VILLAGER_TUNING.ambient_enabled
	VILLAGER_TUNING.walk_speed = 51.0
	VILLAGER_TUNING.arrival_distance = 8.0
	VILLAGER_TUNING.ambient_enabled = false

	var packed: PackedScene = load(MALE_VILLAGER_SCENE)
	assertions.assert_true(packed != null, "MaleVillager should load for shared villager tuning test.")
	if packed != null:
		var villager: Node = packed.instantiate()
		tree.root.add_child(villager)
		await tree.process_frame
		assertions.assert_eq(float(villager.get("walk_speed")), 51.0, "Villager walk speed should come from shared villager tuning.")
		assertions.assert_eq(float(villager.get("arrival_distance")), 8.0, "Villager arrival distance should come from shared villager tuning.")
		assertions.assert_false(bool(villager.get("ambient_enabled")), "Villager ambient enabled should come from shared villager tuning.")
		assertions.assert_false(has_exported_property(villager, "walk_speed"), "Villager should not expose per-scene walk speed.")
		assertions.assert_false(has_exported_property(villager, "arrival_distance"), "Villager should not expose per-scene arrival distance.")
		assertions.assert_false(has_exported_property(villager, "ambient_enabled"), "Villager should not expose per-scene ambient enabled.")
		villager.queue_free()
		await tree.process_frame

	VILLAGER_TUNING.walk_speed = original_walk_speed
	VILLAGER_TUNING.arrival_distance = original_arrival_distance
	VILLAGER_TUNING.ambient_enabled = original_ambient_enabled


func has_exported_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false

	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name and (int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0:
			return true

	return false


func assert_detached_interaction_router_refresh_is_safe(assertions: TestAssertions, tree: SceneTree):
	var router: Node = LEVEL_INTERACTION_ROUTER_SCRIPT.new()
	tree.root.add_child(router)
	tree.root.remove_child(router)
	router.call_deferred("refresh_connections")
	await tree.process_frame
	await tree.process_frame
	assertions.assert_false(router.is_inside_tree(), "Detached LevelInteractionRouter should remain outside the tree after a stale deferred refresh.")
	router.queue_free()
	await tree.process_frame


func assert_detached_campfire_refresh_is_safe(assertions: TestAssertions, tree: SceneTree):
	var packed: PackedScene = load(CAMPFIRE_BASE_SCENE)
	assertions.assert_true(packed != null, "CampfireBase should load for detached refresh regression.")
	if packed == null:
		return

	var campfire: Node = packed.instantiate()
	assertions.assert_true(campfire != null, "CampfireBase should instantiate for detached refresh regression.")
	if campfire == null:
		return

	tree.root.add_child(campfire)
	tree.root.remove_child(campfire)
	campfire.call_deferred("refresh_player_detection")
	await tree.process_frame
	await tree.physics_frame
	assertions.assert_false(campfire.is_inside_tree(), "Detached CampfireBase should remain outside the tree after a stale deferred player detection refresh.")
	campfire.queue_free()
	await tree.process_frame


func assert_level_replacement_with_pending_router_refresh_is_safe(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var starting_packed: PackedScene = load(STARTING_WILDERNESS_SCENE)
	var weeping_packed: PackedScene = load(WEEPING_WOODS_SCENE)
	assertions.assert_true(starting_packed != null, "Starting Wilderness should load for router transition regression.")
	assertions.assert_true(weeping_packed != null, "Weeping Woods should load for router transition regression.")
	if starting_packed == null or weeping_packed == null:
		return

	var starting_level: Node = starting_packed.instantiate()
	var weeping_level: Node = weeping_packed.instantiate()
	assertions.assert_true(starting_level != null, "Starting Wilderness should instantiate for router transition regression.")
	assertions.assert_true(weeping_level != null, "Weeping Woods should instantiate for router transition regression.")
	if starting_level == null or weeping_level == null:
		if starting_level != null:
			starting_level.queue_free()
		if weeping_level != null:
			weeping_level.queue_free()
		return

	tree.root.add_child(starting_level)
	await tree.process_frame
	var starting_flow := starting_level.get_node_or_null("StartingWildernessFlowController")
	if starting_flow != null and starting_flow.has_method("prepare_for_route_exit"):
		starting_flow.call("prepare_for_route_exit")
	tree.root.remove_child(starting_level)
	tree.root.add_child(weeping_level)
	await tree.process_frame
	await tree.process_frame

	var weeping_router := weeping_level.get_node_or_null("LevelInteractionRouter")
	assertions.assert_true(weeping_level.is_inside_tree(), "Weeping Woods should enter the tree after replacing Starting Wilderness.")
	assertions.assert_true(weeping_router != null and weeping_router.is_inside_tree(), "Weeping Woods interaction router should remain active after level replacement.")

	starting_level.queue_free()
	weeping_level.queue_free()
	if save_manager != null and save_manager.has_method("set_current_level"):
		save_manager.call("set_current_level", null)
	await tree.process_frame
