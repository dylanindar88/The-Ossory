extends CharacterBody2D

signal interaction_requested(interactable: Node2D)

const DEFAULT_TUNING: PlayerTuning = preload("res://resources/characters/saorise/player_tuning.tres")

@export var tuning: PlayerTuning = DEFAULT_TUNING
@export var initial_form_id: StringName = &"human"
@export var form_definitions: Array[PlayerFormDefinition] = []

@onready var forms_root: Node2D = $Forms
@onready var sprite: AnimatedSprite2D = $Forms/HumanForm/Body
@onready var effects: EffectList = $Effects
@onready var health = $Health
@onready var hurt_box = $HurtBox
@onready var attack_box = $AttackBox
@onready var movement_box: CollisionShape2D = $MovementBox
@onready var hurt_collision_shape: CollisionShape2D = $HurtBox/CollisionShape2D

var current_state
var states = {}
var hitbox_manager: Object
var dead := false
var current_form: PlayerFormDefinition
var current_form_id: StringName = &"human"
var forms_by_id: Dictionary = {}

var last_facing = "right"
var last_horizontal_facing = "right"
var last_move_axis = "horizontal"
var last_input_direction = Vector2.RIGHT

var can_dash = true
var dash_cooldown_timer = 0.0
var walk_speed: float
var run_speed: float
var dash_speed: float
var dash_duration: float
var dash_cooldown: float
var attack_speed_modifier: float
var attack_damage: int
var combo_2_damage_multiplier: float
var attack_combo_restart_delay: float
var attack_cooldown_timer := 0.0
var can_attack_from_hold := false
var block_speed_modifier: float
var nearby_interactables: Array[Node2D] = []
var current_interactable: Node2D
var pending_interaction_target: Node2D
var dialogue_input_locked: bool = false
var blink_generation: int = 0


func _ready():
	cache_form_definitions()
	activate_form(initial_form_id)

	add_to_group("player")
	hurt_box.add_to_group("player_hurtboxes")
	hurt_box.monitoring = true
	hurt_box.monitorable = true
	hurt_box.collision_layer = 2
	hurt_box.collision_mask = 0

	states["move"] = preload("res://scripts/characters/saorise/state_machine/movementState.gd").new()
	states["dash"] = preload("res://scripts/characters/saorise/state_machine/dashState.gd").new()
	states["attack"] = preload("res://scripts/characters/saorise/state_machine/attackState.gd").new()
	states["block"] = preload("res://scripts/characters/saorise/state_machine/blockState.gd").new()

	effects.clear_effects()

	hitbox_manager = preload("res://scripts/characters/saorise/combat/attackBoxManager.gd").new()
	hitbox_manager.attack_box = attack_box
	hitbox_manager.player_health = health
	hitbox_manager.setup()
	configure_hitbox_manager()

	states["attack"].hitbox_manager = hitbox_manager

	if health.has_method("set_tuning"):
		health.set_tuning(tuning)

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)
	if health.has_signal("blink_requested") and not health.blink_requested.is_connected(_on_blink_requested):
		health.blink_requested.connect(_on_blink_requested)

	change_state("move")


func apply_tuning():
	if tuning == null:
		tuning = DEFAULT_TUNING

	walk_speed = tuning.walk_speed
	run_speed = tuning.run_speed
	dash_speed = tuning.dash_speed
	dash_duration = tuning.dash_duration
	dash_cooldown = tuning.dash_cooldown
	attack_speed_modifier = tuning.attack_speed_modifier
	attack_damage = tuning.attack_damage
	combo_2_damage_multiplier = tuning.combo_2_damage_multiplier
	attack_combo_restart_delay = tuning.attack_combo_restart_delay
	block_speed_modifier = tuning.block_speed_modifier


func cache_form_definitions():
	forms_by_id.clear()
	for form in form_definitions:
		if form == null:
			continue

		forms_by_id[form.form_id] = form


func activate_form(form_id: StringName) -> bool:
	var form: PlayerFormDefinition = forms_by_id.get(form_id)
	if form == null:
		form = forms_by_id.get(initial_form_id)
	if form == null and not form_definitions.is_empty():
		form = form_definitions[0]
	if form == null:
		apply_tuning()
		return false

	current_form = form
	current_form_id = form.form_id
	tuning = form.tuning if form.tuning != null else DEFAULT_TUNING
	apply_tuning()
	apply_form_visuals(form)
	apply_form_collisions(form)
	configure_hitbox_manager()
	return true


func set_form(form_id: StringName) -> bool:
	if current_form_id == form_id:
		return true

	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()

	health.set_blocking(false)
	health.set_parry_window(false)
	health.end_parry_bonus()
	velocity = Vector2.ZERO
	can_attack_from_hold = false

	var form_changed := activate_form(form_id)
	if not form_changed:
		return false

	if health.has_method("set_tuning"):
		health.set_tuning(tuning)

	if states.has("move"):
		change_state("move")
	else:
		hold_dialogue_idle()

	update_effects()
	return true


func apply_form_visuals(form: PlayerFormDefinition):
	var previous_sprite_frames: SpriteFrames = sprite.sprite_frames if sprite != null else null

	for child in forms_root.get_children():
		if child is CanvasItem:
			child.visible = false

	var form_node := get_node_or_null(form.form_node_path)
	if form_node is CanvasItem:
		form_node.visible = true

	var body_node: Node = null
	if form_node != null:
		body_node = form_node.get_node_or_null(form.body_node_path)

	if body_node is AnimatedSprite2D:
		sprite = body_node

	if sprite == null:
		return

	if form.sprite_frames != null:
		sprite.sprite_frames = form.sprite_frames
	elif sprite.sprite_frames == null:
		sprite.sprite_frames = previous_sprite_frames

	sprite.position = form.body_position
	sprite.scale = form.body_scale
	sprite.offset = form.body_offset
	sprite.speed_scale = 1.0
	sprite.modulate.a = 1.0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(form.default_animation):
		sprite.play(form.default_animation)


func apply_form_collisions(form: PlayerFormDefinition):
	if movement_box != null and form.movement_shape != null:
		movement_box.shape = form.movement_shape
		movement_box.position = form.movement_shape_position
		movement_box.rotation = form.movement_shape_rotation

	if hurt_collision_shape != null and form.hurt_shape != null:
		hurt_collision_shape.shape = form.hurt_shape
		hurt_collision_shape.position = form.hurt_shape_position
		hurt_collision_shape.rotation = form.hurt_shape_rotation


func configure_hitbox_manager():
	if hitbox_manager == null:
		return

	hitbox_manager.attack_damage = attack_damage
	hitbox_manager.combo_2_damage_multiplier = combo_2_damage_multiplier
	if current_form != null and hitbox_manager.has_method("set_attack_profiles"):
		hitbox_manager.set_attack_profiles(current_form.get_attack_profiles())


func can_current_form_attack() -> bool:
	return current_form == null or current_form.can_attack


func can_current_form_block() -> bool:
	return current_form == null or current_form.can_block


func can_current_form_dash() -> bool:
	return current_form == null or current_form.can_dash


func can_current_form_interact() -> bool:
	return current_form == null or current_form.can_interact


func can_current_form_talk() -> bool:
	return current_form == null or current_form.can_talk


func _physics_process(delta):
	if dead:
		velocity = Vector2.ZERO
		return

	if not can_dash:
		dash_cooldown_timer -= delta

		if dash_cooldown_timer <= 0:
			can_dash = true

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	if dialogue_input_locked:
		hold_dialogue_idle()
		update_effects()
		return

	if current_state:
		current_state.physics_update(self, delta)

	update_effects()


func _unhandled_input(event: InputEvent):
	if dead:
		return

	if dialogue_input_locked:
		return

	if event.is_action_pressed("interact"):
		current_interactable = get_current_interactable()
		pending_interaction_target = current_interactable
		get_viewport().set_input_as_handled()
	elif event.is_action_released("interact"):
		var released_target: Node2D = pending_interaction_target
		pending_interaction_target = null
		current_interactable = get_current_interactable()

		if released_target != null and released_target == current_interactable and has_interactable(released_target):
			try_interact_with(released_target)

		get_viewport().set_input_as_handled()


func change_state(state_name):
	if current_state:
		current_state.exit(self)

	current_state = states[state_name]
	current_state.enter(self)


func take_damage(amount: int, ignore_invulnerability: bool = false, damage_source: Node = null):
	if dead:
		return "ignored"

	if current_state and current_state.has_method("prepare_for_incoming_damage"):
		current_state.prepare_for_incoming_damage(self)

	return health.take_damage(amount, ignore_invulnerability, damage_source)


func set_dialogue_input_locked(locked: bool):
	if dialogue_input_locked == locked:
		return

	dialogue_input_locked = locked
	velocity = Vector2.ZERO
	pending_interaction_target = null
	can_attack_from_hold = false

	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()

	health.set_blocking(false)
	health.set_parry_window(false)
	health.end_parry_bonus()

	if dialogue_input_locked and current_state != states.get("move"):
		change_state("move")

	hold_dialogue_idle()
	update_effects()


func is_dialogue_input_locked() -> bool:
	return dialogue_input_locked


func hold_dialogue_idle():
	velocity = Vector2.ZERO
	health.set_running(false)
	play_directional_idle()


func play_directional_idle():
	var idle_animation := get_directional_idle_animation()
	if sprite.sprite_frames != null and not sprite.sprite_frames.has_animation(idle_animation):
		idle_animation = &"idle"

	sprite.play(idle_animation)
	sprite.flip_h = idle_animation == &"idle" and last_horizontal_facing == "left"


func get_directional_idle_animation() -> StringName:
	if last_facing == "up":
		return &"idle_up"

	if last_facing == "down":
		return &"idle_down"

	return &"idle"


func get_move_input_vector() -> Vector2:
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return input_vector.normalized()


func remember_input_direction(input_vector: Vector2):
	if input_vector != Vector2.ZERO:
		last_input_direction = input_vector


func get_cardinal_direction_to(world_position: Vector2) -> String:
	var direction_vector: Vector2 = world_position - global_position

	if direction_vector.y > abs(direction_vector.x):
		return "down"

	if direction_vector.y < -abs(direction_vector.x):
		return "up"

	if direction_vector.x < 0:
		return "left"

	return "right"


func remember_horizontal_facing(facing: String):
	if facing == "left" or facing == "right":
		last_horizontal_facing = facing


func get_sprite_animation_duration(anim_name: String, fallback: float) -> float:
	var sprite_frames: SpriteFrames = sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(anim_name):
		return fallback

	var animation_speed := sprite_frames.get_animation_speed(anim_name)
	if animation_speed <= 0:
		return fallback

	return float(sprite_frames.get_frame_count(anim_name)) / animation_speed


func move_with_villager_blocking(delta: float):
	var motion: Vector2 = velocity * delta
	if should_stop_for_villager(motion):
		velocity = Vector2.ZERO
		return

	move_and_slide()


func should_stop_for_villager(motion: Vector2) -> bool:
	if motion == Vector2.ZERO:
		return false

	var collision: KinematicCollision2D = move_and_collide(motion, true)
	if collision == null:
		return false

	var collider: Object = collision.get_collider()
	if not (collider is Node2D):
		return false

	var collider_node: Node2D = collider as Node2D
	return collider_node.is_in_group("villagers") and is_motion_toward_node(collider_node, motion)


func is_motion_toward_node(node: Node2D, motion: Vector2) -> bool:
	var current_distance: float = global_position.distance_squared_to(node.global_position)
	var next_distance: float = (global_position + motion).distance_squared_to(node.global_position)
	return next_distance < current_distance


func update_effects():
	if effects == null:
		return

	var active_effects: Array[String] = health.get_active_effects()
	current_interactable = get_current_interactable()

	if current_interactable != null:
		active_effects.append("interactable_pressed" if Input.is_action_pressed("interact") else "interactable")

	effects.set_effects(active_effects)


func register_interactable(interactable: Node2D):
	if interactable == null or nearby_interactables.has(interactable):
		return

	nearby_interactables.append(interactable)
	current_interactable = get_current_interactable()
	update_effects()


func unregister_interactable(interactable: Node2D):
	if interactable == null:
		return

	nearby_interactables.erase(interactable)
	if pending_interaction_target == interactable:
		pending_interaction_target = null

	current_interactable = get_current_interactable()
	update_effects()


func get_current_interactable() -> Node2D:
	if not can_current_form_interact():
		return null

	if CombatStateManager != null and CombatStateManager.is_in_combat():
		return null

	prune_invalid_interactables()

	var nearest_interactable: Node2D = null
	var nearest_distance: float = INF
	for interactable in nearby_interactables:
		var distance: float = global_position.distance_squared_to(interactable.global_position)
		if distance < nearest_distance:
			nearest_interactable = interactable
			nearest_distance = distance

	return nearest_interactable


func prune_invalid_interactables():
	for index in range(nearby_interactables.size() - 1, -1, -1):
		var interactable: Node2D = nearby_interactables[index]
		if interactable == null or not is_instance_valid(interactable) or not interactable.is_inside_tree() or not interactable.visible:
			if pending_interaction_target == interactable:
				pending_interaction_target = null
			nearby_interactables.remove_at(index)


func has_interactable(interactable: Node2D) -> bool:
	prune_invalid_interactables()
	return nearby_interactables.has(interactable)


func try_interact_with(interactable: Node2D):
	if not can_current_form_interact():
		return

	if CombatStateManager != null and not CombatStateManager.can_start_dialogue():
		return

	interaction_requested.emit(interactable)


func get_current_form_id() -> StringName:
	return current_form_id


func _on_died():
	stop_sprite_blink()
	dead = true
	velocity = Vector2.ZERO
	health.set_blocking(false)
	health.set_parry_window(false)
	health.end_parry_bonus()
	update_effects()

	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()

	for area in [hurt_box, attack_box]:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
		for child in area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)

	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	visible = false
	call_deferred("respawn_after_death")


func respawn_after_death():
	if SaveManager != null and SaveManager.has_method("spend_life_and_respawn_player_in_place"):
		SaveManager.spend_life_and_respawn_player_in_place()


func soft_respawn_in_place(extra_invulnerability_time: float = 0.0):
	soft_respawn_at_position(global_position, extra_invulnerability_time)


func soft_respawn_at_position(respawn_position: Vector2, extra_invulnerability_time: float = 0.0):
	stop_sprite_blink()
	global_position = respawn_position
	dead = false
	visible = true
	velocity = Vector2.ZERO
	nearby_interactables.clear()
	current_interactable = null
	pending_interaction_target = null
	dialogue_input_locked = false
	can_attack_from_hold = false
	set_physics_process(true)

	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()

	if health.has_method("restore_full_after_respawn"):
		health.restore_full_after_respawn(extra_invulnerability_time)

	if sprite != null:
		sprite.speed_scale = 1.0
		sprite.modulate.a = 1.0

	for area in [hurt_box, attack_box]:
		area.set_deferred("monitoring", true)
		area.set_deferred("monitorable", true)
		for child in area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", false)

	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", false)

	if states.has("move"):
		change_state("move")

	hold_dialogue_idle()
	update_effects()


func restore_after_load():
	stop_sprite_blink()
	dead = false
	visible = true
	velocity = Vector2.ZERO
	nearby_interactables.clear()
	current_interactable = null
	pending_interaction_target = null
	dialogue_input_locked = false
	set_physics_process(true)

	if sprite != null:
		sprite.speed_scale = 1.0
		sprite.modulate.a = 1.0

	for area in [hurt_box, attack_box]:
		area.set_deferred("monitoring", true)
		area.set_deferred("monitorable", true)
		for child in area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", false)

	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", false)

	if states.has("move"):
		change_state("move")


func _on_blink_requested(duration: float):
	blink_generation += 1
	var current_blink_generation: int = blink_generation
	blink_sprite_for_duration(duration, current_blink_generation)


func blink_sprite_for_duration(duration: float, current_blink_generation: int):
	if sprite == null:
		return

	var elapsed: float = 0.0
	var blink_interval: float = 0.08
	while elapsed < duration and current_blink_generation == blink_generation:
		sprite.modulate.a = 0.35 if sprite.modulate.a >= 1.0 else 1.0
		await get_tree().create_timer(blink_interval).timeout
		elapsed += blink_interval

	if current_blink_generation == blink_generation and sprite != null:
		sprite.modulate.a = 1.0


func stop_sprite_blink():
	blink_generation += 1
	if sprite != null:
		sprite.modulate.a = 1.0
