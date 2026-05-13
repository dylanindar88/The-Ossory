extends RefCounted

func enter(player):
	pass

func exit(player):
	player.health.set_running(false)

func physics_update(player, delta):
	var input_vector: Vector2 = player.get_move_input_vector()
	player.remember_input_direction(input_vector)

	update_last_move_axis(player)

	if Input.is_action_pressed("left_click") and player.attack_cooldown_timer > 0.0:
		player.can_attack_from_hold = true
	elif not Input.is_action_pressed("left_click"):
		player.can_attack_from_hold = false

	# Attack
	var can_start_attack: bool = player.attack_cooldown_timer <= 0.0
	var wants_attack: bool = (
		Input.is_action_just_pressed("left_click")
		or (Input.is_action_pressed("left_click") and player.can_attack_from_hold)
	)
	if can_start_attack and wants_attack and player.can_current_form_attack():
		player.change_state("attack")
		return

	# Dash
	var wants_dash: bool = Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("ui_accept")
	var can_afford_dash: bool = player.can_dash_without_stamina() or player.health.can_dash()
	if wants_dash and player.can_dash and player.can_current_form_dash() and can_afford_dash:
		player.change_state("dash")
		return

	# Block
	var can_afford_block: bool = player.can_block_without_stamina() or player.health.can_start_block()
	if Input.is_action_pressed("right_click") and player.can_current_form_block() and can_afford_block:
		player.change_state("block")
		return

	# Run
	var is_running: bool = input_vector != Vector2.ZERO and (player.current_form_always_runs() or (Input.is_action_pressed("run") and player.health.can_run()))
	var current_speed: float = player.walk_speed

	if is_running:
		current_speed = player.run_speed

	player.health.set_running(is_running and player.current_form_uses_stamina())
	player.velocity = input_vector * current_speed

	update_animation(player, input_vector, is_running)

	player.move_with_non_hostile_npc_blocking(delta)

func update_last_move_axis(player):
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		player.last_move_axis = "horizontal"

	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		player.last_move_axis = "vertical"

func update_animation(player, dir, is_running):
	# Idle
	if dir == Vector2.ZERO:
		player.play_directional_idle()
		return

	var use_horizontal = false

	if dir.x != 0 and dir.y != 0:
		use_horizontal = (player.last_move_axis == "horizontal")
	elif dir.x != 0:
		use_horizontal = true

	# Horizontal movement
	if use_horizontal:
		var anim: StringName = player.get_form_movement_animation(true, false, is_running)
		if player.sprite.sprite_frames != null and not player.sprite.sprite_frames.has_animation(anim):
			anim = &"idle"
		player.sprite.play(anim)

		if dir.x < 0:
			player.sprite.flip_h = true
			player.last_facing = "left"
			player.last_horizontal_facing = "left"
		else:
			player.sprite.flip_h = false
			player.last_facing = "right"
			player.last_horizontal_facing = "right"

		return

	# Vertical movement
	if dir.y < 0:
		var up_anim: StringName = player.get_form_movement_animation(false, true, is_running)
		if player.sprite.sprite_frames != null and not player.sprite.sprite_frames.has_animation(up_anim):
			up_anim = &"idle_up" if player.sprite.sprite_frames.has_animation(&"idle_up") else &"idle"
		player.sprite.play(up_anim)
		player.last_facing = "up"

	elif dir.y > 0:
		var down_anim: StringName = player.get_form_movement_animation(false, false, is_running)
		if player.sprite.sprite_frames != null and not player.sprite.sprite_frames.has_animation(down_anim):
			down_anim = &"idle_down" if player.sprite.sprite_frames.has_animation(&"idle_down") else &"idle"
		player.sprite.play(down_anim)
		player.last_facing = "down"

	player.sprite.flip_h = false
