extends RefCounted

var combo_part: int = 1
var attack_elapsed: float = 0.0
var attack_timer: float = 0.0
var animation_duration: float = 0.7
var launch_time: float = 0.55
var projectile_launched: bool = false


func enter(banshee):
	banshee.keep_assigned_villager_waiting()
	combo_part = 1
	start_ranged_part(banshee)


func exit(banshee):
	banshee.sprite.speed_scale = 1.0
	banshee.ranged_cooldown_timer = banshee.ranged_attack_cooldown
	banshee.attack_cooldown_timer = max(banshee.attack_cooldown_timer, banshee.attack_cooldown)


func physics_update(banshee, delta):
	banshee.keep_assigned_villager_waiting()
	banshee.face_target()
	banshee.velocity = Vector2.ZERO
	banshee.move_and_slide()

	attack_elapsed += delta
	attack_timer -= delta

	if not projectile_launched and attack_elapsed >= launch_time:
		projectile_launched = true
		launch_projectile(banshee)

	if attack_timer <= 0.0:
		if combo_part == 1 and banshee.has_player_target() and banshee.is_player_within_ranged_max_distance():
			combo_part = 2
			start_ranged_part(banshee)
			return

		if banshee.has_player_target() and banshee.player_in_tracking:
			banshee.change_state("chase")
		else:
			banshee.return_to_default_state()


func start_ranged_part(banshee):
	var anim_name: String = "ranged%d" % combo_part
	animation_duration = banshee.get_animation_duration(anim_name, 0.7)
	launch_time = banshee.get_animation_time_until_frame(anim_name, banshee.ranged_launch_frame, animation_duration * 0.75)
	attack_elapsed = 0.0
	attack_timer = animation_duration
	projectile_launched = false
	banshee.sprite.play(anim_name)
	banshee.face_target()


func launch_projectile(banshee):
	var launch_direction: Vector2 = banshee.get_direction_to_player()
	if launch_direction == Vector2.ZERO:
		launch_direction = Vector2.LEFT if banshee.facing_left else Vector2.RIGHT
	banshee.launch_ranged_projectile(combo_part, launch_direction)
