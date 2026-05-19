class_name KnightArrowProjectile
extends CharacterBody2D

@onready var hit_box: Area2D = get_node_or_null("HitBox") as Area2D
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

var source_knight: Node
var direction: Vector2 = Vector2.RIGHT
var speed: float = 260.0
var lifetime: float = 2.0
var damage: int = 8
var hit_targets: Array[Node] = []


func _ready():
	configure_hit_box()


func launch(source: Node, launch_direction: Vector2, projectile_speed: float, projectile_lifetime: float, projectile_damage: int):
	source_knight = source
	direction = launch_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	speed = projectile_speed
	lifetime = projectile_lifetime
	damage = projectile_damage
	rotation = direction.angle()
	velocity = direction * speed


func configure_hit_box():
	if hit_box == null:
		return

	apply_authored_hitbox_profile()
	hit_box.monitoring = true
	hit_box.monitorable = true
	hit_box.collision_layer = 0
	hit_box.collision_mask = 2
	if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
		hit_box.area_entered.connect(_on_hit_box_area_entered)
	call_deferred("hit_current_overlaps")


func _physics_process(delta: float):
	lifetime -= delta
	if lifetime <= 0.0 or should_despawn_for_source():
		queue_free()
		return

	velocity = direction * speed
	move_and_slide()


func should_despawn_for_source() -> bool:
	if source_knight == null:
		return false
	if not is_instance_valid(source_knight) or not source_knight.is_inside_tree():
		return true
	return bool(source_knight.get("dead"))


func _on_hit_box_area_entered(area: Area2D):
	if area == null or not area.is_in_group("player_hurtboxes"):
		return

	var target := area.get_parent()
	if target == null or target in hit_targets:
		return

	hit_targets.append(target)
	if target.has_method("take_damage"):
		var hit_result: Variant = target.take_damage(0, false, source_knight)
		if hit_result == "blocked" and source_knight != null and is_instance_valid(source_knight) and source_knight.has_method("on_attack_blocked"):
			source_knight.on_attack_blocked()
	queue_free()


func hit_current_overlaps():
	if hit_box == null:
		return

	for area in hit_box.get_overlapping_areas():
		_on_hit_box_area_entered(area)


func apply_authored_hitbox_profile():
	var profile_authoring := find_profile_authoring()
	if profile_authoring == null:
		return
	profile_authoring.apply_profile_to_shape(&"default", &"default", 1)


func find_profile_authoring() -> AttackHitboxProfileAuthoring:
	for child in get_children():
		if child is AttackHitboxProfileAuthoring:
			return child as AttackHitboxProfileAuthoring
	return null
