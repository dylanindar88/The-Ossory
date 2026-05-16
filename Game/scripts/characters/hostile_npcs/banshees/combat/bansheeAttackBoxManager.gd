class_name BansheeAttackBoxManager
extends RefCounted

const AttackHitboxShapeControllerScript := preload("res://scripts/characters/shared/combat/AttackHitboxShapeController.gd")

var attack_box: Area2D
var collision_shape: CollisionShape2D
var current_combo_part: int = 0
var banshee: Node
var active_attack_targets: Array[Node2D] = []
var shape_controller := AttackHitboxShapeControllerScript.new()


func setup():
	if attack_box == null:
		return

	attack_box.monitoring = true
	attack_box.monitorable = true
	attack_box.collision_layer = 0
	attack_box.collision_mask = 2

	shape_controller.setup(attack_box)
	collision_shape = shape_controller.collision_shape

	if not attack_box.area_entered.is_connected(_on_attack_hit):
		attack_box.area_entered.connect(_on_attack_hit)


func activate_attack_hitbox(combo_part: int, facing_left: bool):
	if attack_box == null:
		return

	current_combo_part = combo_part
	active_attack_targets.clear()
	update_attackbox_facing(facing_left)

	shape_controller.enable_shape()

	call_deferred("_hit_current_overlaps")


func deactivate_attack_hitbox():
	shape_controller.disable_shape()

	active_attack_targets.clear()
	current_combo_part = 0


func update_attackbox_facing(facing_left: bool):
	shape_controller.apply_horizontal_flip(facing_left)


func get_attack_collision_shape() -> CollisionShape2D:
	return shape_controller.find_attack_collision_shape()


func _on_attack_hit(area: Area2D):
	if current_combo_part <= 0:
		return

	if area == null or not area.is_in_group("player_hurtboxes"):
		return

	var target: Node = area.get_parent()
	if target == null or target in active_attack_targets:
		return

	active_attack_targets.append(target)

	if target.has_method("take_damage"):
		var hit_result = target.take_damage(0, current_combo_part > 1, banshee)
		if hit_result == "blocked" and banshee != null and banshee.has_method("on_attack_blocked"):
			banshee.on_attack_blocked()


func _hit_current_overlaps():
	if attack_box == null or current_combo_part <= 0:
		return

	for area in attack_box.get_overlapping_areas():
		_on_attack_hit(area)
