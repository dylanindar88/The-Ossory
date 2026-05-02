extends CanvasLayer

@onready var overlay: Control = $Overlay
@onready var menu_view: VBoxContainer = $Overlay/Panel/MenuView
@onready var options_view: VBoxContainer = $Overlay/Panel/OptionsView
@onready var save_slots_view: VBoxContainer = $Overlay/Panel/SaveSlotsView
@onready var resume_button: Button = $Overlay/Panel/MenuView/ResumeOption/Button
@onready var save_button: Button = $Overlay/Panel/MenuView/SaveOption/Button
@onready var options_button: Button = $Overlay/Panel/MenuView/OptionsOption/Button
@onready var exit_button: Button = $Overlay/Panel/MenuView/ExitOption/Button
@onready var save_status_label: Label = $Overlay/Panel/MenuView/SaveStatusLabel
@onready var back_button: Button = $Overlay/Panel/OptionsView/BackOption/Button
@onready var save_slots_back_button: Button = $Overlay/Panel/SaveSlotsView/BackOption/Button
@onready var save_slots_status_label: Label = $Overlay/Panel/SaveSlotsView/SaveSlotsStatusLabel
@onready var zoom_slider: HSlider = $Overlay/Panel/OptionsView/ZoomSlider

var camera: Camera2D
var pause_open: bool = false
var pause_allowed: bool = true
var pending_confirmation_slot: int = 0
var pending_confirmation_action: String = ""


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	menu_view.visible = true
	options_view.visible = false
	save_slots_view.visible = false
	save_status_label.text = ""
	save_slots_status_label.text = ""

	resume_button.pressed.connect(resume_game)
	save_button.pressed.connect(open_save_slots)
	options_button.pressed.connect(open_options)
	exit_button.pressed.connect(exit_game)
	back_button.pressed.connect(open_main_menu)
	save_slots_back_button.pressed.connect(open_main_menu)
	zoom_slider.value_changed.connect(_on_zoom_slider_value_changed)
	connect_save_slot_buttons()

	configure_zoom_slider()


func _unhandled_input(event):
	if is_pause_toggle_event(event):
		if pause_open:
			resume_game()
		elif can_pause():
			open_pause_menu()

		get_viewport().set_input_as_handled()


func connect_save_slot_buttons():
	for slot in range(1, SaveManager.SAVE_SLOT_COUNT + 1):
		get_slot_button(slot, "OverwriteButton").pressed.connect(_on_overwrite_slot_pressed.bind(slot))
		get_slot_button(slot, "LoadButton").pressed.connect(_on_load_slot_pressed.bind(slot))
		get_slot_button(slot, "DeleteButton").pressed.connect(_on_delete_slot_pressed.bind(slot))


func is_pause_toggle_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return true

	return event.is_action_pressed("ui_cancel")


func open_pause_menu():
	if not can_pause():
		return

	pause_open = true
	get_tree().paused = true
	overlay.visible = true
	save_status_label.text = ""
	open_main_menu()
	configure_zoom_slider()
	resume_button.grab_focus()


func resume_game():
	pause_open = false
	overlay.visible = false
	clear_pending_confirmation()
	get_tree().paused = false


func open_main_menu():
	menu_view.visible = true
	options_view.visible = false
	save_slots_view.visible = false
	clear_pending_confirmation()
	update_save_button_state()
	if pause_open:
		resume_button.grab_focus()


func open_options():
	configure_zoom_slider()
	menu_view.visible = false
	options_view.visible = true
	save_slots_view.visible = false
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
	save_status_label.text = ""
	save_slots_status_label.text = ""
	clear_pending_confirmation()
	refresh_save_slots()
	get_slot_button(1, "OverwriteButton").grab_focus()


func refresh_save_slots():
	for slot in range(1, SaveManager.SAVE_SLOT_COUNT + 1):
		var summary := SaveManager.get_slot_summary(slot)
		var exists: bool = bool(summary.get("exists", false))
		var status_label := get_slot_status_label(slot)
		var overwrite_button := get_slot_button(slot, "OverwriteButton")
		var load_button := get_slot_button(slot, "LoadButton")
		var delete_button := get_slot_button(slot, "DeleteButton")

		if exists:
			status_label.text = get_occupied_slot_text(summary)
		else:
			status_label.text = "Empty"

		overwrite_button.disabled = not SaveManager.is_save_allowed()
		load_button.disabled = not exists
		delete_button.disabled = not exists

		overwrite_button.text = "Overwrite" if exists else "Save"
		delete_button.text = "Delete"

		if pending_confirmation_slot == slot and pending_confirmation_action == "overwrite":
			overwrite_button.text = "Confirm"
		elif pending_confirmation_slot == slot and pending_confirmation_action == "delete":
			delete_button.text = "Confirm"


func get_occupied_slot_text(summary: Dictionary) -> String:
	var saved_at: String = str(summary.get("saved_at_datetime", ""))
	var reason: String = str(summary.get("reason", ""))
	if saved_at == "":
		saved_at = "Saved"

	if reason == "":
		return saved_at

	return "%s - %s" % [saved_at, reason]


func _on_overwrite_slot_pressed(slot: int):
	if SaveManager.save_exists(slot):
		if not confirm_slot_action(slot, "overwrite", "Press Confirm to overwrite Slot %d" % slot):
			return

	var save_succeeded := SaveManager.save_game_to_slot(slot, "manual")
	save_slots_status_label.text = ("Slot %d Saved" % slot) if save_succeeded else SaveManager.get_save_disabled_message()
	clear_pending_confirmation()
	refresh_save_slots()


func _on_load_slot_pressed(slot: int):
	clear_pending_confirmation()
	var load_succeeded := SaveManager.load_slot_into_current_level(slot)
	save_slots_status_label.text = ("Slot %d Loaded" % slot) if load_succeeded else "Load Failed"
	refresh_save_slots()


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


func get_slot_status_label(slot: int) -> Label:
	return save_slots_view.get_node("SlotList/Slot%d/StatusLabel" % slot) as Label


func get_slot_button(slot: int, button_name: String) -> Button:
	return save_slots_view.get_node("SlotList/Slot%d/ButtonRow/%s" % [slot, button_name]) as Button


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
