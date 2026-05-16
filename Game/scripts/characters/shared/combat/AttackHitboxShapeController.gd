class_name AttackHitboxShapeController
extends RefCounted

var attack_box: Area2D
var collision_shape: CollisionShape2D
var base_position: Vector2 = Vector2.ZERO
var base_rotation: float = 0.0
var base_scale: Vector2 = Vector2.ONE
var base_rectangle_size: Vector2 = Vector2.ZERO


func setup(new_attack_box: Area2D):
	attack_box = new_attack_box
	collision_shape = find_attack_collision_shape()
	cache_base_transform()
	disable_shape()


func find_attack_collision_shape() -> CollisionShape2D:
	if attack_box == null:
		return null

	for child in attack_box.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D

	return null


func cache_base_transform():
	if collision_shape == null:
		return

	base_position = collision_shape.position
	base_rotation = collision_shape.rotation
	base_scale = collision_shape.scale
	if collision_shape.shape is RectangleShape2D:
		base_rectangle_size = (collision_shape.shape as RectangleShape2D).size


func enable_shape():
	if collision_shape == null:
		return

	collision_shape.set_deferred("disabled", false)
	collision_shape.visible = true


func disable_shape(restore_transform: bool = true):
	if collision_shape == null:
		return

	if restore_transform:
		restore_base_transform()
	collision_shape.set_deferred("disabled", true)
	collision_shape.visible = false


func restore_base_transform():
	if collision_shape == null:
		return

	collision_shape.position = base_position
	collision_shape.rotation = base_rotation
	collision_shape.scale = base_scale
	if collision_shape.shape is RectangleShape2D and base_rectangle_size != Vector2.ZERO:
		(collision_shape.shape as RectangleShape2D).size = base_rectangle_size


func apply_profile(profile: Dictionary):
	if collision_shape == null:
		return

	restore_base_transform()
	if profile.has("size"):
		if collision_shape.shape is RectangleShape2D:
			(collision_shape.shape as RectangleShape2D).size = profile["size"]
		else:
			push_warning("AttackBox CollisionShape2D must use RectangleShape2D to apply size profiles.")
	if profile.has("position"):
		collision_shape.position = profile["position"]
	if profile.has("rotation"):
		collision_shape.rotation = profile["rotation"]
	if profile.has("scale"):
		collision_shape.scale = profile["scale"]


func apply_offset(offset: Vector2):
	if collision_shape == null:
		return

	restore_base_transform()
	collision_shape.position = base_position + offset


func get_base_rectangle_height() -> float:
	if base_rectangle_size == Vector2.ZERO:
		return 0.0

	return base_rectangle_size.y * abs(base_scale.y)


func apply_horizontal_flip(facing_left: bool):
	if collision_shape == null:
		return

	restore_base_transform()
	collision_shape.position.x = -abs(base_position.x) if facing_left else abs(base_position.x)
