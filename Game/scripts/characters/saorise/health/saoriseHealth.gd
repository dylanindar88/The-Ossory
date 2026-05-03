extends Node

signal health_changed(current_health: int, max_health: int)
signal stamina_changed(current_stamina: float, max_stamina: float)
signal died
signal damage_blocked
signal blink_requested(duration: float)

const DEFAULT_TUNING: PlayerTuning = preload("res://resources/characters/saorise/player_tuning.tres")

@export var tuning: PlayerTuning = DEFAULT_TUNING

var max_health := 100
var max_stamina := 100.0
var invulnerability_time := 0.75
var dash_stamina_cost := 10.0
var block_invulnerability_time := 0.35
var block_stamina_cost := 20.0
var block_stamina_drain_rate := 8.0
var run_stamina_drain_rate := 8.0
var stamina_regen_rate := 25.0
var stamina_exhaustion_recovery_ratio := 0.8
var parry_bonus_time := 2.0
var parry_damage_multiplier := 1.5
var hits_to_die := 4
var health := max_health
var stamina := max_stamina

var invulnerable := false
var i_frame_timer := 0.0
var blocking := false
var running := false
var dashing := false
var parry_window_active := false
var block_invulnerable := false
var block_invulnerability_timer := 0.0
var parry_bonus_timer := 0.0
var stamina_exhausted := false
var dead := false
var invulnerability_source: Node = null
var stamina_costs_enabled := true

func _ready():
	apply_tuning()
	health = max_health
	stamina = max_stamina
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)

func set_tuning(new_tuning: PlayerTuning):
	var was_at_full_health := health >= max_health
	var was_at_full_stamina := stamina >= max_stamina

	tuning = new_tuning
	apply_tuning()
	health = max_health if was_at_full_health else clamp(health, 0, max_health)
	stamina = max_stamina if was_at_full_stamina else clamp(stamina, 0.0, max_stamina)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)

func apply_tuning():
	if tuning == null:
		tuning = DEFAULT_TUNING

	max_health = tuning.max_health
	hits_to_die = tuning.hits_to_die
	max_stamina = tuning.max_stamina
	invulnerability_time = tuning.invulnerability_time
	dash_stamina_cost = tuning.dash_stamina_cost
	block_invulnerability_time = tuning.block_invulnerability_time
	block_stamina_cost = tuning.block_stamina_cost
	block_stamina_drain_rate = tuning.block_stamina_drain_rate
	run_stamina_drain_rate = tuning.run_stamina_drain_rate
	stamina_regen_rate = tuning.stamina_regen_rate
	stamina_exhaustion_recovery_ratio = tuning.stamina_exhaustion_recovery_ratio
	parry_bonus_time = tuning.parry_bonus_time
	parry_damage_multiplier = tuning.parry_damage_multiplier

func _process(delta):
	if invulnerable:
		i_frame_timer -= delta

		if i_frame_timer <= 0:
			end_invulnerability()

	if block_invulnerable:
		block_invulnerability_timer -= delta

		if block_invulnerability_timer <= 0:
			end_block_invulnerability()

	if parry_bonus_timer > 0:
		parry_bonus_timer -= delta

	if blocking and stamina_costs_enabled:
		drain_block_stamina(delta)
	elif running:
		drain_run_stamina(delta)
	elif not dashing:
		regenerate_stamina(delta)

func take_damage(amount: int, ignore_invulnerability: bool = false, damage_source: Node = null):
	if dead:
		return "ignored"

	if can_parry_damage():
		on_parry_succeeded()
		damage_blocked.emit()
		return "blocked"

	if block_invulnerable:
		return "ignored"

	if has_parry_bonus():
		return "ignored"

	if should_ignore_for_invulnerability(ignore_invulnerability, damage_source):
		return "ignored"

	if can_block_damage():
		on_block_succeeded()
		damage_blocked.emit()
		return "blocked"

	var damage_amount := get_incoming_damage_amount(amount)
	health -= damage_amount
	health = clamp(health, 0, max_health)

	if health > 0:
		start_invulnerability(invulnerability_time, damage_source, true)

	health_changed.emit(health, max_health)

	if health <= 0:
		die()

	return "damaged"

func get_incoming_damage_amount(_amount: int) -> int:
	return max(1, int(ceil(float(max_health) / float(max(hits_to_die, 1)))))

func heal(amount: int):
	if dead:
		return

	health += amount
	health = clamp(health, 0, max_health)
	health_changed.emit(health, max_health)

func should_ignore_for_invulnerability(ignore_invulnerability: bool, damage_source: Node = null) -> bool:
	if not invulnerable:
		return false

	if not ignore_invulnerability:
		return true

	if damage_source == null or invulnerability_source == null:
		return true

	return damage_source != invulnerability_source


func start_invulnerability(time: float, damage_source: Node = null, should_blink: bool = false):
	invulnerable = true
	i_frame_timer = time
	invulnerability_source = damage_source
	if should_blink:
		blink_requested.emit(time)

func end_invulnerability():
	invulnerable = false
	i_frame_timer = 0.0
	invulnerability_source = null

func is_invulnerable() -> bool:
	return invulnerable

func regenerate_stamina(delta: float):
	if stamina >= max_stamina:
		return

	set_stamina(stamina + stamina_regen_rate * delta)

func drain_block_stamina(delta: float):
	drain_stamina(block_stamina_drain_rate, delta)

func drain_run_stamina(delta: float):
	drain_stamina(run_stamina_drain_rate, delta)

func drain_stamina(rate: float, delta: float):
	if stamina <= 0.0:
		return

	set_stamina(stamina - rate * delta)

func set_stamina(value: float):
	var new_stamina: float = clamp(value, 0.0, max_stamina)
	if is_equal_approx(stamina, new_stamina):
		return

	stamina = new_stamina

	if not stamina_exhausted and stamina <= 0.0:
		start_stamina_exhaustion()
	elif stamina_exhausted and stamina >= get_stamina_exhaustion_recovery_threshold():
		end_stamina_exhaustion()

	stamina_changed.emit(stamina, max_stamina)

func spend_stamina(amount: float):
	set_stamina(stamina - amount)

func start_stamina_exhaustion():
	stamina_exhausted = true
	set_blocking(false)
	set_running(false)

func end_stamina_exhaustion():
	stamina_exhausted = false

func is_stamina_exhausted() -> bool:
	return stamina_exhausted

func get_stamina_exhaustion_recovery_threshold() -> float:
	return max_stamina * stamina_exhaustion_recovery_ratio

func has_enough_block_stamina() -> bool:
	return stamina >= block_stamina_cost

func has_enough_dash_stamina() -> bool:
	return stamina >= dash_stamina_cost

func can_start_block() -> bool:
	if not stamina_costs_enabled:
		return true

	return not is_stamina_exhausted() and stamina > 0.0

func can_dash() -> bool:
	return not is_stamina_exhausted() and has_enough_dash_stamina()

func can_run() -> bool:
	return not is_stamina_exhausted() and stamina > 0.0

func set_blocking(active: bool):
	blocking = active

func set_running(active: bool):
	running = active and can_run()

func set_dashing(active: bool):
	dashing = active

func set_parry_window(active: bool):
	parry_window_active = active

func start_block_invulnerability(time: float):
	block_invulnerable = true
	block_invulnerability_timer = time

func end_block_invulnerability():
	block_invulnerable = false
	block_invulnerability_timer = 0.0

func start_parry_bonus():
	parry_bonus_timer = parry_bonus_time

func end_parry_bonus():
	parry_bonus_timer = 0.0

func on_block_succeeded():
	if stamina_costs_enabled:
		spend_stamina(block_stamina_cost)
	start_block_invulnerability(block_invulnerability_time)

func on_dash_started(spend_dash_stamina: bool = true):
	set_dashing(true)
	if spend_dash_stamina:
		spend_stamina(dash_stamina_cost)

func on_parry_succeeded():
	parry_window_active = false
	start_block_invulnerability(block_invulnerability_time)
	start_parry_bonus()

func can_parry_damage() -> bool:
	return parry_window_active and not block_invulnerable

func can_block_damage() -> bool:
	return blocking and (not stamina_costs_enabled or stamina > 0.0)


func set_stamina_costs_enabled(enabled: bool):
	stamina_costs_enabled = enabled
	if not stamina_costs_enabled:
		stamina_exhausted = false

func is_block_effect_active() -> bool:
	return block_invulnerable or can_block_damage()

func is_dash_effect_active() -> bool:
	return dashing and invulnerable

func has_parry_bonus() -> bool:
	return parry_bonus_timer > 0

func get_active_effects() -> Array[String]:
	var active_effects: Array[String] = []

	if is_stamina_exhausted():
		active_effects.append("exhausted")

	if is_block_effect_active():
		active_effects.append("blocking")

	if is_dash_effect_active():
		active_effects.append("dash")

	if has_parry_bonus():
		active_effects.append("parry_bonus")

	return active_effects

func get_attack_damage_multiplier() -> float:
	if has_parry_bonus():
		return parry_damage_multiplier

	return 1.0

func die():
	if dead:
		return

	dead = true
	set_blocking(false)
	set_running(false)
	set_dashing(false)
	set_parry_window(false)
	end_block_invulnerability()
	end_parry_bonus()
	died.emit()


func restore_full_after_respawn(extra_invulnerability_time: float = 0.0):
	dead = false
	health = max_health
	stamina = max_stamina
	invulnerable = false
	i_frame_timer = 0.0
	invulnerability_source = null
	blocking = false
	running = false
	dashing = false
	parry_window_active = false
	block_invulnerable = false
	block_invulnerability_timer = 0.0
	parry_bonus_timer = 0.0
	stamina_exhausted = false
	if extra_invulnerability_time > 0.0:
		start_invulnerability(invulnerability_time + extra_invulnerability_time, null, true)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)

# Temporary test:
# Press Enter to take one standard hit.
func _input(event):
	if event.is_action_pressed("test_damage"):
		take_damage(0)
	if event.is_action_pressed("test_healing"):
		heal(10)
