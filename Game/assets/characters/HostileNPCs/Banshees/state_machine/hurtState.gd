extends RefCounted

var hurt_timer: float = 0.0


func enter(banshee):
	var default_duration: float = banshee.get_animation_duration("hurt", 0.35)
	hurt_timer = banshee.get_hurt_state_duration(default_duration)
	banshee.sprite.play("hurt")


func exit(banshee):
	banshee.clear_hurt_state_overrides()


func physics_update(banshee, delta):
	banshee.move_toward_player(banshee.get_hurt_state_speed_modifier())

	hurt_timer -= delta
	if hurt_timer > 0:
		return

	if banshee.has_player_target() and banshee.player_in_tracking:
		banshee.change_state("chase")
	else:
		banshee.change_state(banshee.get_default_state())
