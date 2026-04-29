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
	if can_start_attack and wants_attack:
		player.change_state("attack")
		return

	# Dash
	var wants_dash: bool = Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("ui_accept")
	if wants_dash and player.can_dash and player.health.can_dash():
		player.change_state("dash")
		return

	# Block
	if Input.is_action_pressed("right_click") and player.health.can_start_block():
		player.change_state("block")
		return

	# Run
	var is_running = input_vector != Vector2.ZERO and Input.is_action_pressed("run") and player.health.can_run()
	var current_speed = player.walk_speed

	if is_running:
		current_speed = player.run_speed

	player.health.set_running(is_running)
	player.velocity = input_vector * current_speed

	update_animation(player, input_vector, is_running)

	player.move_and_slide()

func update_last_move_axis(player):
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		player.last_move_axis = "horizontal"

	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		player.last_move_axis = "vertical"

func update_animation(player, dir, is_running):
	# Idle
	if dir == Vector2.ZERO:
		if player.last_facing == "up":
			player.sprite.play("idle_up")
			player.sprite.flip_h = false
		else:
			player.sprite.play("idle")
			player.sprite.flip_h = player.last_horizontal_facing == "left"

		return

	var use_horizontal = false

	if dir.x != 0 and dir.y != 0:
		use_horizontal = (player.last_move_axis == "horizontal")
	elif dir.x != 0:
		use_horizontal = true

	# Horizontal movement
	if use_horizontal:
		var anim = "walking"

		if is_running:
			anim = "running"

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
		player.sprite.play("running_up" if is_running else "walking_up")
		player.last_facing = "up"

	elif dir.y > 0:
		player.sprite.play("running_down" if is_running else "walking_down")
		player.last_facing = "down"

	player.sprite.flip_h = false
