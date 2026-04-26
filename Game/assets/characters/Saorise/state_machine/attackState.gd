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
	var mouse_pos = player.get_global_mouse_position()
	attack_direction = get_attack_direction(player, mouse_pos)
	player.last_facing = attack_direction

	combo_part = 1
	next_combo_pressed = false

	animation_duration = play_attack_animation(player)
	attack_timer = animation_duration

	if hitbox_manager:
		hitbox_manager.activate_attack_hitbox(combo_part, attack_direction)


func physics_update(player, delta):
	player.sprite.flip_h = attack_direction == "left"

	attack_timer -= delta

	var in_combo_window = (
		attack_timer <= animation_duration - combo_window_start
		and attack_timer >= combo_window_end
	)

	if in_combo_window and Input.is_action_pressed("left_click"):
		next_combo_pressed = true

	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vector = input_vector.normalized()

	player.velocity = input_vector * player.walk_speed * player.attack_speed_modifier
	player.move_and_slide()

	if attack_timer <= 0:
		if next_combo_pressed and combo_part < 3:
			combo_part += 1
			next_combo_pressed = false

			animation_duration = play_attack_animation(player)
			attack_timer = animation_duration

			if hitbox_manager:
				hitbox_manager.activate_attack_hitbox(combo_part, attack_direction)
		else:
			player.change_state("move")


func exit(player):
	if hitbox_manager:
		hitbox_manager.deactivate_attack_hitbox()

	combo_part = 0
	next_combo_pressed = false


func play_attack_animation(player) -> float:
	var anim_name = get_attack_animation_name(player, combo_part)
	player.sprite.play(anim_name)
	player.sprite.flip_h = attack_direction == "left"
	return get_animation_duration(player, anim_name)


func get_attack_direction(player, mouse_pos: Vector2) -> String:
	var attack_vector: Vector2 = mouse_pos - player.global_position

	if attack_vector.y > abs(attack_vector.x):
		return "down"

	if attack_vector.y < -abs(attack_vector.x):
		return "up"

	if attack_vector.x < 0:
		return "left"

	return "right"


func get_attack_animation_name(player, part: int) -> String:
	var side_anim_name := "unarmed_attack_%d" % part
	if attack_direction == "left" or attack_direction == "right":
		return side_anim_name

	var vertical_anim_name := "unarmed_attack_%s%d" % [attack_direction, part]
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames != null and sprite_frames.has_animation(vertical_anim_name):
		return vertical_anim_name

	return side_anim_name


func get_animation_duration(player, anim_name: String) -> float:
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(anim_name):
		return animation_duration

	var animation_speed := sprite_frames.get_animation_speed(anim_name)
	if animation_speed <= 0:
		return animation_duration

	return float(sprite_frames.get_frame_count(anim_name)) / animation_speed
