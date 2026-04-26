extends CharacterBody2D

@export var patrol_path: NodePath
@export var patrol_speed: float = 45.0
@export var patrol_arrival_distance: float = 6.0
@export var run_speed: float = 120.0
@export var attack_damage: int = 5
@export var combo_2_damage_bonus: int = 2
@export var attack_cooldown: float = 0.5
@export var attack_damage_start_frame: int = 3
@export var attack_move_speed_modifier: float = 0.75
@export var hurt_move_speed_modifier: float = 0.25
@export var block_stun_duration: float = 1.0
@export var block_stun_move_speed_modifier: float = 0.15

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

var player_in_detection: bool = false
var player_in_attack_range: bool = false
var player_in_tracking: bool = false
var facing_left: bool = false
var attack_cooldown_timer: float = 0.0
var dead: bool = false
var hurt_duration_override: float = -1.0
var hurt_speed_modifier_override: float = -1.0
var patrol_points: Array[Vector2] = []
var patrol_point_index: int = 0


func _ready():
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
	states["chase"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/chaseState.gd").new()
	states["attack"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/attackState.gd").new()
	states["hurt"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/hurtState.gd").new()
	states["death"] = preload("res://assets/characters/HostileNPCs/Banshees/state_machine/deathState.gd").new()

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

	player = get_tree().get_first_node_in_group("player")
	refresh_patrol_points()
	change_state(get_default_state())


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

	if str(patrol_path) == "":
		patrol_point_index = 0
		return

	var path: Path2D = get_node_or_null(patrol_path) as Path2D
	if path == null or path.curve == null:
		patrol_point_index = 0
		return

	for point in path.curve.get_baked_points():
		patrol_points.append(path.to_global(point))

	if patrol_point_index >= patrol_points.size():
		patrol_point_index = 0


func has_patrol_route() -> bool:
	return patrol_points.size() > 0


func get_current_patrol_point() -> Vector2:
	if not has_patrol_route():
		return global_position

	return patrol_points[patrol_point_index]


func advance_patrol_point():
	if not has_patrol_route():
		return

	patrol_point_index = (patrol_point_index + 1) % patrol_points.size()


func can_attack() -> bool:
	return attack_cooldown_timer <= 0


func has_player_target() -> bool:
	return player != null and is_instance_valid(player) and player.is_inside_tree() and player.visible


func get_direction_to_player() -> Vector2:
	if not has_player_target():
		return Vector2.ZERO

	return (player.global_position - global_position).normalized()


func face_target():
	if not has_player_target():
		return

	update_facing(player.global_position - global_position)


func update_facing(direction: Vector2):
	if direction.x == 0:
		return

	facing_left = direction.x < 0
	sprite.flip_h = facing_left


func move_toward_player(speed_modifier: float):
	if not has_player_target() or not player_in_tracking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = get_direction_to_player()
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
