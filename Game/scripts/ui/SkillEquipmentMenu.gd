extends CanvasLayer

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/SkillEquipmentSlot.tscn")
const ICON_FRAMES: SpriteFrames = preload("res://resources/icons/skills_and_equipment_icons.tres")

@onready var overlay: Control = $Overlay
@onready var pause_panel: Node = get_node_or_null("../PauseMenu")
@onready var slots_root: Control = $Overlay/Panel/SlotsRoot

var menu_open: bool = false
var slots_by_id: Dictionary = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	create_slots()
	refresh_slots()
	if SaveManager.has_signal("upgrade_state_changed"):
		SaveManager.upgrade_state_changed.connect(refresh_slots)


func _unhandled_input(event: InputEvent):
	if is_menu_toggle_event(event):
		if menu_open:
			close_menu()
		elif can_open_menu():
			open_menu()

		get_viewport().set_input_as_handled()
	elif menu_open and is_close_event(event):
		close_menu()
		get_viewport().set_input_as_handled()


func is_menu_toggle_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		return true

	return event.is_action_pressed("skills_equipment_menu")


func is_close_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return true

	return event.is_action_pressed("ui_cancel")


func open_menu():
	close_pause_menu_if_open()
	menu_open = true
	get_tree().paused = true
	overlay.visible = true
	refresh_slots()


func close_menu():
	menu_open = false
	overlay.visible = false
	get_tree().paused = false


func can_open_menu() -> bool:
	return SaveManager == null or SaveManager.is_save_allowed()


func close_pause_menu_if_open():
	if pause_panel != null and bool(pause_panel.get("pause_open")) and pause_panel.has_method("resume_game"):
		pause_panel.call("resume_game")


func create_slots():
	var slot_definitions := get_slot_definitions()
	for definition in slot_definitions:
		var slot = SLOT_SCENE.instantiate()
		slots_root.add_child(slot)
		slot.position = definition["position"]
		slot.call("configure", definition)
		slots_by_id[str(definition["slot_id"])] = slot


func refresh_slots():
	var upgrade_state: Dictionary = SaveManager.get_upgrade_state() if SaveManager != null else {}
	for slot in slots_by_id.values():
		if slot.has_method("apply_upgrade_state"):
			slot.apply_upgrade_state(upgrade_state)


func get_slot_definitions() -> Array[Dictionary]:
	var large_radius := 58.0
	var small_radius := 35.0
	var stat_center := Vector2(375, 245)
	var stat_cluster_radius := 65.0
	return [
		make_slot(&"god_ability_1", "god_ability", Vector2(352, 45), large_radius, 0, 5),
		make_slot(&"god_ability_2", "god_ability", Vector2(180, 157), large_radius, 0, 5),
		make_slot(&"god_ability_3", "god_ability", Vector2(524, 157), large_radius, 0, 5),
		make_slot(&"god_ability_4", "god_ability", Vector2(244, 349), large_radius, 0, 5),
		make_slot(&"god_ability_5", "god_ability", Vector2(460, 349), large_radius, 0, 5),
		make_slot(&"wolf_transformation", "stat", get_pentagram_slot_position(stat_center, stat_cluster_radius, 0, true), small_radius, 4, 4, &"wolf"),
		make_slot(&"health", "stat", get_pentagram_slot_position(stat_center, stat_cluster_radius, 1, true), small_radius, 3, 3, &"health"),
		make_slot(&"stamina", "stat", get_pentagram_slot_position(stat_center, stat_cluster_radius, 2, true), small_radius, 0, 6, &"stamina"),
		make_slot(&"dash_count", "stat", get_pentagram_slot_position(stat_center, stat_cluster_radius, 3, true), small_radius, 0, 3, &"dash"),
		make_slot(&"attack", "stat", get_pentagram_slot_position(stat_center, stat_cluster_radius, 4, true), small_radius, 0, 6, &"damage"),
		make_slot(&"weapon_1", "weapon", Vector2(186, 516), large_radius, 0, 5),
		make_slot(&"weapon_2", "weapon", Vector2(352, 516), large_radius, 0, 5),
		make_slot(&"weapon_3", "weapon", Vector2(518, 516), large_radius, 0, 5),
	]


func get_pentagram_slot_position(center: Vector2, radius: float, index: int, upside_down: bool = false) -> Vector2:
	var start_angle := PI * 0.5 if upside_down else -PI * 0.5
	var angle := start_angle + TAU * float(index) / 5.0
	return center + Vector2(cos(angle), sin(angle)) * radius


func make_slot(slot_id: StringName, slot_type: String, position: Vector2, radius: float, max_level: int, segment_count: int, icon_animation: StringName = &"") -> Dictionary:
	return {
		"slot_id": slot_id,
		"slot_type": slot_type,
		"position": position,
		"radius": radius,
		"max_level": max_level,
		"segment_count": segment_count,
		"icon_animation": icon_animation,
		"icon_frames": ICON_FRAMES,
	}
