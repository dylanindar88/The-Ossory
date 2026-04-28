extends RefCounted

var combo_part: int = 1
var attack_elapsed: float = 0.0
var attack_timer: float = 0.0
var animation_duration: float = 0.5
var damage_start_time: float = 0.25
var hitbox_active: bool = false
var hitbox_started: bool = false


func enter(banshee):
	combo_part = 1
	start_attack_part(banshee)


func exit(banshee):
	banshee.sprite.speed_scale = 1.0
	banshee.attack_cooldown_timer = banshee.attack_cooldown
	deactivate_hitbox(banshee)


func physics_update(banshee, delta):
	banshee.face_target()
	banshee.move_toward_player(banshee.attack_move_speed_modifier)

	attack_elapsed += delta
	attack_timer -= delta

	if not hitbox_started and attack_elapsed >= damage_start_time:
		activate_hitbox(banshee)

	if attack_timer <= 0:
		deactivate_hitbox(banshee)

		if combo_part == 1 and banshee.player_in_attack_range:
			combo_part = 2
			start_attack_part(banshee)
			return

		if banshee.has_player_target() and banshee.player_in_tracking:
			banshee.change_state("chase")
		else:
			banshee.return_to_default_state()


func start_attack_part(banshee):
	var anim_name: String = "melee%d" % combo_part
	animation_duration = banshee.get_animation_duration(anim_name, 0.5)
	damage_start_time = banshee.get_animation_time_until_frame(anim_name, banshee.attack_damage_start_frame, animation_duration * 0.5)
	attack_elapsed = 0.0
	attack_timer = animation_duration
	hitbox_active = false
	hitbox_started = false
	banshee.sprite.play(anim_name)
	banshee.face_target()


func activate_hitbox(banshee):
	hitbox_active = true
	hitbox_started = true
	banshee.hitbox_manager.activate_attack_hitbox(combo_part, banshee.facing_left)


func deactivate_hitbox(banshee):
	if hitbox_active:
		hitbox_active = false

	if banshee.hitbox_manager:
		banshee.hitbox_manager.deactivate_attack_hitbox()
