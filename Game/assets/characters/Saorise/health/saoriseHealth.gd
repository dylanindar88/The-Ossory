extends Node

signal health_changed(current_health: int, max_health: int)
signal died

@export var max_health := 100
var health := max_health

var invulnerable := false
var i_frame_timer := 0.0

func _ready():
	health = max_health
	health_changed.emit(health, max_health)

func _process(delta):
	if invulnerable:
		i_frame_timer -= delta

		if i_frame_timer <= 0:
			end_invulnerability()

func take_damage(amount: int):
	if invulnerable:
		return

	health -= amount
	health = clamp(health, 0, max_health)
	health_changed.emit(health, max_health)

	if health <= 0:
		die()

func heal(amount: int):
	health += amount
	health = clamp(health, 0, max_health)
	health_changed.emit(health, max_health)

func start_invulnerability(time: float):
	invulnerable = true
	i_frame_timer = time

func end_invulnerability():
	invulnerable = false
	i_frame_timer = 0.0

func is_invulnerable() -> bool:
	return invulnerable

func die():
	died.emit()
	print("Player died")

# Temporary test:
# Press Enter to lose 10 HP
func _input(event):
	if event.is_action_pressed("test_damage"):
		take_damage(10)
		print("Current HP:", health)
	if event.is_action_pressed("test_healing"):
		heal(10)
		print("Current HP:", health)
