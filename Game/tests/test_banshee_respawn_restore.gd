extends RefCounted

const STARTING_WILDERNESS_PATH := "res://scenes/levels/StartingWilderness.tscn"
const BANSHEE_VILLAGE_PATH := "res://scenes/levels/BansheeVillage.tscn"
const STARTING_WILDERNESS_BANSHEE_PATH := "PlayableWorld/Environment/Characters/HostileNPCs/Banshees/Banshee2"
const BANSHEE_VILLAGE_BANSHEE_PATH := "PlayableWorld/Environment/Characters/HostileNPCs/Banshee2"
const RESPAWN_DELAY := 0.05
const BANSHEE_TUNING: BansheeTuning = preload("res://resources/characters/hostile_npcs/banshees/banshee_tuning.tres")


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var original_respawn_delay: float = BANSHEE_TUNING.story_respawn_delay_seconds
	BANSHEE_TUNING.story_respawn_delay_seconds = RESPAWN_DELAY
	await assert_starting_wilderness_saved_defeated_restore(assertions, tree, save_manager, true, 0, "dead snapshot")
	await assert_starting_wilderness_saved_defeated_restore(assertions, tree, save_manager, false, 0, "zero-health snapshot")
	await assert_banshee_village_saved_defeated_restore(assertions, tree, save_manager, true, 0, "dead snapshot")
	await assert_banshee_village_saved_defeated_restore(assertions, tree, save_manager, false, 0, "zero-health snapshot")
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
