extends CharacterBody2D

@export var patrol_path: NodePath
@export var patrol_ping_pong: bool = false
@export var assigned_villager_path: NodePath
@export var villager_follow_target_distance: float = 36.0
@export var villager_follow_distance_tolerance: float = 24.0
@export var villager_follow_speed_modifier: float = 0.35
@export var villager_reversal_front_buffer: float = 4.0
const DEFAULT_TUNING: BansheeTuning = preload("res://assets/characters/HostileNPCs/Banshees/banshee_tuning.tres")

@export var tuning: BansheeTuning = DEFAULT_TUNING

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health = $Health
@onready var hurt_box: Area2D = $HurtBox
@onready var attack_box: Area2D = $AttackBox
@onready var player_detection_area: Area2D = $PlayerDetectionArea
@onready var attack_range: Area2D = $AttackRange
@onready var tracking_range: Area2D = $TrackingRange

var current_state
var states: Dictionary = {}
var hitbox_manager: BansheeAttackBoxManager
var player: Node2D
var assigned_villager: Node2D

var player_in_detection: bool = false
var player_in_attack_range: bool = false
var player_in_tracking: bool = false
var assigned_villager_paused: bool = false
var last_villager_stalk_direction: Vector2 = Vector2.ZERO
var holding_for_villager_reversal: bool = false
var facing_left: bool = false
var attack_cooldown_timer: float = 0.0
var dead: bool = false
var hurt_duration_override: float = -1.0
var hurt_speed_modifier_override: float = -1.0
var patrol_path_node: Path2D
var patrol_curve: Curve2D
var patrol_route_loaded: bool = false
var patrol_path_offset: float = 0.0
var patrol_path_length: float = 0.0
var patrol_ping_pong_direction: float = 1.0
var patrol_points: Array[Vector2] = []
var patrol_point_index: int = 0
var patrol_point_direction: int = 1
var return_patrol_target: Vector2
var return_patrol_path_offset: float = 0.0
var return_patrol_point_index: int = 0
var patrol_speed: float
var patrol_arrival_distance: float
var run_speed: float
var attack_damage: int
var combo_2_damage_bonus: int
var attack_cooldown: float
var attack_damage_start_frame: int
var attack_move_speed_modifier: float
var hurt_move_speed_modifier: float
var block_stun_duration: float
var block_stun_move_speed_modifier: float
var player_stop_distance: float
var facing_deadzone: float


func _ready():
	apply_tuning()

	add_to_group("hostile_npcs")
	configure_collision()
	connect_ranges()

	hitbox_manager = preload("res://assets/characters/HostileNPCs/Banshees/combat/bansheeAttackBoxManager.gd").new()
	hitbox_manager.banshee = self
	hitbox_manager.attack_box = attack_box
	hitbox_manager.attack_damage = attack_damage
	hitbox_manager.combo_2_damage_bonus = combo_2_damage_bonus
	hitbox_manager.setup()

	states["idle"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/idleState.gd").new()
	states["patrol"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/patrolState.gd").new()
	states["return_to_patrol"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/returnToPatrolState.gd").new()
	states["scream"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/screamState.gd").new()
	states["chase"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/chaseState.gd").new()
	states["attack"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/attackState.gd").new()
	states["hurt"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/hurtState.gd").new()
	states["death"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/deathState.gd").new()

	if health.has_method("set_tuning"):
		health.set_tuning(tuning)

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

	player = get_tree().get_first_node_in_group("player")
	resolve_assigned_villager()
	refresh_patrol_points()
	change_state(get_default_state())


func apply_tuning():
	if tuning == null:
		tuning = DEFAULT_TUNING

	patrol_speed = tuning.patrol_speed
	patrol_arrival_distance = tuning.patrol_arrival_distance
	run_speed = tuning.run_speed
	attack_damage = tuning.attack_damage
	combo_2_damage_bonus = tuning.combo_2_damage_bonus
	attack_cooldown = tuning.attack_cooldown
	attack_damage_start_frame = tuning.attack_damage_start_frame
	attack_move_speed_modifier = tuning.attack_move_speed_modifier
	hurt_move_speed_modifier = tuning.hurt_move_speed_modifier
	block_stun_duration = tuning.block_stun_duration
	block_stun_move_speed_modifier = tuning.block_stun_move_speed_modifier
	player_stop_distance = tuning.player_stop_distance
	facing_deadzone = tuning.facing_deadzone


func _physics_process(delta):
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	if current_state:
		current_state.physics_update(self, delta)


func configure_collision():
	collision_layer = 0
	collision_mask = 0

	hurt_box.add_to_group("enemies")
	hurt_box.monitorable = true
	hurt_box.monitoring = true
	hurt_box.collision_layer = 4
	hurt_box.collision_mask = 0

	attack_box.collision_layer = 0
	attack_box.collision_mask = 2

	for area in [player_detection_area, attack_range, tracking_range]:
		area.monitoring = true
		area.monitorable = true
		area.collision_layer = 0
		area.collision_mask = 2


func connect_ranges():
	if not player_detection_area.body_entered.is_connected(_on_player_detection_body_entered):
		player_detection_area.body_entered.connect(_on_player_detection_body_entered)
	if not player_detection_area.body_exited.is_connected(_on_player_detection_body_exited):
		player_detection_area.body_exited.connect(_on_player_detection_body_exited)

	if not attack_range.body_entered.is_connected(_on_attack_range_body_entered):
		attack_range.body_entered.connect(_on_attack_range_body_entered)
	if not attack_range.body_exited.is_connected(_on_attack_range_body_exited):
		attack_range.body_exited.connect(_on_attack_range_body_exited)

	if not tracking_range.body_entered.is_connected(_on_tracking_range_body_entered):
		tracking_range.body_entered.connect(_on_tracking_range_body_entered)
	if not tracking_range.body_exited.is_connected(_on_tracking_range_body_exited):
		tracking_range.body_exited.connect(_on_tracking_range_body_exited)


func change_state(state_name: String):
	if dead and state_name != "death":
		return

	if current_state:
		current_state.exit(self)

	current_state = states[state_name]
	current_state.enter(self)


func get_default_state() -> String:
	if has_patrol_route():
		return "patrol"

	return "idle"


func take_damage(amount: int, ignore_invulnerability: bool = false):
	if dead:
		return

	var damage_applied: bool = health.take_damage(amount, ignore_invulnerability)
	if damage_applied and not dead:
		enter_hurt_state()


func on_attack_blocked():
	if dead:
		return

	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()

	attack_cooldown_timer = max(attack_cooldown_timer, attack_cooldown)
	enter_hurt_state(block_stun_duration, block_stun_move_speed_modifier)


func enter_hurt_state(duration_override: float = -1.0, speed_modifier_override: float = -1.0):
	hurt_duration_override = duration_override
	hurt_speed_modifier_override = speed_modifier_override
	change_state("hurt")


func get_hurt_state_duration(default_duration: float) -> float:
	if hurt_duration_override > 0:
		return hurt_duration_override

	return default_duration


func get_hurt_state_speed_modifier() -> float:
	if hurt_speed_modifier_override > 0:
		return hurt_speed_modifier_override

	return hurt_move_speed_modifier


func clear_hurt_state_overrides():
	hurt_duration_override = -1.0
	hurt_speed_modifier_override = -1.0


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


func get_current_patrol_point() -> Vector2:
	if not has_patrol_route():
		return global_position

	return patrol_points[patrol_point_index]


func advance_patrol_point():
	if not has_patrol_route():
		return

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
	if not has_patrol_route():
		return

	if has_smooth_patrol_route():
		patrol_path_offset = get_nearest_patrol_path_offset(global_position)
		return

	var nearest_index := 0
	var nearest_distance := global_position.distance_squared_to(patrol_points[0])

	for index in range(1, patrol_points.size()):
		var distance := global_position.distance_squared_to(patrol_points[index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	patrol_point_index = nearest_index


func return_to_default_state():
	if has_patrol_route():
		begin_return_to_patrol()
		return

	change_state(get_default_state())


func begin_return_to_patrol():
	if not has_patrol_route():
		change_state("idle")
		return

	return_patrol_path_offset = patrol_path_offset
	return_patrol_point_index = patrol_point_index
	return_patrol_target = get_return_patrol_target()
	change_state("return_to_patrol")


func get_return_patrol_target() -> Vector2:
	if has_smooth_patrol_route():
		return get_patrol_position_at_offset(return_patrol_path_offset)

	return get_current_patrol_point()


func complete_return_to_patrol():
	if has_smooth_patrol_route():
		patrol_path_offset = return_patrol_path_offset
	elif patrol_points.size() > 0:
		patrol_point_index = clamp(return_patrol_point_index, 0, patrol_points.size() - 1)

	velocity = Vector2.ZERO
	resume_assigned_villager()
	change_state("patrol")


func move_toward_return_patrol_target(delta: float) -> bool:
	var to_target := return_patrol_target - global_position
	var return_arrival_distance := 1.0
	if to_target.length() <= return_arrival_distance:
		velocity = Vector2.ZERO
		move_and_slide()
		return true

	var direction := to_target.normalized()
	var return_speed := run_speed
	if delta > 0.0:
		return_speed = min(run_speed, to_target.length() / delta)

	velocity = direction * return_speed
	update_facing(direction)
	sprite.play("run")
	move_and_slide()
	return global_position.distance_to(return_patrol_target) <= return_arrival_distance


func move_along_patrol_route(delta: float):
	if not has_smooth_patrol_route():
		move_along_marker_patrol_route()
		return

	advance_patrol_path_offset(delta)
	var target_position := get_patrol_position_at_offset(patrol_path_offset)
	var to_target := target_position - global_position

	if delta > 0.0:
		velocity = to_target / delta
	else:
		velocity = Vector2.ZERO

	if to_target != Vector2.ZERO:
		update_facing(to_target.normalized())

	sprite.play("walk")
	move_and_slide()


func advance_patrol_path_offset(delta: float):
	if patrol_ping_pong:
		patrol_path_offset += patrol_speed * delta * patrol_ping_pong_direction

		if patrol_path_offset >= patrol_path_length:
			patrol_path_offset = patrol_path_length
			patrol_ping_pong_direction = -1.0
		elif patrol_path_offset <= 0.0:
			patrol_path_offset = 0.0
			patrol_ping_pong_direction = 1.0

		return

	patrol_path_offset = wrapf(patrol_path_offset + patrol_speed * delta, 0.0, patrol_path_length)


func move_along_marker_patrol_route():
	var target_position: Vector2 = get_current_patrol_point()
	var to_target: Vector2 = target_position - global_position

	if to_target.length() <= patrol_arrival_distance:
		advance_patrol_point()
		target_position = get_current_patrol_point()
		to_target = target_position - global_position

	var direction: Vector2 = to_target.normalized()
	velocity = direction * patrol_speed
	update_facing(direction)
	sprite.play("walk")
	move_and_slide()


func get_patrol_position_at_offset(offset: float) -> Vector2:
	if not has_smooth_patrol_route():
		return global_position

	return patrol_path_node.to_global(patrol_curve.sample_baked(offset, true))


func get_nearest_patrol_path_offset(world_position: Vector2) -> float:
	if patrol_path_node == null or patrol_curve == null:
		return 0.0

	return patrol_curve.get_closest_offset(patrol_path_node.to_local(world_position))


func can_attack() -> bool:
	return attack_cooldown_timer <= 0


func resolve_assigned_villager():
	assigned_villager = null
	assigned_villager_paused = false
	last_villager_stalk_direction = Vector2.ZERO
	holding_for_villager_reversal = false

	if str(assigned_villager_path) == "":
		return

	assigned_villager = get_node_or_null(assigned_villager_path) as Node2D
	if assigned_villager == null:
		push_warning("%s could not find assigned villager at %s" % [name, assigned_villager_path])


func has_assigned_villager() -> bool:
	return (
		assigned_villager != null
		and is_instance_valid(assigned_villager)
		and assigned_villager.is_inside_tree()
		and assigned_villager.visible
	)


func pause_assigned_villager():
	if not has_assigned_villager() or assigned_villager_paused:
		return

	assigned_villager_paused = true
	if assigned_villager.has_method("pause_for_banshee"):
		assigned_villager.pause_for_banshee()


func resume_assigned_villager():
	if not assigned_villager_paused:
		return

	assigned_villager_paused = false
	if has_assigned_villager() and assigned_villager.has_method("resume_from_banshee"):
		assigned_villager.resume_from_banshee()


func notify_assigned_villager_banshee_defeated():
	assigned_villager_paused = false
	if has_assigned_villager() and assigned_villager.has_method("on_assigned_banshee_defeated"):
		assigned_villager.on_assigned_banshee_defeated()


func move_toward_assigned_villager():
	if not has_assigned_villager():
		velocity = Vector2.ZERO
		sprite.play("walk")
		move_and_slide()
		return

	var stalk_direction: Vector2 = get_assigned_villager_stalk_direction()
	if should_hold_for_villager_reversal(stalk_direction):
		hold_assigned_villager_stalk()
		last_villager_stalk_direction = stalk_direction
		return

	holding_for_villager_reversal = false
	last_villager_stalk_direction = stalk_direction

	var villager_distance: float = global_position.distance_to(assigned_villager.global_position)
	if villager_distance <= villager_follow_distance_tolerance:
		hold_assigned_villager_stalk()
		return

	var target_position: Vector2 = get_assigned_villager_stalk_anchor_position()
	var offset: Vector2 = target_position - global_position
	var distance: float = offset.length()
	if distance <= villager_follow_distance_tolerance:
		hold_assigned_villager_stalk()
		return

	var direction: Vector2 = offset.normalized()
	velocity = direction * run_speed * villager_follow_speed_modifier
	update_facing(direction)
	sprite.play("walk")
	move_and_slide()


func get_assigned_villager_stalk_direction() -> Vector2:
	if has_assigned_villager() and assigned_villager.has_method("get_stalk_direction"):
		var raw_stalk_direction: Variant = assigned_villager.call("get_stalk_direction")
		if not (raw_stalk_direction is Vector2):
			return last_villager_stalk_direction

		var stalk_direction: Vector2 = raw_stalk_direction
		if stalk_direction != Vector2.ZERO:
			return stalk_direction

	return last_villager_stalk_direction


func get_assigned_villager_stalk_anchor_position() -> Vector2:
	if has_assigned_villager() and assigned_villager.has_method("get_stalk_anchor_position"):
		var raw_anchor_position: Variant = assigned_villager.call("get_stalk_anchor_position", villager_follow_target_distance)
		if raw_anchor_position is Vector2:
			var anchor_position: Vector2 = raw_anchor_position
			return anchor_position

	if has_assigned_villager():
		return assigned_villager.global_position

	return global_position


func should_hold_for_villager_reversal(stalk_direction: Vector2) -> bool:
	if stalk_direction == Vector2.ZERO or last_villager_stalk_direction == Vector2.ZERO:
		return false

	if holding_for_villager_reversal:
		return get_banshee_position_along_villager_direction(stalk_direction) >= -villager_reversal_front_buffer

	if last_villager_stalk_direction.dot(stalk_direction) < -0.6:
		holding_for_villager_reversal = get_banshee_position_along_villager_direction(stalk_direction) >= -villager_reversal_front_buffer
		return holding_for_villager_reversal

	return false


func get_banshee_position_along_villager_direction(stalk_direction: Vector2) -> float:
	if not has_assigned_villager():
		return 0.0

	return (global_position - assigned_villager.global_position).dot(stalk_direction)


func hold_assigned_villager_stalk():
	velocity = Vector2.ZERO
	sprite.play("walk")
	move_and_slide()


func has_player_target() -> bool:
	return player != null and is_instance_valid(player) and player.is_inside_tree() and player.visible


func get_direction_to_player() -> Vector2:
	if not has_player_target():
		return Vector2.ZERO

	return (player.global_position - global_position).normalized()


func face_target():
	if not has_player_target():
		return

	var offset: Vector2 = player.global_position - global_position
	if offset.length() <= player_stop_distance:
		return

	update_facing(offset)


func update_facing(direction: Vector2):
	if abs(direction.x) <= facing_deadzone:
		return

	facing_left = direction.x < 0
	sprite.flip_h = facing_left


func move_toward_player(speed_modifier: float):
	if not has_player_target() or not player_in_tracking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var offset: Vector2 = player.global_position - global_position
	if offset.length() <= player_stop_distance:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = offset.normalized()
	velocity = direction * run_speed * speed_modifier
	update_facing(direction)
	move_and_slide()


func get_animation_duration(anim_name: String, fallback: float) -> float:
	var sprite_frames: SpriteFrames = sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(anim_name):
		return fallback

	var animation_speed: float = sprite_frames.get_animation_speed(anim_name)
	if animation_speed <= 0:
		return fallback

	return float(sprite_frames.get_frame_count(anim_name)) / animation_speed


func get_animation_time_until_frame(anim_name: String, frame_number: int, fallback: float) -> float:
	var sprite_frames: SpriteFrames = sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(anim_name):
		return fallback

	var animation_speed: float = sprite_frames.get_animation_speed(anim_name)
	if animation_speed <= 0:
		return fallback

	var frame_count: int = sprite_frames.get_frame_count(anim_name)
	var frame_index: int = clamp(frame_number - 1, 0, frame_count)
	var time: float = 0.0

	for frame in range(frame_index):
		time += sprite_frames.get_frame_duration(anim_name, frame) / animation_speed

	return time


func disable_combat_areas():
	for area in [hurt_box, attack_box, player_detection_area, attack_range, tracking_range]:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
		for child in area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)


func _on_died():
	dead = true
	notify_assigned_villager_banshee_defeated()
	change_state("death")


func _on_player_detection_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	player = body
	player_in_detection = true
	player_in_tracking = true


func _on_player_detection_body_exited(body: Node2D):
	if body == player:
		player_in_detection = false


func _on_attack_range_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	player = body
	player_in_attack_range = true
	player_in_tracking = true


func _on_attack_range_body_exited(body: Node2D):
	if body == player:
		player_in_attack_range = false


func _on_tracking_range_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	player = body
	player_in_tracking = true


func _on_tracking_range_body_exited(body: Node2D):
	if body != player:
		return

	player_in_tracking = false
	player_in_detection = false
	player_in_attack_range = false
