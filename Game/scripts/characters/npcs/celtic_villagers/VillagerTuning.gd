class_name VillagerTuning
extends Resource

@export_group("Movement")
@export var walk_speed: float = 45.0
@export var arrival_distance: float = 6.0

@export_group("Ambient Patrol")
@export var ambient_enabled: bool = true
@export_range(0.1, 10.0, 0.1) var ambient_check_interval_seconds: float = 1.25
@export_range(0.0, 1.0, 0.01) var ambient_stop_chance: float = 0.05
@export var ambient_stop_cooldown_seconds: float = 7.0
@export var ambient_idle_min_seconds: float = 1.0
@export var ambient_idle_max_seconds: float = 2.25
@export var ambient_marker_stop_radius: float = 32.0
@export var ambient_marker_stop_multiplier: float = 2.0
@export var ambient_house_stop_radius: float = 38.0
@export var ambient_house_stop_multiplier: float = 4.0
@export var ambient_house_idle_min_seconds: float = 1.5
@export var ambient_house_idle_max_seconds: float = 3.5
@export_range(0.0, 1.0, 0.01) var ambient_reverse_chance: float = 0.18
@export_range(0.0, 1.0, 0.01) var ambient_social_chance: float = 0.14
@export var ambient_social_radius: float = 54.0
@export var ambient_social_cooldown_seconds: float = 12.0
@export var ambient_social_min_seconds: float = 1.5
@export var ambient_social_max_seconds: float = 3.25
