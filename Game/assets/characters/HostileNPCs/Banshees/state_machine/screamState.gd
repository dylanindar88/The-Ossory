extends RefCounted

var scream_timer: float = 0.0


func enter(banshee):
	banshee.velocity = Vector2.ZERO
	banshee.move_and_slide()
	banshee.face_target()

	scream_timer = banshee.get_animation_duration("scream", 0.8)
	banshee.sprite.play("scream")


func exit(_banshee):
	pass


func physics_update(banshee, delta):
	banshee.velocity = Vector2.ZERO
	banshee.face_target()
	banshee.move_and_slide()

	if not banshee.has_player_target() or not banshee.player_in_tracking:
		banshee.return_to_default_state()
		return

	scream_timer -= delta
	if scream_timer > 0 and banshee.sprite.is_playing():
		return

	banshee.change_state("chase")
