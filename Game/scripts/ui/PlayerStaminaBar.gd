extends TextureProgressBar

@onready var stamina_container: Node = get_parent()
@onready var health_node: Node = stamina_container.get_parent().get_node_or_null("Health")


func _ready():
	stamina_container.visible = false

	if health_node == null:
		return

	min_value = 0.0
	max_value = health_node.max_stamina
	value = health_node.stamina
	update_visibility()

	if not health_node.stamina_changed.is_connected(_on_stamina_changed):
		health_node.stamina_changed.connect(_on_stamina_changed)


func _on_stamina_changed(current_stamina: float, max_stamina: float):
	max_value = max_stamina
	value = current_stamina
	update_visibility()


func update_visibility():
	stamina_container.visible = value < max_value
