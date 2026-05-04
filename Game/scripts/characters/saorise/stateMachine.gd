extends CharacterBody2D

signal interaction_requested(interactable: Node2D)
signal transformation_timer_changed(current_time: float, max_time: float, active: bool)
signal transformation_state_changed(active: bool)
signal transformation_cooldown_changed(current: float, max: float, active: bool)

const DEFAULT_TUNING: PlayerTuning = preload("res://resources/characters/saorise/player_tuning.tres")
const TRANSFORMATION_AUTOSAVE_BLOCKER = "player_transforming"

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
var is_transforming: bool = false
var transformation_time_remaining: float = 0.0
var transformation_duration: float = 0.0
var transformation_generation: int = 0
var transformation_cooldown_seconds: float = 30.0
var transformation_cooldown_timer: float = 0.0
var story_wolf_transformation_locked: bool = false
var life_respawn_pending: bool = false


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
	hitbox_manager.damage_source = self
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
	var form: PlayerFormDefinition = forms_by_id.get(form_id) as PlayerFormDefinition
	if form == null:
		form = forms_by_id.get(initial_form_id) as PlayerFormDefinition
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
	if health != null and health.has_method("set_stamina_costs_enabled"):
		health.set_stamina_costs_enabled(current_form_uses_stamina())
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
	var form_damage_multiplier: float = 1.0
	if current_form != null:
		form_damage_multiplier = current_form.attack_damage_multiplier
	hitbox_manager.form_attack_damage_multiplier = form_damage_multiplier
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

	if is_transforming:
		velocity = Vector2.ZERO
		update_effects()
		return

	if not dialogue_input_locked:
		update_transformation_timer(delta)
	if is_transforming:
		velocity = Vector2.ZERO
		update_effects()
		return

	if not can_dash:
		dash_cooldown_timer -= delta

		if dash_cooldown_timer <= 0:
			can_dash = true

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	if transformation_cooldown_timer > 0.0:
		transformation_cooldown_timer = maxf(transformation_cooldown_timer - delta, 0.0)
		emit_transformation_cooldown_progress()

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

	if event.is_action_pressed("transform"):
		try_start_wolf_transformation()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
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

	return health.take_damage(amount, ignore_invulnerability, damage_source, get_current_form_incoming_damage_multiplier())


func get_current_form_incoming_damage_multiplier() -> float:
	if current_form != null:
		return current_form.incoming_damage_multiplier

	return 1.0


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


func try_start_wolf_transformation() -> bool:
	if current_form_id == &"wolf" or is_transforming:
		return false

	if not has_wolf_transformation_unlocked():
		return false

	if transformation_cooldown_timer > 0.0:
		return false

	if dialogue_input_locked or dead:
		return false

	start_wolf_transformation()
	return true


func has_wolf_transformation_unlocked() -> bool:
	if SaveManager == null or not SaveManager.has_method("get_upgrade_state"):
		return false

	var state: Dictionary = SaveManager.get_upgrade_state()
	var unlocked: Variant = state.get("unlocked", {})
	return unlocked is Dictionary and bool(unlocked.get("wolf_transformation", false))


func start_wolf_transformation():
	var wolf_form: PlayerFormDefinition = forms_by_id.get(&"wolf") as PlayerFormDefinition
	if wolf_form == null:
		return

	transformation_duration = wolf_form.transformation_duration_seconds
	if transformation_duration <= 0.0:
		transformation_duration = 30.0
	transformation_time_remaining = transformation_duration
	transformation_generation += 1
	var generation: int = transformation_generation

	begin_transform_lock()
	set_form(&"wolf")
	transformation_state_changed.emit(true)
	transformation_timer_changed.emit(transformation_time_remaining, transformation_duration, true)
	await play_transformation_animation(false)

	if generation != transformation_generation or dead:
		return

	is_transforming = false
	set_transformation_autosave_blocked(false)
	hold_dialogue_idle()
	update_effects()


func finish_wolf_transformation():
	if current_form_id != &"wolf" or is_transforming or story_wolf_transformation_locked:
		return

	transformation_generation += 1
	var generation: int = transformation_generation
	begin_transform_lock()
	transformation_time_remaining = 0.0
	transformation_timer_changed.emit(0.0, transformation_duration, true)
	await play_transformation_animation(true)

	if generation != transformation_generation or dead:
		return

	set_form(&"human")
	is_transforming = false
	transformation_duration = 0.0
	transformation_time_remaining = 0.0
	transformation_state_changed.emit(false)
	transformation_timer_changed.emit(0.0, 0.0, false)
	start_transformation_cooldown()
	set_transformation_autosave_blocked(false)
	hold_dialogue_idle()
	update_effects()


func begin_transform_lock():
	is_transforming = true
	set_transformation_autosave_blocked(true)
	velocity = Vector2.ZERO
	can_attack_from_hold = false
	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()
	health.set_running(false)
	health.set_blocking(false)
	health.set_parry_window(false)
	health.end_parry_bonus()
	if states.has("move") and current_state != states.get("move"):
		change_state("move")


func play_transformation_animation(reverse: bool):
	var anim_name: StringName = get_transformation_animation_name()
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		await get_tree().process_frame
		return

	sprite.speed_scale = 1.0
	sprite.flip_h = last_horizontal_facing == "left"
	if reverse:
		sprite.play(anim_name, -1.0, true)
	else:
		sprite.play(anim_name)

	await sprite.animation_finished
	sprite.speed_scale = 1.0


func get_transformation_animation_name() -> StringName:
	if current_form != null:
		return current_form.transformation_animation

	return &"transformation"


func update_transformation_timer(delta: float):
	if current_form_id != &"wolf":
		return

	if story_wolf_transformation_locked:
		return

	if transformation_duration <= 0.0:
		return

	transformation_time_remaining = maxf(transformation_time_remaining - delta, 0.0)
	transformation_timer_changed.emit(transformation_time_remaining, transformation_duration, true)
	if transformation_time_remaining <= 0.0:
		finish_wolf_transformation()


func start_transformation_cooldown():
	transformation_cooldown_timer = transformation_cooldown_seconds
	emit_transformation_cooldown_progress()


func start_story_wolf_transformation_lock():
	if current_form_id != &"wolf":
		return

	story_wolf_transformation_locked = true
	if transformation_duration <= 0.0:
		var wolf_form: PlayerFormDefinition = forms_by_id.get(&"wolf") as PlayerFormDefinition
		transformation_duration = wolf_form.transformation_duration_seconds if wolf_form != null else 20.0
	transformation_time_remaining = maxf(transformation_time_remaining, transformation_duration)
	transformation_timer_changed.emit(transformation_time_remaining, transformation_duration, true)


func restore_story_wolf_transformation_lock():
	var wolf_form: PlayerFormDefinition = forms_by_id.get(&"wolf") as PlayerFormDefinition
	if wolf_form == null:
		return

	transformation_generation += 1
	story_wolf_transformation_locked = true
	is_transforming = false
	transformation_duration = wolf_form.transformation_duration_seconds
	if transformation_duration <= 0.0:
		transformation_duration = 20.0
	transformation_time_remaining = transformation_duration
	clear_transformation_cooldown()
	set_form(&"wolf")
	transformation_state_changed.emit(true)
	transformation_timer_changed.emit(transformation_time_remaining, transformation_duration, true)
	set_transformation_autosave_blocked(false)


func end_story_wolf_transformation_lock(start_refill_from_zero: bool = true):
	if not story_wolf_transformation_locked and current_form_id != &"wolf":
		return

	story_wolf_transformation_locked = false
	transformation_generation += 1
	var generation: int = transformation_generation

	if current_form_id == &"wolf":
		begin_transform_lock()
		transformation_time_remaining = 0.0
		transformation_timer_changed.emit(0.0, transformation_duration, true)
		await play_transformation_animation(true)

		if generation != transformation_generation or dead:
			return

		set_form(&"human")

	is_transforming = false
	transformation_duration = 0.0
	transformation_time_remaining = 0.0
	transformation_state_changed.emit(false)
	transformation_timer_changed.emit(0.0, 0.0, false)
	if start_refill_from_zero:
		start_transformation_cooldown()
	else:
		clear_transformation_cooldown()
	set_transformation_autosave_blocked(false)
	hold_dialogue_idle()
	update_effects()


func is_story_wolf_transformation_locked() -> bool:
	return story_wolf_transformation_locked


func clear_transformation_cooldown():
	transformation_cooldown_timer = 0.0
	transformation_cooldown_changed.emit(0.0, 0.0, false)


func set_transformation_autosave_blocked(blocked: bool):
	if SaveManager != null and SaveManager.has_method("set_autosave_blocked"):
		SaveManager.set_autosave_blocked(TRANSFORMATION_AUTOSAVE_BLOCKER, blocked)


func emit_transformation_cooldown_progress():
	if transformation_cooldown_timer <= 0.0 or transformation_cooldown_seconds <= 0.0:
		transformation_cooldown_changed.emit(0.0, 0.0, false)
		return

	var cooldown_progress := transformation_cooldown_seconds - transformation_cooldown_timer
	transformation_cooldown_changed.emit(cooldown_progress, transformation_cooldown_seconds, true)


func is_wolf_form() -> bool:
	return current_form_id == &"wolf"


func is_transforming_forms() -> bool:
	return is_transforming


func is_life_respawn_pending() -> bool:
	return life_respawn_pending


func current_form_uses_stamina() -> bool:
	return current_form == null or current_form.uses_stamina


func current_form_always_runs() -> bool:
	return current_form != null and current_form.always_run


func can_dash_without_stamina() -> bool:
	return not current_form_uses_stamina()


func can_block_without_stamina() -> bool:
	return not current_form_uses_stamina()


func get_form_movement_animation(use_horizontal: bool, moving_up: bool, is_running: bool) -> StringName:
	if current_form == null:
		if use_horizontal:
			return &"running" if is_running else &"walking"
		if moving_up:
			return &"running_up" if is_running else &"walking_up"
		return &"running_down" if is_running else &"walking_down"

	if use_horizontal:
		return current_form.run_side_animation if is_running else current_form.walk_side_animation
	if moving_up:
		return current_form.run_up_animation if is_running else current_form.walk_up_animation
	return current_form.run_down_animation if is_running else current_form.walk_down_animation


func get_attack_animation_prefix() -> StringName:
	if current_form != null:
		return current_form.attack_animation_prefix

	return &"unarmed_attack"


func get_save_form_id() -> StringName:
	if current_form_id == &"wolf" or is_transforming:
		return &"human"

	return current_form_id


func end_transformation_immediately():
	transformation_generation += 1
	is_transforming = false
	story_wolf_transformation_locked = false
	transformation_duration = 0.0
	transformation_time_remaining = 0.0
	set_transformation_autosave_blocked(false)
	clear_transformation_cooldown()
	if current_form_id == &"wolf":
		set_form(&"human")
	transformation_state_changed.emit(false)
	transformation_timer_changed.emit(0.0, 0.0, false)


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
	end_transformation_immediately()
	stop_sprite_blink()
	dead = true
	life_respawn_pending = true
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
		if not SaveManager.spend_life_and_respawn_player_in_place():
			life_respawn_pending = false
		return

	life_respawn_pending = false


func soft_respawn_in_place(extra_invulnerability_time: float = 0.0):
	soft_respawn_at_position(global_position, extra_invulnerability_time)


func soft_respawn_at_position(respawn_position: Vector2, extra_invulnerability_time: float = 0.0):
	end_transformation_immediately()
	stop_sprite_blink()
	global_position = respawn_position
	dead = false
	life_respawn_pending = false
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
	end_transformation_immediately()
	stop_sprite_blink()
	dead = false
	life_respawn_pending = false
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
