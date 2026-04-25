extends RefCounted

var dash_timer = 0.0
var dash_direction = Vector2.ZERO


func enter(player):
	player.can_dash = false
	player.dash_cooldown_timer = player.dash_cooldown

	dash_timer = player.dash_duration

	# ✅ INVULNERABILITY NOW BELONGS TO HEALTH
	player.health.start_invulnerability(player.dash_duration)

	var dir = player.last_input_direction
	var use_horizontal = false

	if dir.x != 0 and dir.y != 0:
		use_horizontal = (player.last_move_axis == "horizontal")
	elif dir.x != 0:
		use_horizontal = true
	else:
		use_horizontal = false

	if use_horizontal:
		dash_direction = Vector2(sign(dir.x), 0)

		if dir.x < 0:
			player.last_facing = "left"
		else:
			player.last_facing = "right"
	else:
		dash_direction = Vector2(0, sign(dir.y))

	if dash_direction == Vector2.ZERO:
		if player.last_facing == "left":
			dash_direction = Vector2.LEFT
		else:
			dash_direction = Vector2.RIGHT


func exit(player):
	# Optional safety: ensure i-frames end cleanly
	player.health.end_invulnerability()


func physics_update(player, delta):
	dash_timer -= delta

	player.velocity = dash_direction * player.dash_speed

	update_dash_animation(player)

	player.move_and_slide()

	if dash_timer <= 0:
		player.change_state("move")

func update_dash_animation(player):
	if dash_direction.x != 0:
		player.sprite.play("dash")

		if dash_direction.x < 0:
			player.sprite.flip_h = true
			player.last_facing = "left"
		else:
			player.sprite.flip_h = false
			player.last_facing = "right"

		return

	if dash_direction.y < 0:
		player.sprite.play("dash_up")
		player.last_facing = "up"
	else:
		player.sprite.play("dash_down")
		player.last_facing = "down"

	player.sprite.flip_h = false
