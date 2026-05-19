extends RefCounted


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	await assert_save_schema(assertions, tree, save_manager)
	await assert_exit_autosave_is_noop(assertions, tree, save_manager)
	await assert_combat_blocks_all_saves(assertions, tree, save_manager)
	await assert_full_death_uses_autosave_checkpoint(assertions, tree, save_manager)
	await assert_scene_transition_gate_lifecycle(assertions, tree, save_manager)
	assert_v1_save_rejected(assertions, save_manager)


func assert_save_schema(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var level_path: String = save_manager.STARTING_WILDERNESS_SCENE
	var packed: PackedScene = load(level_path)
	assertions.assert_true(packed != null, "Starting Wilderness should load for save schema test.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	var data: Dictionary = save_manager.call("build_save_data", "test", level, 1)
	assertions.assert_eq(int(data.get("version", 0)), save_manager.SAVE_VERSION, "Save data should use current schema version.")
	assertions.assert_eq(save_manager.SAVE_VERSION, 2, "Current schema version should be 2.")
	assertions.assert_has_key(data, "level_states_by_path", "Save data should contain canonical level state store.")
	assertions.assert_has_key(data, "defeated_hostiles", "Save data should contain generic hostile state.")
	assertions.assert_has_key(data, "non_hostile_npcs", "Save data should contain generic non-hostile NPC state.")
	assertions.assert_not_has_key(data, "level_state", "Save data should not contain legacy top-level level_state.")
	var old_defeated_key := "defeated_" + "banshees"
	var old_npc_key := "villa" + "gers"
	assertions.assert_not_has_key(data, old_defeated_key, "Save data should not contain old defeated banshee key.")
	assertions.assert_not_has_key(data, old_npc_key, "Save data should not contain old generic NPC key.")

	var states_by_path: Variant = data.get("level_states_by_path", {})
	assertions.assert_true(states_by_path is Dictionary, "level_states_by_path should be a dictionary.")
	if states_by_path is Dictionary:
		assertions.assert_has_key(states_by_path, level_path, "level_states_by_path should contain current level path.")

	level.queue_free()
	save_manager.call("set_current_level", null)
	await tree.process_frame


func assert_exit_autosave_is_noop(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	save_manager.call("delete_save", save_manager.AUTOSAVE_SLOT)
	assertions.assert_false(bool(save_manager.call("autosave_level_exiting", null)), "Level-exit autosave should be disabled and return false.")
	assertions.assert_false(bool(save_manager.call("save_exists", save_manager.AUTOSAVE_SLOT)), "Level-exit autosave should not create the autosave checkpoint.")

	var packed: PackedScene = load(save_manager.STARTING_WILDERNESS_SCENE)
	assertions.assert_true(packed != null, "Starting Wilderness should load for exit autosave no-op checks.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	assertions.assert_true(bool(save_manager.call("autosave_level_entered", level)), "Level-entry autosave should still write the checkpoint.")
	var entry_data: Dictionary = save_manager.call("load_game", save_manager.AUTOSAVE_SLOT)
	assertions.assert_eq(str(entry_data.get("reason", "")), "level_enter", "Level-entry autosave should write an intentional checkpoint reason.")

	assertions.assert_false(bool(save_manager.call("autosave_level_exiting", level)), "Level-exit autosave should remain a no-op even after a level-entry checkpoint exists.")
	var after_exit_data: Dictionary = save_manager.call("load_game", save_manager.AUTOSAVE_SLOT)
	assertions.assert_eq(str(after_exit_data.get("reason", "")), "level_enter", "Level-exit autosave should not overwrite the level-entry checkpoint.")

	level.queue_free()
	save_manager.call("set_current_level", null)
	await tree.process_frame


func assert_v1_save_rejected(assertions: TestAssertions, save_manager: Node):
	var v1_data := {
		"version": 1,
		"slot": 1,
		"level_path": save_manager.STARTING_WILDERNESS_SCENE,
	}
	var path: String = save_manager.call("get_save_path", 1)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assertions.assert_true(file != null, "Should open isolated v1 save file for writing.")
	if file == null:
		return
	file.store_string(JSON.stringify(v1_data))
	file = null

	var loaded: Dictionary = save_manager.call("load_game", 1)
	assertions.assert_true(loaded.is_empty(), "v1 save should be rejected.")
	assertions.assert_true(str(save_manager.get("last_error")).contains("unsupported version"), "v1 rejection should explain unsupported version.")
	save_manager.call("delete_save", 1)


func assert_combat_blocks_all_saves(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var combat_manager: Node = tree.root.get_node_or_null("/root/CombatStateManager")
	assertions.assert_true(combat_manager != null, "CombatStateManager should be available for combat save blocking.")
	if combat_manager == null:
		return

	combat_manager.call("clear_all")
	save_manager.call("delete_save", 1)
	save_manager.call("delete_save", save_manager.AUTOSAVE_SLOT)

	var knight_scene: PackedScene = load("res://scenes/characters/hostile_npcs/knights/BasicKnightMelee.tscn")
	var knight: Node = knight_scene.instantiate()
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	tree.root.add_child(player)
	tree.root.add_child(knight)
	await tree.process_frame

	knight.call("force_aggro", player)
	await tree.process_frame
	assertions.assert_true(bool(combat_manager.call("is_in_combat")), "Knight aggro should mark the player as in combat.")
	assertions.assert_false(bool(save_manager.call("save_game", "combat_autosave_test", null)), "Autosave should be blocked while a knight is aggroed.")
	assertions.assert_false(bool(save_manager.call("save_game_to_slot", 1, "combat_manual_test", null)), "Manual saves should be blocked while a knight is aggroed.")
	assertions.assert_eq(str(save_manager.get("last_error")), "Cannot save during combat", "Manual save failure should explain combat save blocking.")

	knight.call("return_to_camp")
	await tree.process_frame
	assertions.assert_false(bool(combat_manager.call("is_in_combat")), "Combat should clear when the knight stops engaging.")

	knight.queue_free()
	player.queue_free()
	combat_manager.call("clear_all")
	await tree.process_frame


func assert_full_death_uses_autosave_checkpoint(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	save_manager.call("delete_save", 1)
	save_manager.call("delete_save", save_manager.AUTOSAVE_SLOT)
	var combat_manager: Node = tree.root.get_node_or_null("/root/CombatStateManager")
	if combat_manager != null:
		combat_manager.call("clear_all")

	var packed: PackedScene = load(save_manager.STARTING_WILDERNESS_SCENE)
	assertions.assert_true(packed != null, "Starting Wilderness should load for full-death checkpoint test.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	var player: Node2D = tree.get_first_node_in_group("player") as Node2D
	assertions.assert_true(player != null, "Starting Wilderness should provide a player for checkpoint restore.")
	if player == null:
		level.queue_free()
		save_manager.call("set_current_level", null)
		await tree.process_frame
		return

	var checkpoint_position := Vector2(123.0, 456.0)
	var manual_position := Vector2(777.0, 888.0)
	player.global_position = checkpoint_position
	var health_node: Node = player.get_node_or_null("Health")
	assertions.assert_true(health_node != null, "Player should expose Health for checkpoint restore.")
	if health_node != null:
		health_node.set("health", 1)
		health_node.set("stamina", 0.0)
	assertions.assert_true(bool(save_manager.call("save_game", "level_enter", level)), "Autosave checkpoint should be written at level entry.")

	player.global_position = manual_position
	if health_node != null:
		health_node.set("health", int(health_node.get("max_health")))
		health_node.set("stamina", float(health_node.get("max_stamina")))
	assertions.assert_true(bool(save_manager.call("save_game_to_slot", 1, "manual_bad_spot", level)), "Manual save should be allowed outside combat.")

	save_manager.call("set_player_lives_for_dev", 1)
	assertions.assert_true(bool(save_manager.call("spend_life_and_respawn_player_in_place")), "Final stock loss should load the autosave death checkpoint.")
	await tree.process_frame
	await tree.process_frame

	assertions.assert_eq(save_manager.call("get_player_lives"), save_manager.call("get_max_player_lives"), "Death checkpoint restore should refill player stocks.")
	assertions.assert_true(player.global_position.is_equal_approx(checkpoint_position), "Full death should restore the autosave checkpoint, not the newer manual save.")
	if health_node != null:
		assertions.assert_eq(int(health_node.get("health")), int(health_node.get("max_health")), "Death checkpoint restore should refill health.")
		assertions.assert_true(is_equal_approx(float(health_node.get("stamina")), float(health_node.get("max_stamina"))), "Death checkpoint restore should refill stamina.")

	level.queue_free()
	save_manager.call("set_current_level", null)
	await tree.process_frame


func assert_scene_transition_gate_lifecycle(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	save_manager.call("show_scene_transition_gate")
	assertions.assert_true(bool(save_manager.call("is_scene_transition_gate_visible")), "Scene transition gate should become visible before a pending scene restore.")
	var gate := tree.root.get_node_or_null("SceneTransitionGate") as CanvasLayer
	assertions.assert_true(gate != null, "Scene transition gate should be a root CanvasLayer so scene changes cannot remove it.")
	if gate != null:
		assertions.assert_eq(gate.layer, 4096, "Scene transition gate should render above normal level content.")
		var blocker := gate.get_node_or_null("Blocker") as ColorRect
		assertions.assert_true(blocker != null and blocker.visible, "Scene transition gate should include a visible full-screen blocker.")

	save_manager.set("pending_scene_load_slot", 999)
	save_manager.set("pending_scene_load_scene_path", "res://missing_test_scene.tscn")
	save_manager.set("pending_scene_load_entry_marker_path", NodePath(""))
	save_manager.call("apply_pending_scene_load")
	await tree.process_frame
	assertions.assert_true(bool(save_manager.call("is_scene_transition_gate_visible")), "Scene transition gate should stay visible during the first pending-load wait frame.")
	await tree.process_frame
	assertions.assert_true(bool(save_manager.call("is_scene_transition_gate_visible")), "Scene transition gate should stay visible while the pending load is being applied.")
	await tree.process_frame
	await tree.process_frame
	assertions.assert_false(bool(save_manager.call("is_scene_transition_gate_visible")), "Scene transition gate should hide after failed pending load fallback and settle.")
