extends Area2D

@export var route_id: String = ""
@export_file("*.tscn") var destination_scene_path: String = ""
@export var destination_entry_marker_path: NodePath = NodePath("")
@export var blocked_message: String = "This path is not available yet."
@export var missing_destination_message: String = "No destination has been assigned for this route yet."

var travel_enabled: bool = true


func _ready():
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 2

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func interact(_player: Node2D):
	if not travel_enabled:
		push_warning(blocked_message)
		return

	if destination_scene_path == "" or not ResourceLoader.exists(destination_scene_path):
		push_warning(missing_destination_message)
		return

	if SaveManager != null and SaveManager.has_method("prepare_current_level_for_route_exit"):
		SaveManager.prepare_current_level_for_route_exit()
	if SaveManager != null and SaveManager.has_method("save_game"):
		SaveManager.save_game("route_exit_%s" % get_route_save_id(), get_tree().current_scene)

	if SaveManager != null and SaveManager.has_method("change_scene_to_file_and_load"):
		SaveManager.change_scene_to_file_and_load(destination_scene_path, SaveManager.AUTOSAVE_SLOT, false, "route_enter_%s" % get_route_save_id(), destination_entry_marker_path)
	else:
		get_tree().change_scene_to_file(destination_scene_path)


func set_travel_enabled(enabled: bool):
	travel_enabled = enabled


func get_route_save_id() -> String:
	if route_id != "":
		return route_id

	return name.to_lower()


func _on_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	if body.has_method("register_interactable"):
		body.register_interactable(self)


func _on_body_exited(body: Node2D):
	if not body.is_in_group("player"):
		return

	if body.has_method("unregister_interactable"):
		body.unregister_interactable(self)
