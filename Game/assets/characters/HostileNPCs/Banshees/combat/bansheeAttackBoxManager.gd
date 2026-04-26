class_name BansheeAttackBoxManager
extends RefCounted

var attack_box: Area2D
var collision_shape: CollisionShape2D
var attack_damage: int = 5
var combo_2_damage_bonus: int = 2
var current_combo_part: int = 0
var banshee: Node
var active_attack_targets: Array[Node2D] = []


func setup():
	if attack_box == null:
		return

	attack_box.monitoring = true
	attack_box.monitorable = true
	attack_box.collision_layer = 0
	attack_box.collision_mask = 2

	collision_shape = get_attack_collision_shape()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		collision_shape.visible = false

	if not attack_box.area_entered.is_connected(_on_attack_hit):
		attack_box.area_entered.connect(_on_attack_hit)


func activate_attack_hitbox(combo_part: int, facing_left: bool):
	if attack_box == null:
		return

	current_combo_part = combo_part
	active_attack_targets.clear()
	update_attackbox_facing(facing_left)

	if collision_shape:
		collision_shape.set_deferred("disabled", false)
		collision_shape.visible = true

	call_deferred("_hit_current_overlaps")


func deactivate_attack_hitbox():
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		collision_shape.visible = false

	active_attack_targets.clear()
	current_combo_part = 0


func update_attackbox_facing(facing_left: bool):
	if collision_shape == null:
		return

	collision_shape.position.x = -abs(collision_shape.position.x) if facing_left else abs(collision_shape.position.x)


func get_attack_collision_shape() -> CollisionShape2D:
	if attack_box == null:
		return null

	for child in attack_box.get_children():
		if child is CollisionShape2D:
			return child

	return null


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
		var hit_result = target.take_damage(get_current_attack_damage(), should_ignore_invulnerability())
		if hit_result == "blocked" and banshee != null and banshee.has_method("on_attack_blocked"):
			banshee.on_attack_blocked()


func _hit_current_overlaps():
	if attack_box == null or current_combo_part <= 0:
		return

	for area in attack_box.get_overlapping_areas():
		_on_attack_hit(area)


func get_current_attack_damage() -> int:
	if current_combo_part == 2:
		return attack_damage + combo_2_damage_bonus

	return attack_damage


func should_ignore_invulnerability() -> bool:
	return current_combo_part > 1
