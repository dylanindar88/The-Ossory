extends Control

@onready var health_bar = $HealthBar
@onready var player = get_tree().get_first_node_in_group("player")

var health_node

func _ready():
	if player == null:
		return

	health_node = player.get_node_or_null("Health")

	if health_node == null:
		return

	setup_health_bar()


func setup_health_bar():
	health_bar.min_value = 0
	health_bar.max_value = health_node.max_health
	health_bar.value = health_node.health

	if not health_node.health_changed.is_connected(_on_health_changed):
		health_node.health_changed.connect(_on_health_changed)


func _on_health_changed(current_health: int, max_health: int):
	health_bar.max_value = max_health
	health_bar.value = current_health
