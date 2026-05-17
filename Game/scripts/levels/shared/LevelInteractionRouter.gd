extends Node

@export var level_controller_path: NodePath = NodePath("")
@export var player_group: StringName = &"player"

var player: Node
var level_controller: Node


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("refresh_connections")


func _exit_tree():
	disconnect_player()
	player = null
	level_controller = null
	set_process(false)
	var tree := get_tree() if is_inside_tree() else null
	if tree != null and tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.disconnect(_on_tree_node_added)


func _process(_delta):
	refresh_connections()


func refresh_connections():
	if not is_inside_tree():
		disconnect_player()
		player = null
		level_controller = null
		set_process(false)
		return

	var tree := get_tree()
	if tree == null:
		disconnect_player()
		player = null
		level_controller = null
		set_process(false)
		return

	resolve_level_controller()
	var current_player: Node = tree.get_first_node_in_group(player_group)
	if current_player == player and is_player_connected():
		set_process(false)
		return

	disconnect_player()
	player = current_player
	connect_player()
	set_process(not is_player_connected())


func resolve_level_controller():
	if level_controller_path.is_empty():
		level_controller = null
		return

	level_controller = get_node_or_null(level_controller_path)


func connect_player():
	if not is_valid_player_reference() or not player.has_signal("interaction_requested"):
		return

	var callback := Callable(self, "_on_player_interaction_requested")
	if not player.is_connected("interaction_requested", callback):
		player.connect("interaction_requested", callback)


func disconnect_player():
	if not is_valid_player_reference() or not player.has_signal("interaction_requested"):
		return

	var callback := Callable(self, "_on_player_interaction_requested")
	if player.is_connected("interaction_requested", callback):
		player.disconnect("interaction_requested", callback)


func is_player_connected() -> bool:
	if not is_valid_player_reference() or not player.has_signal("interaction_requested"):
		return false

	return player.is_connected("interaction_requested", Callable(self, "_on_player_interaction_requested"))


func is_valid_player_reference() -> bool:
	return player != null and is_instance_valid(player)


func _on_player_interaction_requested(interactable: Node2D):
	if interactable == null or not is_instance_valid(interactable):
		return

	if level_controller != null and level_controller.has_method("handle_level_interaction"):
		var handled: Variant = level_controller.call("handle_level_interaction", interactable, player)
		if handled is bool and handled:
			return

	if interactable.has_method("interact"):
		interactable.interact(player)


func _on_tree_node_added(_node: Node):
	if not is_inside_tree():
		return
	call_deferred("refresh_connections")
