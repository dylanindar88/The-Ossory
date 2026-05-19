extends RefCounted

const FRAME_SLICED_ATTACK_PREFIXES := {
	"unarmed_attack": true,
	"attack": true,
}
const FRAME_SLICED_COMBO_START_FRAMES := {
	1: 0,
	2: 6,
	3: 11,
}
const FRAME_SLICED_COMBO_END_FRAMES := {
	1: 5,
	2: 10,
	3: 15,
}

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
	maintain_attack_slice_frame(player)

	var in_combo_window = (
		attack_timer <= animation_duration - combo_window_start
		and attack_timer >= combo_window_end
	)

	if in_combo_window and Input.is_action_pressed("left_click"):
		next_combo_pressed = true

	var input_vector: Vector2 = player.get_move_input_vector()
	var movement_speed: float = player.run_speed if player.current_form_always_runs() else player.walk_speed
	player.velocity = input_vector * movement_speed * player.attack_speed_modifier
	player.move_with_non_hostile_npc_blocking(delta)

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


func exit(_player):
	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()

	combo_part = 0
	next_combo_pressed = false


func finish_combo(player):
	player.attack_cooldown_timer = player.attack_combo_restart_delay
	player.can_attack_from_hold = Input.is_action_pressed("left_click")
	player.change_state("move")


func play_attack_animation(player) -> float:
	var anim_name: String = get_attack_animation_name(player, combo_part)
	player.sprite.play(anim_name)
	seek_attack_animation_to_slice(player, anim_name, combo_part, 0.0)
	player.sprite.flip_h = attack_direction == "left"
	return get_attack_slice_duration(player, anim_name, combo_part)


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
	var previous_animation_name: String = str(player.sprite.animation)
	var previous_frame: int = player.sprite.frame
	var previous_frame_progress: float = player.sprite.frame_progress
	var previous_slice_progress: float = get_attack_slice_progress(player, previous_animation_name, combo_part)
	var anim_name: String = get_attack_animation_name(player, combo_part)
	player.sprite.play(anim_name)

	if uses_frame_sliced_attack(player, anim_name):
		seek_attack_animation_to_slice(player, anim_name, combo_part, previous_slice_progress)
	else:
		var sprite_frames: SpriteFrames = player.sprite.sprite_frames
		if sprite_frames != null and sprite_frames.has_animation(anim_name):
			previous_frame = min(previous_frame, sprite_frames.get_frame_count(anim_name) - 1)
		player.sprite.set_frame_and_progress(previous_frame, previous_frame_progress)
	player.sprite.flip_h = attack_direction == "left"
	return get_attack_slice_duration(player, anim_name, combo_part)


func get_attack_animation_name(player, part: int) -> String:
	var prefix: String = str(player.get_attack_animation_prefix())
	if is_frame_sliced_attack_prefix(prefix):
		return get_frame_sliced_attack_animation_name(player, prefix)

	var side_anim_name: String = "%s_%d" % [prefix, part]
	if attack_direction == "left" or attack_direction == "right":
		return side_anim_name

	var vertical_anim_name: String = "%s_%s%d" % [prefix, attack_direction, part]
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames != null and sprite_frames.has_animation(vertical_anim_name):
		return vertical_anim_name

	return side_anim_name


func get_frame_sliced_attack_animation_name(player, prefix: String) -> String:
	if attack_direction == "up":
		var up_anim_name: String = "%s_up" % prefix
		if has_sprite_animation(player, up_anim_name):
			return up_anim_name

	if attack_direction == "down":
		var down_anim_name: String = "%s_down" % prefix
		if has_sprite_animation(player, down_anim_name):
			return down_anim_name

	return prefix


func seek_attack_animation_to_slice(player, anim_name: String, part: int, slice_progress: float):
	if not uses_frame_sliced_attack(player, anim_name):
		return

	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(anim_name):
		return

	var start_frame: int = get_combo_start_frame(part)
	var end_frame: int = mini(get_combo_end_frame(part), sprite_frames.get_frame_count(anim_name) - 1)
	var frame_count: int = maxi(end_frame - start_frame + 1, 1)
	var clamped_progress: float = clamp(slice_progress, 0.0, 0.9999)
	var local_frame: int = mini(int(floor(clamped_progress * float(frame_count))), frame_count - 1)
	player.sprite.set_frame_and_progress(start_frame + local_frame, 0.0)


func maintain_attack_slice_frame(player):
	var anim_name: String = str(player.sprite.animation)
	if not uses_frame_sliced_attack(player, anim_name):
		return

	var end_frame: int = get_combo_end_frame(combo_part)
	if player.sprite.frame > end_frame:
		player.sprite.set_frame_and_progress(end_frame, 0.0)


func get_attack_slice_progress(player, anim_name: String, part: int) -> float:
	if not uses_frame_sliced_attack(player, anim_name):
		return 0.0

	var start_frame: int = get_combo_start_frame(part)
	var frame_count: int = get_combo_frame_count(part)
	var local_frame: int = clampi(player.sprite.frame - start_frame, 0, frame_count - 1)
	return clamp((float(local_frame) + player.sprite.frame_progress) / float(frame_count), 0.0, 0.9999)


func get_attack_slice_duration(player, anim_name: String, part: int) -> float:
	if not uses_frame_sliced_attack(player, anim_name):
		return player.get_sprite_animation_duration(anim_name, animation_duration)

	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(anim_name):
		return animation_duration

	var animation_speed: float = sprite_frames.get_animation_speed(anim_name)
	if animation_speed <= 0.0:
		return animation_duration

	return float(get_combo_frame_count(part)) / animation_speed


func get_combo_start_frame(part: int) -> int:
	return int(FRAME_SLICED_COMBO_START_FRAMES.get(part, FRAME_SLICED_COMBO_START_FRAMES[1]))


func get_combo_end_frame(part: int) -> int:
	return int(FRAME_SLICED_COMBO_END_FRAMES.get(part, FRAME_SLICED_COMBO_END_FRAMES[1]))


func get_combo_frame_count(part: int) -> int:
	return maxi(get_combo_end_frame(part) - get_combo_start_frame(part) + 1, 1)


func uses_frame_sliced_attack(player, anim_name: String) -> bool:
	return is_frame_sliced_attack_prefix(str(player.get_attack_animation_prefix())) and has_sprite_animation(player, anim_name)


func has_sprite_animation(player, anim_name: String) -> bool:
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	return sprite_frames != null and sprite_frames.has_animation(anim_name)


func is_frame_sliced_attack_prefix(prefix: String) -> bool:
	return FRAME_SLICED_ATTACK_PREFIXES.has(prefix)
