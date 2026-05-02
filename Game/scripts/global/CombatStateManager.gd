extends Node

signal combat_state_changed(in_combat: bool)
signal dialogue_active_changed(active: bool)

const SAVE_BLOCKER_COMBAT = "combat"

var engaged_hostiles: Dictionary = {}
var dialogue_active: bool = false
var last_in_combat: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	refresh_save_blocker()


func _process(_delta: float):
	update_combat_state()


func is_in_combat() -> bool:
	prune_invalid_hostiles()
	return not engaged_hostiles.is_empty()


func can_start_dialogue() -> bool:
	return not dialogue_active and not is_in_combat()


func is_dialogue_active() -> bool:
	return dialogue_active


func set_dialogue_active(active: bool):
	if dialogue_active == active:
		return

	dialogue_active = active
	dialogue_active_changed.emit(dialogue_active)
	if not dialogue_active:
		refresh_hostile_detection_after_dialogue()


func set_hostile_engaged(hostile: Node, engaged: bool):
	if hostile == null:
		return

	if engaged:
		if not is_instance_valid(hostile) or not hostile.is_inside_tree():
			return
		engaged_hostiles[hostile] = true
	else:
		engaged_hostiles.erase(hostile)

	update_combat_state()


func clear_hostile(hostile: Node):
	set_hostile_engaged(hostile, false)


func clear_all():
	engaged_hostiles.clear()
	update_combat_state()


func update_combat_state():
	prune_invalid_hostiles()
	var now_in_combat: bool = not engaged_hostiles.is_empty()
	refresh_save_blocker()
	if now_in_combat == last_in_combat:
		return

	last_in_combat = now_in_combat
	combat_state_changed.emit(now_in_combat)


func prune_invalid_hostiles():
	for hostile in engaged_hostiles.keys():
		if hostile == null or not is_instance_valid(hostile) or not hostile.is_inside_tree():
			engaged_hostiles.erase(hostile)


func refresh_save_blocker():
	if SaveManager != null and SaveManager.has_method("set_save_blocked"):
		SaveManager.set_save_blocked(SAVE_BLOCKER_COMBAT, not engaged_hostiles.is_empty())


func refresh_hostile_detection_after_dialogue():
	for hostile in get_tree().get_nodes_in_group("hostile_npcs"):
		if hostile != null and hostile.has_method("refresh_player_detection_after_dialogue"):
			hostile.refresh_player_detection_after_dialogue()
