class_name PlayerFormDefinition
extends Resource

const DEFAULT_ATTACK_PROFILES := {
	"right": {
		1: {"size": Vector2(41, 31), "position": Vector2(18, -25), "rotation": -PI / 2.0},
		2: {"size": Vector2(41, 43), "position": Vector2(24, -25), "rotation": -PI / 2.0},
		3: {"size": Vector2(41, 31), "position": Vector2(18, -25), "rotation": -PI / 2.0},
	},
	"left": {
		1: {"size": Vector2(41, 31), "position": Vector2(-18, -25), "rotation": -PI / 2.0},
		2: {"size": Vector2(41, 43), "position": Vector2(-24, -25), "rotation": -PI / 2.0},
		3: {"size": Vector2(41, 31), "position": Vector2(-18, -25), "rotation": -PI / 2.0},
	},
	"down": {
		1: {"size": Vector2(36, 52), "position": Vector2(0, -7), "rotation": 0.0},
		2: {"size": Vector2(36, 62), "position": Vector2(0, -2), "rotation": 0.0},
		3: {"size": Vector2(36, 52), "position": Vector2(0, -7), "rotation": 0.0},
	},
	"up": {
		1: {"size": Vector2(31, 42), "position": Vector2(0, -48), "rotation": 0.0},
		2: {"size": Vector2(31, 56), "position": Vector2(0, -55), "rotation": 0.0},
		3: {"size": Vector2(31, 42), "position": Vector2(0, -48), "rotation": 0.0},
	},
}

@export var form_id: StringName = &"human"
@export var tuning: PlayerTuning
@export var form_node_path: NodePath
@export var body_node_path: NodePath = NodePath("Body")
@export var sprite_frames: SpriteFrames
@export var default_animation: StringName = &"idle"
@export var body_position := Vector2(0, -1)
@export var body_scale := Vector2(0.28, 0.28)
@export var body_offset := Vector2(0, -88)

@export_group("Abilities")
@export var can_attack := true
@export var can_block := true
@export var can_dash := true
@export var can_interact := true
@export var can_talk := true

@export_group("Movement")
@export var always_run := false
@export var uses_stamina := true
@export var walk_side_animation: StringName = &"walking"
@export var walk_up_animation: StringName = &"walking_up"
@export var walk_down_animation: StringName = &"walking_down"
@export var run_side_animation: StringName = &"running"
@export var run_up_animation: StringName = &"running_up"
@export var run_down_animation: StringName = &"running_down"

@export_group("Transformation")
@export var transformation_duration_seconds: float = 0.0
@export var transformation_animation: StringName = &"transformation"

@export_group("Movement Collision")
@export var movement_shape: Shape2D
@export var movement_shape_position := Vector2(0.0420001, -4.332)
@export var movement_shape_rotation := PI / 2.0

@export_group("Hurtbox")
@export var hurt_shape: Shape2D
@export var hurt_shape_position := Vector2(0, -20)
@export var hurt_shape_rotation := 0.0

@export_group("Combat")
@export var attack_profiles: Dictionary = {}
@export var attack_animation_prefix: StringName = &"unarmed_attack"
@export var attack_damage_multiplier: float = 1.0
@export var incoming_damage_multiplier: float = 1.0


func get_attack_profiles() -> Dictionary:
	if attack_profiles.is_empty():
		return DEFAULT_ATTACK_PROFILES.duplicate(true)

	return attack_profiles.duplicate(true)
