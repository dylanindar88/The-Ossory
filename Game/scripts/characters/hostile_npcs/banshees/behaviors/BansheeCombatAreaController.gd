class_name BansheeCombatAreaController
extends Node

var banshee


func setup(owner_banshee):
	banshee = owner_banshee


func configure_collision():
	banshee.collision_layer = 0
	banshee.collision_mask = 0

	banshee.hurt_box.add_to_group("enemies")
	banshee.hurt_box.monitorable = true
	banshee.hurt_box.monitoring = true
	banshee.hurt_box.collision_layer = 4
	banshee.hurt_box.collision_mask = 0

	banshee.attack_box.collision_layer = 0
	banshee.attack_box.collision_mask = 2

	for area in get_combat_areas(false):
		area.monitoring = true
		area.monitorable = true
		area.collision_layer = 0
		area.collision_mask = 2


func disable_combat_areas():
	for area in get_combat_areas(true):
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
		for child in area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)


func enable_combat_areas():
	configure_collision()
	for area in get_combat_areas(true):
		area.set_deferred("monitoring", true)
		area.set_deferred("monitorable", true)
		for child in area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", false)


func set_story_combat_enabled(enabled: bool, visible_alpha: float = 1.0):
	banshee.combat_enabled = enabled
	banshee.modulate.a = visible_alpha
	if not enabled:
		banshee.story_revealed = false
		banshee.stop_health_regeneration()
		banshee.clear_combat_engagement()
	banshee.player_in_detection = false
	banshee.player_in_attack_range = false
	banshee.player_in_tracking = false

	if enabled and not banshee.dead:
		enable_combat_areas()
	else:
		disable_combat_areas()


func set_damage_enabled(enabled: bool):
	banshee.damage_enabled = enabled


func enable_story_combat(visible_alpha: float = 1.0):
	set_story_combat_enabled(true, visible_alpha)


func disable_story_combat(visible_alpha: float):
	set_story_combat_enabled(false, visible_alpha)


func get_combat_areas(include_hurt_and_attack: bool) -> Array[Area2D]:
	var areas: Array[Area2D] = [
		banshee.player_detection_area,
		banshee.attack_range,
		banshee.tracking_range,
	]
	if include_hurt_and_attack:
		areas.insert(0, banshee.attack_box)
		areas.insert(0, banshee.hurt_box)

	return areas
