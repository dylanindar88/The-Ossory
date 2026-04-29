extends RefCounted


func enter(banshee):
	banshee.sprite.play("walk")
	if not banshee.patrol_route_loaded:
		banshee.refresh_patrol_points()


func exit(_banshee):
	pass


func physics_update(banshee, _delta):
	if banshee.has_player_target() and banshee.player_in_detection:
		banshee.change_state("scream")
		return

	if not banshee.has_patrol_route():
		banshee.patrol_route_loaded = false
		banshee.change_state("idle")
		return

	banshee.move_along_patrol_route(_delta)
