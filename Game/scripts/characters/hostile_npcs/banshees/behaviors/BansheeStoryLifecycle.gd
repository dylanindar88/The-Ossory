class_name BansheeStoryLifecycle
extends Node

var banshee
var detection_suppression_generation: int = 0


func setup(owner_banshee):
	banshee = owner_banshee


func get_unrevealed_alpha(fallback_alpha: float = 0.2) -> float:
	if banshee == null:
		return fallback_alpha

	var alpha: Variant = banshee.get("undetected_alpha")
	if alpha == null:
		return fallback_alpha

	return float(alpha)


func set_story_revealed(revealed: bool, hidden_alpha: float):
	banshee.story_revealed = revealed
	if banshee.story_revealed:
		banshee.modulate.a = 1.0
	else:
		banshee.modulate.a = get_unrevealed_alpha(hidden_alpha)


func hide_as_story_defeated(hidden_alpha: float):
	banshee.dead = true
	banshee.visible = false
	banshee.velocity = Vector2.ZERO
	banshee.clear_combat_engagement()
	banshee.stop_health_regeneration()
	banshee.set_physics_process(false)
	banshee.disable_combat_areas()
	set_story_revealed(false, hidden_alpha)

	var health_node: Node = banshee.health
	if health_node != null:
		health_node.set("dead", true)
		health_node.set("health", 0)


func collect_story_save_state() -> Dictionary:
	var health_node: Node = banshee.health
	var current_health: int = 0
	var max_health_value: int = 0
	var health_is_dead: bool = false
	if health_node != null:
		current_health = int(health_node.get("health"))
		max_health_value = int(health_node.get("max_health"))
		health_is_dead = bool(health_node.get("dead"))

	return {
		"position": vector_to_data(banshee.global_position),
		"health": current_health,
		"max_health": max_health_value,
		"dead": banshee.dead or health_is_dead,
		"revealed": banshee.story_revealed,
		"combat_enabled": banshee.combat_enabled,
		"damage_enabled": banshee.damage_enabled,
		"combat_variant": banshee.combat_variant,
		"facing_left": banshee.facing_left,
		"patrol_route": banshee.patrol_route.to_save_data(),
		"villager_stalk": banshee.villager_stalk_behavior.to_save_data(),
	}


func reveal_for_story_detection():
	if banshee.dead or not banshee.combat_enabled or banshee.story_revealed or banshee.suppress_story_detection:
		return

	banshee.story_revealed = true
	banshee.modulate.a = 1.0
	banshee.player_detected_for_reveal.emit(banshee)


func begin_story_detection_suppression():
	# Area monitoring is restored with deferred calls, so ignore one restore-frame
	# detection pass before allowing story reveal logic to run again.
	detection_suppression_generation += 1
	banshee.suppress_story_detection = true
	banshee.call_deferred("end_story_detection_suppression_after_physics")


func end_story_detection_suppression_after_physics():
	var generation := detection_suppression_generation
	if banshee == null or not is_instance_valid(banshee) or not banshee.is_inside_tree():
		return

	var tree: SceneTree = banshee.get_tree()
	if tree == null:
		return

	await tree.physics_frame
	if generation != detection_suppression_generation:
		return
	if banshee == null or not is_instance_valid(banshee) or not banshee.is_inside_tree():
		return

	banshee.suppress_story_detection = false


func restore_after_load():
	banshee.last_damage_source = null
	banshee.last_killer_form_id = &""
	banshee.damage_enabled = false
	banshee.dead = false
	banshee.visible = true
	banshee.velocity = Vector2.ZERO
	banshee.returning_to_static_position = false
	banshee.clear_combat_engagement()
	banshee.attack_cooldown_timer = 0.0
	banshee.ranged_cooldown_timer = 0.0
	banshee.player_in_detection = false
	banshee.player_in_attack_range = false
	banshee.player_in_tracking = false
	banshee.story_revealed = false
	set_story_revealed(false, get_unrevealed_alpha())
	banshee.clear_hurt_state_overrides()
	banshee.set_physics_process(true)

	if banshee.sprite != null:
		banshee.sprite.speed_scale = 1.0

	var health_node: Node = banshee.health
	if health_node != null:
		health_node.set("dead", false)
		if health_node.has_method("stop_regeneration"):
			health_node.stop_regeneration()
		health_node.set("invulnerable", false)
		health_node.set("i_frame_timer", 0.0)
		health_node.set("health", int(health_node.get("max_health")))
		if health_node.has_signal("health_changed"):
			health_node.emit_signal("health_changed", health_node.get("health"), health_node.get("max_health"))

	banshee.player = banshee.get_tree().get_first_node_in_group("player")
	if banshee.combat_enabled:
		banshee.enable_combat_areas()
	else:
		banshee.disable_combat_areas()
	banshee.setup_villager_stalk_behavior()
	banshee.refresh_patrol_points()
	banshee.apply_variant_tuning()

	banshee.change_state(banshee.get_default_state())


func respawn_for_story(hidden_alpha: float):
	var respawn_position: Vector2 = get_story_respawn_position()
	banshee.global_position = respawn_position
	restore_after_load()
	banshee.global_position = respawn_position
	banshee.facing_left = banshee.story_spawn_facing_left
	if banshee.sprite != null:
		banshee.sprite.flip_h = banshee.facing_left
	banshee.set_story_combat_enabled(true, get_unrevealed_alpha(hidden_alpha))
	banshee.set_damage_enabled(true)
	set_story_revealed(false, hidden_alpha)
	banshee.stop_health_regeneration()
	banshee.begin_assigned_villager_catchup_if_needed()


func restore_for_story_load(hidden_alpha: float, combat_should_be_enabled: bool, should_be_revealed: bool):
	begin_story_detection_suppression()
	var restore_position: Vector2 = banshee.story_spawn_position
	banshee.global_position = restore_position
	restore_after_load()
	banshee.global_position = restore_position
	banshee.facing_left = banshee.story_spawn_facing_left
	if banshee.sprite != null:
		banshee.sprite.flip_h = banshee.facing_left

	var visible_alpha: float = get_unrevealed_alpha(hidden_alpha)
	if combat_should_be_enabled and should_be_revealed:
		visible_alpha = 1.0

	banshee.set_story_combat_enabled(combat_should_be_enabled, visible_alpha)
	banshee.set_damage_enabled(combat_should_be_enabled)
	set_story_revealed(combat_should_be_enabled and should_be_revealed, hidden_alpha)
	banshee.stop_health_regeneration()
	if combat_should_be_enabled:
		banshee.begin_assigned_villager_catchup_if_needed()


func restore_from_story_save(state: Dictionary, hidden_alpha: float, combat_should_be_enabled: bool, should_be_revealed: bool):
	begin_story_detection_suppression()
	banshee.apply_saved_combat_variant(state)
	var saved_position: Vector2 = data_to_vector(state.get("position", {}), banshee.global_position)
	var saved_health: int = int(state.get("health", banshee.health.get("max_health")))
	var saved_facing_left: bool = bool(state.get("facing_left", banshee.facing_left))

	banshee.global_position = saved_position
	restore_after_load()
	banshee.global_position = saved_position
	banshee.patrol_route.apply_save_data(state.get("patrol_route", {}))
	banshee.villager_stalk_behavior.apply_save_data(state.get("villager_stalk", {}))
	banshee.facing_left = saved_facing_left

	if banshee.sprite != null:
		banshee.sprite.flip_h = banshee.facing_left

	var health_node: Node = banshee.health
	if health_node != null:
		banshee.apply_variant_tuning()
		var max_health_value: int = int(health_node.get("max_health"))
		var restored_health: int = int(clamp(saved_health, 1, max_health_value))
		health_node.set("health", restored_health)
		health_node.set("dead", false)
		health_node.set("invulnerable", false)
		health_node.set("i_frame_timer", 0.0)
		if health_node.has_signal("health_changed"):
			health_node.emit_signal("health_changed", restored_health, max_health_value)

	var visible_alpha: float = get_unrevealed_alpha(hidden_alpha)
	if combat_should_be_enabled and should_be_revealed:
		visible_alpha = 1.0

	banshee.set_story_combat_enabled(combat_should_be_enabled, visible_alpha)
	banshee.set_damage_enabled(combat_should_be_enabled and bool(state.get("damage_enabled", combat_should_be_enabled)))
	set_story_revealed(combat_should_be_enabled and should_be_revealed, hidden_alpha)
	banshee.stop_health_regeneration()
	if combat_should_be_enabled:
		banshee.begin_assigned_villager_catchup_if_needed()


func restore_dead_from_story_save(state: Dictionary, hidden_alpha: float):
	banshee.apply_saved_combat_variant(state)
	var saved_position: Vector2 = data_to_vector(state.get("position", {}), banshee.global_position)
	banshee.global_position = saved_position
	banshee.facing_left = bool(state.get("facing_left", banshee.facing_left))
	if banshee.sprite != null:
		banshee.sprite.flip_h = banshee.facing_left

	banshee.refresh_patrol_points()
	banshee.patrol_route.apply_save_data(state.get("patrol_route", {}))
	banshee.setup_villager_stalk_behavior()
	banshee.villager_stalk_behavior.apply_save_data(state.get("villager_stalk", {}))
	hide_as_story_defeated(hidden_alpha)


func data_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	if not (value is Dictionary):
		return fallback

	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


func vector_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func get_story_respawn_position() -> Vector2:
	var villager: Node = banshee.get_assigned_villager()
	if villager is Node2D and banshee.has_patrol_route():
		var villager_node: Node2D = villager as Node2D
		return banshee.get_nearest_patrol_position(villager_node.global_position)

	return banshee.story_spawn_position
