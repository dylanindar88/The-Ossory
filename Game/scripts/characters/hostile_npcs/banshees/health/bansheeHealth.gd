extends Node

signal health_changed(current_health: int, max_health: int)
signal died

const DEFAULT_TUNING: BansheeTuning = preload("res://resources/characters/hostile_npcs/banshees/banshee_tuning.tres")

@export var tuning: BansheeTuning = DEFAULT_TUNING

var max_health: int = 50
var invulnerability_time: float = 0.1
var regeneration_rate: float = 2.0

var health: int = max_health
var invulnerable: bool = false
var i_frame_timer: float = 0.0
var dead: bool = false
var regenerating: bool = false
var regeneration_progress: float = 0.0


func _ready():
	apply_tuning()
	health = max_health
	health_changed.emit(health, max_health)


func set_tuning(new_tuning: BansheeTuning):
	var was_at_full_health := health >= max_health

	tuning = new_tuning
	apply_tuning()
	health = max_health if was_at_full_health else clamp(health, 0, max_health)
	health_changed.emit(health, max_health)


func apply_tuning():
	if tuning == null:
		tuning = DEFAULT_TUNING

	max_health = tuning.max_health
	invulnerability_time = tuning.invulnerability_time


func set_effective_max_health(value: int):
	var new_max_health: int = maxi(value, 1)
	var was_at_full_health := health >= max_health
	max_health = new_max_health
	health = max_health if was_at_full_health else clamp(health, 0, max_health)
	regeneration_progress = clamp(regeneration_progress, 0.0, float(max_health))
	health_changed.emit(health, max_health)


func _process(delta):
	if regenerating:
		regenerate(delta)

	if invulnerable:
		i_frame_timer -= delta
		if i_frame_timer <= 0:
			end_invulnerability()


func take_damage(amount: int, ignore_invulnerability: bool = false) -> bool:
	if dead or (invulnerable and not ignore_invulnerability):
		return false

	health = clamp(health - amount, 0, max_health)
	stop_regeneration()
	regeneration_progress = float(health)
	health_changed.emit(health, max_health)

	if health <= 0:
		die()
	else:
		start_invulnerability(invulnerability_time)

	return true


func start_invulnerability(time: float):
	invulnerable = true
	i_frame_timer = time


func end_invulnerability():
	invulnerable = false
	i_frame_timer = 0.0


func is_invulnerable() -> bool:
	return invulnerable


func start_regeneration():
	if dead or health >= max_health:
		regenerating = false
		return

	regeneration_progress = float(health)
	regenerating = true


func stop_regeneration():
	regenerating = false
	regeneration_progress = float(health)


func regenerate(delta: float):
	if dead or health >= max_health:
		stop_regeneration()
		return

	regeneration_progress = min(float(max_health), regeneration_progress + regeneration_rate * delta)
	var next_health: int = mini(max_health, int(floor(regeneration_progress)))
	if next_health == health:
		return

	health = next_health
	health_changed.emit(health, max_health)

	if health >= max_health:
		stop_regeneration()


func die():
	if dead:
		return

	dead = true
	invulnerable = true
	stop_regeneration()
	died.emit()
