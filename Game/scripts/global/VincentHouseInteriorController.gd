extends Node2D

signal exit_requested(interior: Node2D)

@export var exit_area_path: NodePath = NodePath("PlayableWorld/Environment/Interactables/PlayerProximityArea")
@export var entry_marker_path: NodePath = NodePath("PlayableWorld/Markers/EntryMarker")
@export var vincent_path: NodePath = NodePath("PlayableWorld/Environment/Characters/Vincent")

var exit_area: Area2D
var vincent: Node2D
var active_room: bool = false


func _ready():
	exit_area = get_node_or_null(exit_area_path) as Area2D
	vincent = get_node_or_null(vincent_path) as Node2D
	connect_exit_area()
	set_active_room(visible)


func interact(_player: Node2D):
	request_exit()


func connect_exit_area():
	if exit_area == null:
		return

	exit_area.collision_layer = 0
	exit_area.collision_mask = 2

	if not exit_area.body_entered.is_connected(_on_exit_area_body_entered):
		exit_area.body_entered.connect(_on_exit_area_body_entered)
	if not exit_area.body_exited.is_connected(_on_exit_area_body_exited):
		exit_area.body_exited.connect(_on_exit_area_body_exited)


func set_active_room(active: bool):
	active_room = active
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if exit_area != null:
		exit_area.monitoring = active
		exit_area.monitorable = active


func set_vincent_present(present: bool):
	if vincent == null:
		return

	vincent.visible = present
	vincent.process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
	if vincent.has_method("set_interaction_enabled"):
		vincent.set_interaction_enabled(present)


func get_vincent() -> Node:
	return vincent


func get_entry_position() -> Vector2:
	var marker := get_node_or_null(entry_marker_path) as Node2D
	if marker != null:
		return marker.global_position

	return global_position


func _on_exit_area_body_entered(body: Node2D):
	if not active_room:
		return

	if not body.is_in_group("player"):
		return

	if body.has_method("register_interactable"):
		body.register_interactable(self)


func _on_exit_area_body_exited(body: Node2D):
	if not body.is_in_group("player"):
		return

	if body.has_method("unregister_interactable"):
		body.unregister_interactable(self)


func request_exit():
	exit_requested.emit(self)
