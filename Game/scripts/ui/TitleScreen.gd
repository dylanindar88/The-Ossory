extends CanvasLayer

const BANSHEE_VILLAGE_SCENE: String = "res://scenes/levels/BansheeVillage.tscn"
const STARTING_WILDERNESS_SCENE: String = "res://scenes/levels/StartingWilderness.tscn"
const WEEPING_WOODS_SCENE: String = "res://scenes/levels/WeepingWoods.tscn"
const NEW_GAME_START_SCENE: String = STARTING_WILDERNESS_SCENE

@onready var main_view: VBoxContainer = $Control/Panel/RightContent/ViewContainer/MainView
@onready var new_game_slots_view: VBoxContainer = $Control/Panel/RightContent/ViewContainer/NewGameSlotsView
@onready var load_slots_view: VBoxContainer = $Control/Panel/RightContent/ViewContainer/LoadSlotsView
@onready var options_view: VBoxContainer = $Control/Panel/RightContent/ViewContainer/OptionsView
@onready var dev_menu_view: VBoxContainer = $Control/Panel/RightContent/ViewContainer/DevMenuView
@onready var continue_button: Button = $Control/Panel/RightContent/ViewContainer/MainView/ContinueOption/Button
@onready var load_button: Button = $Control/Panel/RightContent/ViewContainer/MainView/LoadOption/Button
@onready var new_game_button: Button = $Control/Panel/RightContent/ViewContainer/MainView/NewGameOption/Button
@onready var options_button: Button = $Control/Panel/RightContent/ViewContainer/MainView/OptionsOption/Button
@onready var exit_button: Button = $Control/Panel/RightContent/ViewContainer/MainView/ExitOption/Button
@onready var main_status_label: Label = $Control/Panel/RightContent/ViewContainer/MainView/MainStatusLabel
@onready var new_game_status_label: Label = $Control/Panel/RightContent/ViewContainer/NewGameSlotsView/NewGameStatusLabel
@onready var new_game_back_button: Button = $Control/Panel/RightContent/ViewContainer/NewGameSlotsView/BackOption/Button
@onready var load_slots_status_label: Label = $Control/Panel/RightContent/ViewContainer/LoadSlotsView/LoadSlotsStatusLabel
@onready var load_slots_back_button: Button = $Control/Panel/RightContent/ViewContainer/LoadSlotsView/BackOption/Button
@onready var zoom_slider: HSlider = $Control/Panel/RightContent/ViewContainer/OptionsView/ZoomSlider
@onready var hud_gauges_checkbox: CheckBox = $Control/Panel/RightContent/ViewContainer/OptionsView/GaugeLocationOptions/HudGaugeOption
@onready var player_gauges_checkbox: CheckBox = $Control/Panel/RightContent/ViewContainer/OptionsView/GaugeLocationOptions/PlayerGaugeOption
@onready var options_back_button: Button = $Control/Panel/RightContent/ViewContainer/OptionsView/BackOption/Button
@onready var dev_status_label: Label = $Control/Panel/RightContent/ViewContainer/DevMenuView/DevStatusLabel
@onready var dev_back_button: Button = $Control/Panel/RightContent/ViewContainer/DevMenuView/BackOption/Button

var pending_new_game_slot: int = 0
var pending_delete_slot: int = 0
var syncing_gauge_checkboxes: bool = false
var first_dev_button: Button


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	open_main_view()
	connect_main_buttons()
	connect_new_game_slot_buttons()
	connect_load_slot_buttons()
	connect_options_buttons()
	connect_dev_buttons()
	refresh_main_buttons()
	configure_zoom_slider()
	configure_gauge_checkboxes()
	dev_menu_view.visible = false


func _unhandled_input(event: InputEvent):
	if is_dev_menu_event(event):
		open_dev_menu()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func connect_main_buttons():
	continue_button.pressed.connect(_on_continue_pressed)
	load_button.pressed.connect(open_load_slots)
	new_game_button.pressed.connect(open_new_game_slots)
	options_button.pressed.connect(open_options)
	exit_button.pressed.connect(exit_game)


func connect_new_game_slot_buttons():
	for slot in range(1, SaveManager.MANUAL_SAVE_SLOT_COUNT + 1):
		get_new_game_slot_button(slot).pressed.connect(_on_new_game_slot_pressed.bind(slot))
	new_game_back_button.pressed.connect(open_main_view)


func connect_load_slot_buttons():
	for slot in range(1, SaveManager.SAVE_SLOT_COUNT + 1):
		get_load_slot_button(slot).pressed.connect(_on_load_slot_pressed.bind(slot))
		get_load_slot_delete_button(slot).pressed.connect(_on_delete_slot_pressed.bind(slot))
	load_slots_back_button.pressed.connect(open_main_view)


func connect_options_buttons():
	zoom_slider.value_changed.connect(_on_zoom_slider_value_changed)
	hud_gauges_checkbox.toggled.connect(_on_hud_gauges_toggled)
	player_gauges_checkbox.toggled.connect(_on_player_gauges_toggled)
	options_back_button.pressed.connect(open_main_view)


func connect_dev_buttons():
	build_dev_menu_from_registry()
	dev_back_button.pressed.connect(open_main_view)


func build_dev_menu_from_registry():
	first_dev_button = null
	hide_static_dev_buttons()

	var generated_options: VBoxContainer = get_or_create_generated_dev_options()
	for child in generated_options.get_children():
		child.queue_free()

	var entries: Array = []
	if SaveManager != null and SaveManager.has_method("get_title_dev_level_entries"):
		entries = SaveManager.get_title_dev_level_entries()
	if entries.is_empty():
		entries = [
			{
				"scene_path": STARTING_WILDERNESS_SCENE,
				"display_name": "01 - Starting Wilderness",
				"dev_presets": [{"label": "Start", "preset": ""}],
			},
			{
				"scene_path": WEEPING_WOODS_SCENE,
				"display_name": "02 - Weeping Woods",
				"dev_presets": [{"label": "Start", "preset": ""}],
			},
			{
				"scene_path": BANSHEE_VILLAGE_SCENE,
				"display_name": "03 - Banshee Village",
				"dev_presets": [
					{"label": "Start", "preset": "start"},
					{"label": "First Report", "preset": "first_banshee_report_ready"},
					{"label": "Second Report", "preset": "second_banshee_report_ready"},
					{"label": "Third Report", "preset": "third_banshee_report_ready"},
				],
			},
		]

	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		add_dev_level_section(generated_options, entry)


func hide_static_dev_buttons():
	for node_name in ["BansheeStartOption", "BansheeFirstReportOption", "BansheeSecondReportOption", "BansheeThirdReportOption", "StartingWildernessOption"]:
		var node: Node = dev_menu_view.get_node_or_null(node_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_or_create_generated_dev_options() -> VBoxContainer:
	var existing: VBoxContainer = dev_menu_view.get_node_or_null("GeneratedDevOptions") as VBoxContainer
	if existing != null:
		return existing

	var generated_options: VBoxContainer = VBoxContainer.new()
	generated_options.name = "GeneratedDevOptions"
	generated_options.custom_minimum_size = Vector2(420, 320)
	generated_options.add_theme_constant_override("separation", 8)
	dev_menu_view.add_child(generated_options)
	var status_index: int = dev_status_label.get_index()
	dev_menu_view.move_child(generated_options, status_index)
	return generated_options


func add_dev_level_section(parent: VBoxContainer, entry: Dictionary):
	var scene_path: String = str(entry.get("scene_path", ""))
	var display_name: String = str(entry.get("display_name", scene_path))
	var raw_presets: Variant = entry.get("dev_presets", [])
	if scene_path == "" or not (raw_presets is Array):
		return

	var level_label: Label = Label.new()
	level_label.custom_minimum_size = Vector2(420, 24)
	level_label.text = display_name
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(level_label)

	for raw_preset in raw_presets:
		if not (raw_preset is Dictionary):
			continue
		var preset_data: Dictionary = raw_preset
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(420, 38)
		button.text = str(preset_data.get("label", "Start"))
		button.pressed.connect(_on_dev_start_pressed.bind(scene_path, str(preset_data.get("preset", ""))))
		parent.add_child(button)
		if first_dev_button == null:
			first_dev_button = button


func is_dev_menu_event(event: InputEvent) -> bool:
	return (
		(OS.is_debug_build() or Engine.is_editor_hint())
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_D
		and event.ctrl_pressed
		and event.shift_pressed
	)


func open_main_view():
	main_view.visible = true
	new_game_slots_view.visible = false
	load_slots_view.visible = false
	options_view.visible = false
	dev_menu_view.visible = false
	main_status_label.text = ""
	pending_new_game_slot = 0
	pending_delete_slot = 0
	refresh_main_buttons()
	focus_main_button()


func open_new_game_slots():
	main_view.visible = false
	new_game_slots_view.visible = true
	load_slots_view.visible = false
	options_view.visible = false
	dev_menu_view.visible = false
	new_game_status_label.text = ""
	pending_new_game_slot = 0
	pending_delete_slot = 0
	refresh_new_game_slots()
	get_new_game_slot_button(1).grab_focus()


func open_load_slots():
	main_view.visible = false
	new_game_slots_view.visible = false
	load_slots_view.visible = true
	options_view.visible = false
	dev_menu_view.visible = false
	load_slots_status_label.text = ""
	pending_new_game_slot = 0
	pending_delete_slot = 0
	refresh_load_slots()
	focus_first_load_slot()


func open_options():
	main_view.visible = false
	new_game_slots_view.visible = false
	load_slots_view.visible = false
	options_view.visible = true
	dev_menu_view.visible = false
	pending_delete_slot = 0
	configure_zoom_slider()
	configure_gauge_checkboxes()
	zoom_slider.grab_focus()


func open_dev_menu():
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	main_view.visible = false
	new_game_slots_view.visible = false
	load_slots_view.visible = false
	options_view.visible = false
	dev_menu_view.visible = true
	dev_status_label.text = ""
	pending_delete_slot = 0
	if first_dev_button != null:
		first_dev_button.grab_focus()
	else:
		dev_back_button.grab_focus()


func refresh_main_buttons():
	var has_save: bool = SaveManager.get_most_recent_save_slot(true) >= 0
	continue_button.disabled = not has_save
	load_button.disabled = not has_save


func focus_main_button():
	if not continue_button.disabled:
		continue_button.grab_focus()
	elif not load_button.disabled:
		load_button.grab_focus()
	else:
		new_game_button.grab_focus()


func refresh_new_game_slots():
	for slot in range(1, SaveManager.MANUAL_SAVE_SLOT_COUNT + 1):
		var summary: Dictionary = SaveManager.get_slot_summary(slot)
		var exists: bool = bool(summary.get("exists", false))
		var status_label: Label = get_new_game_slot_status_label(slot)
		var button: Button = get_new_game_slot_button(slot)
		status_label.text = get_slot_display_text(summary) if exists else "Empty"
		if exists:
			button.text = "Confirm" if pending_new_game_slot == slot else "Overwrite"
		else:
			button.text = "Start"


func refresh_load_slots():
	for slot in range(1, SaveManager.SAVE_SLOT_COUNT + 1):
		var summary: Dictionary = SaveManager.get_slot_summary(slot)
		var exists: bool = bool(summary.get("exists", false))
		var slot_label: Label = get_load_slot_label(slot)
		var status_label: Label = get_load_slot_status_label(slot)
		var button: Button = get_load_slot_button(slot)
		var delete_button: Button = get_load_slot_delete_button(slot)
		slot_label.text = get_load_slot_label_text(slot, summary, exists)
		status_label.text = str(summary.get("timestamp_text", "")) if exists else "Empty"
		button.disabled = not exists
		delete_button.disabled = not exists
		delete_button.text = "Confirm" if pending_delete_slot == slot and exists else "Delete"


func focus_first_load_slot():
	for slot in range(1, SaveManager.SAVE_SLOT_COUNT + 1):
		var button: Button = get_load_slot_button(slot)
		if not button.disabled:
			button.grab_focus()
			return

	load_slots_back_button.grab_focus()


func get_slot_display_text(summary: Dictionary) -> String:
	var display_name: String = str(summary.get("display_name", "Saved"))
	var timestamp_text: String = str(summary.get("timestamp_text", ""))
	if timestamp_text == "":
		return display_name

	return "%s - %s" % [display_name, timestamp_text]


func get_load_slot_label_text(slot: int, summary: Dictionary, exists: bool) -> String:
	if SaveManager.is_autosave_slot(slot):
		return "Autosave (AUTO)"

	if exists:
		return str(summary.get("display_name", "Slot %d" % slot))

	return "Slot %d" % slot


func get_new_game_slot_status_label(slot: int) -> Label:
	return new_game_slots_view.get_node("SlotList/Slot%d/StatusLabel" % slot) as Label


func get_new_game_slot_button(slot: int) -> Button:
	return new_game_slots_view.get_node("SlotList/Slot%d/Button" % slot) as Button


func get_load_slot_label(slot: int) -> Label:
	return load_slots_view.get_node("SlotList/Slot%d/SlotLabel" % slot) as Label


func get_load_slot_status_label(slot: int) -> Label:
	return load_slots_view.get_node("SlotList/Slot%d/StatusLabel" % slot) as Label


func get_load_slot_button(slot: int) -> Button:
	return load_slots_view.get_node("SlotList/Slot%d/Button" % slot) as Button


func get_load_slot_delete_button(slot: int) -> Button:
	return load_slots_view.get_node("SlotList/Slot%d/DeleteButton" % slot) as Button


func _on_continue_pressed():
	continue_button.disabled = true
	if not SaveManager.load_most_recent_save(true):
		main_status_label.text = SaveManager.last_error if SaveManager.last_error != "" else "Load Failed"
		refresh_main_buttons()


func _on_load_slot_pressed(slot: int):
	pending_delete_slot = 0
	get_load_slot_button(slot).disabled = true
	if not SaveManager.load_save_slot_from_any_level(slot):
		load_slots_status_label.text = SaveManager.last_error if SaveManager.last_error != "" else "Load Failed"
		refresh_load_slots()


func _on_delete_slot_pressed(slot: int):
	if pending_delete_slot != slot:
		pending_delete_slot = slot
		load_slots_status_label.text = "Press Confirm to delete this save."
		refresh_load_slots()
		get_load_slot_delete_button(slot).grab_focus()
		return

	if SaveManager.delete_save(slot):
		load_slots_status_label.text = "Save deleted."
	else:
		load_slots_status_label.text = SaveManager.last_error if SaveManager.last_error != "" else "Could not delete save."
	pending_delete_slot = 0
	refresh_load_slots()
	refresh_main_buttons()
	focus_first_load_slot()


func _on_new_game_slot_pressed(slot: int):
	if SaveManager.save_exists(slot) and pending_new_game_slot != slot:
		pending_new_game_slot = slot
		new_game_status_label.text = "Press Confirm to overwrite Slot %d" % slot
		refresh_new_game_slots()
		return

	if not SaveManager.start_new_game(slot, NEW_GAME_START_SCENE):
		new_game_status_label.text = SaveManager.last_error if SaveManager.last_error != "" else "Could not start new game."


func _on_zoom_slider_value_changed(value: float):
	if SaveManager != null and SaveManager.has_method("set_default_camera_zoom"):
		SaveManager.set_default_camera_zoom(value)


func configure_zoom_slider():
	zoom_slider.min_value = 1.75
	zoom_slider.max_value = 3.0
	zoom_slider.step = 0.05
	if SaveManager != null and SaveManager.has_method("get_default_camera_zoom"):
		zoom_slider.value = SaveManager.get_default_camera_zoom()
	else:
		zoom_slider.value = 2.25


func configure_gauge_checkboxes():
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


func _on_dev_start_pressed(scene_path: String, preset: String):
	if not SaveManager.start_dev_scene(scene_path, preset):
		dev_status_label.text = SaveManager.last_error if SaveManager.last_error != "" else "Could not start dev scene."


func exit_game():
	get_tree().quit()
