extends RefCounted

enum Phase {
	RAISING,
	IDLE,
	RELEASING,
}

var phase: int = Phase.RAISING
var phase_timer: float = 0.0
var action_duration: float = 0.25


func enter(player):
	phase = Phase.RAISING
	action_duration = get_animation_duration(player, "block_action")
	phase_timer = action_duration
	player.health.set_blocking(false)
	play_block_action(player, false)


func exit(player):
	player.health.set_blocking(false)
	player.sprite.speed_scale = 1.0


func physics_update(player, delta):
	update_movement(player)

	if phase == Phase.RAISING:
		phase_timer -= delta

		if not Input.is_action_pressed("right_click"):
			start_releasing(player)
			return

		if phase_timer <= 0:
			phase = Phase.IDLE
			player.health.set_blocking(true)
			player.sprite.speed_scale = 1.0
			player.sprite.play("block_idle")

	elif phase == Phase.IDLE:
		if not Input.is_action_pressed("right_click"):
			start_releasing(player)

	elif phase == Phase.RELEASING:
		phase_timer -= delta

		if phase_timer <= 0:
			player.change_state("move")


func start_releasing(player):
	if phase == Phase.RELEASING:
		return

	var was_raising: bool = phase == Phase.RAISING
	var elapsed_action_time: float = action_duration - phase_timer

	phase = Phase.RELEASING
	phase_timer = elapsed_action_time if was_raising else action_duration
	player.health.set_blocking(false)
	play_block_action(player, true, not was_raising)


func play_block_action(player, reversed: bool, from_end: bool = false):
	player.sprite.speed_scale = 1.0

	if reversed:
		player.sprite.play("block_action", -1.0, from_end)
	else:
		player.sprite.play("block_action")


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
