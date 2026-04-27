class_name BansheeTuning
extends Resource

@export_group("Patrol")
@export var patrol_speed: float = 55.0
@export var patrol_arrival_distance: float = 6.0

@export_group("Movement")
@export var run_speed: float = 130.0
@export var player_stop_distance: float = 20.0
@export var facing_deadzone: float = 0.1

@export_group("Attack")
@export var attack_damage: int = 5
@export var combo_2_damage_bonus: int = 2
@export var attack_cooldown: float = 0.5
@export var attack_damage_start_frame: int = 3
@export var attack_move_speed_modifier: float = 0.8

@export_group("Hurt")
@export var hurt_move_speed_modifier: float = 0.25
@export var block_stun_duration: float = 1.0
@export var block_stun_move_speed_modifier: float = 0.15

@export_group("Health")
@export var max_health: int = 50
@export var invulnerability_time: float = 0.1
