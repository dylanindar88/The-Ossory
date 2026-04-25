class_name AttackBoxManager
extends RefCounted

var attack_box: Area2D
var collision_shape: CollisionShape2D
var attack_damage := 10

var active_attack_targets: Array[Node2D] = []
var current_combo_part: int = 0

var attack_profiles := {
	"right": {
		1: {"size": Vector2(21, 31), "position": Vector2(18, -32), "rotation": -PI / 2.0},
		2: {"size": Vector2(21, 41), "position": Vector2(23, -32), "rotation": -PI / 2.0},
		3: {"size": Vector2(21, 31), "position": Vector2(18, -32), "rotation": -PI / 2.0},
	},
	"left": {
		1: {"size": Vector2(21, 31), "position": Vector2(-18, -32), "rotation": -PI / 2.0},
		2: {"size": Vector2(21, 41), "position": Vector2(-23, -32), "rotation": -PI / 2.0},
		3: {"size": Vector2(21, 31), "position": Vector2(-18, -32), "rotation": -PI / 2.0},
	},
	"down": {
		1: {"size": Vector2(26, 52), "position": Vector2(0, -12), "rotation": 0.0},
		2: {"size": Vector2(26, 62), "position": Vector2(0, -7), "rotation": 0.0},
		3: {"size": Vector2(26, 52), "position": Vector2(0, -12), "rotation": 0.0},
	},
	"up": {
		1: {"size": Vector2(21, 42), "position": Vector2(0, -43), "rotation": 0.0},
		2: {"size": Vector2(21, 52), "position": Vector2(0, -48), "rotation": 0.0},
		3: {"size": Vector2(21, 42), "position": Vector2(0, -43), "rotation": 0.0},
	},
}


func setup():
	if attack_box == null:
		return

	attack_box.monitoring = true

	collision_shape = get_attack_collision_shape()
	if collision_shape:
		collision_shape.disabled = true

	if not attack_box.area_entered.is_connected(_on_attack_hit):
		attack_box.area_entered.connect(_on_attack_hit)


func activate_attack_hitbox(combo_part: int, direction: String):
	if attack_box == null:
		return

	current_combo_part = combo_part
	active_attack_targets.clear()

	update_attackbox_shape(combo_part, direction)

	if collision_shape:
		collision_shape.disabled = false


func deactivate_attack_hitbox():
	if attack_box == null:
		return

	if collision_shape:
		collision_shape.disabled = true

	active_attack_targets.clear()
	current_combo_part = 0


func update_attackbox_shape(combo_part: int, direction: String):
	if collision_shape == null:
		push_warning("AttackBox has no CollisionShape2D child.")
		return

	var shape = collision_shape.shape

	if shape == null or not shape is RectangleShape2D:
		push_warning("AttackBox CollisionShape2D must use RectangleShape2D.")
		return

	var profile := get_attack_profile(direction, combo_part)

	shape.size = profile["size"]
	collision_shape.position = profile["position"]
	collision_shape.rotation = profile["rotation"]


func get_attack_profile(direction: String, combo_part: int) -> Dictionary:
	var direction_profiles: Dictionary = attack_profiles.get(direction, attack_profiles["right"])
	return direction_profiles.get(combo_part, direction_profiles[1])


func get_attack_collision_shape() -> CollisionShape2D:
	if attack_box == null:
		return null

	for child in attack_box.get_children():
		if child is CollisionShape2D:
			return child

	return null


func has_hit_target(target: Node2D) -> bool:
	return target in active_attack_targets


func register_hit(target: Node2D):
	if not has_hit_target(target):
		active_attack_targets.append(target)


func _on_attack_hit(area: Area2D):
	if area == null:
		return

	if not area.is_in_group("enemies"):
		return

	var target = area.get_parent()

	if target == null:
		return

	if has_hit_target(target):
		return

	register_hit(target)

	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
