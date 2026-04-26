extends RefCounted


func enter(banshee):
	banshee.sprite.play("run")


func exit(_banshee):
	pass


func physics_update(banshee, _delta):
	if not banshee.has_player_target() or not banshee.player_in_tracking:
		banshee.change_state(banshee.get_default_state())
		return

	if banshee.player_in_attack_range:
		banshee.face_target()

		if banshee.can_attack():
			banshee.change_state("attack")
		else:
			banshee.sprite.play("run")
			banshee.move_toward_player(banshee.attack_move_speed_modifier)

		return

	var direction: Vector2 = banshee.get_direction_to_player()
	banshee.velocity = direction * banshee.run_speed
	banshee.update_facing(direction)
	banshee.sprite.play("run")
	banshee.move_and_slide()
