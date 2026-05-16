extends Node

signal health_changed(current_health: int, max_health: int)
signal died

@export var tuning: Resource

var max_health: int = 35
var health: int = max_health
var invulnerability_time: float = 0.15
var invulnerable: bool = false
var invulnerability_timer: float = 0.0
var dead: bool = false


func _ready():
	apply_tuning()
	health = max_health
	health_changed.emit(health, max_health)


func _process(delta: float):
	if not invulnerable:
		return

	invulnerability_timer -= delta
	if invulnerability_timer <= 0.0:
		invulnerable = false
		invulnerability_timer = 0.0


func set_tuning(new_tuning: Resource):
	var was_full_health: bool = health >= max_health
	tuning = new_tuning
	apply_tuning()
	health = max_health if was_full_health else clamp(health, 0, max_health)
	health_changed.emit(health, max_health)


func apply_tuning():
	if tuning == null:
		return

	max_health = maxi(tuning.max_health, 1)
	invulnerability_time = maxf(tuning.invulnerability_time, 0.0)


func take_damage(amount: int, ignore_invulnerability: bool = false) -> bool:
	if dead or (invulnerable and not ignore_invulnerability):
		return false

	health = clamp(health - maxi(amount, 0), 0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0:
		die()
		return true

	if invulnerability_time > 0.0:
		invulnerable = true
		invulnerability_timer = invulnerability_time
	return true


func heal_to_full():
	dead = false
	invulnerable = false
	invulnerability_timer = 0.0
	health = max_health
	health_changed.emit(health, max_health)


func force_dead():
	dead = true
	invulnerable = true
	invulnerability_timer = 0.0
	health = 0
	health_changed.emit(health, max_health)


func die():
	if dead:
		return

	force_dead()
	died.emit()
