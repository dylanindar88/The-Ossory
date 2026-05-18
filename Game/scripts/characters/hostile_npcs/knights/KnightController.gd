extends CharacterBody2D

signal defeated(knight: Node)
signal encounter_dialogue_started(knight: Node)
signal player_detected(knight: Node, player: Node)
signal player_tracking_changed(knight: Node)

const DIALOGUE_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/DialogueBubble.tscn")
const AttackHitboxShapeControllerScript := preload("res://scripts/characters/shared/combat/AttackHitboxShapeController.gd")
const TopDownMovement := preload("res://scripts/characters/shared/movement/TopDownMovement.gd")
const CHARACTER_NAVIGATION_SETTINGS := preload("res://scripts/levels/shared/CharacterNavigationSettings.gd")
const FACING_RIGHT := "right"
const FACING_LEFT := "left"
const FACING_UP := "up"
const FACING_DOWN := "down"
const DEFAULT_BEHAVIOR_IDLE := "idle"
const DEFAULT_BEHAVIOR_PACE := "pace"
const DEFAULT_BEHAVIOR_CONVERSATION := "conversation"
const STATE_RETURN_HOME := "return_home"
const STATE_HURT := "hurt"
const WORLD_COLLISION_LAYER := 1
const PLAYER_COLLISION_LAYER := 2
const HOSTILE_COLLISION_LAYER := 4
const NPC_COLLISION_LAYER := 8
const KNIGHT_BODY_COLLISION_MASK := WORLD_COLLISION_LAYER | PLAYER_COLLISION_LAYER | NPC_COLLISION_LAYER
const DEFAULT_AVOIDANCE_NEIGHBOR_DISTANCE := 56.0
const DEFAULT_AVOIDANCE_TIME_HORIZON := 0.35
const MELEE_ATTACK_CONTACT_TOLERANCE := 4.0
const CHASE_TARGET_SPREAD_RADIUS := 18.0
const CHASE_TARGET_SPREAD_SLOTS := 6
const NAVIGATION_NEAR_SELF_DISTANCE := 1.0
const NAVIGATION_PROGRESS_EPSILON := 1.0
const NAVIGATION_STUCK_REPATH_SECONDS := 0.35
const RETURN_HOME_STUCK_RESET_SECONDS := 3.0
const PREVIOUS_MELEE_ATTACK_BOX_HEIGHT := 28.0 * 1.06767
const HORIZONTAL_ATTACK_BOX_OFFSET_RATIO := 24.0 / PREVIOUS_MELEE_ATTACK_BOX_HEIGHT
const UP_ATTACK_BOX_OFFSET_RATIO := 10.0 / PREVIOUS_MELEE_ATTACK_BOX_HEIGHT
const DOWN_ATTACK_BOX_OFFSET_RATIO := 25.0 / PREVIOUS_MELEE_ATTACK_BOX_HEIGHT
const BLOCK_STUN_HURT_FREEZE_FRAME := 1
const FORM_CHANGE_SETTLE_PHYSICS_FRAMES := 2
const HORIZONTAL_BASE_ANIMATIONS := {
	"idle": true,
	"walk": true,
	"run": true,
	"attack": true,
}
const DIRECTIONAL_ANIMATIONS := {
	"idle": {
		FACING_UP: "idle_up",
	},
	"walk": {
		FACING_UP: "walk_up",
		FACING_DOWN: "walk_down",
	},
	"run": {
		FACING_UP: "run_up",
		FACING_DOWN: "run_down",
	},
	"attack": {
		FACING_UP: "attack_up",
		FACING_DOWN: "attack_down",
	},
}

@export var tuning: Resource
@export var patrol_path: NodePath
@export var patrol_ping_pong: bool = false
@export var campfire_base_path: NodePath
@export var encounter_dialogue_override: Resource
@export_enum("idle", "pace", "conversation") var default_behavior: String = DEFAULT_BEHAVIOR_IDLE
@export_enum("right", "left", "up", "down") var home_facing_direction: String = FACING_RIGHT
@export var pace_point_a_path: NodePath
@export var pace_point_b_path: NodePath
@export var pace_distance: float = 48.0
@export var pace_speed_scale: float = 0.65
@export var conversation_partner_path: NodePath
@export var conversation_group_id: StringName
@export var conversation_dialogue_bank: Resource
@export var conversation_interval_seconds: float = 4.0
@export var encounter_bark_auto_close_seconds: float = 2.25

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var health: Node = get_node_or_null("Health")
@onready var effects: EffectList = get_node_or_null("Effects") as EffectList
@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
@onready var hurt_box: Area2D = get_node_or_null("HurtBox") as Area2D
@onready var attack_box: Area2D = get_node_or_null("AttackBox") as Area2D
@onready var detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D
@onready var tracking_area: Area2D = get_node_or_null("TrackingArea") as Area2D
@onready var attack_range_area: Area2D = get_node_or_null("AttackRange") as Area2D
@onready var projectile_spawn: Marker2D = get_node_or_null("ProjectileSpawn") as Marker2D
@onready var dialogue_anchor: Marker2D = get_node_or_null("DialogueAnchor") as Marker2D
@onready var movement_box: CollisionShape2D = get_node_or_null("MovementBox") as CollisionShape2D

var patrol_route := PatrolRoute.new()
var player: Node2D
var player_in_detection: bool = false
var player_in_tracking: bool = false
var player_in_attack_range: bool = false
var facing_left: bool = false
var dead: bool = false
var combat_enabled: bool = true
var damage_enabled: bool = true
var respawn_enabled: bool = true
var encounter_dialogue_played: bool = false
var active_dialogue_bubble: Node
var attack_cooldown_timer: float = 0.0
var attack_windup_timer: float = 0.0
var attack_recover_timer: float = 0.0
var attack_has_dealt_damage: bool = false
var active_attack_animation: String = "attack"
var active_attack_duration: float = 0.0
var active_attack_hit_time: float = 0.0
var hurt_timer: float = 0.0
var hurt_duration_override: float = -1.0
var hurt_speed_modifier_override: float = -1.0
var hurt_animation_hold_active: bool = false
var hurt_animation_finishing_after_hold: bool = false
var hurt_animation_finish_timer: float = 0.0
var state_before_hurt: String = "idle"
var state: String = "idle"
var last_facing_direction: String = FACING_RIGHT
var last_horizontal_facing_direction: String = FACING_RIGHT
var spawn_position: Vector2
var spawn_facing_left: bool = false
var home_position: Vector2
var pace_target_index: int = 0
var camp_aggro_active: bool = false
var personal_aggro_active: bool = false
var conversation_timer: float = 0.0
var active_dialogue_is_encounter_bark: bool = false
var last_chase_used_navigation: bool = false
var current_movement_uses_navigation: bool = false
var knight_index: int = -1
var current_physics_delta: float = 0.0
var navigation_progress_position: Vector2
var navigation_stuck_timer: float = 0.0
var return_home_stuck_timer: float = 0.0
var authored_navigation_path_desired_distance: float = 0.0
var authored_navigation_target_desired_distance: float = 0.0
var alive_body_collision_enabled: bool = true
var refreshing_player_ranges_after_transform: bool = false
var was_engaged_before_transform_refresh: bool = false
var pending_form_settle_physics_frames: int = 0
var tracked_transform_signal_player: Node = null
var attack_shape_controller := AttackHitboxShapeControllerScript.new()


func _ready():
	spawn_position = global_position
	home_position = global_position
	navigation_progress_position = global_position
	spawn_facing_left = facing_left
	cache_authored_body_collision_state()
	add_to_group("hostile_npcs")
	apply_tuning()
	configure_collision()
	connect_areas()
	refresh_patrol_points()
	player = get_tree().get_first_node_in_group("player") as Node2D
	if health != null:
		health.set_tuning(tuning)
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)
	apply_home_facing()
	change_state(get_default_state())


func _exit_tree():
	untrack_player_transform_signal()


func _physics_process(delta: float):
	current_physics_delta = delta
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if dead:
		return
	refresh_personal_detection_enabled()

	if state == STATE_HURT:
		update_hurt(delta)
		return

	if state == "attack":
		update_attack(delta)
		return

	if can_start_attack():
		start_attack()
		return

	if should_chase_player():
		chase_player(delta)
	elif should_return_home():
		move_home(delta)
	elif has_camp_default_behavior():
		update_default_behavior(delta)
	elif has_patrol_route():
		change_state("patrol")
		move_along_patrol_route(delta)
	else:
		change_state("idle")
		velocity = Vector2.ZERO
		play_directional_animation("idle")


func apply_tuning():
	if tuning == null:
		return

	set_circle_shape_radius(detection_area, tuning.detection_range)
	set_circle_shape_radius(tracking_area, tuning.tracking_range)
	set_circle_shape_radius(attack_range_area, tuning.attack_range)


func set_circle_shape_radius(area: Area2D, radius: float):
	if area == null:
		return

	var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is CircleShape2D):
		return

	shape_node.shape = shape_node.shape.duplicate()
	var circle := shape_node.shape as CircleShape2D
	circle.radius = radius


func configure_collision():
	collision_layer = HOSTILE_COLLISION_LAYER
	collision_mask = KNIGHT_BODY_COLLISION_MASK
	set_body_collision_enabled(true)
	configure_navigation_agent()

	if hurt_box != null:
		hurt_box.add_to_group("enemies")
		hurt_box.monitoring = true
		hurt_box.monitorable = true
		hurt_box.collision_layer = 4
		hurt_box.collision_mask = 0

	if attack_box != null:
		attack_box.monitoring = false
		attack_box.monitorable = true
		attack_box.collision_layer = 0
		attack_box.collision_mask = 2
		if not attack_box.area_entered.is_connected(_on_attack_box_area_entered):
			attack_box.area_entered.connect(_on_attack_box_area_entered)
		attack_shape_controller.setup(attack_box)
		set_attack_shape_enabled(false)

	for area in [tracking_area, attack_range_area]:
		if area is Area2D:
			area.monitoring = true
			area.monitorable = true
			area.collision_layer = 0
			area.collision_mask = 2
	if detection_area != null:
		detection_area.monitorable = true
		detection_area.collision_layer = 0
		detection_area.collision_mask = 2
		refresh_personal_detection_enabled()


func configure_navigation_agent():
	if navigation_agent == null:
		return

	navigation_agent.navigation_layers = get_navigation_layer_for_current_role()
	authored_navigation_path_desired_distance = navigation_agent.path_desired_distance
	authored_navigation_target_desired_distance = navigation_agent.target_desired_distance
	navigation_agent.avoidance_enabled = false
	navigation_agent.radius = get_navigation_avoidance_radius()
	navigation_agent.neighbor_distance = maxf(DEFAULT_AVOIDANCE_NEIGHBOR_DISTANCE, navigation_agent.radius * 6.0)
	navigation_agent.max_neighbors = 8
	navigation_agent.time_horizon_agents = DEFAULT_AVOIDANCE_TIME_HORIZON
	navigation_agent.time_horizon_obstacles = DEFAULT_AVOIDANCE_TIME_HORIZON
	navigation_agent.max_speed = get_max_navigation_speed()


func get_navigation_layer_for_current_role() -> int:
	return CHARACTER_NAVIGATION_SETTINGS.CAMPFIRE_BASE_KNIGHT_NAVIGATION_LAYER if is_camp_linked() else CHARACTER_NAVIGATION_SETTINGS.DEFAULT_CHARACTER_NAVIGATION_LAYER


func get_navigation_avoidance_radius() -> float:
	if movement_box == null or movement_box.shape == null:
		return 12.0

	var max_scale := maxf(abs(movement_box.scale.x), abs(movement_box.scale.y))
	if movement_box.shape is CapsuleShape2D:
		return maxf((movement_box.shape as CapsuleShape2D).radius * max_scale, 8.0)
	if movement_box.shape is CircleShape2D:
		return maxf((movement_box.shape as CircleShape2D).radius * max_scale, 8.0)
	if movement_box.shape is RectangleShape2D:
		var size := (movement_box.shape as RectangleShape2D).size
		return maxf(minf(size.x * abs(movement_box.scale.x), size.y * abs(movement_box.scale.y)) * 0.5, 8.0)
	return 12.0


func get_max_navigation_speed() -> float:
	if tuning == null:
		return 120.0
	return maxf(float(tuning.walk_speed), float(tuning.run_speed))


func connect_areas():
	connect_area_body_signal(detection_area, "body_entered", "_on_detection_body_entered")
	connect_area_body_signal(detection_area, "body_exited", "_on_detection_body_exited")
	connect_area_body_signal(tracking_area, "body_entered", "_on_tracking_body_entered")
	connect_area_body_signal(tracking_area, "body_exited", "_on_tracking_body_exited")
	connect_area_body_signal(attack_range_area, "body_entered", "_on_attack_range_body_entered")
	connect_area_body_signal(attack_range_area, "body_exited", "_on_attack_range_body_exited")


func connect_area_body_signal(area: Area2D, signal_name: StringName, method_name: String):
	if area == null:
		return

	var callback := Callable(self, method_name)
	if not area.is_connected(signal_name, callback):
		area.connect(signal_name, callback)


func refresh_patrol_points():
	patrol_route.refresh(self, patrol_path)


func has_patrol_route() -> bool:
	return patrol_route.has_route()


func move_along_patrol_route(delta: float):
	if tuning == null:
		return

	if patrol_route.has_smooth_route():
		patrol_route.advance_path_offset(tuning.walk_speed, delta, patrol_ping_pong)
		move_toward_position(patrol_route.get_position_at_offset(patrol_route.path_offset, global_position), tuning.walk_speed, false, delta)
		return

	var target := patrol_route.get_current_point(global_position)
	var offset := target - global_position
	if offset.length() <= tuning.patrol_arrival_distance:
		patrol_route.advance_point(patrol_ping_pong)
		target = patrol_route.get_current_point(global_position)
	move_toward_position(target, tuning.walk_speed, false, delta)


func should_chase_player() -> bool:
	if not (combat_enabled and has_player_target()):
		return false
	if is_camp_linked():
		return camp_aggro_active
	return player_in_tracking


func chase_player(delta: float = -1.0):
	if tuning == null or not has_player_target():
		return

	change_state("chase")
	last_chase_used_navigation = false
	var chase_target := get_chase_target_position()
	var movement_delta := current_physics_delta if delta < 0.0 else delta
	if should_direct_chase_outside_camp_navigation(chase_target):
		move_toward_position(chase_target, tuning.run_speed, false, movement_delta)
		return
	if navigation_agent == null:
		return
	if move_with_navigation_target(chase_target, tuning.run_speed, movement_delta):
		last_chase_used_navigation = true


func should_direct_chase_outside_camp_navigation(chase_target: Vector2) -> bool:
	if not is_camp_linked() or not camp_aggro_active:
		return false
	var campfire := get_linked_campfire_base()
	if campfire == null or not campfire.has_method("is_position_inside_camp_navigation"):
		return false
	return not bool(campfire.is_position_inside_camp_navigation(chase_target))


func get_chase_target_position() -> Vector2:
	if not has_player_target():
		return global_position
	if is_melee_knight() and not is_player_within_attack_distance():
		return player.global_position + get_chase_target_spread_offset()
	return player.global_position


func get_chase_target_spread_offset() -> Vector2:
	var key := "%s:%s:%d:%d" % [get_path(), name, int(round(home_position.x)), int(round(home_position.y))]
	var slot := absi(int(key.hash())) % CHASE_TARGET_SPREAD_SLOTS
	var angle := TAU * float(slot) / float(CHASE_TARGET_SPREAD_SLOTS)
	return Vector2(cos(angle), sin(angle)) * CHASE_TARGET_SPREAD_RADIUS


func should_use_navigation_for_chase(_chase_target: Variant = null) -> bool:
	return navigation_agent != null


func should_return_home() -> bool:
	if not has_camp_default_behavior() or camp_aggro_active or personal_aggro_active:
		return false
	if state == STATE_RETURN_HOME:
		return not is_at_home()
	if player_in_tracking:
		return false
	return state == "chase" or state == "attack"


func move_home(_delta: float = 0.0):
	if tuning == null:
		return

	change_state(STATE_RETURN_HOME)
	apply_return_home_navigation_distances()
	if is_at_home():
		finish_return_home()
		return

	if should_direct_return_until_camp_navigation():
		move_toward_position(home_position, tuning.walk_speed, false, _delta)
		update_navigation_progress(false, home_position, _delta)
		return

	if navigation_agent == null:
		velocity = Vector2.ZERO
		return

	move_with_navigation_target(home_position, tuning.walk_speed, _delta)


func should_direct_return_until_camp_navigation() -> bool:
	if not is_camp_linked():
		return false
	var campfire := get_linked_campfire_base()
	if campfire == null or not campfire.has_method("is_position_inside_camp_navigation"):
		return false
	return not bool(campfire.is_position_inside_camp_navigation(global_position))


func move_with_navigation_target(target_position: Vector2, speed: float, delta: float = 0.0) -> bool:
	if navigation_agent == null:
		return false

	current_movement_uses_navigation = false
	navigation_agent.target_position = target_position
	var target_distance := global_position.distance_to(target_position)
	if navigation_agent.is_navigation_finished() and target_distance > get_navigation_target_arrival_distance():
		refresh_navigation_path(target_position)

	var next_position := navigation_agent.get_next_path_position()
	if global_position.distance_to(next_position) <= NAVIGATION_NEAR_SELF_DISTANCE and target_distance > get_navigation_target_arrival_distance():
		refresh_navigation_path(target_position)
		next_position = navigation_agent.get_next_path_position()
	if global_position.distance_to(next_position) <= NAVIGATION_NEAR_SELF_DISTANCE and target_distance > get_navigation_target_arrival_distance():
		register_blocked_movement()
		update_navigation_progress(false, target_position, delta)
		return false

	var moved := move_toward_position(next_position, speed, true, delta)
	update_navigation_progress(moved, target_position, delta)
	return moved


func get_navigation_target_arrival_distance() -> float:
	if state == STATE_RETURN_HOME and tuning != null:
		return tuning.patrol_arrival_distance
	if navigation_agent != null:
		return maxf(navigation_agent.target_desired_distance, NAVIGATION_NEAR_SELF_DISTANCE)
	return NAVIGATION_NEAR_SELF_DISTANCE


func update_navigation_progress(moved: bool, target_position: Vector2, delta: float):
	if moved or global_position.distance_to(navigation_progress_position) > NAVIGATION_PROGRESS_EPSILON:
		navigation_progress_position = global_position
		navigation_stuck_timer = 0.0
		return_home_stuck_timer = 0.0
		return
	if delta <= 0.0:
		return

	navigation_stuck_timer += delta
	if state == STATE_RETURN_HOME:
		return_home_stuck_timer += delta
		if return_home_stuck_timer >= RETURN_HOME_STUCK_RESET_SECONDS:
			finish_return_home()
			return
	if navigation_stuck_timer >= NAVIGATION_STUCK_REPATH_SECONDS:
		refresh_navigation_path(target_position)
		navigation_stuck_timer = 0.0


func refresh_navigation_path(target_position: Vector2):
	if navigation_agent == null:
		return
	navigation_agent.target_position = target_position


func reset_navigation_progress():
	navigation_progress_position = global_position
	navigation_stuck_timer = 0.0
	return_home_stuck_timer = 0.0


func finish_return_home():
	global_position = home_position
	velocity = Vector2.ZERO
	clear_personal_aggro()
	clear_navigation_velocity()
	reset_navigation_progress()
	apply_home_facing()
	change_state(get_default_state())
	update_default_behavior(0.0)
	refresh_personal_detection_enabled()


func update_default_behavior(delta: float):
	match default_behavior:
		DEFAULT_BEHAVIOR_PACE:
			update_pace_behavior(delta)
		DEFAULT_BEHAVIOR_CONVERSATION:
			update_conversation_behavior(delta)
		_:
			update_idle_behavior()


func update_idle_behavior():
	change_state(DEFAULT_BEHAVIOR_IDLE)
	velocity = Vector2.ZERO
	apply_home_facing()
	play_directional_animation("idle")


func update_pace_behavior(delta: float = -1.0):
	if tuning == null:
		return

	change_state(DEFAULT_BEHAVIOR_PACE)
	var points := get_pace_points()
	if points.is_empty():
		update_idle_behavior()
		return

	var target: Vector2 = points[clampi(pace_target_index, 0, points.size() - 1)]
	if global_position.distance_to(target) <= tuning.patrol_arrival_distance:
		pace_target_index = (pace_target_index + 1) % points.size()
		target = points[pace_target_index]
	var movement_delta := current_physics_delta if delta < 0.0 else delta
	if not move_toward_position(target, tuning.walk_speed * pace_speed_scale, false, movement_delta):
		pace_target_index = (pace_target_index + 1) % points.size()
		velocity = Vector2.ZERO
		play_directional_animation("idle")


func update_conversation_behavior(delta: float):
	change_state(DEFAULT_BEHAVIOR_CONVERSATION)
	velocity = Vector2.ZERO
	var partner := get_conversation_partner()
	if partner != null:
		update_facing(partner.global_position - global_position)
	else:
		apply_home_facing()
	play_directional_animation("idle")
	update_conversation_dialogue(delta)


func update_conversation_dialogue(delta: float):
	if conversation_dialogue_bank == null:
		return
	if active_dialogue_bubble != null and is_instance_valid(active_dialogue_bubble):
		return

	conversation_timer -= delta
	if conversation_timer > 0.0:
		return

	if conversation_dialogue_bank.has_method("get_sequence"):
		var sequence: Resource = conversation_dialogue_bank.get_sequence()
		if sequence != null and sequence.has_method("is_empty") and not sequence.is_empty():
			active_dialogue_bubble = DIALOGUE_BUBBLE_SCENE.instantiate() as DialogueBubble
			add_child(active_dialogue_bubble)
			active_dialogue_bubble.open(sequence)
	conversation_timer = maxf(conversation_interval_seconds, 0.5)


func get_pace_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var point_a: Variant = get_marker_global_position(pace_point_a_path)
	var point_b: Variant = get_marker_global_position(pace_point_b_path)
	if point_a is Vector2 and point_b is Vector2:
		points.append(point_a)
		points.append(point_b)
		return points

	points.append(home_position + Vector2(-pace_distance, 0.0))
	points.append(home_position + Vector2(pace_distance, 0.0))
	return points


func get_marker_global_position(path: NodePath) -> Variant:
	if str(path) == "":
		return null
	var node := get_node_or_null(path) as Node2D
	if node == null:
		return null
	return node.global_position


func get_conversation_partner() -> Node2D:
	if str(conversation_partner_path) != "":
		var partner := get_node_or_null(conversation_partner_path) as Node2D
		if partner != null:
			return partner

	if str(conversation_group_id) == "":
		return null
	var root := get_parent()
	if root == null:
		return null
	return find_conversation_partner_in(root)


func find_conversation_partner_in(root: Node) -> Node2D:
	for child in root.get_children():
		if child != self and child is Node2D and child.get("conversation_group_id") == conversation_group_id:
			return child as Node2D
		var nested := find_conversation_partner_in(child)
		if nested != null:
			return nested
	return null


func move_toward_position(target_position: Vector2, speed: float, using_navigation: bool = false, delta: float = 0.0) -> bool:
	var offset := target_position - global_position
	if tuning != null and has_player_target() and target_position == player.global_position and offset.length() <= tuning.player_stop_distance:
		velocity = Vector2.ZERO
	else:
		velocity = offset.normalized() * speed if offset.length() > 1.0 else Vector2.ZERO
	if velocity == Vector2.ZERO:
		if state != "chase" and state != STATE_RETURN_HOME:
			play_directional_animation("idle")
		return false

	update_facing(velocity.normalized())
	play_directional_animation("run" if state == "chase" else "walk")
	var before_position := global_position
	current_movement_uses_navigation = using_navigation
	var moved := TopDownMovement.move(self, velocity, delta)
	if moved:
		return true
	if before_position.distance_to(global_position) <= 0.1:
		register_blocked_movement()
		return false
	return true


func should_route_movement_through_avoidance() -> bool:
	return false


func _on_navigation_velocity_computed(_safe_velocity: Vector2):
	if dead:
		return
	if navigation_agent != null:
		navigation_agent.velocity = Vector2.ZERO


func register_blocked_movement():
	if state == "chase" or state == STATE_RETURN_HOME:
		return
	velocity = Vector2.ZERO
	play_directional_animation("idle")


func can_start_attack() -> bool:
	if state == STATE_HURT:
		return false
	if not (combat_enabled and has_player_target() and attack_cooldown_timer <= 0.0 and tuning != null):
		return false
	if is_camp_linked() and not (camp_aggro_active or personal_aggro_active):
		return false
	if should_launch_projectile():
		var distance := global_position.distance_to(player.global_position)
		return distance >= tuning.ranged_min_distance and distance <= tuning.attack_range
	if not is_player_within_attack_distance():
		return false
	return true


func is_melee_knight() -> bool:
	return not should_launch_projectile()


func is_player_within_attack_distance() -> bool:
	if tuning == null or not has_player_target():
		return false
	return global_position.distance_to(player.global_position) <= get_effective_melee_attack_range()


func get_effective_melee_attack_range() -> float:
	if tuning == null:
		return MELEE_ATTACK_CONTACT_TOLERANCE
	return float(tuning.attack_range) + MELEE_ATTACK_CONTACT_TOLERANCE


func get_authored_attack_range_extent() -> float:
	var shape_node: CollisionShape2D = null
	if attack_range_area != null:
		shape_node = attack_range_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return 0.0

	var area_scale := attack_range_area.global_scale if attack_range_area != null else Vector2.ONE
	var shape_scale := shape_node.scale
	var combined_scale := Vector2(abs(area_scale.x * shape_scale.x), abs(area_scale.y * shape_scale.y))
	var max_scale := maxf(combined_scale.x, combined_scale.y)

	if shape_node.shape is CircleShape2D:
		return (shape_node.shape as CircleShape2D).radius * max_scale
	if shape_node.shape is CapsuleShape2D:
		var capsule := shape_node.shape as CapsuleShape2D
		return maxf(capsule.radius, capsule.height * 0.5) * max_scale
	if shape_node.shape is RectangleShape2D:
		var size := (shape_node.shape as RectangleShape2D).size
		return maxf(size.x * combined_scale.x, size.y * combined_scale.y) * 0.5
	return 0.0


func is_player_close_enough_for_melee_attack() -> bool:
	return is_melee_knight() and is_player_within_attack_distance()


func start_attack():
	clear_hurt_animation_hold()
	change_state("attack")
	velocity = Vector2.ZERO
	attack_windup_timer = tuning.attack_windup_seconds
	attack_recover_timer = tuning.attack_recover_seconds
	attack_has_dealt_damage = false
	face_player()
	active_attack_animation = get_directional_animation_name("attack")
	active_attack_duration = get_animation_duration(active_attack_animation, tuning.attack_windup_seconds + tuning.attack_recover_seconds)
	active_attack_hit_time = active_attack_duration * 0.5
	attack_windup_timer = active_attack_hit_time
	attack_recover_timer = maxf(active_attack_duration - active_attack_hit_time, 0.0)
	play_animation(active_attack_animation)


func update_attack(delta: float):
	velocity = Vector2.ZERO
	move_and_slide()
	if attack_windup_timer > 0.0:
		attack_windup_timer -= delta
		if attack_windup_timer <= 0.0:
			perform_attack()
		return

	attack_recover_timer -= delta
	if attack_recover_timer <= 0.0:
		finish_attack()


func finish_attack():
	cancel_active_attack()
	clear_hurt_animation_hold()
	if sprite != null:
		sprite.speed_scale = 1.0
	attack_cooldown_timer = tuning.attack_cooldown if tuning != null else attack_cooldown_timer
	change_state("chase" if should_chase_player() else get_default_state())


func on_attack_blocked():
	if dead:
		return

	if tuning != null:
		attack_cooldown_timer = maxf(attack_cooldown_timer, tuning.attack_cooldown)
	enter_hurt_state(get_block_stun_duration(), get_block_stun_speed_modifier())
	start_block_stun_hurt_animation_hold()


func enter_hurt_state(duration_override: float = -1.0, speed_modifier_override: float = -1.0):
	state_before_hurt = state
	clear_hurt_animation_hold()
	hurt_duration_override = duration_override
	hurt_speed_modifier_override = speed_modifier_override
	cancel_active_attack()
	clear_navigation_velocity()
	velocity = Vector2.ZERO
	hurt_timer = get_hurt_duration()
	change_state(STATE_HURT)
	play_animation(STATE_HURT)


func update_hurt(delta: float):
	var hurt_speed_modifier := get_hurt_speed_modifier()
	velocity = Vector2.ZERO * hurt_speed_modifier
	clear_navigation_velocity()
	if hurt_animation_finishing_after_hold:
		hurt_animation_finish_timer = maxf(hurt_animation_finish_timer - delta, 0.0)
		if hurt_animation_finish_timer > 0.0:
			return
		hurt_animation_finishing_after_hold = false
	elif sprite != null and str(sprite.animation) != resolve_animation_name(STATE_HURT):
		play_animation(STATE_HURT)

	if hurt_animation_hold_active:
		maintain_block_stun_hurt_animation_hold()
	hurt_timer = maxf(hurt_timer - delta, 0.0)
	if hurt_timer > 0.0:
		return

	if hurt_animation_hold_active and begin_block_stun_hurt_animation_finish():
		return

	if dead:
		return
	if should_chase_player():
		clear_hurt_state_overrides()
		change_state("chase")
	elif should_return_home_after_hurt():
		clear_hurt_state_overrides()
		change_state(STATE_RETURN_HOME)
	else:
		clear_hurt_state_overrides()
		change_state(get_default_state())


func get_hurt_duration() -> float:
	var fallback := get_animation_duration(STATE_HURT, 0.35)
	if hurt_duration_override > 0.0:
		return hurt_duration_override
	if tuning == null:
		return fallback
	return maxf(float(tuning.hurt_duration_seconds), 0.0) if float(tuning.hurt_duration_seconds) > 0.0 else fallback


func get_hurt_speed_modifier() -> float:
	if hurt_speed_modifier_override > 0.0:
		return hurt_speed_modifier_override
	return 0.0


func clear_hurt_state_overrides():
	hurt_duration_override = -1.0
	hurt_speed_modifier_override = -1.0
	clear_hurt_animation_hold()


func start_block_stun_hurt_animation_hold():
	if not has_hurt_animation():
		return

	hurt_animation_hold_active = true
	hurt_animation_finishing_after_hold = false
	hurt_animation_finish_timer = 0.0
	play_animation(STATE_HURT)
	maintain_block_stun_hurt_animation_hold()


func maintain_block_stun_hurt_animation_hold():
	if not has_hurt_animation():
		clear_hurt_animation_hold()
		return

	var hurt_animation := resolve_animation_name(STATE_HURT)
	if str(sprite.animation) != hurt_animation:
		sprite.animation = StringName(hurt_animation)
	sprite.frame = clampi(BLOCK_STUN_HURT_FREEZE_FRAME, 0, sprite.sprite_frames.get_frame_count(hurt_animation) - 1)
	sprite.frame_progress = 0.0
	sprite.speed_scale = 0.0
	if not sprite.is_playing():
		sprite.play()


func begin_block_stun_hurt_animation_finish() -> bool:
	hurt_animation_hold_active = false
	if not has_hurt_animation():
		clear_hurt_animation_hold()
		return false

	var hurt_animation := resolve_animation_name(STATE_HURT)
	sprite.speed_scale = 1.0
	sprite.animation = StringName(hurt_animation)
	sprite.frame = clampi(BLOCK_STUN_HURT_FREEZE_FRAME, 0, sprite.sprite_frames.get_frame_count(hurt_animation) - 1)
	sprite.frame_progress = 0.0
	sprite.play()
	hurt_animation_finish_timer = get_animation_duration_from_frame(hurt_animation, sprite.frame, 0.0)
	if hurt_animation_finish_timer <= 0.0:
		clear_hurt_animation_hold()
		return false

	hurt_animation_finishing_after_hold = true
	return true


func clear_hurt_animation_hold():
	hurt_animation_hold_active = false
	hurt_animation_finishing_after_hold = false
	hurt_animation_finish_timer = 0.0
	if sprite != null:
		sprite.speed_scale = 1.0


func has_hurt_animation() -> bool:
	return has_animation_resource() and sprite.sprite_frames.has_animation(STATE_HURT)


func get_block_stun_duration() -> float:
	if tuning == null:
		return get_animation_duration(STATE_HURT, 0.35)
	return maxf(float(tuning.block_stun_duration), 0.0)


func get_block_stun_speed_modifier() -> float:
	if tuning == null:
		return 0.0
	return maxf(float(tuning.block_stun_move_speed_modifier), 0.0)


func should_return_home_after_hurt() -> bool:
	if should_return_home():
		return true
	if not has_camp_default_behavior() or camp_aggro_active or player_in_tracking or is_at_home():
		return false
	return state_before_hurt == "chase" or state_before_hurt == "attack" or state_before_hurt == STATE_RETURN_HOME


func cancel_active_attack():
	attack_windup_timer = 0.0
	attack_recover_timer = 0.0
	attack_has_dealt_damage = true
	set_attack_shape_enabled(false)
	if attack_box != null:
		attack_box.set_deferred("monitoring", false)


func perform_attack():
	if attack_has_dealt_damage:
		return
	attack_has_dealt_damage = true

	if should_launch_projectile():
		launch_projectile()
		return

	activate_melee_hitbox()


func should_launch_projectile() -> bool:
	return tuning != null and tuning.projectile_scene != null and projectile_spawn != null


func launch_projectile():
	var projectile: Node = tuning.projectile_scene.instantiate()
	if projectile == null:
		return

	var projectile_parent: Node = get_parent()
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	projectile_parent.add_child(projectile)
	if projectile is Node2D:
		(projectile as Node2D).global_position = projectile_spawn.global_position

	if projectile.has_method("launch"):
		projectile.launch(self, get_direction_to_player(), tuning.projectile_speed, tuning.projectile_lifetime, tuning.attack_damage)


func activate_melee_hitbox():
	if attack_box == null:
		return

	attack_box.set_deferred("monitoring", true)
	apply_directional_attack_shape_offset()
	set_attack_shape_enabled(true)
	await get_tree().physics_frame
	hit_current_attack_overlaps()
	await get_tree().physics_frame
	set_attack_shape_enabled(false)
	if attack_box != null:
		attack_box.set_deferred("monitoring", false)


func set_attack_shape_enabled(enabled: bool):
	if attack_box == null:
		return

	if enabled:
		attack_shape_controller.enable_shape()
	else:
		attack_shape_controller.disable_shape()


func apply_directional_attack_shape_offset():
	if last_facing_direction == FACING_UP:
		attack_shape_controller.apply_offset(Vector2(0.0, -get_scaled_attack_box_offset(UP_ATTACK_BOX_OFFSET_RATIO)))
		return
	if last_facing_direction == FACING_DOWN:
		attack_shape_controller.apply_offset(Vector2(0.0, get_scaled_attack_box_offset(DOWN_ATTACK_BOX_OFFSET_RATIO)))
		return

	var horizontal_sign := -1.0 if last_horizontal_facing_direction == FACING_LEFT else 1.0
	attack_shape_controller.apply_offset(Vector2(get_scaled_attack_box_offset(HORIZONTAL_ATTACK_BOX_OFFSET_RATIO) * horizontal_sign, 0.0))


func get_scaled_attack_box_offset(offset_ratio: float) -> float:
	var base_height: float = attack_shape_controller.get_base_rectangle_height()
	if base_height <= 0.0:
		return 0.0

	return base_height * offset_ratio


func hit_current_attack_overlaps():
	if attack_box == null or not attack_box.monitoring:
		return

	for area in attack_box.get_overlapping_areas():
		_on_attack_box_area_entered(area)


func _on_attack_box_area_entered(area: Area2D):
	if not attack_has_dealt_damage or area == null or not area.is_in_group("player_hurtboxes"):
		return

	var target := area.get_parent()
	if target != null and target.has_method("take_damage"):
		var hit_result: Variant = target.take_damage(0, false, self)
		if hit_result == "blocked":
			on_attack_blocked()


func take_damage(amount: int, ignore_invulnerability: bool = false, _damage_source: Node = null):
	if dead or not damage_enabled or health == null:
		return false

	var applied: bool = health.take_damage(amount, ignore_invulnerability) == true
	if applied and not dead:
		enter_hurt_state()
	return applied


func _on_died():
	dead = true
	hurt_timer = 0.0
	clear_hurt_state_overrides()
	velocity = Vector2.ZERO
	clear_transform_range_refresh()
	untrack_player_transform_signal()
	clear_personal_aggro()
	cancel_active_attack()
	clear_active_dialogue_bubble()
	set_body_collision_enabled(false)
	set_combat_enabled(false)
	play_animation("death")
	defeated.emit(self)


func set_combat_enabled(enabled: bool):
	combat_enabled = enabled
	damage_enabled = enabled
	if not enabled:
		clear_personal_aggro()
	set_navigation_avoidance_enabled(enabled)
	if hurt_box != null:
		hurt_box.set_deferred("monitoring", enabled)
		hurt_box.set_deferred("monitorable", enabled)
	for area in [attack_box, tracking_area, attack_range_area]:
		if area is Area2D:
			(area as Area2D).set_deferred("monitoring", enabled)
	refresh_personal_detection_enabled()
	set_attack_shape_enabled(false)


func cache_authored_body_collision_state():
	alive_body_collision_enabled = movement_box == null or not movement_box.disabled


func set_body_collision_enabled(enabled: bool):
	if movement_box != null:
		movement_box.set_deferred("disabled", not (enabled and alive_body_collision_enabled))


func set_respawn_enabled(enabled: bool):
	respawn_enabled = enabled


func set_navigation_avoidance_enabled(_enabled: bool):
	if navigation_agent != null:
		navigation_agent.avoidance_enabled = false
	clear_navigation_velocity()


func clear_navigation_velocity():
	if navigation_agent != null:
		navigation_agent.velocity = Vector2.ZERO


func respawn_at(respawn_position: Vector2):
	global_position = respawn_position
	clear_navigation_velocity()
	reset_navigation_progress()
	restore_authored_navigation_distances()
	velocity = Vector2.ZERO
	hurt_timer = 0.0
	clear_hurt_state_overrides()
	clear_transform_range_refresh()
	untrack_player_transform_signal()
	if health != null:
		health.heal_to_full()
	dead = false
	visible = true
	set_body_collision_enabled(true)
	set_combat_enabled(true)
	set_navigation_avoidance_enabled(true)
	camp_aggro_active = false
	clear_personal_aggro()
	clear_active_dialogue_bubble()
	change_state(get_default_state())
	play_directional_animation("idle")
	refresh_personal_detection_enabled()


func hide_as_defeated():
	dead = true
	visible = false
	velocity = Vector2.ZERO
	hurt_timer = 0.0
	clear_hurt_state_overrides()
	clear_transform_range_refresh()
	untrack_player_transform_signal()
	clear_navigation_velocity()
	reset_navigation_progress()
	restore_authored_navigation_distances()
	clear_personal_aggro()
	cancel_active_attack()
	clear_active_dialogue_bubble()
	set_body_collision_enabled(false)
	set_combat_enabled(false)
	set_navigation_avoidance_enabled(false)
	if health != null:
		health.force_dead()


func collect_story_save_state() -> Dictionary:
	return {
		"position": vector_to_data(global_position),
		"dead": dead,
		"health": 0 if health == null else int(health.health),
		"respawn_enabled": respawn_enabled,
		"encounter_dialogue_played": encounter_dialogue_played,
		"facing_left": facing_left,
		"last_facing_direction": last_facing_direction,
	}


func apply_story_save_state(saved_state: Dictionary):
	global_position = data_to_vector(saved_state.get("position", {}), global_position)
	reset_navigation_progress()
	facing_left = bool(saved_state.get("facing_left", facing_left))
	last_horizontal_facing_direction = FACING_LEFT if facing_left else FACING_RIGHT
	last_facing_direction = str(saved_state.get("last_facing_direction", last_horizontal_facing_direction))
	respawn_enabled = bool(saved_state.get("respawn_enabled", respawn_enabled))
	encounter_dialogue_played = bool(saved_state.get("encounter_dialogue_played", encounter_dialogue_played))
	if bool(saved_state.get("dead", false)) or int(saved_state.get("health", 1)) <= 0:
		hide_as_defeated()
		return

	dead = false
	visible = true
	hurt_timer = 0.0
	clear_hurt_state_overrides()
	clear_transform_range_refresh()
	untrack_player_transform_signal()
	clear_personal_aggro()
	set_body_collision_enabled(true)
	set_combat_enabled(true)
	if health != null:
		health.heal_to_full()
		health.health = clamp(int(saved_state.get("health", health.health)), 1, health.max_health)
		health.health_changed.emit(health.health, health.max_health)


func reset_for_level_entry():
	global_position = home_position
	clear_navigation_velocity()
	reset_navigation_progress()
	restore_authored_navigation_distances()
	velocity = Vector2.ZERO
	hurt_timer = 0.0
	clear_hurt_state_overrides()
	clear_transform_range_refresh()
	untrack_player_transform_signal()
	facing_left = spawn_facing_left
	last_horizontal_facing_direction = FACING_LEFT if facing_left else FACING_RIGHT
	last_facing_direction = last_horizontal_facing_direction
	respawn_enabled = true
	encounter_dialogue_played = false
	if health != null:
		health.heal_to_full()
	dead = false
	visible = true
	set_body_collision_enabled(true)
	set_combat_enabled(true)
	set_navigation_avoidance_enabled(true)
	camp_aggro_active = false
	clear_personal_aggro()
	clear_active_dialogue_bubble()
	player_in_detection = false
	player_in_tracking = false
	player_in_attack_range = false
	change_state(get_default_state())
	refresh_personal_detection_enabled()


func set_encounter_dialogue_override(sequence: Resource):
	encounter_dialogue_override = sequence


func clear_encounter_dialogue_override():
	encounter_dialogue_override = null


func try_start_encounter_dialogue(auto_close_seconds: float = -1.0) -> bool:
	if encounter_dialogue_played:
		return false

	var sequence := get_encounter_dialogue_sequence()
	if sequence == null or sequence.is_empty():
		return false

	encounter_dialogue_played = true
	clear_active_dialogue_bubble()
	active_dialogue_bubble = DIALOGUE_BUBBLE_SCENE.instantiate() as DialogueBubble
	active_dialogue_is_encounter_bark = true
	add_child(active_dialogue_bubble)
	active_dialogue_bubble.open(sequence)
	encounter_dialogue_started.emit(self)
	auto_close_active_encounter_bark(auto_close_seconds if auto_close_seconds >= 0.0 else encounter_bark_auto_close_seconds)
	return true


func auto_close_active_encounter_bark(delay_seconds: float):
	if delay_seconds <= 0.0 or active_dialogue_bubble == null:
		return

	var bubble := active_dialogue_bubble
	await get_tree().create_timer(delay_seconds).timeout
	if active_dialogue_bubble == bubble and is_instance_valid(bubble):
		clear_active_dialogue_bubble()


func clear_active_dialogue_bubble():
	if active_dialogue_bubble != null and is_instance_valid(active_dialogue_bubble):
		if active_dialogue_bubble.has_method("close"):
			active_dialogue_bubble.close(false)
		else:
			active_dialogue_bubble.queue_free()
	active_dialogue_bubble = null
	active_dialogue_is_encounter_bark = false


func get_encounter_dialogue_sequence() -> Resource:
	if encounter_dialogue_override != null:
		return encounter_dialogue_override
	if tuning != null and tuning.encounter_dialogue_bank != null:
		return tuning.encounter_dialogue_bank.get_sequence()
	return null


func has_player_target() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		track_player_transform_signal(player)
	return player != null and player.visible


func refresh_personal_detection_enabled():
	if not is_camp_linked():
		set_personal_detection_enabled(combat_enabled and not dead)
		set_personal_tracking_enabled(combat_enabled and not dead)
		return

	set_personal_detection_enabled(false)
	set_personal_tracking_enabled(false)


func set_personal_detection_enabled(enabled: bool):
	if detection_area == null:
		return
	detection_area.set_deferred("monitoring", enabled)


func set_personal_tracking_enabled(enabled: bool):
	if tracking_area == null:
		return
	tracking_area.set_deferred("monitoring", enabled)


func is_outside_linked_camp_bounds() -> bool:
	var campfire := get_linked_campfire_base()
	if campfire == null or not campfire.has_method("is_position_inside_camp_bounds"):
		return false
	return not bool(campfire.is_position_inside_camp_bounds(global_position))


func start_personal_aggro(target: Node):
	if dead or not combat_enabled or camp_aggro_active or is_camp_linked():
		return
	player = target as Node2D
	if player == null:
		return
	track_player_transform_signal(player)
	personal_aggro_active = true
	player_in_tracking = true
	clear_navigation_velocity()
	reset_navigation_progress()
	change_state("chase")
	chase_player()
	player_tracking_changed.emit(self)


func clear_personal_aggro():
	personal_aggro_active = false


func force_aggro(target: Node):
	if dead or not combat_enabled:
		return
	player = target as Node2D
	track_player_transform_signal(player)
	clear_personal_aggro()
	camp_aggro_active = player != null
	if camp_aggro_active:
		player_in_tracking = true
		clear_navigation_velocity()
		reset_navigation_progress()
		change_state("chase")
		chase_player()
	refresh_personal_detection_enabled()


func return_to_camp():
	clear_transform_range_refresh()
	camp_aggro_active = false
	clear_personal_aggro()
	player_in_tracking = false
	player_in_attack_range = false
	cancel_active_attack()
	clear_active_dialogue_bubble()
	if dead:
		return
	reset_navigation_progress()
	change_state(STATE_RETURN_HOME)
	refresh_personal_detection_enabled()


func has_active_player_tracking() -> bool:
	return player_in_tracking


func is_currently_engaging_player() -> bool:
	return camp_aggro_active or personal_aggro_active or state == "chase" or state == "attack"


func should_defer_player_range_change(body: Node) -> bool:
	if body == null:
		return false
	if refreshing_player_ranges_after_transform and body == player:
		return true
	if body.has_method("is_transforming_forms") and bool(body.call("is_transforming_forms")):
		return true
	return body.has_method("is_life_respawn_pending") and bool(body.call("is_life_respawn_pending"))


func refresh_player_ranges_after_transform():
	was_engaged_before_transform_refresh = was_engaged_before_transform_refresh or is_currently_engaging_player() or player_in_tracking
	pending_form_settle_physics_frames = maxi(pending_form_settle_physics_frames, FORM_CHANGE_SETTLE_PHYSICS_FRAMES)
	if refreshing_player_ranges_after_transform:
		return

	refreshing_player_ranges_after_transform = true
	call_deferred("refresh_player_ranges_after_transform_deferred")


func refresh_player_ranges_after_transform_deferred():
	if not is_inside_tree():
		clear_transform_range_refresh()
		return

	await get_tree().physics_frame

	if not is_inside_tree():
		clear_transform_range_refresh()
		return

	if dead or not combat_enabled:
		player_in_detection = false
		player_in_tracking = false
		player_in_attack_range = false
		clear_transform_range_refresh()
		return

	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		player_in_detection = false
		player_in_tracking = false
		player_in_attack_range = false
		clear_transform_range_refresh()
		player_tracking_changed.emit(self)
		return

	var player_is_still_transforming: bool = player.has_method("is_transforming_forms") and bool(player.call("is_transforming_forms"))
	var player_respawn_pending: bool = player.has_method("is_life_respawn_pending") and bool(player.call("is_life_respawn_pending"))
	if player_is_still_transforming or player_respawn_pending:
		if player_is_still_transforming:
			player_in_tracking = player_in_tracking or was_engaged_before_transform_refresh
		call_deferred("refresh_player_ranges_after_transform_deferred")
		return

	if pending_form_settle_physics_frames > 0:
		pending_form_settle_physics_frames -= 1
		player_in_tracking = player_in_tracking or was_engaged_before_transform_refresh
		call_deferred("refresh_player_ranges_after_transform_deferred")
		return

	var was_tracking := player_in_tracking
	var was_personal := personal_aggro_active
	var was_camp := camp_aggro_active
	var was_engaged := was_engaged_before_transform_refresh or is_currently_engaging_player()
	var overlapping_detection := is_player_overlapping_area(detection_area)
	var overlapping_tracking := is_player_overlapping_area(tracking_area)
	var overlapping_attack := is_player_overlapping_area(attack_range_area)

	clear_transform_range_refresh()
	player_in_detection = overlapping_detection
	player_in_attack_range = overlapping_attack
	player_in_tracking = overlapping_tracking and (was_engaged or overlapping_detection or overlapping_attack or not is_camp_linked())

	if player_in_tracking and (was_camp or was_personal):
		clear_navigation_velocity()
		reset_navigation_progress()
		change_state("chase")
	elif was_personal and not player_in_tracking:
		return_to_camp()
	elif was_tracking != player_in_tracking:
		player_tracking_changed.emit(self)


func is_player_overlapping_area(area: Area2D) -> bool:
	if area == null or not area.monitoring:
		return false

	for body in area.get_overlapping_bodies():
		if body == player:
			return true
	return false


func track_player_transform_signal(player_node: Node):
	if player_node == null or not player_node.has_signal("transformation_state_changed"):
		return

	var callback := Callable(self, "_on_player_transformation_state_changed")
	if tracked_transform_signal_player == player_node:
		if not player_node.is_connected("transformation_state_changed", callback):
			player_node.connect("transformation_state_changed", callback)
		return

	untrack_player_transform_signal()
	tracked_transform_signal_player = player_node
	if not player_node.is_connected("transformation_state_changed", callback):
		player_node.connect("transformation_state_changed", callback)


func untrack_player_transform_signal():
	var callback := Callable(self, "_on_player_transformation_state_changed")
	if tracked_transform_signal_player != null and is_instance_valid(tracked_transform_signal_player):
		if tracked_transform_signal_player.is_connected("transformation_state_changed", callback):
			tracked_transform_signal_player.disconnect("transformation_state_changed", callback)
	tracked_transform_signal_player = null


func clear_transform_range_refresh():
	refreshing_player_ranges_after_transform = false
	was_engaged_before_transform_refresh = false
	pending_form_settle_physics_frames = 0


func _on_player_transformation_state_changed(_active: bool):
	if player == null or not is_instance_valid(player):
		return
	refresh_player_ranges_after_transform()


func get_home_position() -> Vector2:
	return home_position


func set_campfire_base_path_if_empty(path: NodePath):
	if str(campfire_base_path) == "":
		campfire_base_path = path
		configure_navigation_agent()
		refresh_personal_detection_enabled()


func get_linked_campfire_base() -> Node:
	if str(campfire_base_path) == "":
		return null
	return get_node_or_null(campfire_base_path)


func has_camp_default_behavior() -> bool:
	return str(campfire_base_path) != "" or default_behavior != DEFAULT_BEHAVIOR_IDLE


func is_camp_linked() -> bool:
	return str(campfire_base_path) != ""


func get_default_state() -> String:
	if has_camp_default_behavior():
		return default_behavior
	return "patrol" if has_patrol_route() else DEFAULT_BEHAVIOR_IDLE


func is_at_home() -> bool:
	var arrival_distance: float = tuning.patrol_arrival_distance if tuning != null else 6.0
	return global_position.distance_to(home_position) <= arrival_distance


func apply_home_facing():
	last_facing_direction = home_facing_direction
	if home_facing_direction == FACING_LEFT or home_facing_direction == FACING_RIGHT:
		last_horizontal_facing_direction = home_facing_direction
		facing_left = home_facing_direction == FACING_LEFT


func face_player():
	if has_player_target():
		update_facing(get_direction_to_player())


func get_direction_to_player() -> Vector2:
	if not has_player_target():
		return Vector2.RIGHT
	return (player.global_position - global_position).normalized()


func update_facing(direction: Vector2):
	if direction == Vector2.ZERO:
		return

	if abs(direction.y) > abs(direction.x):
		last_facing_direction = FACING_UP if direction.y < 0.0 else FACING_DOWN
		return

	if abs(direction.x) <= (tuning.facing_deadzone if tuning != null else 0.1):
		return

	last_facing_direction = FACING_LEFT if direction.x < 0.0 else FACING_RIGHT
	last_horizontal_facing_direction = last_facing_direction
	facing_left = last_facing_direction == FACING_LEFT


func play_animation(animation_name: String):
	if sprite == null or sprite.sprite_frames == null:
		return

	var resolved_animation := resolve_animation_name(animation_name)
	if not hurt_animation_hold_active:
		sprite.speed_scale = 1.0
	apply_animation_flip(resolved_animation)
	if sprite.sprite_frames.has_animation(resolved_animation):
		var resolved_name := StringName(resolved_animation)
		if sprite.animation != resolved_name:
			sprite.animation = resolved_name
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.play()
		elif not sprite.is_playing():
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.play()


func play_directional_animation(base_animation_name: String):
	play_animation(get_directional_animation_name(base_animation_name))


func get_directional_animation_name(base_animation_name: String) -> String:
	if not has_animation_resource():
		return base_animation_name

	var direction_lookup: Dictionary = DIRECTIONAL_ANIMATIONS.get(base_animation_name, {})
	var directional_animation: String = str(direction_lookup.get(last_facing_direction, base_animation_name))
	if sprite.sprite_frames.has_animation(directional_animation):
		return directional_animation

	return base_animation_name


func resolve_animation_name(animation_name: String) -> String:
	if not has_animation_resource():
		return animation_name
	if sprite.sprite_frames.has_animation(animation_name):
		return animation_name
	return "idle" if sprite.sprite_frames.has_animation("idle") else animation_name


func apply_animation_flip(animation_name: String):
	if sprite == null:
		return

	var is_horizontal_animation: bool = HORIZONTAL_BASE_ANIMATIONS.has(animation_name)
	var is_horizontal_facing: bool = last_facing_direction == FACING_LEFT or last_facing_direction == FACING_RIGHT
	sprite.flip_h = is_horizontal_animation and is_horizontal_facing and last_horizontal_facing_direction == FACING_LEFT


func get_animation_duration(animation_name: String, fallback: float) -> float:
	if not has_animation_resource() or not sprite.sprite_frames.has_animation(animation_name):
		return fallback

	var animation_speed: float = sprite.sprite_frames.get_animation_speed(animation_name)
	if animation_speed <= 0.0:
		return fallback

	var duration: float = 0.0
	var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
	for frame_index in range(frame_count):
		duration += sprite.sprite_frames.get_frame_duration(animation_name, frame_index) / animation_speed

	return duration if duration > 0.0 else fallback


func get_animation_duration_from_frame(animation_name: String, frame_index: int, fallback: float) -> float:
	if not has_animation_resource() or not sprite.sprite_frames.has_animation(animation_name):
		return fallback

	var animation_speed: float = sprite.sprite_frames.get_animation_speed(animation_name)
	if animation_speed <= 0.0:
		return fallback

	var duration: float = 0.0
	var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
	var starting_frame := clampi(frame_index, 0, frame_count - 1)
	for current_frame in range(starting_frame, frame_count):
		duration += sprite.sprite_frames.get_frame_duration(animation_name, current_frame) / animation_speed

	return duration if duration > 0.0 else fallback


func has_animation_resource() -> bool:
	return sprite != null and sprite.sprite_frames != null


func change_state(new_state: String):
	if state == new_state:
		if state == STATE_RETURN_HOME:
			apply_return_home_navigation_distances()
		return
	var old_state := state
	state = new_state
	if state == STATE_RETURN_HOME:
		apply_return_home_navigation_distances()
	elif old_state == STATE_RETURN_HOME:
		restore_authored_navigation_distances()


func apply_return_home_navigation_distances():
	if navigation_agent == null or tuning == null:
		return

	var arrival_distance: float = maxf(float(tuning.patrol_arrival_distance), NAVIGATION_NEAR_SELF_DISTANCE)
	navigation_agent.target_desired_distance = arrival_distance
	navigation_agent.path_desired_distance = minf(maxf(authored_navigation_path_desired_distance, NAVIGATION_NEAR_SELF_DISTANCE), arrival_distance)


func restore_authored_navigation_distances():
	if navigation_agent == null:
		return

	if authored_navigation_path_desired_distance > 0.0:
		navigation_agent.path_desired_distance = authored_navigation_path_desired_distance
	if authored_navigation_target_desired_distance > 0.0:
		navigation_agent.target_desired_distance = authored_navigation_target_desired_distance


func vector_to_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func data_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	if not (value is Dictionary):
		return fallback
	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


func _on_detection_body_entered(body: Node2D):
	if body.is_in_group("player"):
		if is_camp_linked():
			return
		player = body
		track_player_transform_signal(body)
		if should_defer_player_range_change(body):
			player_in_detection = true
			refresh_player_ranges_after_transform()
			return
		player_in_detection = true
		if not is_camp_linked():
			try_start_encounter_dialogue()
			player_detected.emit(self, body)
		elif not camp_aggro_active and is_outside_linked_camp_bounds():
			start_personal_aggro(body)
		elif not camp_aggro_active and state == DEFAULT_BEHAVIOR_IDLE:
			play_directional_animation("idle")


func _on_detection_body_exited(body: Node2D):
	if body == player:
		if is_camp_linked():
			return
		if should_defer_player_range_change(body):
			refresh_player_ranges_after_transform()
			return
		player_in_detection = false


func _on_tracking_body_entered(body: Node2D):
	if body.is_in_group("player"):
		if is_camp_linked():
			return
		player = body
		track_player_transform_signal(body)
		if should_defer_player_range_change(body):
			player_in_tracking = true
			refresh_player_ranges_after_transform()
			return
		player_in_tracking = true
		if not is_camp_linked():
			player_detected.emit(self, body)
		elif not camp_aggro_active and state == DEFAULT_BEHAVIOR_IDLE:
			play_directional_animation("idle")
		player_tracking_changed.emit(self)


func _on_tracking_body_exited(body: Node2D):
	if body == player:
		if is_camp_linked():
			return
		if should_defer_player_range_change(body):
			refresh_player_ranges_after_transform()
			return
		player_in_tracking = false
		if personal_aggro_active:
			clear_personal_aggro()
			return_to_camp()
		player_tracking_changed.emit(self)


func _on_attack_range_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player = body
		track_player_transform_signal(body)
		if should_defer_player_range_change(body):
			player_in_attack_range = true
			refresh_player_ranges_after_transform()
			return
		player_in_attack_range = true


func _on_attack_range_body_exited(body: Node2D):
	if body == player:
		if should_defer_player_range_change(body):
			refresh_player_ranges_after_transform()
			return
		player_in_attack_range = false
