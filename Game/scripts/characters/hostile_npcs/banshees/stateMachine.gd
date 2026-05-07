extends CharacterBody2D

signal defeated(banshee: Node)
signal player_detected_for_reveal(banshee: Node)

const COMBAT_VARIANT_CORRUPTED_MELEE = "corrupted_melee"
const COMBAT_VARIANT_CORRUPTED_STRONG_RANGED = "corrupted_strong_ranged"
const DEFAULT_TUNING: BansheeTuning = preload("res://resources/characters/hostile_npcs/banshees/banshee_tuning.tres")
const BANSHEE_PROJECTILE_SCENE: PackedScene = preload("res://scenes/characters/hostile_npcs/banshees/banshee_projectile.tscn")

@export var patrol_path: NodePath
@export var patrol_ping_pong: bool = false
@export var assigned_villager_path: NodePath
@export var villager_follow_target_distance: float = 36.0
@export var villager_follow_distance_tolerance: float = 24.0
@export var villager_follow_speed_modifier: float = 0.35
@export var villager_reversal_front_buffer: float = 4.0
@export var tuning: BansheeTuning = DEFAULT_TUNING
@export_enum("corrupted_melee", "corrupted_strong_ranged") var combat_variant: String = COMBAT_VARIANT_CORRUPTED_MELEE

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health = $Health
@onready var hurt_box: Area2D = $HurtBox
@onready var attack_box: Area2D = $AttackBox
@onready var player_detection_area: Area2D = $PlayerDetectionArea
@onready var attack_range: Area2D = $AttackRange
@onready var tracking_range: Area2D = $TrackingRange
@onready var tracking_range_shape_node: CollisionShape2D = $TrackingRange/CollisionShape2D

var current_state
var current_state_name: String = ""
var states: Dictionary = {}
var hitbox_manager: BansheeAttackBoxManager
var player: Node2D
var patrol_route := PatrolRoute.new()
var villager_stalk_behavior := BansheeVillagerStalkBehavior.new()
var combat_area_controller := BansheeCombatAreaController.new()
var aggro_sensor := BansheeAggroSensor.new()
var story_lifecycle := BansheeStoryLifecycle.new()

var player_in_detection: bool = false
var player_in_attack_range: bool = false
var player_in_tracking: bool = false
var facing_left: bool = false
var attack_cooldown_timer: float = 0.0
var ranged_cooldown_timer: float = 0.0
var dead: bool = false
var hurt_duration_override: float = -1.0
var hurt_speed_modifier_override: float = -1.0
var return_patrol_target: Vector2
var return_patrol_path_offset: float = 0.0
var return_patrol_point_index: int = 0
var returning_to_static_position: bool = false
var patrol_speed: float
var patrol_arrival_distance: float
var base_run_speed: float
var run_speed: float
var strong_ranged_run_speed_multiplier: float
var strong_ranged_tracking_radius_multiplier: float
var strong_ranged_max_health_multiplier: float
var base_tracking_radius: float = 0.0
var tracking_range_circle: CircleShape2D
var attack_cooldown: float
var attack_damage_start_frame: int
var attack_move_speed_modifier: float
var ranged_attack_cooldown: float
var ranged_min_distance: float
var ranged_preferred_distance: float
var ranged_max_distance: float
var ranged_launch_frame: int
var ranged_projectile_speed: float
var ranged_projectile_lifetime: float
var ranged_projectile_spawn_offset: Vector2
var ranged_choice_far_weight: float
var ranged_choice_retreating_bonus: float
var ranged_choice_close_penalty: float
var hurt_move_speed_modifier: float
var block_stun_duration: float
var block_stun_move_speed_modifier: float
var player_stop_distance: float
var facing_deadzone: float
var combat_enabled: bool = true
var damage_enabled: bool = true
var story_revealed: bool = false
var story_spawn_position: Vector2
var story_spawn_facing_left: bool = false
var suppress_story_detection: bool = false
var last_damage_source: Node = null
var last_killer_form_id: StringName = &""


func _ready():
	apply_tuning()
	story_spawn_position = global_position
	story_spawn_facing_left = facing_left

	add_to_group("hostile_npcs")
	combat_area_controller.setup(self)
	aggro_sensor.setup(self)
	story_lifecycle.setup(self)
	configure_collision()
	connect_ranges()
	setup_villager_stalk_behavior()

	hitbox_manager = preload("res://scripts/characters/hostile_npcs/banshees/combat/bansheeAttackBoxManager.gd").new()
	hitbox_manager.banshee = self
	hitbox_manager.attack_box = attack_box
	hitbox_manager.setup()

	states["idle"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/idleState.gd").new()
	states["patrol"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/patrolState.gd").new()
	states["return_to_patrol"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/returnToPatrolState.gd").new()
	states["scream"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/screamState.gd").new()
	states["chase"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/chaseState.gd").new()
	states["attack"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/attackState.gd").new()
	states["ranged_attack"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/rangedAttackState.gd").new()
	states["hurt"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/hurtState.gd").new()
	states["death"] = preload("res://scripts/characters/hostile_npcs/banshees/state_machine/deathState.gd").new()

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
	base_run_speed = tuning.run_speed
	run_speed = base_run_speed
	strong_ranged_run_speed_multiplier = tuning.strong_ranged_run_speed_multiplier
	strong_ranged_tracking_radius_multiplier = tuning.strong_ranged_tracking_radius_multiplier
	strong_ranged_max_health_multiplier = tuning.strong_ranged_max_health_multiplier
	attack_cooldown = tuning.attack_cooldown
	attack_damage_start_frame = tuning.attack_damage_start_frame
	attack_move_speed_modifier = tuning.attack_move_speed_modifier
	ranged_attack_cooldown = tuning.ranged_attack_cooldown
	ranged_min_distance = tuning.ranged_min_distance
	ranged_preferred_distance = tuning.ranged_preferred_distance
	ranged_max_distance = tuning.ranged_max_distance
	ranged_launch_frame = tuning.ranged_launch_frame
	ranged_projectile_speed = tuning.ranged_projectile_speed
	ranged_projectile_lifetime = tuning.ranged_projectile_lifetime
	ranged_projectile_spawn_offset = tuning.ranged_projectile_spawn_offset
	ranged_choice_far_weight = tuning.ranged_choice_far_weight
	ranged_choice_retreating_bonus = tuning.ranged_choice_retreating_bonus
	ranged_choice_close_penalty = tuning.ranged_choice_close_penalty
	hurt_move_speed_modifier = tuning.hurt_move_speed_modifier
	block_stun_duration = tuning.block_stun_duration
	block_stun_move_speed_modifier = tuning.block_stun_move_speed_modifier
	player_stop_distance = tuning.player_stop_distance
	facing_deadzone = tuning.facing_deadzone
	cache_tracking_range_shape()
	apply_variant_tuning()


func _physics_process(delta):
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if ranged_cooldown_timer > 0:
		ranged_cooldown_timer -= delta

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
	combat_area_controller.configure_collision()


func connect_ranges():
	aggro_sensor.connect_ranges()


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


func take_damage(amount: int, ignore_invulnerability: bool = false, damage_source: Node = null):
	if dead or not combat_enabled or not damage_enabled:
		return

	stop_health_regeneration()
	last_damage_source = damage_source
	last_killer_form_id = get_damage_source_form_id(damage_source)
	var damage_applied: bool = health.take_damage(amount, ignore_invulnerability)
	if damage_applied and not dead:
		enter_hurt_state()


func get_damage_source_form_id(damage_source: Node) -> StringName:
	if damage_source != null and damage_source.has_method("get_current_form_id"):
		return damage_source.get_current_form_id()

	return &""


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

	begin_return_to_static_position()


func begin_return_to_static_position():
	keep_assigned_villager_waiting()
	returning_to_static_position = true
	return_patrol_target = story_spawn_position
	change_state("return_to_patrol")


func begin_return_to_patrol():
	if not has_patrol_route():
		begin_return_to_static_position()
		return

	keep_assigned_villager_waiting()
	returning_to_static_position = false
	return_patrol_path_offset = patrol_route.path_offset
	return_patrol_point_index = patrol_route.point_index
	return_patrol_target = get_return_patrol_target()
	change_state("return_to_patrol")


func get_return_patrol_target() -> Vector2:
	if has_smooth_patrol_route():
		return get_patrol_position_at_offset(return_patrol_path_offset)

	return get_current_patrol_point()


func complete_return_to_patrol():
	if returning_to_static_position:
		returning_to_static_position = false
	elif has_assigned_villager():
		select_nearest_patrol_point()
	elif has_smooth_patrol_route():
		patrol_route.path_offset = return_patrol_path_offset
	elif patrol_route.points.size() > 0:
		patrol_route.point_index = clamp(return_patrol_point_index, 0, patrol_route.points.size() - 1)

	velocity = Vector2.ZERO
	resume_assigned_villager()
	change_state(get_default_state())
	start_health_regeneration()


func move_toward_return_patrol_target(delta: float) -> bool:
	if has_assigned_villager() and not returning_to_static_position:
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


func cache_tracking_range_shape():
	if tracking_range_shape_node == null:
		return

	if tracking_range_shape_node.shape is CircleShape2D:
		tracking_range_shape_node.shape = tracking_range_shape_node.shape.duplicate()
		tracking_range_circle = tracking_range_shape_node.shape as CircleShape2D
		if base_tracking_radius <= 0.0:
			base_tracking_radius = tracking_range_circle.radius


func apply_variant_tuning():
	run_speed = base_run_speed
	if tracking_range_circle != null and base_tracking_radius > 0.0:
		tracking_range_circle.radius = base_tracking_radius
	apply_effective_max_health(tuning.max_health)

	if not is_strong_ranged_variant():
		return

	run_speed = base_run_speed * strong_ranged_run_speed_multiplier
	if tracking_range_circle != null and base_tracking_radius > 0.0:
		tracking_range_circle.radius = base_tracking_radius * strong_ranged_tracking_radius_multiplier
	apply_effective_max_health(int(round(float(tuning.max_health) * strong_ranged_max_health_multiplier)))


func apply_effective_max_health(value: int):
	if health != null and health.has_method("set_effective_max_health"):
		health.set_effective_max_health(value)


func is_strong_ranged_variant() -> bool:
	return combat_variant == COMBAT_VARIANT_CORRUPTED_STRONG_RANGED


func can_ranged_attack() -> bool:
	return is_strong_ranged_variant() and ranged_cooldown_timer <= 0.0 and has_player_target() and is_player_in_ranged_range() and has_ranged_animations()


func has_ranged_animations() -> bool:
	var sprite_frames: SpriteFrames = sprite.sprite_frames
	return sprite_frames != null and sprite_frames.has_animation("ranged1") and sprite_frames.has_animation("ranged2")


func is_player_in_ranged_range() -> bool:
	var distance: float = get_player_distance()
	return distance >= ranged_min_distance and distance <= ranged_max_distance


func is_player_within_ranged_max_distance() -> bool:
	return get_player_distance() <= ranged_max_distance


func get_player_distance() -> float:
	if not has_player_target():
		return INF

	return global_position.distance_to(player.global_position)


func should_choose_ranged_attack() -> bool:
	if not can_ranged_attack():
		return false

	var distance: float = get_player_distance()
	if player_in_attack_range and distance < ranged_min_distance:
		return false

	var score: float = 0.0
	var range_span: float = maxf(ranged_preferred_distance - ranged_min_distance, 1.0)
	var distance_score: float = clampf((distance - ranged_min_distance) / range_span, 0.0, 1.0)
	score += distance_score * ranged_choice_far_weight

	if is_player_moving_away():
		score += ranged_choice_retreating_bonus
	if player_in_attack_range:
		score -= ranged_choice_close_penalty

	score = clampf(score, 0.0, 1.0)
	return score >= 0.55


func is_player_moving_away() -> bool:
	if not has_player_target():
		return false

	var player_velocity: Vector2 = Vector2.ZERO
	var raw_velocity: Variant = player.get("velocity")
	if raw_velocity is Vector2:
		player_velocity = raw_velocity

	if player_velocity.length() <= 1.0:
		return false

	var away_from_banshee: Vector2 = (player.global_position - global_position).normalized()
	return player_velocity.normalized().dot(away_from_banshee) > 0.55


func launch_ranged_projectile(combo_part: int, launch_direction: Vector2):
	var projectile := BANSHEE_PROJECTILE_SCENE.instantiate()
	if projectile == null:
		return

	var projectile_parent: Node = get_parent()
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	if projectile_parent == null:
		return

	projectile_parent.add_child(projectile)
	if projectile is Node2D:
		var projectile_node := projectile as Node2D
		projectile_node.global_position = get_ranged_projectile_spawn_position(launch_direction)

	if projectile.has_method("launch"):
		projectile.launch(self, launch_direction, ranged_projectile_speed, ranged_projectile_lifetime, combo_part)


func get_ranged_projectile_spawn_position(launch_direction: Vector2) -> Vector2:
	var horizontal_sign: float = -1.0 if facing_left else 1.0
	if abs(launch_direction.x) > facing_deadzone:
		horizontal_sign = sign(launch_direction.x)

	var offset := Vector2(abs(ranged_projectile_spawn_offset.x) * horizontal_sign, ranged_projectile_spawn_offset.y)
	return global_position + offset


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
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false

	if player.has_method("is_life_respawn_pending") and bool(player.call("is_life_respawn_pending")):
		return true

	return player.visible


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
	combat_area_controller.disable_combat_areas()


func enable_combat_areas():
	combat_area_controller.enable_combat_areas()


func set_story_combat_enabled(enabled: bool, visible_alpha: float = 1.0):
	combat_area_controller.set_story_combat_enabled(enabled, visible_alpha)


func set_damage_enabled(enabled: bool):
	combat_area_controller.set_damage_enabled(enabled)


func enable_story_combat(visible_alpha: float = 1.0):
	combat_area_controller.enable_story_combat(visible_alpha)


func disable_story_combat(visible_alpha: float):
	combat_area_controller.disable_story_combat(visible_alpha)


#
# Story and save lifecycle
#


func set_story_revealed(revealed: bool, hidden_alpha: float):
	story_lifecycle.set_story_revealed(revealed, hidden_alpha)


func hide_as_story_defeated(hidden_alpha: float):
	story_lifecycle.hide_as_story_defeated(hidden_alpha)


func collect_story_save_state() -> Dictionary:
	return story_lifecycle.collect_story_save_state()


func set_combat_variant(variant: String):
	if variant == COMBAT_VARIANT_CORRUPTED_STRONG_RANGED:
		combat_variant = variant
		apply_variant_tuning()
		return

	combat_variant = COMBAT_VARIANT_CORRUPTED_MELEE
	apply_variant_tuning()


func get_combat_variant() -> String:
	return combat_variant


func apply_saved_combat_variant(state: Dictionary):
	set_combat_variant(str(state.get("combat_variant", combat_variant)))


func reveal_for_story_detection():
	story_lifecycle.reveal_for_story_detection()


func begin_story_detection_suppression():
	story_lifecycle.begin_story_detection_suppression()


func end_story_detection_suppression_after_physics():
	await story_lifecycle.end_story_detection_suppression_after_physics()


func restore_after_load():
	story_lifecycle.restore_after_load()


func respawn_for_story(hidden_alpha: float):
	story_lifecycle.respawn_for_story(hidden_alpha)


func restore_for_story_load(hidden_alpha: float, combat_should_be_enabled: bool, should_be_revealed: bool):
	story_lifecycle.restore_for_story_load(hidden_alpha, combat_should_be_enabled, should_be_revealed)


func restore_from_story_save(state: Dictionary, hidden_alpha: float, combat_should_be_enabled: bool, should_be_revealed: bool):
	story_lifecycle.restore_from_story_save(state, hidden_alpha, combat_should_be_enabled, should_be_revealed)


func restore_dead_from_story_save(state: Dictionary, hidden_alpha: float):
	story_lifecycle.restore_dead_from_story_save(state, hidden_alpha)


func data_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	return story_lifecycle.data_to_vector(value, fallback)


func vector_to_data(value: Vector2) -> Dictionary:
	return story_lifecycle.vector_to_data(value)


func get_story_respawn_position() -> Vector2:
	return story_lifecycle.get_story_respawn_position()


func _on_died():
	dead = true
	clear_combat_engagement()
	stop_health_regeneration()
	notify_assigned_villager_banshee_defeated()
	change_state("death")
	defeated.emit(self)


func _on_player_detection_body_entered(body: Node2D):
	aggro_sensor.on_player_detection_body_entered(body)


func _on_player_detection_body_exited(body: Node2D):
	aggro_sensor.on_player_detection_body_exited(body)


func _on_attack_range_body_entered(body: Node2D):
	aggro_sensor.on_attack_range_body_entered(body)


func _on_attack_range_body_exited(body: Node2D):
	aggro_sensor.on_attack_range_body_exited(body)


func _on_tracking_range_body_entered(body: Node2D):
	aggro_sensor.on_tracking_range_body_entered(body)


func _on_tracking_range_body_exited(body: Node2D):
	aggro_sensor.on_tracking_range_body_exited(body)


func should_ignore_player_aggro() -> bool:
	return aggro_sensor.should_ignore_player_aggro()


func should_defer_player_range_exit(body: Node2D) -> bool:
	return aggro_sensor.should_defer_player_range_exit(body)


func should_defer_player_range_change(body: Node2D) -> bool:
	return aggro_sensor.should_defer_player_range_change(body)


func can_range_overlap_start_aggro() -> bool:
	return aggro_sensor.can_range_overlap_start_aggro()


func can_tracking_range_maintain_aggro(was_already_engaged: bool = false) -> bool:
	return aggro_sensor.can_tracking_range_maintain_aggro(was_already_engaged)


func is_passive_aggro_state() -> bool:
	return aggro_sensor.is_passive_aggro_state()


func refresh_player_ranges_after_transform():
	aggro_sensor.refresh_player_ranges_after_transform()


func refresh_player_ranges_after_transform_deferred():
	await aggro_sensor.refresh_player_ranges_after_transform_deferred()


func is_player_overlapping_area(area: Area2D) -> bool:
	return aggro_sensor.is_player_overlapping_area(area)


func refresh_player_detection_after_dialogue():
	aggro_sensor.refresh_player_detection_after_dialogue()


func get_overlapping_player(area: Area2D) -> Node2D:
	return aggro_sensor.get_overlapping_player(area)


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

	if current_state_name == "scream" or current_state_name == "chase" or current_state_name == "attack" or current_state_name == "ranged_attack":
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
