extends RefCounted

const STARTING_WILDERNESS_PATH := "res://scenes/levels/StartingWilderness.tscn"
const BANSHEE_VILLAGE_PATH := "res://scenes/levels/BansheeVillage.tscn"
const WEEPING_WOODS_PATH := "res://scenes/levels/WeepingWoods.tscn"
const STARTING_WILDERNESS_BANSHEE_PATH := "PlayableWorld/Environment/Characters/HostileNPCs/Banshees/Banshee2"
const BANSHEE_VILLAGE_BANSHEE_PATH := "PlayableWorld/Environment/Characters/HostileNPCs/Banshee2"
const RESPAWN_DELAY := 0.05
const BANSHEE_TUNING: BansheeTuning = preload("res://resources/characters/hostile_npcs/banshees/banshee_tuning.tres")
const BANSHEE_SCENE := "res://scenes/characters/hostile_npcs/banshees/Banshee.tscn"
const BANSHEE_ENCOUNTER_CONTROLLER_SCRIPT := preload("res://scripts/levels/shared/BansheeEncounterController.gd")
const BANSHEE_LEVEL_SUPPORT_SCRIPT := preload("res://scripts/levels/shared/BansheeLevelSupport.gd")


class MockPlayer:
	extends Node2D

	func _ready():
		add_to_group("player")


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var original_respawn_delay: float = BANSHEE_TUNING.story_respawn_delay_seconds
	BANSHEE_TUNING.story_respawn_delay_seconds = RESPAWN_DELAY
	await assert_starting_wilderness_saved_defeated_restore(assertions, tree, save_manager, true, 0, "dead snapshot")
	await assert_starting_wilderness_saved_defeated_restore(assertions, tree, save_manager, false, 0, "zero-health snapshot")
	await assert_banshee_village_saved_defeated_restore(assertions, tree, save_manager, true, 0, "dead snapshot")
	await assert_banshee_village_saved_defeated_restore(assertions, tree, save_manager, false, 0, "zero-health snapshot")
	await assert_shared_banshee_encounter_refreshes_members(assertions, tree, save_manager)
	await assert_generic_banshee_level_support(assertions, tree, save_manager)
	await assert_weeping_woods_banshee_support(assertions, tree, save_manager)
	BANSHEE_TUNING.story_respawn_delay_seconds = original_respawn_delay


func assert_starting_wilderness_saved_defeated_restore(assertions: TestAssertions, tree: SceneTree, save_manager: Node, saved_dead: bool, saved_health: int, label: String):
	var packed: PackedScene = load(STARTING_WILDERNESS_PATH)
	assertions.assert_true(packed != null, "Starting Wilderness should load for Banshee respawn restore test.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	set_banshee_world_rules(save_manager, true)
	var provider: Node = save_manager.call("get_level_state_provider", level)
	var flow: Node = level.get_node_or_null("StartingWildernessFlowController")
	assertions.assert_true(provider != null, "Starting Wilderness should have a save provider.")
	assertions.assert_true(flow != null, "Starting Wilderness should have a flow controller.")
	assertions.assert_false(has_exported_property(flow, "respawn_delay_seconds"), "Starting Wilderness should not expose per-level Banshee respawn delay.")
	if flow != null and flow.get("encounter_controller") != null:
		assertions.assert_false(has_exported_property(flow.get("encounter_controller"), "respawn_delay_seconds"), "Banshee encounter controller should not expose per-controller respawn delay.")

	var state: Dictionary = provider.call("collect_level_state")
	var encounter_state: Dictionary = state.get("encounter", {})
	encounter_state["temporarily_cleared_banshee_paths"] = []
	encounter_state["permanently_cleared_banshee_paths"] = []
	encounter_state["banshees"] = with_banshee_saved_defeated_state(encounter_state.get("banshees", []), STARTING_WILDERNESS_BANSHEE_PATH, saved_dead, saved_health)
	state["encounter"] = encounter_state

	provider.call("apply_level_state", state)
	await tree.process_frame
	await tree.physics_frame

	var banshee: Node = level.get_node_or_null(STARTING_WILDERNESS_BANSHEE_PATH)
	assert_defeated_waiting_state(assertions, banshee, "Starting Wilderness %s" % label)

	await tree.create_timer(RESPAWN_DELAY + 0.05).timeout
	await tree.process_frame
	assert_respawned_state(assertions, banshee, "Starting Wilderness %s" % label)

	level.queue_free()
	save_manager.call("set_current_level", null)
	set_banshee_world_rules(save_manager, false)
	await tree.process_frame


func assert_banshee_village_saved_defeated_restore(assertions: TestAssertions, tree: SceneTree, save_manager: Node, saved_dead: bool, saved_health: int, label: String):
	var packed: PackedScene = load(BANSHEE_VILLAGE_PATH)
	assertions.assert_true(packed != null, "Banshee Village should load for Banshee respawn restore test.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	var provider: Node = save_manager.call("get_level_state_provider", level)
	assertions.assert_true(provider != null, "Banshee Village should have a save provider.")
	assertions.assert_false(has_exported_property(provider, "respawn_delay_seconds"), "Banshee Village should not expose per-level Banshee respawn delay.")

	var state: Dictionary = provider.call("collect_level_state")
	state["quest_stage"] = "combat_active"
	state["temporarily_cleared_banshee_paths"] = []
	state["permanently_cleared_banshee_paths"] = []
	state["banshees"] = with_banshee_saved_defeated_state(state.get("banshees", []), BANSHEE_VILLAGE_BANSHEE_PATH, saved_dead, saved_health)

	provider.call("apply_level_state", state)
	await tree.process_frame
	await tree.physics_frame

	var banshee: Node = level.get_node_or_null(BANSHEE_VILLAGE_BANSHEE_PATH)
	assert_defeated_waiting_state(assertions, banshee, "Banshee Village %s" % label)

	await tree.create_timer(RESPAWN_DELAY + 0.05).timeout
	await tree.process_frame
	assert_respawned_state(assertions, banshee, "Banshee Village %s" % label)

	level.queue_free()
	save_manager.call("set_current_level", null)
	await tree.process_frame


func assert_shared_banshee_encounter_refreshes_members(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var level := Node2D.new()
	var hostile_root := Node2D.new()
	var controller := BANSHEE_ENCOUNTER_CONTROLLER_SCRIPT.new()
	var banshee_packed: PackedScene = load(BANSHEE_SCENE)
	assertions.assert_true(banshee_packed != null, "Banshee scene should load for shared encounter refresh coverage.")
	if banshee_packed == null:
		return

	hostile_root.name = "HostileNPCs"
	level.add_child(hostile_root)
	level.add_child(controller)
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame

	controller.state_root_path = controller.get_path_to(level)
	controller.hostile_root_path = controller.get_path_to(hostile_root)
	assertions.assert_true((controller.get("banshees") as Array).is_empty(), "Shared Banshee encounter starts empty before late Banshee authoring is added.")

	var banshee := banshee_packed.instantiate()
	hostile_root.add_child(banshee)
	await tree.process_frame
	set_banshee_world_rules(save_manager, true)
	controller.apply_level_state({})
	await tree.process_frame

	assertions.assert_eq((controller.get("banshees") as Array).size(), 1, "Shared Banshee encounter should refresh members when applying state.")
	assertions.assert_eq(int(banshee.get("banshee_index")), 0, "Shared Banshee encounter should assign indexes after refresh.")
	assertions.assert_true(bool(banshee.get("combat_enabled")), "Shared Banshee encounter should apply world rules to refreshed Banshees.")

	level.queue_free()
	save_manager.call("set_current_level", null)
	set_banshee_world_rules(save_manager, false)
	await tree.process_frame


func assert_generic_banshee_level_support(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var level := Node2D.new()
	var hostile_root := Node2D.new()
	var banshee_root := Node2D.new()
	var support := BANSHEE_LEVEL_SUPPORT_SCRIPT.new()
	var banshee_packed: PackedScene = load(BANSHEE_SCENE)
	assertions.assert_true(banshee_packed != null, "Banshee scene should load for generic level support coverage.")
	if banshee_packed == null:
		return

	hostile_root.name = "HostileNPCs"
	banshee_root.name = "Banshees"
	level.add_child(hostile_root)
	hostile_root.add_child(banshee_root)
	level.add_child(support)
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	set_banshee_world_rules(save_manager, false)
	var banshee := banshee_packed.instantiate()
	banshee_root.add_child(banshee)
	support.configure(level, hostile_root, BansheeLevelSupport.MODE_STORY_RULES)
	await tree.process_frame
	await tree.process_frame

	var controller: Node = support.call("get_encounter_controller")
	assertions.assert_true(controller != null, "Generic Banshee level support should create an encounter controller.")
	if controller != null:
		assertions.assert_eq((controller.get("banshees") as Array).size(), 1, "Generic Banshee level support should discover Banshees from the configured hostile root.")
		assertions.assert_eq(int(banshee.get("banshee_index")), 0, "Generic Banshee level support should assign indexes.")
		assertions.assert_false(bool(banshee.get("combat_enabled")), "Generic Banshee support should obey story rules and stay passive before Banshee progression.")
		assertions.assert_false(bool(banshee.get("damage_enabled")), "Generic Banshee support should keep damage disabled before Banshee progression.")
		assertions.assert_eq(str(banshee.get("current_state_name")), "idle", "Banshees with no patrol path should remain idle before aggro.")
		assert_banshee_detection_signal_wired(assertions, banshee, "Generic Banshee level support")
		trigger_banshee_detection(banshee, MockPlayer.new(), level)
		await tree.process_frame
		assertions.assert_eq(str(banshee.get("current_state_name")), "idle", "Generic Banshee should ignore detection before Banshee progression enables combat.")

		set_banshee_world_rules(save_manager, true)
		controller.call("apply_level_state", {})
		await tree.process_frame
		assertions.assert_true(bool(banshee.get("combat_enabled")), "Generic Banshee support should enable combat once Banshee progression allows it.")
		assertions.assert_true(bool(banshee.get("damage_enabled")), "Generic Banshee support should enable damage once Banshee progression allows it.")
		trigger_banshee_detection(banshee, MockPlayer.new(), level)
		await tree.process_frame
		assertions.assert_eq(str(banshee.get("current_state_name")), "scream", "Generic Banshee should enter aggro flow after Banshee progression enables combat.")

	level.queue_free()
	save_manager.call("set_current_level", null)
	set_banshee_world_rules(save_manager, false)
	await tree.process_frame


func assert_weeping_woods_banshee_support(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var packed: PackedScene = load(WEEPING_WOODS_PATH)
	assertions.assert_true(packed != null, "Weeping Woods should load for Banshee support coverage.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	set_banshee_world_rules(save_manager, false)
	await tree.process_frame
	await tree.process_frame

	var flow: Node = level.get_node_or_null("WeepingWoodsFlowController")
	assertions.assert_true(flow != null, "Weeping Woods should have a flow controller.")
	if flow != null:
		var controller: Node = flow.get("banshee_encounter_controller")
		assertions.assert_true(controller != null, "Weeping Woods should create a reusable Banshee encounter controller.")
		if controller != null:
			var authored_count := count_authored_banshees(level)
			var discovered_banshees: Array = controller.get("banshees") as Array
			assertions.assert_true(authored_count > 0, "Weeping Woods should have authored Banshees for this coverage.")
			assertions.assert_eq(discovered_banshees.size(), authored_count, "Weeping Woods Banshee support should discover all authored Banshees.")
			for index in range(discovered_banshees.size()):
				var banshee: Node = discovered_banshees[index]
				assertions.assert_eq(int(banshee.get("banshee_index")), index, "Weeping Woods Banshees should receive deterministic indexes.")
				assertions.assert_false(bool(banshee.get("combat_enabled")), "Weeping Woods Banshees should stay passive before Banshee Village progression enables them.")
				assertions.assert_false(bool(banshee.get("damage_enabled")), "Weeping Woods Banshees should not be damage-enabled before Banshee Village progression.")
				if str(banshee.get("patrol_path")) == "":
					assertions.assert_eq(str(banshee.get("current_state_name")), "idle", "Weeping Woods Banshees without patrol paths should idle before aggro.")

			if not discovered_banshees.is_empty():
				var first_banshee: Node = discovered_banshees[0]
				assert_banshee_detection_signal_wired(assertions, first_banshee, "Weeping Woods")
				trigger_banshee_detection(first_banshee, MockPlayer.new(), level)
				await tree.process_frame
				assertions.assert_eq(str(first_banshee.get("current_state_name")), "idle", "Weeping Woods Banshee should ignore detection before Banshee Village progression.")

				set_banshee_world_rules(save_manager, true)
				controller.call("apply_level_state", {})
				await tree.process_frame
				assertions.assert_true(bool(first_banshee.get("combat_enabled")), "Weeping Woods Banshee should become combat-enabled after Banshee Village progression.")
				assertions.assert_true(bool(first_banshee.get("damage_enabled")), "Weeping Woods Banshee should become damage-enabled after Banshee Village progression.")
				trigger_banshee_detection(first_banshee, MockPlayer.new(), level)
				await tree.process_frame
				assertions.assert_eq(str(first_banshee.get("current_state_name")), "scream", "Weeping Woods Banshee should enter aggro flow after Banshee Village progression enables combat.")

		var state: Dictionary = flow.call("collect_level_state")
		assertions.assert_has_key(state, "banshee_encounter", "Weeping Woods state should include reusable Banshee encounter state.")

	level.queue_free()
	save_manager.call("set_current_level", null)
	set_banshee_world_rules(save_manager, false)
	await tree.process_frame


func count_authored_banshees(level: Node) -> int:
	var root := level.get_node_or_null("PlayableWorld/Environment/Characters/HostileNPCs/Banshees")
	if root == null:
		return 0
	var count := 0
	for child in root.get_children():
		if child.is_in_group("hostile_npcs") and child.has_method("set_combat_variant"):
			count += 1
	return count


func assert_banshee_detection_signal_wired(assertions: TestAssertions, banshee: Node, label: String):
	assertions.assert_true(banshee != null, "%s should have a Banshee to inspect detection wiring." % label)
	if banshee == null:
		return
	var detection_area := banshee.get_node_or_null("PlayerDetectionArea") as Area2D
	assertions.assert_true(detection_area != null, "%s Banshee should have a PlayerDetectionArea." % label)
	if detection_area == null:
		return
	assertions.assert_true(detection_area.body_entered.is_connected(banshee._on_player_detection_body_entered), "%s Banshee detection should be wired to the actor." % label)


func trigger_banshee_detection(banshee: Node, player: Node2D, parent: Node):
	parent.add_child(player)
	var detection_area := banshee.get_node_or_null("PlayerDetectionArea") as Area2D
	if detection_area != null:
		detection_area.body_entered.emit(player)


func with_banshee_saved_defeated_state(raw_states: Variant, target_path: String, saved_dead: bool, saved_health: int) -> Array:
	var states: Array = []
	if raw_states is Array:
		states = (raw_states as Array).duplicate(true)

	var found := false
	for index in range(states.size()):
		if not (states[index] is Dictionary):
			continue

		var state: Dictionary = states[index]
		if str(state.get("node_path", "")) != target_path:
			continue

		state["dead"] = saved_dead
		state["health"] = saved_health
		state["revealed"] = true
		states[index] = state
		found = true
		break

	if not found:
		states.append({
			"node_path": target_path,
			"dead": saved_dead,
			"health": saved_health,
			"revealed": true,
		})

	return states


func assert_defeated_waiting_state(assertions: TestAssertions, banshee: Node, label: String):
	assertions.assert_true(banshee != null, "%s Banshee should exist." % label)
	if banshee == null:
		return

	var health_node: Node = banshee.get_node_or_null("Health")
	var health_bar_display: CanvasItem = banshee.get_node_or_null("HealthBarDisplay") as CanvasItem
	assertions.assert_true(bool(banshee.get("dead")), "%s Banshee should be marked dead while waiting to respawn." % label)
	assertions.assert_false(banshee.visible, "%s Banshee should be hidden while waiting to respawn." % label)
	assertions.assert_false(banshee.is_physics_processing(), "%s Banshee physics should be stopped while waiting to respawn." % label)
	assertions.assert_false(bool(banshee.get("combat_enabled")), "%s Banshee combat should be disabled while waiting to respawn." % label)
	if health_node != null:
		assertions.assert_true(bool(health_node.get("dead")), "%s Banshee health should be dead while waiting to respawn." % label)
		assertions.assert_eq(int(health_node.get("health")), 0, "%s Banshee health should be zero while waiting to respawn." % label)
	if health_bar_display != null:
		assertions.assert_false(health_bar_display.visible, "%s Banshee health bar should be hidden while waiting to respawn." % label)


func assert_respawned_state(assertions: TestAssertions, banshee: Node, label: String):
	assertions.assert_true(banshee != null, "%s Banshee should still exist after respawn." % label)
	if banshee == null:
		return

	var health_node: Node = banshee.get_node_or_null("Health")
	var health_bar_display: CanvasItem = banshee.get_node_or_null("HealthBarDisplay") as CanvasItem
	assertions.assert_false(bool(banshee.get("dead")), "%s Banshee should be alive after respawn." % label)
	assertions.assert_true(banshee.visible, "%s Banshee should be visible after respawn." % label)
	assertions.assert_true(banshee.is_physics_processing(), "%s Banshee physics should run after respawn." % label)
	assertions.assert_true(bool(banshee.get("combat_enabled")), "%s Banshee combat should be enabled after respawn." % label)
	assertions.assert_true(float(banshee.get("modulate").a) < 1.0, "%s Banshee should respawn with hidden story alpha." % label)
	if health_node != null:
		assertions.assert_false(bool(health_node.get("dead")), "%s Banshee health should be alive after respawn." % label)
		assertions.assert_eq(int(health_node.get("health")), int(health_node.get("max_health")), "%s Banshee should respawn at full health." % label)
	if health_bar_display != null:
		assertions.assert_false(health_bar_display.visible, "%s Banshee health bar should stay hidden at full health." % label)


func set_banshee_world_rules(save_manager: Node, enabled: bool):
	if save_manager == null or not save_manager.has_method("set_banshee_world_rule"):
		return

	save_manager.call("set_banshee_world_rule", "banshees_hostile_enabled", enabled)
	save_manager.call("set_banshee_world_rule", "player_can_damage_banshees", enabled)
	save_manager.call("set_banshee_world_rule", "wolf_permanent_clear_enabled", false)
	save_manager.call("set_banshee_world_rule", "bishop_defeated", false)


func has_exported_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false

	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name and (int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0:
			return true

	return false
