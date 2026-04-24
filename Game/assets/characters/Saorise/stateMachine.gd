extends CharacterBody2D

@export var walk_speed = 85
@export var run_speed = 210
@export var dash_speed = 420
@export var dash_duration = 0.18
@export var dash_cooldown = 0.75
@export var attack_speed_modifier = 0.75
@export var attack_damage = 10

@onready var sprite = $AnimatedSprite2D
@onready var health = $Health
@onready var attack_box = $AttackBox

var current_state
var states = {}
var hitbox_manager: Object

var last_facing = "right"
var last_move_axis = "horizontal"
var last_input_direction = Vector2.RIGHT

var can_dash = true
var dash_cooldown_timer = 0.0


func _ready():
	add_to_group("player")

	states["move"] = preload("res://assets/characters/Saorise/state_machine/movementState.gd").new()
	states["dash"] = preload("res://assets/characters/Saorise/state_machine/dashState.gd").new()
	states["attack"] = preload("res://assets/characters/Saorise/state_machine/attackState.gd").new()

	hitbox_manager = preload("res://assets/characters/Saorise/combat/attackBoxManager.gd").new()
	hitbox_manager.attack_box = attack_box
	hitbox_manager.attack_damage = attack_damage
	hitbox_manager.setup()

	states["attack"].hitbox_manager = hitbox_manager
	states["attack"].attack_speed_modifier = attack_speed_modifier

	change_state("move")


func _physics_process(delta):
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
