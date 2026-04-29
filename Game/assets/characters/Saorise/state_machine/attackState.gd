extends RefCounted

var combo_part: int = 0
var attack_timer: float = 0.0
var animation_duration: float = 0.4

# Scaled combo window (same relative timing as before)
var combo_window_start: float = 0.17
var combo_window_end: float = 0.03

var next_combo_pressed: bool = false
var attack_direction: String = "right"

var hitbox_manager: Object


func enter(player):
	player.can_attack_from_hold = false

	update_attack_direction(player, false)

	combo_part = 1
	next_combo_pressed = false

	animation_duration = play_attack_animation(player)
	attack_timer = animation_duration

	if hitbox_manager:
		hitbox_manager.activate_attack_hitbox(combo_part, attack_direction)


func physics_update(player, delta):
	update_attack_direction(player)

	attack_timer -= delta

	var in_combo_window = (
		attack_timer <= animation_duration - combo_window_start
		and attack_timer >= combo_window_end
	)

	if in_combo_window and Input.is_action_pressed("left_click"):
		next_combo_pressed = true

	var input_vector: Vector2 = player.get_move_input_vector()
	player.velocity = input_vector * player.walk_speed * player.attack_speed_modifier
	player.move_with_villager_blocking(delta)

	if attack_timer <= 0:
		if next_combo_pressed and combo_part < 3:
			combo_part += 1
			next_combo_pressed = false

			update_attack_direction(player, false)
			animation_duration = play_attack_animation(player)
			attack_timer = animation_duration

			if hitbox_manager:
				hitbox_manager.activate_attack_hitbox(combo_part, attack_direction)
		else:
			finish_combo(player)


func exit(player):
	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()

	combo_part = 0
	next_combo_pressed = false


func finish_combo(player):
	player.attack_cooldown_timer = player.attack_combo_restart_delay
	player.can_attack_from_hold = Input.is_action_pressed("left_click")
	player.change_state("move")


func play_attack_animation(player) -> float:
	var anim_name = get_attack_animation_name(player, combo_part)
	player.sprite.play(anim_name)
	player.sprite.flip_h = attack_direction == "left"
	return player.get_sprite_animation_duration(anim_name, animation_duration)


func update_attack_direction(player, preserve_animation_progress: bool = true):
	var new_attack_direction: String = player.get_cardinal_direction_to(player.get_global_mouse_position())
	if new_attack_direction == attack_direction:
		player.last_facing = attack_direction
		player.remember_horizontal_facing(attack_direction)
		player.sprite.flip_h = attack_direction == "left"
		return

	attack_direction = new_attack_direction
	player.last_facing = attack_direction
	player.remember_horizontal_facing(attack_direction)

	if combo_part <= 0:
		return

	if preserve_animation_progress:
		var elapsed_attack_time: float = animation_duration - attack_timer
		animation_duration = transition_attack_animation(player)
		attack_timer = max(animation_duration - elapsed_attack_time, 0.0)

	if preserve_animation_progress and hitbox_manager and hitbox_manager.has_method("update_attack_direction"):
		hitbox_manager.update_attack_direction(combo_part, attack_direction)


func transition_attack_animation(player) -> float:
	var previous_frame: int = player.sprite.frame
	var previous_frame_progress: float = player.sprite.frame_progress
	var anim_name = get_attack_animation_name(player, combo_part)
	player.sprite.play(anim_name)

	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames != null and sprite_frames.has_animation(anim_name):
		previous_frame = min(previous_frame, sprite_frames.get_frame_count(anim_name) - 1)

	player.sprite.set_frame_and_progress(previous_frame, previous_frame_progress)
	player.sprite.flip_h = attack_direction == "left"
	return player.get_sprite_animation_duration(anim_name, animation_duration)


func get_attack_animation_name(player, part: int) -> String:
	var side_anim_name := "unarmed_attack_%d" % part
	if attack_direction == "left" or attack_direction == "right":
		return side_anim_name

	var vertical_anim_name := "unarmed_attack_%s%d" % [attack_direction, part]
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames != null and sprite_frames.has_animation(vertical_anim_name):
		return vertical_anim_name

	return side_anim_name
