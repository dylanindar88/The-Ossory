class_name BansheeAggroSensor
extends Node

var banshee
var refreshing_player_ranges_after_transform: bool = false
var was_engaged_before_transform_refresh: bool = false
var tracked_transform_signal_player: Node = null
var pending_form_settle_physics_frames: int = 0

const FORM_CHANGE_SETTLE_PHYSICS_FRAMES: int = 2


func setup(owner_banshee):
	banshee = owner_banshee


func connect_ranges():
	if not banshee.player_detection_area.body_entered.is_connected(banshee._on_player_detection_body_entered):
		banshee.player_detection_area.body_entered.connect(banshee._on_player_detection_body_entered)
	if not banshee.player_detection_area.body_exited.is_connected(banshee._on_player_detection_body_exited):
		banshee.player_detection_area.body_exited.connect(banshee._on_player_detection_body_exited)

	if not banshee.attack_range.body_entered.is_connected(banshee._on_attack_range_body_entered):
		banshee.attack_range.body_entered.connect(banshee._on_attack_range_body_entered)
	if not banshee.attack_range.body_exited.is_connected(banshee._on_attack_range_body_exited):
		banshee.attack_range.body_exited.connect(banshee._on_attack_range_body_exited)

	if not banshee.tracking_range.body_entered.is_connected(banshee._on_tracking_range_body_entered):
		banshee.tracking_range.body_entered.connect(banshee._on_tracking_range_body_entered)
	if not banshee.tracking_range.body_exited.is_connected(banshee._on_tracking_range_body_exited):
		banshee.tracking_range.body_exited.connect(banshee._on_tracking_range_body_exited)


func on_player_detection_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	track_player_transform_signal(body)

	if should_defer_player_range_change(body):
		banshee.player = body
		refresh_player_ranges_after_transform()
		return

	if should_ignore_player_aggro():
		return

	banshee.player = body
	track_player_transform_signal(body)
	banshee.player_in_detection = true
	banshee.player_in_tracking = true
	banshee.stop_health_regeneration()
	banshee.reveal_for_story_detection()
	banshee.update_combat_engagement()


func on_player_detection_body_exited(body: Node2D):
	if body == banshee.player:
		if should_defer_player_range_exit(body):
			refresh_player_ranges_after_transform()
			return

		banshee.player_in_detection = false
		banshee.update_combat_engagement()


func on_attack_range_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	track_player_transform_signal(body)

	if should_defer_player_range_change(body):
		banshee.player = body
		refresh_player_ranges_after_transform()
		return

	if should_ignore_player_aggro():
		return

	banshee.player = body
	track_player_transform_signal(body)
	banshee.player_in_attack_range = true
	banshee.player_in_tracking = true
	banshee.stop_health_regeneration()
	banshee.update_combat_engagement()


func on_attack_range_body_exited(body: Node2D):
	if body == banshee.player:
		if should_defer_player_range_exit(body):
			refresh_player_ranges_after_transform()
			return

		banshee.player_in_attack_range = false
		banshee.update_combat_engagement()


func on_tracking_range_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	track_player_transform_signal(body)

	if should_defer_player_range_change(body):
		banshee.player = body
		refresh_player_ranges_after_transform()
		return

	if should_ignore_player_aggro():
		return

	banshee.player = body
	track_player_transform_signal(body)
	if not can_tracking_range_maintain_aggro(banshee.is_currently_engaging_player()):
		return

	banshee.player_in_tracking = true
	banshee.stop_health_regeneration()
	banshee.update_combat_engagement()


func on_tracking_range_body_exited(body: Node2D):
	if body != banshee.player:
		return

	if should_defer_player_range_exit(body):
		refresh_player_ranges_after_transform()
		return

	banshee.player_in_tracking = false
	banshee.player_in_detection = false
	banshee.player_in_attack_range = false
	banshee.update_combat_engagement()


func should_ignore_player_aggro() -> bool:
	return banshee.dead or not banshee.combat_enabled or banshee.suppress_story_detection or (CombatStateManager != null and CombatStateManager.is_dialogue_active())


func should_defer_player_range_exit(body: Node2D) -> bool:
	return should_defer_player_range_change(body)


func should_defer_player_range_change(body: Node2D) -> bool:
	if body == null:
		return false

	if refreshing_player_ranges_after_transform and body == banshee.player:
		return true

	if body.has_method("is_transforming_forms") and bool(body.call("is_transforming_forms")):
		return true

	return body.has_method("is_life_respawn_pending") and bool(body.call("is_life_respawn_pending"))


func can_range_overlap_start_aggro() -> bool:
	return banshee.player_in_detection or banshee.player_in_attack_range


func can_tracking_range_maintain_aggro(was_already_engaged: bool = false) -> bool:
	return was_already_engaged or can_range_overlap_start_aggro()


func is_passive_aggro_state() -> bool:
	return banshee.current_state_name == "idle" or banshee.current_state_name == "patrol" or banshee.current_state_name == "return_to_patrol"


func refresh_player_ranges_after_transform():
	was_engaged_before_transform_refresh = was_engaged_before_transform_refresh or banshee.is_currently_engaging_player()
	pending_form_settle_physics_frames = max(pending_form_settle_physics_frames, FORM_CHANGE_SETTLE_PHYSICS_FRAMES)
	if refreshing_player_ranges_after_transform:
		return

	refreshing_player_ranges_after_transform = true
	banshee.call_deferred("refresh_player_ranges_after_transform_deferred")


func refresh_player_ranges_after_transform_deferred():
	await banshee.get_tree().physics_frame

	if should_ignore_player_aggro():
		refreshing_player_ranges_after_transform = false
		was_engaged_before_transform_refresh = false
		pending_form_settle_physics_frames = 0
		banshee.player_in_detection = false
		banshee.player_in_attack_range = false
		banshee.player_in_tracking = false
		banshee.update_combat_engagement()
		return

	if banshee.player == null or not is_instance_valid(banshee.player):
		refreshing_player_ranges_after_transform = false
		was_engaged_before_transform_refresh = false
		pending_form_settle_physics_frames = 0
		banshee.player_in_detection = false
		banshee.player_in_attack_range = false
		banshee.player_in_tracking = false
		banshee.update_combat_engagement()
		return

	var player_is_still_transforming: bool = banshee.player.has_method("is_transforming_forms") and bool(banshee.player.call("is_transforming_forms"))
	var player_respawn_pending: bool = banshee.player.has_method("is_life_respawn_pending") and bool(banshee.player.call("is_life_respawn_pending"))
	if player_is_still_transforming or player_respawn_pending:
		if banshee.player.has_method("is_transforming_forms") and bool(banshee.player.call("is_transforming_forms")):
			banshee.player_in_tracking = banshee.player_in_tracking or was_engaged_before_transform_refresh
			banshee.update_combat_engagement()
		banshee.call_deferred("refresh_player_ranges_after_transform_deferred")
		return

	if pending_form_settle_physics_frames > 0:
		pending_form_settle_physics_frames -= 1
		banshee.player_in_tracking = banshee.player_in_tracking or was_engaged_before_transform_refresh
		banshee.update_combat_engagement()
		banshee.call_deferred("refresh_player_ranges_after_transform_deferred")
		return

	var was_already_engaged: bool = banshee.is_currently_engaging_player() or was_engaged_before_transform_refresh
	var overlapping_detection: bool = is_player_overlapping_area(banshee.player_detection_area)
	var overlapping_attack: bool = is_player_overlapping_area(banshee.attack_range)
	var overlapping_tracking: bool = is_player_overlapping_area(banshee.tracking_range)

	refreshing_player_ranges_after_transform = false
	was_engaged_before_transform_refresh = false
	pending_form_settle_physics_frames = 0
	banshee.player_in_detection = overlapping_detection
	banshee.player_in_attack_range = overlapping_attack
	banshee.player_in_tracking = overlapping_tracking and can_tracking_range_maintain_aggro(was_already_engaged)

	if can_range_overlap_start_aggro():
		banshee.stop_health_regeneration()
		if is_passive_aggro_state():
			banshee.change_state("scream")
		else:
			banshee.update_combat_engagement()
		return

	banshee.update_combat_engagement()


func is_refreshing_player_ranges_after_transform() -> bool:
	return refreshing_player_ranges_after_transform


func is_player_overlapping_area(area: Area2D) -> bool:
	return get_overlapping_player(area) == banshee.player


func track_player_transform_signal(player_node: Node):
	if player_node == null or not player_node.has_signal("transformation_state_changed"):
		return

	var callback := Callable(self, "_on_player_transformation_state_changed")
	if tracked_transform_signal_player == player_node:
		if not player_node.is_connected("transformation_state_changed", callback):
			player_node.connect("transformation_state_changed", callback)
		return

	if tracked_transform_signal_player != null and is_instance_valid(tracked_transform_signal_player):
		if tracked_transform_signal_player.is_connected("transformation_state_changed", callback):
			tracked_transform_signal_player.disconnect("transformation_state_changed", callback)

	tracked_transform_signal_player = player_node
	if not player_node.is_connected("transformation_state_changed", callback):
		player_node.connect("transformation_state_changed", callback)


func _on_player_transformation_state_changed(_active: bool):
	if banshee == null or banshee.player == null or not is_instance_valid(banshee.player):
		return

	refresh_player_ranges_after_transform()


func refresh_player_detection_after_dialogue():
	if banshee.dead or not banshee.combat_enabled or banshee.suppress_story_detection or CombatStateManager.is_dialogue_active():
		return

	var overlapping_player: Node2D = get_overlapping_player(banshee.player_detection_area)
	if overlapping_player == null:
		return

	banshee.player = overlapping_player
	track_player_transform_signal(overlapping_player)
	banshee.player_in_detection = true
	banshee.player_in_tracking = true
	banshee.player_in_attack_range = get_overlapping_player(banshee.attack_range) != null
	banshee.stop_health_regeneration()
	banshee.reveal_for_story_detection()
	if is_passive_aggro_state():
		banshee.change_state("scream")
	else:
		banshee.update_combat_engagement()


func get_overlapping_player(area: Area2D) -> Node2D:
	if area == null:
		return null
	if not area.monitoring:
		return null

	for body in area.get_overlapping_bodies():
		if body is Node2D and body.is_in_group("player"):
			return body as Node2D

	return null
