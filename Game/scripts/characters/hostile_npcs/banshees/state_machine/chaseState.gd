extends RefCounted


func enter(banshee):
	banshee.keep_assigned_villager_waiting()
	banshee.sprite.play("run")


func exit(_banshee):
	pass


func physics_update(banshee, _delta):
	banshee.keep_assigned_villager_waiting()

	if not banshee.has_player_target() or not banshee.player_in_tracking:
		if banshee.has_player_target() and banshee.is_refreshing_player_ranges_after_transform():
			banshee.velocity = Vector2.ZERO
			banshee.face_target()
			banshee.move_and_slide()
			return

		banshee.return_to_default_state()
		return

	if banshee.player_in_attack_range:
		banshee.face_target()

		if banshee.can_attack():
			banshee.change_state("attack")
		elif banshee.should_choose_ranged_attack():
			banshee.change_state("ranged_attack")
		else:
			banshee.sprite.play("run")
			banshee.move_toward_player(banshee.attack_move_speed_modifier)

		return

	if banshee.should_choose_ranged_attack():
		banshee.change_state("ranged_attack")
		return

	banshee.sprite.play("run")
	banshee.move_toward_player(1.0)
