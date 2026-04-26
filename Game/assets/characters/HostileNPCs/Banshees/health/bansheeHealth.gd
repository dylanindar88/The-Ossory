extends Node

signal health_changed(current_health: int, max_health: int)
signal died

@export var max_health: int = 50
@export var invulnerability_time: float = 0.1

var health: int = max_health
var invulnerable: bool = false
var i_frame_timer: float = 0.0
var dead: bool = false


func _ready():
	health = max_health
	health_changed.emit(health, max_health)


func _process(delta):
	if not invulnerable:
		return

	i_frame_timer -= delta
	if i_frame_timer <= 0:
		end_invulnerability()


func take_damage(amount: int, ignore_invulnerability: bool = false) -> bool:
	if dead or (invulnerable and not ignore_invulnerability):
		return false

	health = clamp(health - amount, 0, max_health)
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


func die():
	if dead:
		return

	dead = true
	invulnerable = true
	died.emit()
