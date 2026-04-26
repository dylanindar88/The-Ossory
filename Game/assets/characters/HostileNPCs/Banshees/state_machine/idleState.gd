extends RefCounted


func enter(banshee):
	banshee.velocity = Vector2.ZERO
	banshee.sprite.play("idle")


func exit(_banshee):
	pass


func physics_update(banshee, _delta):
	banshee.velocity = Vector2.ZERO
	banshee.move_and_slide()

	if banshee.has_player_target() and banshee.player_in_detection:
		banshee.change_state("chase")
