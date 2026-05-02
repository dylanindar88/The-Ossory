extends Area2D

@export var interactable_source_path: NodePath = NodePath("..")

var interactable_source: Node2D


func _ready():
	interactable_source = get_node_or_null(interactable_source_path) as Node2D
	if interactable_source == null:
		interactable_source = get_parent() as Node2D

	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 2

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	if body.has_method("register_interactable"):
		body.register_interactable(interactable_source)


func _on_body_exited(body: Node2D):
	if not body.is_in_group("player"):
		return

	if body.has_method("unregister_interactable"):
		body.unregister_interactable(interactable_source)
