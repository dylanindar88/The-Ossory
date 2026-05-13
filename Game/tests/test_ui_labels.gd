extends RefCounted


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	await assert_title_screen_autosave_label(assertions, tree, save_manager)
	await assert_pause_menu_autosave_label(assertions, tree, save_manager)


func assert_title_screen_autosave_label(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var title_scene: PackedScene = load("res://scenes/ui/TitleScreen.tscn")
	assertions.assert_true(title_scene != null, "Title screen should load for UI label test.")
	if title_scene == null:
		return

	var title_screen: Node = title_scene.instantiate()
	tree.root.add_child(title_screen)
	await tree.process_frame
	var label_text: String = title_screen.call("get_load_slot_label_text", save_manager.AUTOSAVE_SLOT, {}, false)
	assertions.assert_eq(label_text, "Autosave (AUTO)", "Title screen should label autosave slot explicitly.")
	title_screen.queue_free()
	await tree.process_frame


func assert_pause_menu_autosave_label(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var pause_scene: PackedScene = load("res://scenes/ui/PauseMenu.tscn")
	assertions.assert_true(pause_scene != null, "Pause menu should load for UI label test.")
	if pause_scene == null:
		return

	var pause_menu: Node = pause_scene.instantiate()
	tree.root.add_child(pause_menu)
	await tree.process_frame
	var label_text: String = pause_menu.call("get_save_slot_label_text", save_manager.AUTOSAVE_SLOT, {}, false, true)
	assertions.assert_eq(label_text, "Autosave (AUTO)", "Pause menu should label autosave slot explicitly.")
	pause_menu.queue_free()
	await tree.process_frame
