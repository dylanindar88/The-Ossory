extends RefCounted


func enter(banshee):
	banshee.keep_assigned_villager_waiting()
	banshee.sprite.play("run")


func exit(_banshee):
	pass


func physics_update(banshee, delta):
	banshee.keep_assigned_villager_waiting()

	if banshee.has_player_target() and banshee.player_in_detection:
		banshee.change_state("scream")
		return

	if not banshee.has_patrol_route() and not banshee.has_assigned_villager() and not banshee.returning_to_static_position:
		banshee.change_state("idle")
		return

	if banshee.move_toward_return_patrol_target(delta):
		banshee.complete_return_to_patrol()
