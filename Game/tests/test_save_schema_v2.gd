extends RefCounted


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	await assert_save_schema(assertions, tree, save_manager)
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
