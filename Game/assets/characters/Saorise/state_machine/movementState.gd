extends RefCounted

func enter(player):
	pass

func exit(player):
	pass

func physics_update(player, delta):
	var input_vector = Vector2.ZERO

	# WASD movement
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	input_vector = input_vector.normalized()

	# Save last direction for dash memory
	if input_vector != Vector2.ZERO:
		player.last_input_direction = input_vector

	update_last_move_axis(player)

	# Attack
	if Input.is_action_just_pressed("left_click"):
		player.change_state("attack")
		return

	# Dash
	if (Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("ui_accept")) and player.can_dash:
		player.change_state("dash")
		return

	# Run
	var is_running = Input.is_action_pressed("run")
	var current_speed = player.walk_speed

	if is_running:
		current_speed = player.run_speed

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
		player.sprite.play("idle")

		if player.last_facing == "left":
			player.sprite.flip_h = true
		else:
			player.sprite.flip_h = false

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
		else:
			player.sprite.flip_h = false
			player.last_facing = "right"

		return

	# Vertical movement
	if dir.y < 0:
		player.sprite.play("running_up" if is_running else "walking_up")

	elif dir.y > 0:
		player.sprite.play("running_down" if is_running else "walking_down")

	player.sprite.flip_h = (player.last_facing == "left")
