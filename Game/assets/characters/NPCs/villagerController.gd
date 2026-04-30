extends CharacterBody2D

@export var patrol_path: NodePath
@export var patrol_ping_pong: bool = false
@export var walk_speed: float = 45.0
@export var arrival_distance: float = 6.0

@onready var sprite: AnimatedSprite2D = $Body
@onready var player_proximity_area: Area2D = get_node_or_null("PlayerProximityArea") as Area2D

var patrol_route := PatrolRoute.new()
var paused_by_external_actor: bool = false
var external_pause_completed: bool = false
var player_in_proximity: bool = false
var player_proximity_needs_resync: bool = false
var last_facing: String = "down"
var last_horizontal_facing: String = "right"
var last_move_direction: Vector2 = Vector2.ZERO


func _ready():
	add_to_group("villagers")
	connect_player_proximity_area()
	refresh_patrol_points()


func _physics_process(delta):
	if should_idle() or not has_patrol_route():
		velocity = Vector2.ZERO
		play_idle_animation()
		return

	move_along_patrol_route(delta)


func pause_for_external_actor():
	paused_by_external_actor = true
	velocity = Vector2.ZERO
	play_idle_animation()


func resume_from_external_actor():
	if external_pause_completed:
		return

	paused_by_external_actor = false


func complete_external_pause():
	external_pause_completed = true
	paused_by_external_actor = false
	velocity = Vector2.ZERO
	play_idle_animation()


func pause_for_banshee():
	pause_for_external_actor()


func resume_from_banshee():
	resume_from_external_actor()


func on_assigned_banshee_defeated():
	complete_external_pause()


func connect_player_proximity_area():
	if player_proximity_area == null:
		return

	player_proximity_area.monitoring = true
	player_proximity_area.monitorable = true
	player_proximity_area.collision_layer = 0
	player_proximity_area.collision_mask = 2

	if not player_proximity_area.body_entered.is_connected(_on_player_proximity_body_entered):
		player_proximity_area.body_entered.connect(_on_player_proximity_body_entered)
	if not player_proximity_area.body_exited.is_connected(_on_player_proximity_body_exited):
		player_proximity_area.body_exited.connect(_on_player_proximity_body_exited)


func should_idle() -> bool:
	return external_pause_completed or paused_by_external_actor or player_in_proximity


func is_player_nearby() -> bool:
	return player_in_proximity


func refresh_patrol_points():
	patrol_route.refresh(self, patrol_path)


func has_patrol_route() -> bool:
	return patrol_route.has_route()


func has_smooth_patrol_route() -> bool:
	return patrol_route.has_smooth_route()


func move_along_patrol_route(delta: float):
	if not has_smooth_patrol_route():
		move_along_marker_patrol_route(delta)
		return

	patrol_route.advance_path_offset(walk_speed, delta, patrol_ping_pong)
	var target_position := get_patrol_position_at_offset(patrol_route.path_offset)
	var to_target := target_position - global_position

	if delta > 0.0:
		velocity = to_target / delta
	else:
		velocity = Vector2.ZERO

	if to_target != Vector2.ZERO:
		var direction: Vector2 = to_target.normalized()
		last_move_direction = direction
		update_animation(direction)

	if not move_with_player_blocking(delta):
		resync_patrol_route_to_current_position()


func move_along_marker_patrol_route(delta: float):
	var target_position: Vector2 = patrol_route.get_current_point(global_position)
	var to_target: Vector2 = target_position - global_position

	if to_target.length() <= arrival_distance:
		patrol_route.advance_point(patrol_ping_pong)
		target_position = patrol_route.get_current_point(global_position)
		to_target = target_position - global_position

	var direction := to_target.normalized()
	last_move_direction = direction
	velocity = direction * walk_speed
	update_animation(direction)
	if not move_with_player_blocking(delta):
		resync_patrol_route_to_current_position()


func resync_patrol_route_to_current_position():
	patrol_route.select_nearest(global_position)


func move_with_player_blocking(delta: float) -> bool:
	var motion: Vector2 = velocity * delta
	if should_stop_for_character_blocker(motion):
		velocity = Vector2.ZERO
		play_idle_animation()
		return false

	move_and_slide()
	return true


func should_stop_for_character_blocker(motion: Vector2) -> bool:
	if motion == Vector2.ZERO:
		return false

	var collision: KinematicCollision2D = move_and_collide(motion, true)
	if collision == null:
		return false

	var collider: Object = collision.get_collider()
	if not (collider is Node2D):
		return false

	var collider_node: Node2D = collider as Node2D
	var is_character_blocker: bool = collider_node.is_in_group("player") or collider_node.is_in_group("villagers")
	return is_character_blocker and is_motion_toward_node(collider_node, motion)


func is_motion_toward_node(node: Node2D, motion: Vector2) -> bool:
	var current_distance: float = global_position.distance_squared_to(node.global_position)
	var next_distance: float = (global_position + motion).distance_squared_to(node.global_position)
	return next_distance < current_distance


func get_patrol_position_at_offset(offset: float) -> Vector2:
	return patrol_route.get_position_at_offset(offset, global_position)


func get_nearest_patrol_path_offset(world_position: Vector2) -> float:
	return patrol_route.get_nearest_path_offset(world_position)


func get_stalk_direction() -> Vector2:
	return last_move_direction


func get_stalk_anchor_position(distance: float) -> Vector2:
	return patrol_route.get_anchor_position(global_position, distance, patrol_ping_pong, last_move_direction)


func update_animation(direction: Vector2):
	if abs(direction.y) > abs(direction.x):
		if direction.y < 0:
			last_facing = "up"
			sprite.flip_h = false
			sprite.play("walk_up" if has_animation("walk_up") else "walk")
			return

		last_facing = "down"
		sprite.flip_h = false
		sprite.play("walk_down" if has_animation("walk_down") else "walk")
		return

	last_facing = "left" if direction.x < 0 else "right"
	last_horizontal_facing = last_facing
	sprite.flip_h = direction.x < 0
	sprite.play("walk")


func play_idle_animation():
	if last_facing == "up" and has_animation("idle_up"):
		sprite.flip_h = false
		sprite.play("idle_up")
		return

	sprite.flip_h = last_horizontal_facing == "left"
	sprite.play("idle")


func has_animation(anim_name: String) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)


func _on_player_proximity_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	player_in_proximity = true
	player_proximity_needs_resync = true


func _on_player_proximity_body_exited(body: Node2D):
	if not body.is_in_group("player"):
		return

	player_in_proximity = false
	if player_proximity_needs_resync:
		resync_patrol_route_to_current_position()
		player_proximity_needs_resync = false
