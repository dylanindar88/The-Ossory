extends RefCounted


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	for raw_level_path in save_manager.LEVEL_DISPLAY_REGISTRY.keys():
		await assert_level_contract(assertions, tree, save_manager, str(raw_level_path))


func assert_level_contract(assertions: TestAssertions, tree: SceneTree, save_manager: Node, level_path: String):
	var packed: PackedScene = load(level_path)
	assertions.assert_true(packed != null, "Registered level should load: %s" % level_path)
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	var provider: Node = save_manager.call("get_level_state_provider", level)
	assertions.assert_true(provider != null, "Level should expose a level-state provider: %s" % level_path)
	if provider != null:
		assertions.assert_true(provider.has_method("collect_level_state"), "Provider should collect level state: %s" % level_path)
		assertions.assert_true(provider.has_method("apply_level_state"), "Provider should apply level state: %s" % level_path)
		assertions.assert_true(provider.has_method("validate_level_state"), "Provider should validate level state: %s" % level_path)
		assertions.assert_true(provider.has_method("uses_level_owned_hostile_state"), "Provider should declare hostile ownership: %s" % level_path)
		assertions.assert_true(provider.has_method("uses_level_owned_non_hostile_npc_state"), "Provider should declare non-hostile NPC ownership: %s" % level_path)

	var state: Dictionary = save_manager.call("collect_level_state", level)
	assertions.assert_true(state is Dictionary, "Collected level state should be a dictionary: %s" % level_path)
	if provider != null and provider.has_method("validate_level_state"):
		var raw_messages: Variant = provider.call("validate_level_state", state)
		assertions.assert_true(raw_messages is Array, "Validation should return an array: %s" % level_path)
		if raw_messages is Array:
			assertions.assert_eq((raw_messages as Array).size(), 0, "Collected level state should validate cleanly: %s" % level_path)

	save_manager.call("apply_level_state", level, state)
	await tree.process_frame
	var state_after_apply: Dictionary = save_manager.call("collect_level_state", level)
	assertions.assert_true(state_after_apply is Dictionary, "Level should collect after apply: %s" % level_path)

	level.queue_free()
	save_manager.call("set_current_level", null)
	await tree.process_frame
