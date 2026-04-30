class_name BansheeVillagerStalkBehavior
extends Node

var assigned_villager_path: NodePath
var follow_target_distance: float = 36.0
var follow_distance_tolerance: float = 24.0
var follow_speed_modifier: float = 0.35
var reversal_front_buffer: float = 4.0

var banshee
var assigned_villager: Node2D
var assigned_villager_paused: bool = false
var last_villager_stalk_direction: Vector2 = Vector2.ZERO
var holding_for_villager_reversal: bool = false


func setup(
	owner_banshee,
	villager_path: NodePath,
	target_distance: float,
	distance_tolerance: float,
	speed_modifier: float,
	front_buffer: float
):
	banshee = owner_banshee
	assigned_villager_path = villager_path
	follow_target_distance = target_distance
	follow_distance_tolerance = distance_tolerance
	follow_speed_modifier = speed_modifier
	reversal_front_buffer = front_buffer
	resolve_assigned_villager()


func resolve_assigned_villager():
	assigned_villager = null
	assigned_villager_paused = false
	last_villager_stalk_direction = Vector2.ZERO
	holding_for_villager_reversal = false

	if banshee == null or str(assigned_villager_path) == "":
		return

	assigned_villager = banshee.get_node_or_null(assigned_villager_path) as Node2D
	if assigned_villager == null:
		push_warning("%s could not find assigned villager at %s" % [banshee.name, assigned_villager_path])


func is_active() -> bool:
	return has_assigned_villager()


func has_assigned_villager() -> bool:
	return (
		assigned_villager != null
		and is_instance_valid(assigned_villager)
		and assigned_villager.is_inside_tree()
		and assigned_villager.visible
	)


func keep_villager_waiting():
	if not has_assigned_villager() or assigned_villager_paused:
		return

	assigned_villager_paused = true
	if assigned_villager.has_method("pause_for_banshee"):
		assigned_villager.pause_for_banshee()


func resume_villager():
	if not assigned_villager_paused:
		return

	assigned_villager_paused = false
	if has_assigned_villager() and assigned_villager.has_method("resume_from_banshee"):
		assigned_villager.resume_from_banshee()


func notify_villager_banshee_defeated():
	assigned_villager_paused = false
	if has_assigned_villager() and assigned_villager.has_method("on_assigned_banshee_defeated"):
		assigned_villager.on_assigned_banshee_defeated()


func move_toward_assigned_villager():
	if not has_assigned_villager():
		banshee.velocity = Vector2.ZERO
		banshee.sprite.play("walk")
		banshee.move_and_slide()
		return

	var stalk_direction: Vector2 = get_assigned_villager_stalk_direction()
	if should_hold_for_villager_reversal(stalk_direction):
		hold_assigned_villager_stalk()
		last_villager_stalk_direction = stalk_direction
		return

	holding_for_villager_reversal = false
	last_villager_stalk_direction = stalk_direction

	var villager_distance: float = banshee.global_position.distance_to(assigned_villager.global_position)
	if villager_distance <= follow_distance_tolerance:
		hold_assigned_villager_stalk()
		return

	var target_position: Vector2 = get_assigned_villager_stalk_anchor_position()
	var offset: Vector2 = target_position - banshee.global_position
	var distance: float = offset.length()
	if distance <= follow_distance_tolerance:
		hold_assigned_villager_stalk()
		return

	var direction: Vector2 = offset.normalized()
	banshee.velocity = direction * banshee.run_speed * follow_speed_modifier
	banshee.update_facing(direction)
	banshee.sprite.play("walk")
	banshee.move_and_slide()


func move_toward_return_target(delta: float) -> bool:
	var return_arrival_distance: float = get_return_arrival_distance()
	var to_target: Vector2 = assigned_villager.global_position - banshee.global_position
	if to_target.length() <= return_arrival_distance:
		banshee.velocity = Vector2.ZERO
		banshee.move_and_slide()
		return true

	var direction: Vector2 = to_target.normalized()
	var return_speed: float = banshee.run_speed
	if delta > 0.0:
		return_speed = min(banshee.run_speed, to_target.length() / delta)

	banshee.velocity = direction * return_speed
	banshee.update_facing(direction)
	banshee.sprite.play("run")
	banshee.move_and_slide()
	return banshee.global_position.distance_to(assigned_villager.global_position) <= return_arrival_distance


func get_return_arrival_distance() -> float:
	return follow_target_distance + follow_distance_tolerance


func get_assigned_villager_stalk_direction() -> Vector2:
	if has_assigned_villager() and assigned_villager.has_method("get_stalk_direction"):
		var raw_stalk_direction: Variant = assigned_villager.call("get_stalk_direction")
		if not (raw_stalk_direction is Vector2):
			return last_villager_stalk_direction

		var stalk_direction: Vector2 = raw_stalk_direction
		if stalk_direction != Vector2.ZERO:
			return stalk_direction

	return last_villager_stalk_direction


func get_assigned_villager_stalk_anchor_position() -> Vector2:
	if has_assigned_villager() and assigned_villager.has_method("get_stalk_anchor_position"):
		var raw_anchor_position: Variant = assigned_villager.call("get_stalk_anchor_position", follow_target_distance)
		if raw_anchor_position is Vector2:
			var anchor_position: Vector2 = raw_anchor_position
			return anchor_position

	if has_assigned_villager():
		return assigned_villager.global_position

	return banshee.global_position


func should_hold_for_villager_reversal(stalk_direction: Vector2) -> bool:
	if stalk_direction == Vector2.ZERO or last_villager_stalk_direction == Vector2.ZERO:
		return false

	if holding_for_villager_reversal:
		return get_banshee_position_along_villager_direction(stalk_direction) >= -reversal_front_buffer

	if last_villager_stalk_direction.dot(stalk_direction) < -0.6:
		holding_for_villager_reversal = get_banshee_position_along_villager_direction(stalk_direction) >= -reversal_front_buffer
		return holding_for_villager_reversal

	return false


func get_banshee_position_along_villager_direction(stalk_direction: Vector2) -> float:
	if not has_assigned_villager():
		return 0.0

	return (banshee.global_position - assigned_villager.global_position).dot(stalk_direction)


func hold_assigned_villager_stalk():
	banshee.velocity = Vector2.ZERO
	face_assigned_villager()
	banshee.sprite.play("walk")
	banshee.move_and_slide()


func face_assigned_villager():
	if not has_assigned_villager():
		return

	var offset: Vector2 = assigned_villager.global_position - banshee.global_position
	if offset == Vector2.ZERO:
		return

	banshee.update_facing(offset)
