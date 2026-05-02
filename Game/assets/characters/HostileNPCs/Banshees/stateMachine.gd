extends CharacterBody2D

signal defeated(banshee: Node)
signal player_detected_for_reveal(banshee: Node)

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
var current_state_name: String = ""
var states: Dictionary = {}
var hitbox_manager: BansheeAttackBoxManager
var player: Node2D
var patrol_route := PatrolRoute.new()
var villager_stalk_behavior := BansheeVillagerStalkBehavior.new()

var player_in_detection: bool = false
var player_in_attack_range: bool = false
var player_in_tracking: bool = false
var facing_left: bool = false
var attack_cooldown_timer: float = 0.0
var dead: bool = false
var hurt_duration_override: float = -1.0
var hurt_speed_modifier_override: float = -1.0
var return_patrol_target: Vector2
var return_patrol_path_offset: float = 0.0
var return_patrol_point_index: int = 0
var patrol_speed: float
var patrol_arrival_distance: float
var run_speed: float
var attack_cooldown: float
var attack_damage_start_frame: int
var attack_move_speed_modifier: float
var hurt_move_speed_modifier: float
var block_stun_duration: float
var block_stun_move_speed_modifier: float
var player_stop_distance: float
var facing_deadzone: float
var combat_enabled: bool = true
var story_revealed: bool = false
var story_spawn_position: Vector2
var story_spawn_facing_left: bool = false


func _ready():
	apply_tuning()
	story_spawn_position = global_position
	story_spawn_facing_left = facing_left

	add_to_group("hostile_npcs")
	configure_collision()
	connect_ranges()
	setup_villager_stalk_behavior()

	hitbox_manager = preload("res://assets/characters/HostileNPCs/Banshees/combat/bansheeAttackBoxManager.gd").new()
	hitbox_manager.banshee = self
	hitbox_manager.attack_box = attack_box
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
	refresh_patrol_points()
	change_state(get_default_state())


func apply_tuning():
	if tuning == null:
		tuning = DEFAULT_TUNING

	patrol_speed = tuning.patrol_speed
	patrol_arrival_distance = tuning.patrol_arrival_distance
	run_speed = tuning.run_speed
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


func setup_villager_stalk_behavior():
	villager_stalk_behavior.setup(
		self,
		assigned_villager_path,
		villager_follow_target_distance,
		villager_follow_distance_tolerance,
		villager_follow_speed_modifier,
		villager_reversal_front_buffer
	)


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

	current_state_name = state_name
	current_state = states[state_name]
	current_state.enter(self)
	update_combat_engagement()


func get_default_state() -> String:
	if has_patrol_route():
		return "patrol"

	return "idle"


func take_damage(amount: int, ignore_invulnerability: bool = false):
	if dead or not combat_enabled:
		return

	stop_health_regeneration()
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
	patrol_route.refresh(self, patrol_path)


func has_patrol_route() -> bool:
	return patrol_route.has_route()


func has_smooth_patrol_route() -> bool:
	return patrol_route.has_smooth_route()


func get_current_patrol_point() -> Vector2:
	return patrol_route.get_current_point(global_position)


func advance_patrol_point():
	patrol_route.advance_point(patrol_ping_pong)


func select_nearest_patrol_point():
	patrol_route.select_nearest(global_position)


func return_to_default_state():
	if has_patrol_route():
		begin_return_to_patrol()
		return

	return_to_static_position()


func return_to_static_position():
	global_position = story_spawn_position
	velocity = Vector2.ZERO
	resume_assigned_villager()
	change_state(get_default_state())
	start_health_regeneration()


func begin_return_to_patrol():
	if not has_patrol_route():
		change_state("idle")
		return

	keep_assigned_villager_waiting()
	return_patrol_path_offset = patrol_route.path_offset
	return_patrol_point_index = patrol_route.point_index
	return_patrol_target = get_return_patrol_target()
	change_state("return_to_patrol")


func get_return_patrol_target() -> Vector2:
	if has_smooth_patrol_route():
		return get_patrol_position_at_offset(return_patrol_path_offset)

	return get_current_patrol_point()


func complete_return_to_patrol():
	if has_assigned_villager():
		select_nearest_patrol_point()
	elif has_smooth_patrol_route():
		patrol_route.path_offset = return_patrol_path_offset
	elif patrol_route.points.size() > 0:
		patrol_route.point_index = clamp(return_patrol_point_index, 0, patrol_route.points.size() - 1)

	velocity = Vector2.ZERO
	resume_assigned_villager()
	change_state("patrol")
	start_health_regeneration()


func move_toward_return_patrol_target(delta: float) -> bool:
	if has_assigned_villager():
		return villager_stalk_behavior.move_toward_return_target(delta)

	var to_target: Vector2 = return_patrol_target - global_position
	var return_arrival_distance: float = 1.0
	if to_target.length() <= return_arrival_distance:
		velocity = Vector2.ZERO
		move_and_slide()
		return true

	var direction: Vector2 = to_target.normalized()
	var return_speed: float = run_speed
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

	patrol_route.advance_path_offset(patrol_speed, delta, patrol_ping_pong)
	var target_position := get_patrol_position_at_offset(patrol_route.path_offset)
	var to_target := target_position - global_position

	if delta > 0.0:
		velocity = to_target / delta
	else:
		velocity = Vector2.ZERO

	if to_target != Vector2.ZERO:
		update_facing(to_target.normalized())

	sprite.play("walk")
	move_and_slide()


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
	return patrol_route.get_position_at_offset(offset, global_position)


func get_nearest_patrol_path_offset(world_position: Vector2) -> float:
	return patrol_route.get_nearest_path_offset(world_position)


func get_nearest_patrol_position(world_position: Vector2) -> Vector2:
	if not has_patrol_route():
		return global_position

	patrol_route.select_nearest(world_position)
	if has_smooth_patrol_route():
		return get_patrol_position_at_offset(patrol_route.path_offset)

	return get_current_patrol_point()


func can_attack() -> bool:
	return attack_cooldown_timer <= 0


func has_assigned_villager() -> bool:
	return villager_stalk_behavior != null and villager_stalk_behavior.is_active()


func get_assigned_villager() -> Node:
	if villager_stalk_behavior == null or not villager_stalk_behavior.has_assigned_villager():
		return null

	return villager_stalk_behavior.assigned_villager


func keep_assigned_villager_waiting():
	if villager_stalk_behavior != null:
		villager_stalk_behavior.keep_villager_waiting()


func resume_assigned_villager():
	if villager_stalk_behavior != null:
		villager_stalk_behavior.resume_villager()


func notify_assigned_villager_banshee_defeated():
	if villager_stalk_behavior != null:
		villager_stalk_behavior.notify_villager_banshee_defeated()


func move_toward_assigned_villager():
	if villager_stalk_behavior != null:
		villager_stalk_behavior.move_toward_assigned_villager()


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


func enable_combat_areas():
	configure_collision()
	for area in [hurt_box, attack_box, player_detection_area, attack_range, tracking_range]:
		area.set_deferred("monitoring", true)
		area.set_deferred("monitorable", true)
		for child in area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", false)


func set_story_combat_enabled(enabled: bool, visible_alpha: float = 1.0):
	combat_enabled = enabled
	modulate.a = visible_alpha
	if not enabled:
		story_revealed = false
		stop_health_regeneration()
		clear_combat_engagement()
	player_in_detection = false
	player_in_attack_range = false
	player_in_tracking = false

	if enabled and not dead:
		enable_combat_areas()
	else:
		disable_combat_areas()


func enable_story_combat(visible_alpha: float = 1.0):
	set_story_combat_enabled(true, visible_alpha)


func disable_story_combat(visible_alpha: float):
	set_story_combat_enabled(false, visible_alpha)


#
# Story and save lifecycle
#


func set_story_revealed(revealed: bool, hidden_alpha: float):
	story_revealed = revealed
	if story_revealed:
		modulate.a = 1.0
	else:
		modulate.a = hidden_alpha


func hide_as_story_defeated(hidden_alpha: float):
	dead = true
	visible = false
	velocity = Vector2.ZERO
	clear_combat_engagement()
	stop_health_regeneration()
	set_physics_process(false)
	disable_combat_areas()
	set_story_revealed(false, hidden_alpha)

	var health_node: Node = health
	if health_node != null:
		health_node.set("dead", true)
		health_node.set("health", 0)


func collect_story_save_state() -> Dictionary:
	var health_node: Node = health
	var current_health: int = 0
	var max_health_value: int = 0
	var health_is_dead: bool = false
	if health_node != null:
		current_health = int(health_node.get("health"))
		max_health_value = int(health_node.get("max_health"))
		health_is_dead = bool(health_node.get("dead"))

	return {
		"position": vector_to_data(global_position),
		"health": current_health,
		"max_health": max_health_value,
		"dead": dead or health_is_dead,
		"revealed": story_revealed,
		"combat_enabled": combat_enabled,
		"facing_left": facing_left,
		"patrol_route": patrol_route.to_save_data(),
		"villager_stalk": villager_stalk_behavior.to_save_data(),
	}


func reveal_for_story_detection():
	if dead or not combat_enabled or story_revealed:
		return

	story_revealed = true
	modulate.a = 1.0
	player_detected_for_reveal.emit(self)


func restore_after_load():
	dead = false
	visible = true
	velocity = Vector2.ZERO
	clear_combat_engagement()
	attack_cooldown_timer = 0.0
	player_in_detection = false
	player_in_attack_range = false
	player_in_tracking = false
	story_revealed = false
	clear_hurt_state_overrides()
	set_physics_process(true)

	if sprite != null:
		sprite.speed_scale = 1.0

	var health_node: Node = health
	if health_node != null:
		health_node.set("dead", false)
		if health_node.has_method("stop_regeneration"):
			health_node.stop_regeneration()
		health_node.set("invulnerable", false)
		health_node.set("i_frame_timer", 0.0)
		health_node.set("health", int(health_node.get("max_health")))
		if health_node.has_signal("health_changed"):
			health_node.emit_signal("health_changed", health_node.get("health"), health_node.get("max_health"))

	player = get_tree().get_first_node_in_group("player")
	enable_combat_areas()
	setup_villager_stalk_behavior()
	refresh_patrol_points()

	change_state(get_default_state())


func respawn_for_story(hidden_alpha: float):
	var respawn_position: Vector2 = get_story_respawn_position()
	global_position = respawn_position
	restore_after_load()
	global_position = respawn_position
	facing_left = story_spawn_facing_left
	if sprite != null:
		sprite.flip_h = facing_left
	set_story_combat_enabled(true, hidden_alpha)
	set_story_revealed(false, hidden_alpha)
	stop_health_regeneration()


func restore_for_story_load(hidden_alpha: float, combat_should_be_enabled: bool, should_be_revealed: bool):
	var restore_position: Vector2 = get_story_respawn_position()
	global_position = restore_position
	restore_after_load()
	global_position = restore_position
	facing_left = story_spawn_facing_left
	if sprite != null:
		sprite.flip_h = facing_left

	var visible_alpha: float = hidden_alpha
	if combat_should_be_enabled and should_be_revealed:
		visible_alpha = 1.0

	set_story_combat_enabled(combat_should_be_enabled, visible_alpha)
	set_story_revealed(combat_should_be_enabled and should_be_revealed, hidden_alpha)
	stop_health_regeneration()


func restore_from_story_save(state: Dictionary, hidden_alpha: float, combat_should_be_enabled: bool, should_be_revealed: bool):
	var saved_position: Vector2 = data_to_vector(state.get("position", {}), global_position)
	var saved_health: int = int(state.get("health", health.get("max_health")))
	var saved_facing_left: bool = bool(state.get("facing_left", facing_left))

	global_position = saved_position
	restore_after_load()
	global_position = saved_position
	patrol_route.apply_save_data(state.get("patrol_route", {}))
	villager_stalk_behavior.apply_save_data(state.get("villager_stalk", {}))
	facing_left = saved_facing_left

	if sprite != null:
		sprite.flip_h = facing_left

	var health_node: Node = health
	if health_node != null:
		var max_health_value: int = int(health_node.get("max_health"))
		var restored_health: int = int(clamp(saved_health, 1, max_health_value))
		health_node.set("health", restored_health)
		health_node.set("dead", false)
		health_node.set("invulnerable", false)
		health_node.set("i_frame_timer", 0.0)
		if health_node.has_signal("health_changed"):
			health_node.emit_signal("health_changed", restored_health, max_health_value)

	var visible_alpha: float = hidden_alpha
	if combat_should_be_enabled and should_be_revealed:
		visible_alpha = 1.0

	set_story_combat_enabled(combat_should_be_enabled, visible_alpha)
	set_story_revealed(combat_should_be_enabled and should_be_revealed, hidden_alpha)
	stop_health_regeneration()


func restore_dead_from_story_save(state: Dictionary, hidden_alpha: float):
	var saved_position: Vector2 = data_to_vector(state.get("position", {}), global_position)
	global_position = saved_position
	facing_left = bool(state.get("facing_left", facing_left))
	if sprite != null:
		sprite.flip_h = facing_left

	refresh_patrol_points()
	patrol_route.apply_save_data(state.get("patrol_route", {}))
	setup_villager_stalk_behavior()
	villager_stalk_behavior.apply_save_data(state.get("villager_stalk", {}))
	hide_as_story_defeated(hidden_alpha)


func data_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	if not (value is Dictionary):
		return fallback

	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


func vector_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func get_story_respawn_position() -> Vector2:
	var villager: Node = get_assigned_villager()
	if villager is Node2D and has_patrol_route():
		var villager_node: Node2D = villager as Node2D
		return get_nearest_patrol_position(villager_node.global_position)

	return story_spawn_position


func _on_died():
	dead = true
	clear_combat_engagement()
	stop_health_regeneration()
	notify_assigned_villager_banshee_defeated()
	change_state("death")
	defeated.emit(self)


func _on_player_detection_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	if should_ignore_player_aggro():
		return

	player = body
	player_in_detection = true
	player_in_tracking = true
	stop_health_regeneration()
	reveal_for_story_detection()
	update_combat_engagement()


func _on_player_detection_body_exited(body: Node2D):
	if body == player:
		player_in_detection = false
		update_combat_engagement()


func _on_attack_range_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	if should_ignore_player_aggro():
		return

	player = body
	player_in_attack_range = true
	player_in_tracking = true
	stop_health_regeneration()
	update_combat_engagement()


func _on_attack_range_body_exited(body: Node2D):
	if body == player:
		player_in_attack_range = false
		update_combat_engagement()


func _on_tracking_range_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	if should_ignore_player_aggro():
		return

	player = body
	player_in_tracking = true
	stop_health_regeneration()
	update_combat_engagement()


func _on_tracking_range_body_exited(body: Node2D):
	if body != player:
		return

	player_in_tracking = false
	player_in_detection = false
	player_in_attack_range = false
	update_combat_engagement()


func should_ignore_player_aggro() -> bool:
	return dead or not combat_enabled or (CombatStateManager != null and CombatStateManager.is_dialogue_active())


func refresh_player_detection_after_dialogue():
	if dead or not combat_enabled or CombatStateManager.is_dialogue_active():
		return

	var overlapping_player: Node2D = get_overlapping_player(player_detection_area)
	if overlapping_player == null:
		return

	player = overlapping_player
	player_in_detection = true
	player_in_tracking = true
	player_in_attack_range = get_overlapping_player(attack_range) != null
	stop_health_regeneration()
	reveal_for_story_detection()
	if current_state_name == "idle" or current_state_name == "patrol" or current_state_name == "return_to_patrol":
		change_state("scream")
	else:
		update_combat_engagement()


func get_overlapping_player(area: Area2D) -> Node2D:
	if area == null:
		return null

	for body in area.get_overlapping_bodies():
		if body is Node2D and body.is_in_group("player"):
			return body as Node2D

	return null


func update_combat_engagement():
	if CombatStateManager == null:
		return

	CombatStateManager.set_hostile_engaged(self, is_currently_engaging_player())


func clear_combat_engagement():
	if CombatStateManager != null:
		CombatStateManager.clear_hostile(self)


func is_currently_engaging_player() -> bool:
	if dead or not combat_enabled or CombatStateManager.is_dialogue_active():
		return false

	if current_state_name == "scream" or current_state_name == "chase" or current_state_name == "attack":
		return has_player_target() and player_in_tracking

	if current_state_name == "hurt":
		return has_player_target() and player_in_tracking

	return false


func start_health_regeneration():
	if health != null and health.has_method("start_regeneration"):
		health.start_regeneration()


func stop_health_regeneration():
	if health != null and health.has_method("stop_regeneration"):
		health.stop_regeneration()
