class_name KnightTuning
extends Resource

@export_group("Identity")
@export var actor_id: StringName = &"basic_knight"
@export var display_name: String = "Basic Knight"

@export_group("Health")
@export var max_health: int = 35
@export var invulnerability_time: float = 0.15
@export var hurt_duration_seconds: float = 0.35
@export var block_stun_duration: float = 1.0
@export var block_stun_move_speed_modifier: float = 0.15

@export_group("Movement")
@export var walk_speed: float = 48.0
@export var run_speed: float = 92.0
@export var patrol_arrival_distance: float = 6.0
@export var player_stop_distance: float = 24.0
@export var facing_deadzone: float = 0.1

@export_group("Detection")
@export var detection_range: float = 120.0
@export var tracking_range: float = 260.0

@export_group("Attack")
@export var attack_range: float = 42.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.0
@export var attack_windup_seconds: float = 0.22
@export var attack_recover_seconds: float = 0.35

@export_group("Ranged Attack")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 260.0
@export var projectile_lifetime: float = 2.0
@export var ranged_min_distance: float = 70.0
@export var ranged_preferred_distance: float = 160.0

@export_group("Respawn")
@export var respawn_delay_seconds: float = 10.0

@export_group("Dialogue")
@export var encounter_dialogue_bank: DialogueBank
