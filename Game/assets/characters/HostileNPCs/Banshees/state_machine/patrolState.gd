extends RefCounted


func enter(banshee):
	banshee.sprite.play("walk")
	banshee.refresh_patrol_points()


func exit(_banshee):
	pass


func physics_update(banshee, _delta):
	if banshee.has_player_target() and banshee.player_in_detection:
		banshee.change_state("chase")
		return

	if not banshee.has_patrol_route():
		banshee.change_state("idle")
		return

	var target_position: Vector2 = banshee.get_current_patrol_point()
	var to_target: Vector2 = target_position - banshee.global_position

	if to_target.length() <= banshee.patrol_arrival_distance:
		banshee.advance_patrol_point()
		target_position = banshee.get_current_patrol_point()
		to_target = target_position - banshee.global_position

	var direction: Vector2 = to_target.normalized()
	banshee.velocity = direction * banshee.patrol_speed
	banshee.update_facing(direction)
	banshee.sprite.play("walk")
	banshee.move_and_slide()
