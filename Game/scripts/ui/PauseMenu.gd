extends CanvasLayer

const TITLE_SCREEN_SCENE := "res://scenes/ui/TitleScreen.tscn"

@onready var overlay: Control = $Overlay
@onready var menu_view: VBoxContainer = $Overlay/Panel/MenuView
@onready var options_view: VBoxContainer = $Overlay/Panel/OptionsView
@onready var save_slots_view: VBoxContainer = $Overlay/Panel/SaveSlotsView
@onready var respawn_view: VBoxContainer = $Overlay/Panel/RespawnView
@onready var resume_button: Button = $Overlay/Panel/MenuView/ResumeOption/Button
@onready var save_button: Button = $Overlay/Panel/MenuView/SaveOption/Button
@onready var options_button: Button = $Overlay/Panel/MenuView/OptionsOption/Button
@onready var authored_dev_travel_option: Control = $Overlay/Panel/MenuView/DevTravelOption
@onready var authored_dev_travel_button: Button = $Overlay/Panel/MenuView/DevTravelOption/Button
@onready var title_screen_button: Button = $Overlay/Panel/MenuView/TitleScreenOption/Button
@onready var exit_button: Button = $Overlay/Panel/MenuView/ExitOption/Button
@onready var save_status_label: Label = $Overlay/Panel/MenuView/SaveStatusLabel
@onready var respawn_button: Button = $Overlay/Panel/RespawnView/RespawnOption/Button
@onready var respawn_title_screen_button: Button = $Overlay/Panel/RespawnView/MainMenuOption/Button
@onready var respawn_exit_button: Button = $Overlay/Panel/RespawnView/ExitOption/Button
@onready var respawn_status_label: Label = $Overlay/Panel/RespawnView/RespawnStatusLabel
@onready var back_button: Button = $Overlay/Panel/OptionsView/BackOption/Button
@onready var save_slots_back_button: Button = $Overlay/Panel/SaveSlotsView/BackOption/Button
@onready var save_slots_status_label: Label = $Overlay/Panel/SaveSlotsView/SaveSlotsStatusLabel
@onready var zoom_slider: HSlider = $Overlay/Panel/OptionsView/ZoomSlider
@onready var hud_gauges_checkbox: CheckBox = $Overlay/Panel/OptionsView/GaugeLocationOptions/HudGaugeOption
@onready var player_gauges_checkbox: CheckBox = $Overlay/Panel/OptionsView/GaugeLocationOptions/PlayerGaugeOption

var camera: Camera2D
var pause_open: bool = false
var pause_allowed: bool = true
var respawn_view_open: bool = false
var pending_confirmation_slot: int = 0
var pending_confirmation_action: String = ""
var syncing_gauge_checkboxes: bool = false
var dev_travel_option: Control
var dev_travel_button: Button
var dev_travel_view: VBoxContainer
var dev_travel_options: VBoxContainer
var dev_travel_status_label: Label
var dev_travel_back_button: Button
var first_dev_travel_button: Button
var dev_travel_option_template: Control


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	menu_view.visible = true
	options_view.visible = false
	save_slots_view.visible = false
	respawn_view.visible = false
	var authored_dev_travel_view := $Overlay/Panel.get_node_or_null("DevTravelView") as Control
	if authored_dev_travel_view != null:
		authored_dev_travel_view.visible = false
	save_status_label.text = ""
	save_slots_status_label.text = ""
	respawn_status_label.text = ""

	resume_button.pressed.connect(resume_game)
	save_button.pressed.connect(open_save_slots)
	options_button.pressed.connect(open_options)
	title_screen_button.pressed.connect(return_to_title_screen)
	exit_button.pressed.connect(exit_game)
	respawn_button.pressed.connect(_on_respawn_pressed)
	respawn_title_screen_button.pressed.connect(return_to_title_screen)
	respawn_exit_button.pressed.connect(exit_game)
	back_button.pressed.connect(open_main_menu)
	save_slots_back_button.pressed.connect(open_main_menu)
	zoom_slider.value_changed.connect(_on_zoom_slider_value_changed)
	hud_gauges_checkbox.toggled.connect(_on_hud_gauges_toggled)
	player_gauges_checkbox.toggled.connect(_on_player_gauges_toggled)
	SaveManager.player_lives_changed.connect(_on_player_lives_changed)
	connect_save_slot_buttons()
	bind_dev_travel_controls()

	configure_zoom_slider()
	configure_gauge_checkboxes()
	if SaveManager.get_player_lives() <= 0 and not is_respawn_load_pending():
		call_deferred("open_respawn_view")


func _unhandled_input(event):
	if is_pause_toggle_event(event):
		if respawn_view_open:
			var respawn_viewport := get_viewport()
			if respawn_viewport != null:
				respawn_viewport.set_input_as_handled()
			return

		if pause_open:
			resume_game()
		elif can_pause():
			open_pause_menu()

		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func connect_save_slot_buttons():
	for slot in range(1, SaveManager.SAVE_SLOT_COUNT + 1):
		get_slot_button(slot, "OverwriteButton").pressed.connect(_on_overwrite_slot_pressed.bind(slot))
		get_slot_button(slot, "LoadButton").pressed.connect(_on_load_slot_pressed.bind(slot))
		get_slot_button(slot, "DeleteButton").pressed.connect(_on_delete_slot_pressed.bind(slot))


func bind_dev_travel_controls():
	if not is_dev_travel_enabled():
		if authored_dev_travel_option != null:
			authored_dev_travel_option.visible = false
			authored_dev_travel_option.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	bind_dev_travel_menu_option()
	bind_dev_travel_view()


func is_dev_travel_enabled() -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint()


func bind_dev_travel_menu_option():
	dev_travel_option = authored_dev_travel_option
	dev_travel_button = authored_dev_travel_button
	if dev_travel_button != null:
		for connection in dev_travel_button.pressed.get_connections():
			var callable: Callable = connection.get("callable", Callable())
			if callable.is_valid():
				dev_travel_button.pressed.disconnect(callable)
		dev_travel_button.text = "Dev Travel"
		dev_travel_button.pressed.connect(open_dev_travel)


func bind_dev_travel_view():
	dev_travel_view = $Overlay/Panel.get_node_or_null("DevTravelView") as VBoxContainer
	if dev_travel_view == null:
		push_warning("PauseMenu dev travel is enabled, but Overlay/Panel/DevTravelView is missing from the scene.")
		return

	dev_travel_options = dev_travel_view.get_node_or_null("ScrollContainer/DevTravelOptions") as VBoxContainer
	dev_travel_status_label = dev_travel_view.get_node_or_null("DevTravelStatusLabel") as Label
	dev_travel_back_button = dev_travel_view.get_node_or_null("BackButton") as Button
	if dev_travel_options == null or dev_travel_status_label == null or dev_travel_back_button == null:
		push_warning("PauseMenu DevTravelView is missing one or more required child nodes.")
		dev_travel_view = null
		return
	if not bind_dev_travel_templates():
		dev_travel_view = null
		return

	var back_callable := Callable(self, "open_main_menu")
	if not dev_travel_back_button.pressed.is_connected(back_callable):
		dev_travel_back_button.pressed.connect(back_callable)
	dev_travel_status_label.text = ""
	dev_travel_view.visible = false


func open_dev_travel():
	if not is_dev_travel_enabled() or dev_travel_view == null:
		return

	menu_view.visible = false
	options_view.visible = false
	save_slots_view.visible = false
	respawn_view.visible = false
	set_dev_travel_view_visible(true)
	clear_pending_confirmation()
	build_dev_travel_options()
	if first_dev_travel_button != null:
		first_dev_travel_button.grab_focus()
	else:
		dev_travel_back_button.grab_focus()


func build_dev_travel_options():
	first_dev_travel_button = null
	dev_travel_status_label.text = ""
	for child in dev_travel_options.get_children():
		if bool(child.get_meta("dev_generated", false)):
			dev_travel_options.remove_child(child)
			child.queue_free()

	var entries: Array = SaveManager.get_title_dev_level_entries() if SaveManager != null and SaveManager.has_method("get_title_dev_level_entries") else []
	for raw_entry in entries:
		if raw_entry is Dictionary:
			add_dev_travel_level_section(raw_entry)


func add_dev_travel_level_section(entry: Dictionary):
	var scene_path: String = str(entry.get("scene_path", ""))
	var raw_presets: Variant = entry.get("dev_presets", [])
	if scene_path == "" or not (raw_presets is Array):
		return

	var option := dev_travel_option_template.duplicate() as Control
	option.name = "LevelOption"
	option.set_meta("dev_generated", true)
	option.visible = true
	dev_travel_options.add_child(option)

	var level_label := option.get_node_or_null("LevelLabel") as Label
	if level_label == null:
		push_warning("Pause dev travel option template is missing a LevelLabel.")
		return
	level_label.text = str(entry.get("display_name", scene_path))

	var preset_dropdown := option.get_node_or_null("PresetDropdown") as OptionButton
	if preset_dropdown == null:
		push_warning("Pause dev travel option template is missing a PresetDropdown.")
		return
	preset_dropdown.clear()
	populate_dev_travel_preset_dropdown(preset_dropdown, raw_presets)

	var button := option.get_node_or_null("TravelButton") as Button
	if button == null:
		push_warning("Pause dev travel option template is missing a TravelButton.")
		return
	button.text = "Travel"
	disconnect_button_signals(button)
	button.pressed.connect(_on_dev_travel_dropdown_pressed.bind(scene_path, preset_dropdown))
	if first_dev_travel_button == null:
		first_dev_travel_button = button


func populate_dev_travel_preset_dropdown(dropdown: OptionButton, raw_presets: Array):
	for raw_preset in raw_presets:
		if not (raw_preset is Dictionary):
			continue
		var preset: Dictionary = raw_preset
		var label := str(preset.get("label", "Start"))
		if bool(preset.get("disabled", false)):
			var reason := str(preset.get("disabled_reason", "Unavailable"))
			if reason != "":
				label = "%s - %s" % [label, reason]
		dropdown.add_item(label)
		var item_index := dropdown.item_count - 1
		dropdown.set_item_metadata(item_index, str(preset.get("preset", "")))
		if bool(preset.get("disabled", false)):
			dropdown.set_item_disabled(item_index, true)


func _on_dev_travel_dropdown_pressed(scene_path: String, dropdown: OptionButton):
	var preset := ""
	if dropdown != null and dropdown.selected >= 0:
		preset = str(dropdown.get_item_metadata(dropdown.selected))
	_on_dev_travel_pressed(scene_path, preset)


func _on_dev_travel_pressed(scene_path: String, preset: String):
	if SaveManager == null or not SaveManager.has_method("dev_switch_active_save_to_level"):
		dev_travel_status_label.text = "Dev travel is unavailable."
		return

	set_dev_travel_buttons_disabled(true)
	var switch_started: bool = SaveManager.dev_switch_active_save_to_level(scene_path, preset)
	if switch_started:
		pause_open = false
		overlay.visible = false
		set_tree_paused_safely(false)
		return

	dev_travel_status_label.text = SaveManager.last_error if SaveManager.last_error != "" else "Could not dev travel."
	set_dev_travel_buttons_disabled(false)


func set_dev_travel_buttons_disabled(disabled: bool):
	if dev_travel_options == null:
		return

	for child in dev_travel_options.get_children():
		if bool(child.get_meta("dev_generated", false)):
			set_buttons_disabled_recursive(child, disabled)


func set_dev_travel_view_visible(visible_value: bool):
	if dev_travel_view != null:
		dev_travel_view.visible = visible_value


func bind_dev_travel_templates() -> bool:
	dev_travel_option_template = dev_travel_options.get_node_or_null("PreviewLevelOption") as Control
	if dev_travel_option_template == null:
		push_warning("PauseMenu DevTravelOptions is missing authored PreviewLevelOption template.")
		return false

	if dev_travel_option_template.get_node_or_null("LevelLabel") == null:
		push_warning("PauseMenu PreviewLevelOption is missing LevelLabel.")
		return false
	if dev_travel_option_template.get_node_or_null("PresetDropdown") == null:
		push_warning("PauseMenu PreviewLevelOption is missing PresetDropdown.")
		return false
	if dev_travel_option_template.get_node_or_null("TravelButton") == null:
		push_warning("PauseMenu PreviewLevelOption is missing TravelButton.")
		return false

	dev_travel_option_template.set_meta("dev_template", true)
	dev_travel_option_template.visible = false
	return true


func find_child_of_type(root: Node, type_name: String) -> Node:
	for child in root.get_children():
		if child.get_class() == type_name:
			return child
	return null


func disconnect_button_signals(button: Button):
	for connection in button.pressed.get_connections():
		var callable: Callable = connection.get("callable", Callable())
		if callable.is_valid():
			button.pressed.disconnect(callable)


func set_buttons_disabled_recursive(root: Node, disabled: bool):
	if root is Button:
		(root as Button).disabled = disabled
	for child in root.get_children():
		set_buttons_disabled_recursive(child, disabled)


func is_pause_toggle_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return true

	return event.is_action_pressed("ui_cancel")


func open_pause_menu():
	if not can_pause():
		return

	respawn_view_open = false
	pause_open = true
	get_tree().paused = true
	overlay.visible = true
	save_status_label.text = ""
	open_main_menu()
	configure_zoom_slider()
	resume_button.grab_focus()


func resume_game():
	if respawn_view_open:
		return

	pause_open = false
	overlay.visible = false
	clear_pending_confirmation()
	set_dev_travel_view_visible(false)
	get_tree().paused = false


func open_main_menu():
	if respawn_view_open:
		return

	menu_view.visible = true
	options_view.visible = false
	save_slots_view.visible = false
	respawn_view.visible = false
	set_dev_travel_view_visible(false)
	clear_pending_confirmation()
	update_save_button_state()
	if pause_open:
		resume_button.grab_focus()


func open_options():
	configure_zoom_slider()
	configure_gauge_checkboxes()
	menu_view.visible = false
	options_view.visible = true
	save_slots_view.visible = false
	respawn_view.visible = false
	set_dev_travel_view_visible(false)
	clear_pending_confirmation()
	zoom_slider.grab_focus()


func open_save_slots():
	if not SaveManager.is_save_allowed():
		save_status_label.text = SaveManager.get_save_disabled_message()
		update_save_button_state()
		return

	menu_view.visible = false
	options_view.visible = false
	save_slots_view.visible = true
	respawn_view.visible = false
	set_dev_travel_view_visible(false)
	save_status_label.text = ""
	save_slots_status_label.text = ""
	clear_pending_confirmation()
	refresh_save_slots()
	get_slot_button(1, "OverwriteButton").grab_focus()


func refresh_save_slots():
	for slot in range(1, SaveManager.SAVE_SLOT_COUNT + 1):
		var summary: Dictionary = SaveManager.get_slot_summary(slot)
		var exists: bool = bool(summary.get("exists", false))
		var is_autosave_slot: bool = SaveManager.has_method("is_autosave_slot") and SaveManager.is_autosave_slot(slot)
		var slot_label: Label = get_slot_label(slot)
		var status_label: Label = get_slot_status_label(slot)
		var overwrite_button: Button = get_slot_button(slot, "OverwriteButton")
		var load_button: Button = get_slot_button(slot, "LoadButton")
		var delete_button: Button = get_slot_button(slot, "DeleteButton")

		slot_label.text = get_save_slot_label_text(slot, summary, exists, is_autosave_slot)
		if exists:
			status_label.text = str(summary.get("timestamp_text", ""))
		else:
			status_label.text = "Empty"

		overwrite_button.visible = not is_autosave_slot
		overwrite_button.disabled = is_autosave_slot or not can_write_saves()
		load_button.disabled = not exists
		delete_button.disabled = not exists

		overwrite_button.text = "Overwrite" if exists else "Save"
		delete_button.text = "Delete"

		if not is_autosave_slot and pending_confirmation_slot == slot and pending_confirmation_action == "overwrite":
			overwrite_button.text = "Confirm"
		elif pending_confirmation_slot == slot and pending_confirmation_action == "delete":
			delete_button.text = "Confirm"


func _on_overwrite_slot_pressed(slot: int):
	if SaveManager.has_method("is_autosave_slot") and SaveManager.is_autosave_slot(slot):
		save_slots_status_label.text = "Autosave cannot be overwritten manually."
		clear_pending_confirmation()
		refresh_save_slots()
		return

	if SaveManager.save_exists(slot):
		if not confirm_slot_action(slot, "overwrite", "Press Confirm to overwrite Slot %d" % slot):
			return

	var save_succeeded := SaveManager.save_game_to_slot(slot, "manual")
	save_slots_status_label.text = ("Slot %d Saved" % slot) if save_succeeded else SaveManager.get_save_disabled_message()
	clear_pending_confirmation()
	refresh_save_slots()


func _on_load_slot_pressed(slot: int):
	clear_pending_confirmation()
	var load_succeeded: bool = SaveManager.load_save_slot_from_any_level(slot)
	save_slots_status_label.text = ("Slot %d Loaded" % slot) if load_succeeded else (SaveManager.last_error if SaveManager.last_error != "" else "Load Failed")
	if load_succeeded:
		close_after_successful_load()
		return
	refresh_save_slots()


func close_after_successful_load():
	respawn_view_open = false
	pause_open = false
	overlay.visible = false
	menu_view.visible = false
	options_view.visible = false
	save_slots_view.visible = false
	respawn_view.visible = false
	set_dev_travel_view_visible(false)
	clear_pending_confirmation()
	set_tree_paused_safely(false)


func set_tree_paused_safely(paused: bool):
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = paused


func open_respawn_view():
	respawn_view_open = true
	pause_open = true
	get_tree().paused = true
	overlay.visible = true
	menu_view.visible = false
	options_view.visible = false
	save_slots_view.visible = false
	respawn_view.visible = true
	set_dev_travel_view_visible(false)
	respawn_status_label.text = ""
	clear_pending_confirmation()
	respawn_button.disabled = SaveManager.get_most_recent_save_slot(true) < 0
	if respawn_button.disabled:
		respawn_status_label.text = "No save found."
		respawn_exit_button.grab_focus()
	else:
		respawn_button.grab_focus()


func close_respawn_view():
	respawn_view_open = false
	pause_open = false
	overlay.visible = false
	respawn_view.visible = false
	respawn_status_label.text = ""
	get_tree().paused = false


func _on_respawn_pressed():
	respawn_button.disabled = true
	close_respawn_view()
	get_tree().paused = false
	var load_succeeded := SaveManager.load_most_recent_save(true)
	if load_succeeded:
		return

	open_respawn_view()
	respawn_button.disabled = SaveManager.get_most_recent_save_slot(true) < 0
	respawn_status_label.text = SaveManager.last_error if SaveManager.last_error != "" else "Load Failed"
	if respawn_button.disabled:
		respawn_exit_button.grab_focus()
	else:
		respawn_button.grab_focus()


func _on_player_lives_changed(current_lives: int, _max_lives: int):
	if current_lives <= 0 and not is_respawn_load_pending():
		call_deferred("open_respawn_view")


func is_respawn_load_pending() -> bool:
	return SaveManager.has_method("is_respawn_load_pending") and SaveManager.is_respawn_load_pending()


func _on_delete_slot_pressed(slot: int):
	if not confirm_slot_action(slot, "delete", "Press Confirm to delete Slot %d" % slot):
		return

	var delete_succeeded := SaveManager.delete_save(slot)
	save_slots_status_label.text = ("Slot %d Deleted" % slot) if delete_succeeded else "Delete Failed"
	clear_pending_confirmation()
	refresh_save_slots()


func confirm_slot_action(slot: int, action: String, message: String) -> bool:
	if pending_confirmation_slot == slot and pending_confirmation_action == action:
		return true

	pending_confirmation_slot = slot
	pending_confirmation_action = action
	save_slots_status_label.text = message
	refresh_save_slots()
	return false


func clear_pending_confirmation():
	pending_confirmation_slot = 0
	pending_confirmation_action = ""


func get_save_slot_label_text(slot: int, summary: Dictionary, exists: bool, is_autosave_slot: bool) -> String:
	if is_autosave_slot:
		return "Autosave (AUTO)"

	if exists:
		return str(summary.get("display_name", "Slot %d" % slot))

	return "Slot %d" % slot


func get_slot_label(slot: int) -> Label:
	return save_slots_view.get_node("SlotList/Slot%d/SlotLabel" % slot) as Label


func get_slot_status_label(slot: int) -> Label:
	return save_slots_view.get_node("SlotList/Slot%d/StatusLabel" % slot) as Label


func get_slot_button(slot: int, button_name: String) -> Button:
	return save_slots_view.get_node("SlotList/Slot%d/ButtonRow/%s" % [slot, button_name]) as Button


func return_to_title_screen():
	respawn_view_open = false
	pause_open = false
	overlay.visible = false
	menu_view.visible = false
	options_view.visible = false
	save_slots_view.visible = false
	respawn_view.visible = false
	set_dev_travel_view_visible(false)
	clear_pending_confirmation()
	save_status_label.text = ""
	save_slots_status_label.text = ""
	respawn_status_label.text = ""
	get_tree().paused = false

	var error: Error = get_tree().change_scene_to_file(TITLE_SCREEN_SCENE)
	if error != OK:
		push_warning("Could not return to title screen. Error: %s" % error_string(error))


func exit_game():
	get_tree().quit()


func configure_zoom_slider():
	camera = get_player_camera()

	var min_zoom := 1.75
	var max_zoom := 3.0
	var current_zoom := 2.25

	if camera != null:
		var camera_min_zoom: Variant = camera.get("min_zoom")
		var camera_max_zoom: Variant = camera.get("max_zoom")
		if camera_min_zoom != null:
			min_zoom = float(camera_min_zoom)
		if camera_max_zoom != null:
			max_zoom = float(camera_max_zoom)
		current_zoom = camera.zoom.x

	zoom_slider.min_value = min_zoom
	zoom_slider.max_value = max_zoom
	zoom_slider.step = 0.05
	zoom_slider.value = clamp(current_zoom, min_zoom, max_zoom)


func get_player_camera() -> Camera2D:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null

	return player.get_node_or_null("Camera2D") as Camera2D


func _on_zoom_slider_value_changed(value: float):
	if camera == null:
		camera = get_player_camera()

	if camera == null:
		return

	if camera.has_method("change_zoom"):
		camera.change_zoom(value)
	else:
		camera.zoom = Vector2(value, value)


func configure_gauge_checkboxes():
	if hud_gauges_checkbox == null or player_gauges_checkbox == null:
		return

	var settings: Dictionary = {}
	if SaveManager != null and SaveManager.has_method("get_gauge_display_settings"):
		settings = SaveManager.get_gauge_display_settings()
	syncing_gauge_checkboxes = true
	hud_gauges_checkbox.button_pressed = bool(settings.get("show_hud_gauges", true))
	player_gauges_checkbox.button_pressed = bool(settings.get("show_player_gauges", true))
	if not hud_gauges_checkbox.button_pressed and not player_gauges_checkbox.button_pressed:
		hud_gauges_checkbox.button_pressed = true
		player_gauges_checkbox.button_pressed = true
	syncing_gauge_checkboxes = false


func _on_hud_gauges_toggled(enabled: bool):
	if syncing_gauge_checkboxes:
		return

	apply_gauge_display_choice(enabled, player_gauges_checkbox.button_pressed, hud_gauges_checkbox)


func _on_player_gauges_toggled(enabled: bool):
	if syncing_gauge_checkboxes:
		return

	apply_gauge_display_choice(hud_gauges_checkbox.button_pressed, enabled, player_gauges_checkbox)


func apply_gauge_display_choice(show_hud: bool, show_player: bool, changed_checkbox: CheckBox):
	if not show_hud and not show_player:
		syncing_gauge_checkboxes = true
		changed_checkbox.button_pressed = true
		syncing_gauge_checkboxes = false
		return

	if SaveManager != null and SaveManager.has_method("set_gauge_display_settings"):
		SaveManager.set_gauge_display_settings(show_hud, show_player)


func set_pause_allowed(allowed: bool):
	pause_allowed = allowed
	SaveManager.set_save_allowed(allowed)

	if not pause_allowed and pause_open:
		resume_game()

	update_save_button_state()


func can_pause() -> bool:
	return pause_allowed


func update_save_button_state():
	if save_button == null:
		return

	save_button.disabled = not SaveManager.is_save_allowed()


func can_write_saves() -> bool:
	if SaveManager.has_method("is_save_write_allowed"):
		return SaveManager.is_save_write_allowed()

	return SaveManager.is_save_allowed()
