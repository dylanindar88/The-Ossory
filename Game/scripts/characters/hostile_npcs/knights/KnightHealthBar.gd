extends TextureProgressBar

const HEALTH_BAR_COLOR = preload("res://scripts/ui/HealthBarColor.gd")

@onready var bar_container: CanvasItem = get_parent() as CanvasItem
@onready var health_node: Node = bar_container.get_parent().get_node_or_null("Health")


func _ready():
	if bar_container != null:
		bar_container.visible = false

	if health_node == null:
		return

	min_value = 0.0
	max_value = get_numeric_health_value("max_health", 1)
	value = get_numeric_health_value("health", int(max_value))
	update_color()
	update_visibility()

	if health_node.has_signal("health_changed"):
		var callback := Callable(self, "_on_health_changed")
		if not health_node.is_connected("health_changed", callback):
			health_node.connect("health_changed", callback)


func _on_health_changed(current_health: int, new_max_health: int):
	max_value = new_max_health
	value = current_health
	update_color()
	update_visibility()


func update_color():
	HEALTH_BAR_COLOR.apply_to_bar(self, float(value), float(max_value))


func update_visibility():
	if bar_container != null:
		bar_container.visible = value > min_value and value < max_value


func get_numeric_health_value(property_name: String, fallback: int) -> int:
	var raw_value: Variant = health_node.get(property_name)
	if raw_value is int:
		return raw_value
	if raw_value is float:
		return int(raw_value)
	return fallback
