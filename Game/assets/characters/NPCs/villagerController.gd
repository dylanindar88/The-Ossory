extends CharacterBody2D

@export var patrol_path: NodePath
@export var patrol_ping_pong: bool = false
@export var walk_speed: float = 45.0
@export var arrival_distance: float = 6.0

@onready var sprite: AnimatedSprite2D = $Body
@onready var player_proximity_area: Area2D = get_node_or_null("PlayerProximityArea") as Area2D

var patrol_path_node: Path2D
var patrol_curve: Curve2D
var patrol_route_loaded: bool = false
var patrol_path_offset: float = 0.0
var patrol_path_length: float = 0.0
var patrol_ping_pong_direction: float = 1.0
var patrol_points: Array[Vector2] = []
var patrol_point_index: int = 0
var patrol_point_direction: int = 1
var paused_for_banshee: bool = false
var assigned_banshee_defeated: bool = false
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


func pause_for_banshee():
	paused_for_banshee = true
	velocity = Vector2.ZERO
	play_idle_animation()


func resume_from_banshee():
	if assigned_banshee_defeated:
		return

	paused_for_banshee = false


func on_assigned_banshee_defeated():
	assigned_banshee_defeated = true
	paused_for_banshee = false
	velocity = Vector2.ZERO
	play_idle_animation()


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
	return assigned_banshee_defeated or paused_for_banshee or player_in_proximity


func is_player_nearby() -> bool:
	return player_in_proximity


func refresh_patrol_points():
	patrol_points.clear()
	patrol_path_node = null
	patrol_curve = null
	patrol_route_loaded = false
	patrol_path_offset = 0.0
	patrol_path_length = 0.0

	if str(patrol_path) == "":
		patrol_point_index = 0
		return

	var path_node: Node = get_node_or_null(patrol_path)
	if path_node == null:
		patrol_point_index = 0
		return

	var route_path: Path2D = get_route_path(path_node)
	if route_path != null and route_path.curve != null:
		set_patrol_curve(route_path)

	if patrol_curve == null:
		add_marker_patrol_points(path_node)

	if patrol_point_index >= patrol_points.size():
		patrol_point_index = 0

	patrol_route_loaded = has_patrol_route()


func get_route_path(path_node: Node) -> Path2D:
	if path_node is Path2D:
		return path_node as Path2D

	return path_node.get_node_or_null("Path") as Path2D


func set_patrol_curve(path: Path2D):
	patrol_path_node = path
	patrol_curve = path.curve
	patrol_path_length = patrol_curve.get_baked_length()

	if patrol_path_length <= 0.0:
		patrol_path_node = null
		patrol_curve = null
		patrol_path_length = 0.0
		return

	patrol_path_offset = get_nearest_patrol_path_offset(global_position)


func add_marker_patrol_points(path_node: Node):
	var stops_node := path_node.get_node_or_null("Stops")
	if stops_node != null:
		add_marker_patrol_points_from(stops_node)
		if not patrol_points.is_empty():
			return

	add_marker_patrol_points_from(path_node)


func add_marker_patrol_points_from(marker_parent: Node):
	var marker_points: Array[Marker2D] = []
	for child in marker_parent.get_children():
		if child is Marker2D:
			marker_points.append(child as Marker2D)

	marker_points.sort_custom(
		func(a: Marker2D, b: Marker2D):
			return String(a.name).naturalnocasecmp_to(String(b.name)) < 0
	)

	for marker in marker_points:
		patrol_points.append(marker.global_position)


func has_patrol_route() -> bool:
	return patrol_curve != null or patrol_points.size() > 0


func has_smooth_patrol_route() -> bool:
	return patrol_path_node != null and patrol_curve != null and patrol_path_length > 0.0


func move_along_patrol_route(delta: float):
	if not has_smooth_patrol_route():
		move_along_marker_patrol_route(delta)
		return

	advance_patrol_path_offset(delta)
	var target_position := get_patrol_position_at_offset(patrol_path_offset)
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


func advance_patrol_path_offset(delta: float):
	if patrol_ping_pong:
		patrol_path_offset += walk_speed * delta * patrol_ping_pong_direction

		if patrol_path_offset >= patrol_path_length:
			patrol_path_offset = patrol_path_length
			patrol_ping_pong_direction = -1.0
		elif patrol_path_offset <= 0.0:
			patrol_path_offset = 0.0
			patrol_ping_pong_direction = 1.0

		return

	patrol_path_offset = wrapf(patrol_path_offset + walk_speed * delta, 0.0, patrol_path_length)


func move_along_marker_patrol_route(delta: float):
	var target_position: Vector2 = patrol_points[patrol_point_index]
	var to_target: Vector2 = target_position - global_position

	if to_target.length() <= arrival_distance:
		advance_patrol_point()
		target_position = patrol_points[patrol_point_index]
		to_target = target_position - global_position

	var direction := to_target.normalized()
	last_move_direction = direction
	velocity = direction * walk_speed
	update_animation(direction)
	if not move_with_player_blocking(delta):
		resync_patrol_route_to_current_position()


func advance_patrol_point():
	if patrol_ping_pong and patrol_points.size() > 1:
		patrol_point_index += patrol_point_direction

		if patrol_point_index >= patrol_points.size():
			patrol_point_direction = -1
			patrol_point_index = patrol_points.size() - 2
		elif patrol_point_index < 0:
			patrol_point_direction = 1
			patrol_point_index = 1

		return

	patrol_point_index = (patrol_point_index + 1) % patrol_points.size()


func select_nearest_patrol_point():
	if patrol_points.is_empty():
		return

	var nearest_index: int = 0
	var nearest_distance: float = global_position.distance_squared_to(patrol_points[0])

	for index in range(1, patrol_points.size()):
		var distance: float = global_position.distance_squared_to(patrol_points[index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	patrol_point_index = nearest_index


func resync_patrol_route_to_current_position():
	if has_smooth_patrol_route():
		patrol_path_offset = get_nearest_patrol_path_offset(global_position)
		return

	select_nearest_patrol_point()


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
	if not has_smooth_patrol_route():
		return global_position

	return patrol_path_node.to_global(patrol_curve.sample_baked(offset, true))


func get_nearest_patrol_path_offset(world_position: Vector2) -> float:
	if patrol_path_node == null or patrol_curve == null:
		return 0.0

	return patrol_curve.get_closest_offset(patrol_path_node.to_local(world_position))


func get_stalk_direction() -> Vector2:
	return last_move_direction


func get_stalk_anchor_position(distance: float) -> Vector2:
	if has_smooth_patrol_route():
		return get_patrol_position_at_offset(get_stalk_anchor_path_offset(distance))

	if last_move_direction == Vector2.ZERO:
		return global_position

	return global_position - last_move_direction * distance


func get_stalk_anchor_path_offset(distance: float) -> float:
	var safe_distance: float = distance
	if safe_distance < 0.0:
		safe_distance = 0.0

	if patrol_ping_pong:
		var anchor_offset: float = patrol_path_offset - patrol_ping_pong_direction * safe_distance
		if anchor_offset < 0.0:
			return 0.0
		if anchor_offset > patrol_path_length:
			return patrol_path_length

		return anchor_offset

	return wrapf(patrol_path_offset - safe_distance, 0.0, patrol_path_length)


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
