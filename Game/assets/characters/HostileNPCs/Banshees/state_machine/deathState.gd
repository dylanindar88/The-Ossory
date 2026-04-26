extends RefCounted

var death_timer: float = 0.0


func enter(banshee):
	banshee.velocity = Vector2.ZERO
	banshee.disable_combat_areas()
	death_timer = banshee.get_animation_duration("death", 0.5)
	banshee.sprite.play("death")


func exit(_banshee):
	pass


func physics_update(banshee, delta):
	banshee.velocity = Vector2.ZERO
	banshee.move_and_slide()

	death_timer -= delta
	if death_timer <= 0:
		banshee.sprite.speed_scale = 0.0
		banshee.visible = false
		banshee.set_physics_process(false)
