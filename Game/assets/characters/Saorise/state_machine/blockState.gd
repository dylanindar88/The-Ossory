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
	action_duration = player.get_sprite_animation_duration(block_action_anim_name, action_duration)
	release_duration = player.get_sprite_animation_duration(block_release_anim_name, release_duration)
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
	release_duration = player.get_sprite_animation_duration(block_release_anim_name, release_duration)

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
	block_direction = player.get_cardinal_direction_to(player.get_global_mouse_position())
	player.last_facing = block_direction
	player.remember_horizontal_facing(block_direction)


func update_block_facing(player):
	player.sprite.flip_h = block_direction == "left"


func get_block_animation_name(player, base_anim_name: String) -> String:
	if block_direction == "left" or block_direction == "right":
		return base_anim_name

	var vertical_anim_name: String = "%s_%s" % [base_anim_name, block_direction]
	var sprite_frames: SpriteFrames = player.sprite.sprite_frames
	if sprite_frames != null and sprite_frames.has_animation(vertical_anim_name):
		return vertical_anim_name

	return base_anim_name


func update_movement(player):
	var input_vector: Vector2 = player.get_move_input_vector()
	player.remember_input_direction(input_vector)

	player.velocity = input_vector * player.walk_speed * player.block_speed_modifier
	player.move_and_slide()
