extends RefCounted

enum Phase {
	RAISING,
	IDLE,
	RELEASING,
}

var phase: int = Phase.RAISING
var phase_timer: float = 0.0
var action_duration: float = 0.25
var release_duration: float = 0.25
var block_direction: String = "right"
var block_action_anim_name: String = "block_action"
var block_release_anim_name: String = "block_release"
var block_idle_anim_name: String = "block_idle"


func enter(player):
	phase = Phase.RAISING
	update_block_direction(player)
	block_action_anim_name = get_block_animation_name(player, "block_action")
	block_release_anim_name = get_block_animation_name(player, "block_release")
	block_idle_anim_name = get_block_animation_name(player, "block_idle")
	action_duration = get_animation_duration(player, block_action_anim_name)
	release_duration = get_animation_duration(player, block_release_anim_name)
	phase_timer = action_duration
	player.health.set_blocking(false)
	player.health.set_parry_window(false)
	play_block_action(player)


func exit(player):
	player.health.set_blocking(false)
	player.health.set_parry_window(false)
	player.sprite.speed_scale = 1.0


func physics_update(player, delta):
	if can_interrupt_with_attack(player):
		player.change_state("attack")
		return

	update_movement(player)
	update_block_direction(player)
	update_block_facing(player)

	if phase == Phase.RAISING:
		update_parry_window(player)
		phase_timer -= delta

		if not Input.is_action_pressed("right_click"):
			start_releasing(player)
			return

		if phase_timer <= 0:
			phase = Phase.IDLE
			player.health.set_parry_window(false)
			player.health.set_blocking(true)
			player.sprite.speed_scale = 1.0
			play_block_idle(player)

	elif phase == Phase.IDLE:
		play_block_idle(player)

		if player.health.stamina <= 0.0 or not Input.is_action_pressed("right_click"):
			start_releasing(player)

	elif phase == Phase.RELEASING:
		phase_timer -= delta

		if phase_timer <= 0 or not player.sprite.is_playing():
			player.change_state("move")


func start_releasing(player):
	if phase == Phase.RELEASING:
		return

	var was_raising: bool = phase == Phase.RAISING
	var elapsed_action_time: float = action_duration - phase_timer
	var elapsed_action_ratio: float = 0.0
	if action_duration > 0.0:
		elapsed_action_ratio = clamp(elapsed_action_time / action_duration, 0.0, 1.0)

	block_release_anim_name = get_block_animation_name(player, "block_release")
	release_duration = get_animation_duration(player, block_release_anim_name)

	phase = Phase.RELEASING
	phase_timer = release_duration * elapsed_action_ratio if was_raising else release_duration
	player.health.set_blocking(false)
	player.health.set_parry_window(false)
	play_block_release(player, was_raising)


func play_block_action(player):
	player.sprite.speed_scale = 1.0
	player.sprite.play(block_action_anim_name)

	update_block_facing(player)


func play_block_release(player, from_raising: bool):
	var action_frame: int = player.sprite.frame
	var action_frame_progress: float = player.sprite.frame_progress

	player.sprite.speed_scale = 1.0
	player.sprite.play(block_release_anim_name)

	if from_raising:
		seek_release_animation_to_matching_pose(player, action_frame, action_frame_progress)

	update_block_facing(player)


func seek_release_animation_to_matching_pose(player, action_frame: int, action_frame_progress: float):
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(block_release_anim_name):
		return

	var release_frame_count: int = sprite_frames.get_frame_count(block_release_anim_name)
	if release_frame_count <= 0:
		return

	var release_frame: int = clamp(release_frame_count - 1 - action_frame, 0, release_frame_count - 1)
	player.sprite.set_frame_and_progress(release_frame, 1.0 - action_frame_progress)


func play_block_idle(player):
	block_idle_anim_name = get_block_animation_name(player, "block_idle")

	if player.sprite.animation != block_idle_anim_name or not player.sprite.is_playing():
		player.sprite.play(block_idle_anim_name)

	update_block_facing(player)


func update_parry_window(player):
	var parry_active: bool = (
		player.sprite.animation == block_action_anim_name
		and player.sprite.speed_scale > 0
		and player.sprite.frame >= 2
		and player.sprite.frame <= 4
		and Input.is_action_pressed("right_click")
	)
	player.health.set_parry_window(parry_active)


func prepare_for_incoming_damage(player):
	if phase == Phase.RAISING:
		update_parry_window(player)
	else:
		player.health.set_parry_window(false)


func can_interrupt_with_attack(player) -> bool:
	return (
		Input.is_action_just_pressed("left_click")
		and player.attack_cooldown_timer <= 0.0
	)


func update_block_direction(player):
	block_direction = get_block_direction(player)
	player.last_facing = block_direction
	if block_direction == "left" or block_direction == "right":
		player.last_horizontal_facing = block_direction


func update_block_facing(player):
	player.sprite.flip_h = block_direction == "left"


func get_block_direction(player) -> String:
	var block_vector: Vector2 = player.get_global_mouse_position() - player.global_position

	if block_vector.y > abs(block_vector.x):
		return "down"

	if block_vector.y < -abs(block_vector.x):
		return "up"

	if block_vector.x < 0:
		return "left"

	return "right"


func get_block_animation_name(player, base_anim_name: String) -> String:
	if block_direction == "left" or block_direction == "right":
		return base_anim_name

	var vertical_anim_name: String = "%s_%s" % [base_anim_name, block_direction]
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames != null and sprite_frames.has_animation(vertical_anim_name):
		return vertical_anim_name

	return base_anim_name


func update_movement(player):
	var input_vector: Vector2 = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vector = input_vector.normalized()

	if input_vector != Vector2.ZERO:
		player.last_input_direction = input_vector

	player.velocity = input_vector * player.walk_speed * player.block_speed_modifier
	player.move_and_slide()


func get_animation_duration(player, anim_name: String) -> float:
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(anim_name):
		return action_duration

	var animation_speed: float = sprite_frames.get_animation_speed(anim_name)
	if animation_speed <= 0:
		return action_duration

	return float(sprite_frames.get_frame_count(anim_name)) / animation_speed
