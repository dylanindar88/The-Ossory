class_name PlayerTransformationController
extends Node

const TRANSFORMATION_AUTOSAVE_BLOCKER = "player_transforming"

var player


func setup(owner_player):
	player = owner_player


func try_start_wolf_transformation() -> bool:
	if player.current_form_id == &"wolf" or player.is_transforming:
		return false

	if not has_wolf_transformation_unlocked():
		return false

	if not has_minimum_transformation_charge():
		return false

	if player.dialogue_input_locked or player.dead:
		return false

	start_wolf_transformation()
	return true


func has_wolf_transformation_unlocked() -> bool:
	if SaveManager == null or not SaveManager.has_method("get_upgrade_state"):
		return false

	var state: Dictionary = SaveManager.get_upgrade_state()
	var unlocked: Variant = state.get("unlocked", {})
	return unlocked is Dictionary and bool(unlocked.get("wolf_transformation", false))


func start_wolf_transformation():
	var wolf_form: PlayerFormDefinition = player.forms_by_id.get(&"wolf") as PlayerFormDefinition
	if wolf_form == null:
		return

	var base_duration := get_wolf_transformation_base_duration(wolf_form)
	var charge_fraction := get_transformation_charge_fraction()
	player.transformation_duration = base_duration * charge_fraction
	player.transformation_time_remaining = player.transformation_duration
	player.transformation_generation += 1
	var generation: int = player.transformation_generation

	clear_transformation_cooldown()
	begin_transform_lock()
	player.set_form(&"wolf")
	player.transformation_state_changed.emit(true)
	player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, true)
	await play_transformation_animation(false)

	if generation != player.transformation_generation or player.dead:
		return

	player.is_transforming = false
	set_transformation_autosave_blocked(false)
	player.hold_dialogue_idle()
	player.update_effects()


func finish_wolf_transformation():
	if player.current_form_id != &"wolf" or player.is_transforming or is_any_wolf_transformation_locked():
		return

	player.transformation_generation += 1
	var generation: int = player.transformation_generation
	begin_transform_lock()
	player.transformation_time_remaining = 0.0
	player.transformation_timer_changed.emit(0.0, player.transformation_duration, true)
	await play_transformation_animation(true)

	if generation != player.transformation_generation or player.dead:
		return

	player.set_form(&"human")
	player.is_transforming = false
	player.transformation_duration = 0.0
	player.transformation_time_remaining = 0.0
	player.transformation_state_changed.emit(false)
	player.transformation_timer_changed.emit(0.0, 0.0, false)
	start_transformation_cooldown()
	set_transformation_autosave_blocked(false)
	player.hold_dialogue_idle()
	player.update_effects()


func begin_transform_lock():
	player.is_transforming = true
	set_transformation_autosave_blocked(true)
	player.velocity = Vector2.ZERO
	player.can_attack_from_hold = false
	if player.hitbox_manager:
		player.hitbox_manager.deactivate_attack_hitbox()
	player.health.set_running(false)
	player.health.set_blocking(false)
	player.health.set_parry_window(false)
	player.health.end_parry_bonus()
	if player.states.has("move") and player.current_state != player.states.get("move"):
		player.change_state("move")


func play_transformation_animation(reverse: bool):
	var anim_name: StringName = get_transformation_animation_name()
	if player.sprite == null or player.sprite.sprite_frames == null or not player.sprite.sprite_frames.has_animation(anim_name):
		await player.get_tree().process_frame
		return

	player.sprite.speed_scale = 1.0
	player.sprite.flip_h = player.last_horizontal_facing == "left"
	if reverse:
		player.sprite.play(anim_name, -1.0, true)
	else:
		player.sprite.play(anim_name)

	await player.sprite.animation_finished
	player.sprite.speed_scale = 1.0


func get_transformation_animation_name() -> StringName:
	if player.current_form != null:
		return player.current_form.transformation_animation

	return &"transformation"


func get_wolf_transformation_base_duration(wolf_form: PlayerFormDefinition = null) -> float:
	if wolf_form == null:
		wolf_form = player.forms_by_id.get(&"wolf") as PlayerFormDefinition

	var base_duration := 30.0
	if wolf_form != null and wolf_form.transformation_duration_seconds > 0.0:
		base_duration = wolf_form.transformation_duration_seconds

	return base_duration


func get_transformation_charge_fraction() -> float:
	if player.transformation_cooldown_seconds <= 0.0:
		return 1.0

	var charge_seconds: float = player.transformation_cooldown_seconds - player.transformation_cooldown_timer
	return clampf(charge_seconds / player.transformation_cooldown_seconds, 0.0, 1.0)


func has_minimum_transformation_charge() -> bool:
	return get_transformation_charge_fraction() >= player.minimum_transformation_charge_fraction


func update_transformation_timer(delta: float):
	if player.current_form_id != &"wolf":
		return

	if is_any_wolf_transformation_locked():
		return

	if player.transformation_duration <= 0.0:
		return

	player.transformation_time_remaining = maxf(player.transformation_time_remaining - delta, 0.0)
	player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, true)
	if player.transformation_time_remaining <= 0.0:
		finish_wolf_transformation()


func update_transformation_cooldown(delta: float):
	if player.transformation_cooldown_timer <= 0.0:
		return

	player.transformation_cooldown_timer = maxf(player.transformation_cooldown_timer - delta, 0.0)
	emit_transformation_cooldown_progress()


func start_transformation_cooldown():
	player.transformation_cooldown_timer = player.transformation_cooldown_seconds
	emit_transformation_cooldown_progress()


func start_story_wolf_transformation_lock():
	if player.current_form_id != &"wolf":
		return

	player.story_wolf_transformation_locked = true
	if player.transformation_duration <= 0.0:
		var wolf_form: PlayerFormDefinition = player.forms_by_id.get(&"wolf") as PlayerFormDefinition
		player.transformation_duration = wolf_form.transformation_duration_seconds if wolf_form != null else 30.0
	player.transformation_time_remaining = maxf(player.transformation_time_remaining, player.transformation_duration)
	player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, true)


func toggle_dev_permanent_wolf_transformation():
	if player.dev_wolf_transformation_locked:
		end_dev_permanent_wolf_transformation()
	else:
		start_dev_permanent_wolf_transformation()


func start_dev_permanent_wolf_transformation():
	var wolf_form: PlayerFormDefinition = player.forms_by_id.get(&"wolf") as PlayerFormDefinition
	if wolf_form == null:
		return

	player.transformation_generation += 1
	player.dev_wolf_transformation_locked = true
	player.is_transforming = false
	player.transformation_duration = wolf_form.transformation_duration_seconds
	if player.transformation_duration <= 0.0:
		player.transformation_duration = 30.0
	player.transformation_time_remaining = player.transformation_duration
	clear_transformation_cooldown()
	set_transformation_autosave_blocked(false)
	player.set_form(&"wolf")
	player.transformation_state_changed.emit(true)
	player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, true)
	player.hold_dialogue_idle()
	player.update_effects()


func end_dev_permanent_wolf_transformation():
	if not player.dev_wolf_transformation_locked:
		return

	player.dev_wolf_transformation_locked = false
	player.transformation_generation += 1
	if player.story_wolf_transformation_locked:
		player.transformation_time_remaining = maxf(player.transformation_time_remaining, player.transformation_duration)
		player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, true)
		return

	player.is_transforming = false
	player.transformation_duration = 0.0
	player.transformation_time_remaining = 0.0
	set_transformation_autosave_blocked(false)
	clear_transformation_cooldown()
	if player.current_form_id == &"wolf":
		player.set_form(&"human")
	player.transformation_state_changed.emit(false)
	player.transformation_timer_changed.emit(0.0, 0.0, false)
	player.hold_dialogue_idle()
	player.update_effects()


func restore_story_wolf_transformation_lock():
	var wolf_form: PlayerFormDefinition = player.forms_by_id.get(&"wolf") as PlayerFormDefinition
	if wolf_form == null:
		return

	player.transformation_generation += 1
	player.story_wolf_transformation_locked = true
	player.is_transforming = false
	player.transformation_duration = wolf_form.transformation_duration_seconds
	if player.transformation_duration <= 0.0:
		player.transformation_duration = 30.0
	player.transformation_time_remaining = player.transformation_duration
	clear_transformation_cooldown()
	player.set_form(&"wolf")
	player.transformation_state_changed.emit(true)
	player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, true)
	set_transformation_autosave_blocked(false)


func end_story_wolf_transformation_lock(start_refill_from_zero: bool = true):
	if not player.story_wolf_transformation_locked and player.current_form_id != &"wolf":
		return

	player.story_wolf_transformation_locked = false
	if player.dev_wolf_transformation_locked:
		player.transformation_time_remaining = maxf(player.transformation_time_remaining, player.transformation_duration)
		player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, true)
		return

	player.transformation_generation += 1
	var generation: int = player.transformation_generation

	if player.current_form_id == &"wolf":
		begin_transform_lock()
		player.transformation_time_remaining = 0.0
		player.transformation_timer_changed.emit(0.0, player.transformation_duration, true)
		await play_transformation_animation(true)

		if generation != player.transformation_generation or player.dead:
			return

		player.set_form(&"human")

	player.is_transforming = false
	player.transformation_duration = 0.0
	player.transformation_time_remaining = 0.0
	player.transformation_state_changed.emit(false)
	player.transformation_timer_changed.emit(0.0, 0.0, false)
	if start_refill_from_zero:
		start_transformation_cooldown()
	else:
		clear_transformation_cooldown()
	set_transformation_autosave_blocked(false)
	player.hold_dialogue_idle()
	player.update_effects()


func is_story_wolf_transformation_locked() -> bool:
	return player.story_wolf_transformation_locked


func is_any_wolf_transformation_locked() -> bool:
	return player.story_wolf_transformation_locked or player.dev_wolf_transformation_locked


func clear_transformation_cooldown():
	player.transformation_cooldown_timer = 0.0
	player.transformation_cooldown_changed.emit(0.0, 0.0, false)
	player.update_effects()


func set_transformation_autosave_blocked(blocked: bool):
	if SaveManager != null and SaveManager.has_method("set_autosave_blocked"):
		SaveManager.set_autosave_blocked(TRANSFORMATION_AUTOSAVE_BLOCKER, blocked)


func emit_transformation_cooldown_progress():
	if player.transformation_cooldown_timer <= 0.0 or player.transformation_cooldown_seconds <= 0.0:
		player.transformation_cooldown_changed.emit(0.0, 0.0, false)
		player.update_effects()
		return

	var cooldown_progress: float = player.transformation_cooldown_seconds - player.transformation_cooldown_timer
	player.transformation_cooldown_changed.emit(cooldown_progress, player.transformation_cooldown_seconds, true)
	player.update_effects()


func is_wolf_form() -> bool:
	return player.current_form_id == &"wolf"


func is_transforming_forms() -> bool:
	return player.is_transforming


func get_save_form_id() -> StringName:
	if player.current_form_id == &"wolf" or player.is_transforming:
		return &"human"

	return player.current_form_id


func collect_transformation_travel_state() -> Dictionary:
	return {
		"form_id": str(player.current_form_id),
		"is_transforming": false,
		"transformation_duration": player.transformation_duration,
		"transformation_time_remaining": player.transformation_time_remaining,
		"transformation_cooldown_seconds": player.transformation_cooldown_seconds,
		"transformation_cooldown_timer": player.transformation_cooldown_timer,
		"story_wolf_transformation_locked": player.story_wolf_transformation_locked,
		"dev_wolf_transformation_locked": player.dev_wolf_transformation_locked,
	}


func apply_transformation_travel_state(state: Dictionary):
	if state.is_empty():
		return

	var form_id: StringName = StringName(str(state.get("form_id", "human")))
	player.transformation_generation += 1
	player.is_transforming = false
	player.story_wolf_transformation_locked = bool(state.get("story_wolf_transformation_locked", false))
	player.dev_wolf_transformation_locked = bool(state.get("dev_wolf_transformation_locked", false))
	player.transformation_duration = maxf(float(state.get("transformation_duration", 0.0)), 0.0)
	player.transformation_time_remaining = clampf(float(state.get("transformation_time_remaining", 0.0)), 0.0, player.transformation_duration)
	player.transformation_cooldown_seconds = maxf(float(state.get("transformation_cooldown_seconds", player.transformation_cooldown_seconds)), 0.0)
	player.transformation_cooldown_timer = clampf(float(state.get("transformation_cooldown_timer", 0.0)), 0.0, player.transformation_cooldown_seconds)
	set_transformation_autosave_blocked(false)

	if form_id == &"wolf" and not has_wolf_transformation_unlocked():
		form_id = &"human"

	player.set_form(form_id)
	if form_id == &"wolf":
		if player.transformation_duration <= 0.0:
			player.transformation_duration = get_wolf_transformation_base_duration()
		if player.transformation_time_remaining <= 0.0:
			player.transformation_time_remaining = player.transformation_duration
		player.transformation_state_changed.emit(true)
		player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, true)
	else:
		player.story_wolf_transformation_locked = false
		player.dev_wolf_transformation_locked = false
		player.transformation_duration = 0.0
		player.transformation_time_remaining = 0.0
		player.transformation_state_changed.emit(false)
		player.transformation_timer_changed.emit(0.0, 0.0, false)

	emit_transformation_cooldown_progress()
	player.hold_dialogue_idle()
	player.update_effects()


func convert_story_wolf_lock_to_timed_wolf():
	if not player.story_wolf_transformation_locked:
		return

	player.story_wolf_transformation_locked = false
	var base_duration: float = get_wolf_transformation_base_duration()
	player.transformation_duration = base_duration
	player.transformation_time_remaining = base_duration
	player.transformation_timer_changed.emit(player.transformation_time_remaining, player.transformation_duration, player.current_form_id == &"wolf")
	set_transformation_autosave_blocked(false)
	player.update_effects()


func end_transformation_immediately():
	player.transformation_generation += 1
	player.is_transforming = false
	player.story_wolf_transformation_locked = false
	player.dev_wolf_transformation_locked = false
	player.transformation_duration = 0.0
	player.transformation_time_remaining = 0.0
	set_transformation_autosave_blocked(false)
	clear_transformation_cooldown()
	if player.current_form_id == &"wolf":
		player.set_form(&"human")
	player.transformation_state_changed.emit(false)
	player.transformation_timer_changed.emit(0.0, 0.0, false)


func should_show_transformation_delay_effect() -> bool:
	return (
		not player.dead
		and not player.is_transforming
		and player.current_form_id != &"wolf"
		and not is_any_wolf_transformation_locked()
		and has_wolf_transformation_unlocked()
		and player.transformation_cooldown_timer > 0.0
		and get_transformation_charge_fraction() < player.minimum_transformation_charge_fraction
	)
