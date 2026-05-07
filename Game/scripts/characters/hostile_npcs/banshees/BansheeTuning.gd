class_name BansheeTuning
extends Resource

@export_group("Patrol")
@export var patrol_speed: float = 65.0
@export var patrol_arrival_distance: float = 6.0

@export_group("Movement")
@export var run_speed: float = 130.0
@export var player_stop_distance: float = 20.0
@export var facing_deadzone: float = 0.1
@export var strong_ranged_run_speed_multiplier: float = 1.12
@export var strong_ranged_tracking_radius_multiplier: float = 1.13

@export_group("Attack")
@export var attack_cooldown: float = 0.5
@export var attack_damage_start_frame: int = 3
@export var attack_move_speed_modifier: float = 0.95

@export_group("Ranged Attack")
@export var ranged_attack_cooldown: float = 2.25
@export var ranged_min_distance: float = 70.0
@export var ranged_preferred_distance: float = 150.0
@export var ranged_max_distance: float = 320.0
@export var ranged_launch_frame: int = 6
@export var ranged_projectile_speed: float = 210.0
@export var ranged_projectile_lifetime: float = 2.0
@export var ranged_projectile_spawn_offset: Vector2 = Vector2(24.0, -20.0)
@export_range(0.0, 1.0, 0.05) var ranged_choice_far_weight: float = 0.75
@export_range(0.0, 1.0, 0.05) var ranged_choice_retreating_bonus: float = 0.35
@export_range(0.0, 1.0, 0.05) var ranged_choice_close_penalty: float = 0.85

@export_group("Hurt")
@export var hurt_move_speed_modifier: float = 0.25
@export var block_stun_duration: float = 1.0
@export var block_stun_move_speed_modifier: float = 0.15

@export_group("Health")
@export var max_health: int = 50
@export var strong_ranged_max_health_multiplier: float = 1.5
@export var invulnerability_time: float = 0.1
