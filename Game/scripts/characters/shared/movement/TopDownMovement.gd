extends RefCounted

const DEFAULT_MIN_MOVEMENT := 0.1
const DEFAULT_MIN_RECOVERY_SPEED := 4.0
const DEFAULT_MIN_FORWARD_DOT := 0.05


static func move(body: CharacterBody2D, requested_velocity: Vector2, _delta: float = 0.0, min_movement: float = DEFAULT_MIN_MOVEMENT) -> bool:
	if body == null:
		return false

	if requested_velocity == Vector2.ZERO:
		body.velocity = Vector2.ZERO
		return false

	var movement_velocity := get_preferred_static_edge_velocity(body, requested_velocity, _delta)
	body.velocity = movement_velocity
	var before_position := body.global_position
	var collided := body.move_and_slide()
	if before_position.distance_to(body.global_position) > min_movement:
		return true
	if not collided:
		return false

	var recovery_velocity := get_best_static_tangent_velocity(body, requested_velocity)
	if recovery_velocity.length() < DEFAULT_MIN_RECOVERY_SPEED:
		return false

	body.velocity = recovery_velocity
	var recovery_before_position := body.global_position
	body.move_and_slide()
	return recovery_before_position.distance_to(body.global_position) > min_movement


static func get_preferred_static_edge_velocity(body: CharacterBody2D, requested_velocity: Vector2, delta: float) -> Vector2:
	if body == null or requested_velocity == Vector2.ZERO or delta <= 0.0:
		return requested_velocity

	var collision := body.move_and_collide(requested_velocity * delta, true)
	if collision == null or not is_static_world_collider(collision.get_collider()):
		return requested_velocity

	var tangent_velocity := get_tangent_velocity_for_normal(requested_velocity, collision.get_normal())
	if tangent_velocity.length() < DEFAULT_MIN_RECOVERY_SPEED:
		return requested_velocity
	if tangent_velocity.normalized().dot(requested_velocity.normalized()) <= DEFAULT_MIN_FORWARD_DOT:
		return requested_velocity
	return tangent_velocity


static func get_best_static_tangent_velocity(body: CharacterBody2D, requested_velocity: Vector2) -> Vector2:
	if body == null or requested_velocity == Vector2.ZERO:
		return Vector2.ZERO

	var best_velocity := Vector2.ZERO
	var best_score := 0.0
	var requested_direction := requested_velocity.normalized()
	for collision_index in range(body.get_slide_collision_count()):
		var collision := body.get_slide_collision(collision_index)
		if collision == null or not is_static_world_collider(collision.get_collider()):
			continue

		var tangent_velocity := get_tangent_velocity_for_normal(requested_velocity, collision.get_normal())
		if tangent_velocity.length() < DEFAULT_MIN_RECOVERY_SPEED:
			continue

		var forward_score := tangent_velocity.normalized().dot(requested_direction)
		if forward_score <= DEFAULT_MIN_FORWARD_DOT:
			continue

		var score := forward_score * tangent_velocity.length()
		if score > best_score:
			best_score = score
			best_velocity = tangent_velocity

	return best_velocity


static func is_static_world_collider(collider: Object) -> bool:
	return collider is StaticBody2D or collider is TileMap


static func get_tangent_velocity_for_normal(requested_velocity: Vector2, normal: Vector2) -> Vector2:
	if requested_velocity == Vector2.ZERO or normal == Vector2.ZERO:
		return Vector2.ZERO
	return requested_velocity.slide(normal.normalized())
