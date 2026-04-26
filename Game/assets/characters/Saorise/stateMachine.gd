extends CharacterBody2D

@export var walk_speed = 85
@export var run_speed = 210
@export var dash_speed = 420
@export var dash_duration = 0.18
@export var dash_cooldown = 0.75
@export var attack_speed_modifier = 0.75
@export var attack_damage = 10
@export var combo_2_damage_bonus = 5
@export var block_speed_modifier = 0.5
@export var block_cooldown = 0.5

@onready var sprite = $AnimatedSprite2D
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


func _ready():
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

	health.block_cooldown = block_cooldown

	hitbox_manager = preload("res://assets/characters/Saorise/combat/attackBoxManager.gd").new()
	hitbox_manager.attack_box = attack_box
	hitbox_manager.attack_damage = attack_damage
	hitbox_manager.combo_2_damage_bonus = combo_2_damage_bonus
	hitbox_manager.setup()

	states["attack"].hitbox_manager = hitbox_manager
	states["attack"].attack_speed_modifier = attack_speed_modifier

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

	change_state("move")


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


func change_state(state_name):
	if current_state:
		current_state.exit(self)

	current_state = states[state_name]
	current_state.enter(self)


func take_damage(amount: int, ignore_invulnerability: bool = false):
	if dead:
		return "ignored"

	return health.take_damage(amount, ignore_invulnerability)


func _on_died():
	dead = true
	velocity = Vector2.ZERO
	health.set_blocking(false)

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
