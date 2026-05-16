class_name AttackBoxManager
extends RefCounted

const AttackHitboxShapeControllerScript := preload("res://scripts/characters/shared/combat/AttackHitboxShapeController.gd")

var attack_box: Area2D
var collision_shape: CollisionShape2D
var attack_damage: int
var combo_2_damage_multiplier: float = 1.5
var form_attack_damage_multiplier: float = 1.0
var player_health: Node
var damage_source: Node

var active_attack_targets: Array[Node2D] = []
var current_combo_part: int = 0
var shape_controller := AttackHitboxShapeControllerScript.new()

var attack_profiles: Dictionary = PlayerFormDefinition.DEFAULT_ATTACK_PROFILES.duplicate(true)


func setup():
	if attack_box == null:
		return

	attack_box.monitoring = true
	attack_box.monitorable = true
	attack_box.collision_layer = 0
	attack_box.collision_mask = 4

	shape_controller.setup(attack_box)
	collision_shape = shape_controller.collision_shape

	if not attack_box.area_entered.is_connected(_on_attack_hit):
		attack_box.area_entered.connect(_on_attack_hit)


func activate_attack_hitbox(combo_part: int, direction: String):
	if attack_box == null:
		return

	current_combo_part = combo_part
	active_attack_targets.clear()

	update_attackbox_shape(combo_part, direction)

	shape_controller.enable_shape()

	call_deferred("_hit_current_overlaps")


func update_attack_direction(combo_part: int, direction: String):
	if attack_box == null or current_combo_part <= 0:
		return

	update_attackbox_shape(combo_part, direction)
	call_deferred("_hit_current_overlaps")


func deactivate_attack_hitbox():
	if attack_box == null:
		return

	shape_controller.disable_shape()

	active_attack_targets.clear()
	current_combo_part = 0


func set_attack_profiles(new_attack_profiles: Dictionary):
	attack_profiles = new_attack_profiles.duplicate(true)
	deactivate_attack_hitbox()


func update_attackbox_shape(combo_part: int, direction: String):
	if collision_shape == null:
		push_warning("AttackBox has no CollisionShape2D child.")
		return

	var profile := get_attack_profile(direction, combo_part)
	shape_controller.apply_profile(profile)


func get_attack_profile(direction: String, combo_part: int) -> Dictionary:
	var direction_profiles: Dictionary = attack_profiles.get(direction, attack_profiles["right"])
	return direction_profiles.get(combo_part, direction_profiles[1])


func get_attack_collision_shape() -> CollisionShape2D:
	return shape_controller.find_attack_collision_shape()


func has_hit_target(target: Node2D) -> bool:
	return target in active_attack_targets


func register_hit(target: Node2D):
	if not has_hit_target(target):
		active_attack_targets.append(target)


func _on_attack_hit(area: Area2D):
	if current_combo_part <= 0:
		return

	if area == null:
		return

	if not area.is_in_group("enemies"):
		return

	var target = area.get_parent()

	if target == null:
		return

	if has_hit_target(target):
		return

	register_hit(target)

	if target.has_method("take_damage"):
		target.take_damage(get_current_attack_damage(), should_ignore_invulnerability(), damage_source)


func _hit_current_overlaps():
	if attack_box == null or current_combo_part <= 0:
		return

	for area in attack_box.get_overlapping_areas():
		_on_attack_hit(area)


func get_current_attack_damage() -> int:
	var damage := float(attack_damage)
	damage *= form_attack_damage_multiplier

	if current_combo_part == 2:
		damage *= combo_2_damage_multiplier

	if player_health != null and player_health.has_method("get_attack_damage_multiplier"):
		damage *= player_health.get_attack_damage_multiplier()

	return int(round(damage))


func should_ignore_invulnerability() -> bool:
	return current_combo_part > 1
