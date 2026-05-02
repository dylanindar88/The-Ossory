extends TextureProgressBar

const HEALTH_BAR_COLOR = preload("res://scripts/ui/HealthBarColor.gd")

@onready var bar_container: Node = get_parent()
@onready var health_node: Node = bar_container.get_parent().get_node_or_null("Health")


func _ready():
	bar_container.visible = false

	if health_node == null:
		return

	min_value = 0.0
	max_value = int(health_node.get("max_health"))
	value = int(health_node.get("health"))
	update_color()
	update_visibility()

	if health_node.has_signal("health_changed"):
		var callback: Callable = Callable(self, "_on_health_changed")
		if not health_node.is_connected("health_changed", callback):
			health_node.connect("health_changed", callback)


func _on_health_changed(current_health: int, max_health: int):
	max_value = max_health
	value = current_health
	update_color()
	update_visibility()


func update_color():
	HEALTH_BAR_COLOR.apply_to_bar(self, float(value), float(max_value))


func update_visibility():
	bar_container.visible = value > min_value and value < max_value
