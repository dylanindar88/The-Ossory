extends RefCounted


func enter(banshee):
	banshee.sprite.play("run")


func exit(_banshee):
	pass


func physics_update(banshee, _delta):
	if not banshee.has_player_target() or not banshee.player_in_tracking:
		banshee.return_to_default_state()
		return

	if banshee.player_in_attack_range:
		banshee.face_target()

		if banshee.can_attack():
			banshee.change_state("attack")
		else:
			banshee.sprite.play("run")
			banshee.move_toward_player(banshee.attack_move_speed_modifier)

		return

	banshee.sprite.play("run")
	banshee.move_toward_player(1.0)
