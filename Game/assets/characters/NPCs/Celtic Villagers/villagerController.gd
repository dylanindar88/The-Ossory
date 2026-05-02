extends CharacterBody2D

signal dialogue_finished(villager: Node)
signal player_left_proximity(villager: Node)

const DIALOGUE_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/DialogueBubble.tscn")

@export var patrol_path: NodePath
@export var patrol_ping_pong: bool = false
@export var walk_speed: float = 45.0
@export var arrival_distance: float = 6.0
@export_group("Ambient Patrol")
@export var ambient_enabled: bool = false
@export_range(0.1, 10.0, 0.1) var ambient_check_interval_seconds: float = 1.25
@export_range(0.0, 1.0, 0.01) var ambient_stop_chance: float = 0.05
@export var ambient_stop_cooldown_seconds: float = 7.0
@export var ambient_idle_min_seconds: float = 1.0
@export var ambient_idle_max_seconds: float = 2.25
@export var ambient_marker_stop_radius: float = 32.0
@export var ambient_marker_stop_multiplier: float = 2.0
@export var ambient_house_stop_radius: float = 38.0
@export var ambient_house_stop_multiplier: float = 4.0
@export var ambient_house_idle_min_seconds: float = 1.5
@export var ambient_house_idle_max_seconds: float = 3.5
@export_range(0.0, 1.0, 0.01) var ambient_reverse_chance: float = 0.18
@export_range(0.0, 1.0, 0.01) var ambient_social_chance: float = 0.14
@export var ambient_social_radius: float = 54.0
@export var ambient_social_cooldown_seconds: float = 12.0
@export var ambient_social_min_seconds: float = 1.5
@export var ambient_social_max_seconds: float = 3.25
@export_group("")
@export var dialogue_bank: DialogueBank
@export var dialogue_override_sequence: DialogueSequence

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
var dialogue_active: bool = false
var active_dialogue_bubble: DialogueBubble
var current_dialogue_player: Node2D
var ambient_behavior: VillagerAmbientPatrolBehavior = VillagerAmbientPatrolBehavior.new()


func _ready():
	add_to_group("villagers")
	connect_player_proximity_area()
	refresh_patrol_points()
	ambient_behavior.setup(self, patrol_path)


func _physics_process(delta):
	if should_idle() or not has_patrol_route():
		clear_ambient_behavior()
		velocity = Vector2.ZERO
		play_idle_animation()
		return

	ambient_behavior.update(delta, can_start_ambient_behavior())
	if ambient_behavior.consume_reverse_after_idle():
		patrol_route.reverse_direction()

	if ambient_behavior.is_busy():
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


func set_dialogue_override(sequence: DialogueSequence):
	dialogue_override_sequence = sequence


func clear_dialogue_override():
	dialogue_override_sequence = null


func pause_for_story():
	pause_for_external_actor()


func resume_from_story():
	resume_from_external_actor()


func complete_story_pause():
	complete_external_pause()


func reset_story_pause():
	external_pause_completed = false
	paused_by_external_actor = false
	velocity = Vector2.ZERO
	resync_patrol_route_to_current_position()


func apply_saved_story_pause_state(paused: bool, completed: bool):
	paused_by_external_actor = paused
	external_pause_completed = completed
	if external_pause_completed or paused_by_external_actor:
		velocity = Vector2.ZERO
		play_idle_animation()


func collect_story_save_state() -> Dictionary:
	return {
		"position": vector_to_data(global_position),
		"last_facing": last_facing,
		"last_horizontal_facing": last_horizontal_facing,
		"last_move_direction": vector_to_data(last_move_direction),
		"paused_by_external_actor": paused_by_external_actor,
		"external_pause_completed": external_pause_completed,
		"patrol_route": patrol_route.to_save_data(),
	}


func apply_story_save_state(state: Dictionary):
	if dialogue_active:
		end_dialogue()

	clear_ambient_behavior()
	global_position = data_to_vector(state.get("position", {}), global_position)
	velocity = Vector2.ZERO
	last_facing = str(state.get("last_facing", last_facing))
	last_horizontal_facing = str(state.get("last_horizontal_facing", last_horizontal_facing))
	last_move_direction = data_to_vector(state.get("last_move_direction", {}), last_move_direction)
	paused_by_external_actor = bool(state.get("paused_by_external_actor", false))
	external_pause_completed = bool(state.get("external_pause_completed", false))
	player_in_proximity = false
	player_proximity_needs_resync = false
	current_dialogue_player = null
	refresh_patrol_points()
	patrol_route.apply_save_data(state.get("patrol_route", {}))
	play_idle_animation()


func vector_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func data_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	if not (value is Dictionary):
		return fallback

	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


func pause_for_banshee():
	pause_for_story()


func resume_from_banshee():
	resume_from_story()


func on_assigned_banshee_defeated():
	complete_story_pause()


func reset_banshee_stalk_state():
	reset_story_pause()


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
	return external_pause_completed or paused_by_external_actor or player_in_proximity or dialogue_active


func can_start_ambient_behavior() -> bool:
	return ambient_enabled and has_patrol_route() and not should_idle()


func clear_ambient_behavior():
	if ambient_behavior != null:
		var partner: Node2D = ambient_behavior.get_social_partner()
		ambient_behavior.reset()
		if partner != null and partner.has_method("cancel_ambient_social_with"):
			partner.cancel_ambient_social_with(self)


func cancel_ambient_social_with(partner: Node2D):
	if ambient_behavior != null:
		ambient_behavior.cancel_social_with(partner)


func is_available_for_ambient_social() -> bool:
	return can_start_ambient_behavior() and ambient_behavior != null and not ambient_behavior.is_busy()


func begin_ambient_social(partner: Node2D, duration: float):
	if not is_available_for_ambient_social():
		return

	ambient_behavior.start_social_with(partner, duration)


func is_player_nearby() -> bool:
	return player_in_proximity


func refresh_patrol_points():
	patrol_route.refresh(self, patrol_path)
	if ambient_behavior != null:
		ambient_behavior.refresh_markers(patrol_path)


func has_patrol_route() -> bool:
	return patrol_route.has_route()


func has_smooth_patrol_route() -> bool:
	return patrol_route.has_smooth_route()


func move_along_patrol_route(delta: float):
	if not has_smooth_patrol_route():
		move_along_marker_patrol_route(delta)
		return

	patrol_route.advance_path_offset(walk_speed, delta, patrol_ping_pong)
	var target_position: Vector2 = get_patrol_position_at_offset(patrol_route.path_offset)
	var to_target: Vector2 = target_position - global_position

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

	var direction: Vector2 = to_target.normalized()
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


func interact(player: Node2D):
	if dialogue_active:
		if active_dialogue_bubble != null:
			active_dialogue_bubble.advance()
		return

	if CombatStateManager != null and not CombatStateManager.can_start_dialogue():
		return

	var sequence: DialogueSequence = get_dialogue_sequence()
	if sequence == null or sequence.is_empty():
		return

	start_dialogue(player, sequence)


func get_dialogue_sequence() -> DialogueSequence:
	if dialogue_override_sequence != null:
		return dialogue_override_sequence

	if dialogue_bank != null:
		return dialogue_bank.get_sequence()

	return null


func start_dialogue(player: Node2D, sequence: DialogueSequence):
	if CombatStateManager != null and not CombatStateManager.can_start_dialogue():
		return

	current_dialogue_player = player
	dialogue_active = true
	velocity = Vector2.ZERO
	face_node(player)
	play_idle_animation()
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(true)
	if current_dialogue_player != null and current_dialogue_player.has_method("set_dialogue_input_locked"):
		current_dialogue_player.set_dialogue_input_locked(true)

	active_dialogue_bubble = DIALOGUE_BUBBLE_SCENE.instantiate() as DialogueBubble
	add_child(active_dialogue_bubble)
	if not active_dialogue_bubble.closed.is_connected(_on_dialogue_bubble_closed):
		active_dialogue_bubble.closed.connect(_on_dialogue_bubble_closed)
	active_dialogue_bubble.open(sequence)


func end_dialogue():
	if active_dialogue_bubble != null and is_instance_valid(active_dialogue_bubble):
		active_dialogue_bubble.close(false)
		return

	_on_dialogue_bubble_closed(false)


func face_node(node: Node2D):
	if node == null or not is_instance_valid(node):
		return

	var offset: Vector2 = node.global_position - global_position
	if offset == Vector2.ZERO:
		return

	if abs(offset.y) > abs(offset.x):
		last_facing = "up" if offset.y < 0.0 else "down"
		return

	last_facing = "left" if offset.x < 0.0 else "right"
	last_horizontal_facing = last_facing


func _on_dialogue_bubble_closed(completed: bool = false):
	active_dialogue_bubble = null
	var was_dialogue_active: bool = dialogue_active
	var dialogue_player: Node2D = current_dialogue_player
	dialogue_active = false
	current_dialogue_player = null
	if dialogue_player != null and is_instance_valid(dialogue_player) and dialogue_player.has_method("set_dialogue_input_locked"):
		dialogue_player.set_dialogue_input_locked(false)
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(false)
	if was_dialogue_active and completed:
		dialogue_finished.emit(self)


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
	player_left_proximity.emit(self)
