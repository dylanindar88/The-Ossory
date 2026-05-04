class_name PlayerTuning
extends Resource

@export_group("Movement")
@export var walk_speed: float = 75.0
@export var run_speed: float = 210.0

@export_group("Dash")
@export var dash_speed: float = 420.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.75
@export var dash_stamina_cost: float = 10.0

@export_group("Attack")
@export var attack_speed_modifier: float = 0.75
@export var attack_damage: int = 10
@export var combo_2_damage_multiplier: float = 1.5
@export var attack_combo_restart_delay: float = 0.25

@export_group("Block")
@export var block_speed_modifier: float = 0.5
@export var block_invulnerability_time: float = 0.35
@export var block_stamina_cost: float = 20.0
@export var block_stamina_drain_rate: float = 8.0

@export_group("Run")
@export var run_stamina_drain_rate: float = 8.0

@export_group("Health")
@export var max_health: int = 100
@export_range(1, 20, 1) var hits_to_die: int = 4
@export var invulnerability_time: float = 0.75

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 15.0
@export_range(0.0, 1.0, 0.05) var stamina_exhaustion_recovery_ratio: float = 0.75

@export_group("Parry")
@export var parry_bonus_time: float = 2.25
@export var parry_damage_multiplier: float = 1.5
