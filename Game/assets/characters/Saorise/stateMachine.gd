extends CharacterBody2D

const DEFAULT_TUNING: PlayerTuning = preload("res://assets/characters/Saorise/player_tuning.tres")

@export var tuning: PlayerTuning = DEFAULT_TUNING

@onready var sprite = $Body
@onready var effects: AnimatedSprite2D = $Effects
@onready var health = $Health
@onready var hurt_box = $HurtBox
@onready var attack_box = $AttackBox

var current_state
var states = {}
var hitbox_manager: Object
var dead := false

var last_facing = "right"
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
var combo_2_damage_bonus: int
var block_speed_modifier: float


func _ready():
	apply_tuning()

	add_to_group("player")
	hurt_box.add_to_group("player_hurtboxes")
	hurt_box.monitoring = true
	hurt_box.monitorable = true
	hurt_box.collision_layer = 2
	hurt_box.collision_mask = 0

	states["move"] = preload("res://assets/characters/Saorise/state_machine/movementState.gd").new()
	states["dash"] = preload("res://assets/characters/Saorise/state_machine/dashState.gd").new()
	states["attack"] = preload("res://assets/characters/Saorise/state_machine/attackState.gd").new()
	states["block"] = preload("res://assets/characters/Saorise/state_machine/blockState.gd").new()

	effects.visible = false
	effects.stop()

	hitbox_manager = preload("res://assets/characters/Saorise/combat/attackBoxManager.gd").new()
	hitbox_manager.attack_box = attack_box
	hitbox_manager.attack_damage = attack_damage
	hitbox_manager.combo_2_damage_bonus = combo_2_damage_bonus
	hitbox_manager.player_health = health
	hitbox_manager.setup()

	states["attack"].hitbox_manager = hitbox_manager

	if health.has_method("set_tuning"):
		health.set_tuning(tuning)

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

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
	combo_2_damage_bonus = tuning.combo_2_damage_bonus
	block_speed_modifier = tuning.block_speed_modifier


func _physics_process(delta):
	if dead:
		velocity = Vector2.ZERO
		return

	if not can_dash:
		dash_cooldown_timer -= delta

		if dash_cooldown_timer <= 0:
			can_dash = true

	if current_state:
		current_state.physics_update(self, delta)

	update_effects()


func change_state(state_name):
	if current_state:
		current_state.exit(self)

	current_state = states[state_name]
	current_state.enter(self)


func take_damage(amount: int, ignore_invulnerability: bool = false):
	if dead:
		return "ignored"

	if current_state and current_state.has_method("prepare_for_incoming_damage"):
		current_state.prepare_for_incoming_damage(self)

	return health.take_damage(amount, ignore_invulnerability)


func update_effects():
	if effects == null:
		return

	if health.has_parry_bonus():
		play_effect("parry_bonus")
		return

	if health.is_block_effect_active():
		play_effect("blocking")
		return

	effects.stop()
	effects.visible = false


func play_effect(anim_name: String):
	if effects.sprite_frames == null or not effects.sprite_frames.has_animation(anim_name):
		effects.stop()
		effects.visible = false
		return

	effects.visible = true

	if effects.animation != anim_name or not effects.is_playing():
		effects.play(anim_name)


func _on_died():
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
