extends RefCounted


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	await assert_title_screen_autosave_label(assertions, tree, save_manager)
	await assert_pause_menu_autosave_label(assertions, tree, save_manager)
	await assert_title_dev_travel_dropdowns(assertions, tree, save_manager)
	await assert_pause_dev_travel_dropdowns(assertions, tree, save_manager)
	await assert_shared_gauge_authoring(assertions, tree)


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


func assert_title_dev_travel_dropdowns(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var title_scene: PackedScene = load("res://scenes/ui/TitleScreen.tscn")
	assertions.assert_true(title_scene != null, "Title screen should load for dev travel dropdown test.")
	if title_scene == null:
		return

	var title_screen: Node = title_scene.instantiate()
	var authored_options := title_screen.get_node_or_null("Control/Panel/RightContent/ViewContainer/DevMenuView/GeneratedDevOptions") as VBoxContainer
	assertions.assert_true(authored_options != null, "Title dev menu options container should be authored in the scene.")
	if authored_options != null:
		assert_authored_title_dev_preview(assertions, authored_options)
	tree.root.add_child(title_screen)
	await tree.process_frame
	var generated_options := title_screen.get_node_or_null("Control/Panel/RightContent/ViewContainer/DevMenuView/GeneratedDevOptions") as VBoxContainer
	assertions.assert_true(generated_options != null, "Title dev menu should generate dropdown options.")
	if generated_options != null:
		var runtime_template_option := generated_options.get_node_or_null("PreviewLevelOption") as Control
		assertions.assert_true(runtime_template_option != null, "Title dev menu should keep the authored option template at runtime.")
		if runtime_template_option != null:
			assertions.assert_true(not runtime_template_option.visible, "Title dev menu template option should be hidden at runtime.")
		assert_title_dev_dropdown_rows(assertions, generated_options, save_manager, authored_options)
		if title_screen.has_method("build_dev_menu_from_registry"):
			title_screen.call("build_dev_menu_from_registry")
		await tree.process_frame
		assertions.assert_eq(count_generated_title_options(generated_options), save_manager.call("get_title_dev_level_entries").size(), "Title dev menu rebuild should not duplicate generated rows.")
	title_screen.queue_free()
	await tree.process_frame


func assert_pause_dev_travel_dropdowns(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var pause_scene: PackedScene = load("res://scenes/ui/PauseMenu.tscn")
	assertions.assert_true(pause_scene != null, "Pause menu should load for dev travel dropdown test.")
	if pause_scene == null:
		return

	var pause_menu: Node = pause_scene.instantiate()
	var pre_ready_dev_option := pause_menu.get_node_or_null("Overlay/Panel/MenuView/DevTravelOption")
	assertions.assert_true(pre_ready_dev_option != null, "Pause menu should author DevTravelOption in MenuView for editor layout.")
	if pre_ready_dev_option != null:
		assertions.assert_true(pre_ready_dev_option.get_node_or_null("Button") is Button, "Pause authored DevTravelOption should expose a Button.")
	var pre_ready_authored_view := pause_menu.get_node_or_null("Overlay/Panel/DevTravelView")
	var pre_ready_options: VBoxContainer = null
	assertions.assert_true(pre_ready_authored_view != null, "Pause dev travel view should be authored in the scene for editor layout.")
	if pre_ready_authored_view != null:
		pre_ready_options = pre_ready_authored_view.get_node_or_null("ScrollContainer/DevTravelOptions") as VBoxContainer
		assertions.assert_true(pre_ready_options != null, "Pause dev travel view should expose generated options container.")
		if pre_ready_options != null:
			assert_authored_pause_dev_preview(assertions, pre_ready_options)
		var pre_ready_status := pre_ready_authored_view.get_node_or_null("DevTravelStatusLabel") as Label
		assertions.assert_true(pre_ready_status != null, "Pause dev travel view should expose a status label.")
		if pre_ready_status != null:
			assertions.assert_eq(pre_ready_status.text, "Status text", "Pause dev travel status label should have editor placeholder text.")
		assertions.assert_true(pre_ready_authored_view.get_node_or_null("BackButton") != null, "Pause dev travel view should expose a back button.")
	tree.root.add_child(pause_menu)
	await tree.process_frame
	var authored_view := pause_menu.get_node_or_null("Overlay/Panel/DevTravelView")
	assertions.assert_true(authored_view != null, "Pause dev travel view should be authored in the scene for editor layout.")
	if authored_view != null:
		assertions.assert_true(authored_view.get_node_or_null("ScrollContainer/DevTravelOptions") != null, "Pause dev travel view should expose generated options container.")
		assertions.assert_true(authored_view.get_node_or_null("DevTravelStatusLabel") != null, "Pause dev travel view should expose a status label.")
		assertions.assert_true(authored_view.get_node_or_null("BackButton") != null, "Pause dev travel view should expose a back button.")
		var runtime_status := authored_view.get_node_or_null("DevTravelStatusLabel") as Label
		if runtime_status != null:
			assertions.assert_eq(runtime_status.text, "", "Pause dev travel status placeholder should be cleared at runtime.")
	if pause_menu.has_method("open_dev_travel"):
		pause_menu.call("open_dev_travel")
	await tree.process_frame
	var panel := pause_menu.get_node_or_null("Overlay/Panel")
	if panel != null:
		assertions.assert_eq(count_named_children(panel, "DevTravelView"), 1, "Pause menu should not create a duplicate DevTravelView at runtime.")
	var menu_view := pause_menu.get_node_or_null("Overlay/Panel/MenuView")
	if menu_view != null:
		assertions.assert_eq(count_named_children(menu_view, "DevTravelOption"), 1, "Pause menu should not create a duplicate DevTravelOption at runtime.")
	var dev_options := pause_menu.get("dev_travel_options") as VBoxContainer
	assertions.assert_true(dev_options != null, "Pause dev travel should generate dropdown options.")
	if dev_options != null:
		var runtime_template_option := dev_options.get_node_or_null("PreviewLevelOption") as Control
		assertions.assert_true(runtime_template_option != null, "Pause dev travel should keep the authored option template at runtime.")
		if runtime_template_option != null:
			assertions.assert_true(not runtime_template_option.visible, "Pause dev travel template option should be hidden at runtime.")
		assert_pause_dev_dropdown_rows(assertions, dev_options, save_manager, pre_ready_options)
		if pause_menu.has_method("open_dev_travel"):
			pause_menu.call("open_dev_travel")
		await tree.process_frame
		assertions.assert_eq(count_generated_pause_options(dev_options), save_manager.call("get_title_dev_level_entries").size(), "Pause dev travel rebuild should not duplicate generated rows.")
	pause_menu.queue_free()
	await tree.process_frame


func assert_title_dev_dropdown_rows(assertions: TestAssertions, container: VBoxContainer, save_manager: Node, template_container: VBoxContainer):
	assertions.assert_true(template_container != null, "Title dev menu should have an authored template container for generated row comparison.")
	if template_container == null:
		return

	var entries: Array = save_manager.call("get_title_dev_level_entries")
	var template_option := template_container.get_node_or_null("PreviewLevelOption") as Control
	var template_label: Label = null
	var template_dropdown: OptionButton = null
	var template_button: Button = null
	if template_option != null:
		template_label = template_option.get_node_or_null("LevelLabel") as Label
		template_dropdown = template_option.get_node_or_null("PresetDropdown") as OptionButton
		template_button = template_option.get_node_or_null("StartButton") as Button
	var generated_count := 0
	var saw_disabled_bishop := false
	for child in container.get_children():
		if not (child is Control) or not bool(child.get_meta("dev_generated", false)):
			continue
		var option := child as Control
		var label_node := option.get_node_or_null("LevelLabel") as Label
		var dropdown := option.get_node_or_null("PresetDropdown") as OptionButton
		var button := option.get_node_or_null("StartButton") as Button
		assertions.assert_true(label_node != null, "Title dev travel generated option should include LevelLabel.")
		assertions.assert_true(dropdown != null, "Title dev travel generated option should include PresetDropdown.")
		assertions.assert_true(button != null, "Title dev travel generated option should include StartButton.")
		if template_option != null:
			assertions.assert_eq(option.custom_minimum_size, template_option.custom_minimum_size, "Title dev travel generated option should preserve authored block size.")
		if label_node != null and template_label != null:
			assertions.assert_eq(label_node.offset_left, template_label.offset_left, "Title dev travel label should preserve authored left offset.")
			assertions.assert_eq(label_node.offset_right, template_label.offset_right, "Title dev travel label should preserve authored right offset.")
		if dropdown != null and template_dropdown != null:
			assertions.assert_eq(dropdown.custom_minimum_size, template_dropdown.custom_minimum_size, "Title dev travel dropdown should preserve the authored template size.")
			assertions.assert_eq(dropdown.offset_left, template_dropdown.offset_left, "Title dev travel dropdown should preserve authored left offset.")
			assertions.assert_eq(dropdown.offset_right, template_dropdown.offset_right, "Title dev travel dropdown should preserve authored right offset.")
		if button != null and template_button != null:
			assertions.assert_eq(button.custom_minimum_size, template_button.custom_minimum_size, "Title dev travel button should preserve the authored template size.")
			assertions.assert_eq(button.offset_left, template_button.offset_left, "Title dev travel button should preserve authored left offset.")
			assertions.assert_eq(button.offset_right, template_button.offset_right, "Title dev travel button should preserve authored right offset.")
		if dropdown == null:
			continue
		generated_count += 1
		for index in range(dropdown.item_count):
			if str(dropdown.get_item_metadata(index)) == "bishop_defeated":
				saw_disabled_bishop = saw_disabled_bishop or dropdown.is_item_disabled(index)
	assertions.assert_eq(generated_count, entries.size(), "Title dev travel should create one fixed option block per registered level.")
	assertions.assert_true(saw_disabled_bishop, "Title dev travel should show Bishop defeated as a disabled placeholder option.")


func assert_pause_dev_dropdown_rows(assertions: TestAssertions, container: VBoxContainer, save_manager: Node, template_container: VBoxContainer):
	assertions.assert_true(template_container != null, "Pause dev travel should have an authored template container for generated row comparison.")
	if template_container == null:
		return

	var entries: Array = save_manager.call("get_title_dev_level_entries")
	var template_option := template_container.get_node_or_null("PreviewLevelOption") as Control
	var template_label: Label = null
	var template_dropdown: OptionButton = null
	var template_button: Button = null
	if template_option != null:
		template_label = template_option.get_node_or_null("LevelLabel") as Label
		template_dropdown = template_option.get_node_or_null("PresetDropdown") as OptionButton
		template_button = template_option.get_node_or_null("TravelButton") as Button
	var generated_count := 0
	var saw_disabled_bishop := false
	for child in container.get_children():
		if not (child is Control) or not bool(child.get_meta("dev_generated", false)):
			continue
		var option := child as Control
		var label_node := option.get_node_or_null("LevelLabel") as Label
		var dropdown := option.get_node_or_null("PresetDropdown") as OptionButton
		var button := option.get_node_or_null("TravelButton") as Button
		assertions.assert_true(label_node != null, "Pause dev travel generated option should include LevelLabel.")
		assertions.assert_true(dropdown != null, "Pause dev travel generated option should include PresetDropdown.")
		assertions.assert_true(button != null, "Pause dev travel generated option should include TravelButton.")
		if template_option != null:
			assertions.assert_eq(option.custom_minimum_size, template_option.custom_minimum_size, "Pause dev travel generated option should preserve authored block size.")
		if label_node != null and template_label != null:
			assertions.assert_eq(label_node.offset_left, template_label.offset_left, "Pause dev travel label should preserve authored left offset.")
			assertions.assert_eq(label_node.offset_right, template_label.offset_right, "Pause dev travel label should preserve authored right offset.")
		if dropdown != null and template_dropdown != null:
			assertions.assert_eq(dropdown.custom_minimum_size, template_dropdown.custom_minimum_size, "Pause dev travel dropdown should preserve authored template size.")
			assertions.assert_eq(dropdown.offset_left, template_dropdown.offset_left, "Pause dev travel dropdown should preserve authored left offset.")
			assertions.assert_eq(dropdown.offset_right, template_dropdown.offset_right, "Pause dev travel dropdown should preserve authored right offset.")
		if button != null and template_button != null:
			assertions.assert_eq(button.custom_minimum_size, template_button.custom_minimum_size, "Pause dev travel button should preserve authored template size.")
			assertions.assert_eq(button.offset_left, template_button.offset_left, "Pause dev travel button should preserve authored left offset.")
			assertions.assert_eq(button.offset_right, template_button.offset_right, "Pause dev travel button should preserve authored right offset.")
		if dropdown == null:
			continue
		generated_count += 1
		for index in range(dropdown.item_count):
			if str(dropdown.get_item_metadata(index)) == "bishop_defeated":
				saw_disabled_bishop = saw_disabled_bishop or dropdown.is_item_disabled(index)
	assertions.assert_eq(generated_count, entries.size(), "Pause dev travel should create one fixed option block per registered level.")
	assertions.assert_true(saw_disabled_bishop, "Pause dev travel should show Bishop defeated as a disabled placeholder option.")


func assert_shared_gauge_authoring(assertions: TestAssertions, tree: SceneTree):
	var gauge_stack_scene: PackedScene = load("res://scenes/ui/PlayerGaugeStack.tscn")
	assertions.assert_true(gauge_stack_scene != null, "Shared player gauge stack scene should load.")
	var preview_settings: Resource = load("res://resources/ui/player_gauge_preview_settings.tres")
	assertions.assert_true(preview_settings != null, "Shared player gauge preview settings should load.")
	var player_tuning: Resource = load("res://resources/characters/saorise/player_tuning.tres")
	assertions.assert_true(player_tuning != null, "Shared Saorise player tuning should load.")

	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	assertions.assert_true(hud_scene != null, "HUD scene should load for shared gauge contract test.")
	if hud_scene != null:
		var hud := hud_scene.instantiate()
		tree.root.add_child(hud)
		await tree.process_frame
		var health_ui := hud.get_node_or_null("HealthUI")
		assertions.assert_true(health_ui != null, "HUD should contain HealthUI.")
		if health_ui != null:
			assert_gauge_stack_contract(assertions, health_ui.get_node_or_null("PlayerGaugeStack"), "HUD")
			assertions.assert_true(health_ui.get("gauge_preview_settings") == preview_settings, "HUD should use the shared gauge preview settings resource.")
			assertions.assert_true(health_ui.get("player_tuning") == player_tuning, "HUD health display should use the real Saorise player tuning resource.")
			assert_stock_layout_contract(assertions, health_ui)
			assert_health_preview_matches_runtime_health_model(assertions, health_ui)
		hud.queue_free()
		await tree.process_frame

	var saorise_scene: PackedScene = load("res://scenes/characters/saorise/Saorise.tscn")
	assertions.assert_true(saorise_scene != null, "Saorise scene should load for shared gauge contract test.")
	if saorise_scene != null:
		var saorise := saorise_scene.instantiate()
		tree.root.add_child(saorise)
		await tree.process_frame
		var stamina_root := saorise.get_node_or_null("Stamina")
		assertions.assert_true(stamina_root != null, "Saorise should contain authored Stamina gauge root.")
		if stamina_root != null:
			assert_gauge_stack_contract(assertions, stamina_root.get_node_or_null("PlayerGaugeStack"), "Saorise")
			assertions.assert_true(stamina_root.get("gauge_preview_settings") == preview_settings, "Saorise under-player gauges should use the shared gauge preview settings resource.")
			assertions.assert_true(stamina_root.get_node_or_null("StaminaBar") == null, "Saorise should not keep the old runtime row template StaminaBar node.")
			assertions.assert_true(stamina_root.get_node_or_null("StaminaBarBorder") == null, "Saorise should not keep the old runtime row template StaminaBarBorder node.")
		var health_node := saorise.get_node_or_null("Health")
		assertions.assert_true(health_node != null, "Saorise should contain Health.")
		if health_node != null:
			assertions.assert_true(health_node.get("tuning") == player_tuning, "Saorise Health should use the same player tuning resource as the HUD health display.")
		saorise.queue_free()
		await tree.process_frame

	var player_gauge_script := FileAccess.get_file_as_string("res://scripts/ui/PlayerStaminaBar.gd")
	assertions.assert_false(player_gauge_script.contains("Node2D.new("), "PlayerStaminaBar should not create gauge row Node2D shells at runtime.")
	assertions.assert_false(player_gauge_script.contains("TextureProgressBar.new("), "PlayerStaminaBar should not create gauge bars at runtime.")
	assertions.assert_false(player_gauge_script.contains("TextureRect.new("), "PlayerStaminaBar should not create gauge borders at runtime.")


func assert_gauge_stack_contract(assertions: TestAssertions, stack: Node, label: String):
	assertions.assert_true(stack != null, "%s should instance PlayerGaugeStack." % label)
	if stack == null:
		return
	for gauge_name in ["StaminaGauge", "TransformationGauge"]:
		var gauge := stack.get_node_or_null(gauge_name)
		assertions.assert_true(gauge != null, "%s PlayerGaugeStack should include %s." % [label, gauge_name])
		if gauge != null:
			assertions.assert_true(gauge.get_node_or_null("Bar") is TextureProgressBar, "%s %s should include authored Bar." % [label, gauge_name])
			assertions.assert_true(gauge.get_node_or_null("Border") is TextureRect, "%s %s should include authored Border." % [label, gauge_name])


func assert_stock_layout_contract(assertions: TestAssertions, health_ui: Node):
	var cluster := health_ui.get_node_or_null("StockIconCluster")
	assertions.assert_true(cluster != null, "HUD stock cluster should be authored.")
	if cluster == null:
		return
	for index in range(1, 7):
		assertions.assert_true(cluster.get_node_or_null("Stock%d" % index) is TextureRect, "HUD should author Stock%d." % index)
	var layouts := cluster.get_node_or_null("StockLayouts")
	assertions.assert_true(layouts != null, "HUD stock cluster should expose editable StockLayouts.")
	if layouts == null:
		return
	for count in range(3, 7):
		var layout := layouts.get_node_or_null("Stocks%d" % count)
		assertions.assert_true(layout != null, "HUD stock cluster should author Stocks%d layout markers." % count)
		if layout == null:
			continue
		for stock_index in range(1, count + 1):
			assertions.assert_true(layout.get_node_or_null("Stock%d" % stock_index) is Marker2D, "Stocks%d should include editable Stock%d marker." % [count, stock_index])


func assert_health_preview_matches_runtime_health_model(assertions: TestAssertions, health_ui: Node):
	var health_bar := health_ui.get_node_or_null("HealthBar") as TextureProgressBar
	assertions.assert_true(health_bar != null, "HUD health preview should expose HealthBar.")
	if health_bar == null:
		return

	var test_tuning := PlayerTuning.new()
	test_tuning.max_health = 100
	test_tuning.hits_to_die = 4
	health_ui.set("player_tuning", test_tuning)
	health_ui.set("display_hits_taken", 2)
	health_ui.call("setup_editor_preview")
	assertions.assert_eq(int(health_bar.min_value), 0, "Health preview should start at zero health.")
	assertions.assert_eq(int(health_bar.max_value), 100, "Health display should use max health from real player tuning.")
	assertions.assert_eq(int(health_bar.step), 25, "Health preview step should match damage per hit.")
	assertions.assert_eq(int(health_bar.value), 50, "Health preview should show health after authored display hits taken.")

	test_tuning.max_health = 101
	test_tuning.hits_to_die = 4
	health_ui.set("display_hits_taken", 1)
	health_ui.call("setup_editor_preview")
	assertions.assert_eq(int(health_bar.step), 26, "Health preview should ceil uneven hit damage like runtime health.")
	assertions.assert_eq(int(health_bar.value), 75, "Health preview should subtract ceiled hit damage from max health.")

	health_ui.set("preview_max_stocks", 6)
	health_ui.set("preview_current_stocks", 5)
	health_ui.set("preview_lost_life_faded", false)
	health_ui.call("setup_editor_preview")
	var visible_stocks_before := count_visible_stock_icons(health_ui)
	health_ui.set("display_hits_taken", 3)
	health_ui.call("setup_editor_preview")
	assertions.assert_eq(count_visible_stock_icons(health_ui), visible_stocks_before, "Health preview changes should not alter stock preview counts.")


func count_visible_stock_icons(health_ui: Node) -> int:
	var visible_count := 0
	var cluster := health_ui.get_node_or_null("StockIconCluster")
	if cluster == null:
		return visible_count
	for index in range(1, 7):
		var icon := cluster.get_node_or_null("Stock%d" % index) as CanvasItem
		if icon != null and icon.visible:
			visible_count += 1
	return visible_count


func find_child_of_type(root: Node, type_name: String) -> Node:
	for child in root.get_children():
		if child.get_class() == type_name:
			return child
	return null


func assert_authored_title_dev_preview(assertions: TestAssertions, container: VBoxContainer):
	var preview_option := container.get_node_or_null("PreviewLevelOption") as Control
	assertions.assert_true(preview_option != null, "Title dev travel should have an editor-visible fixed option template.")
	if preview_option == null:
		return
	assertions.assert_true(preview_option.custom_minimum_size.x > 0.0, "Title dev travel option template should have authored width.")
	assertions.assert_true(preview_option.custom_minimum_size.y > 0.0, "Title dev travel option template should have authored height.")
	var label_node := preview_option.get_node_or_null("LevelLabel") as Label
	var dropdown := preview_option.get_node_or_null("PresetDropdown") as OptionButton
	var button := preview_option.get_node_or_null("StartButton") as Button
	assertions.assert_true(label_node != null, "Title fixed option template should include LevelLabel.")
	assertions.assert_true(dropdown != null, "Title fixed option template should include PresetDropdown.")
	assertions.assert_true(button != null, "Title fixed option template should include StartButton.")
	if label_node != null:
		assertions.assert_true(label_node.text != "", "Title fixed option label should not be blank in the editor.")
	if button != null:
		assertions.assert_true(button.text != "", "Title fixed option button should not be blank in the editor.")


func assert_authored_pause_dev_preview(assertions: TestAssertions, container: VBoxContainer):
	var preview_option := container.get_node_or_null("PreviewLevelOption") as Control
	assertions.assert_true(preview_option != null, "Pause dev travel should have an editor-visible fixed option template.")
	if preview_option == null:
		return
	assertions.assert_true(preview_option.custom_minimum_size.x > 0.0, "Pause dev travel option template should have authored width.")
	assertions.assert_true(preview_option.custom_minimum_size.y > 0.0, "Pause dev travel option template should have authored height.")
	var label_node := preview_option.get_node_or_null("LevelLabel") as Label
	var dropdown := preview_option.get_node_or_null("PresetDropdown") as OptionButton
	var button := preview_option.get_node_or_null("TravelButton") as Button
	assertions.assert_true(label_node != null, "Pause fixed option template should include LevelLabel.")
	assertions.assert_true(dropdown != null, "Pause fixed option template should include PresetDropdown.")
	assertions.assert_true(button != null, "Pause fixed option template should include TravelButton.")
	if label_node != null:
		assertions.assert_true(label_node.text != "", "Pause fixed option label should not be blank in the editor.")
	if button != null:
		assertions.assert_true(button.text != "", "Pause fixed option button should not be blank in the editor.")


func count_named_children(root: Node, child_name: String) -> int:
	var count := 0
	for child in root.get_children():
		if child.name == child_name:
			count += 1
	return count


func count_generated_rows(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is HBoxContainer and bool(child.get_meta("dev_generated", false)):
			count += 1
	return count


func count_generated_title_options(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is Control and bool(child.get_meta("dev_generated", false)):
			count += 1
	return count


func count_generated_pause_options(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is Control and bool(child.get_meta("dev_generated", false)):
			count += 1
	return count
