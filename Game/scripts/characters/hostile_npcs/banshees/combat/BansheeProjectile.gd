extends CharacterBody2D

@onready var hit_box: Area2D = get_node_or_null("HitBox") as Area2D
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var owner_banshee: Node = null
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var lifetime: float = 2.0
var combo_part: int = 1
var hit_targets: Array[Node] = []


func _ready():
	configure_hit_box()
	if sprite != null:
		sprite.play("projectile")


func launch(source_banshee: Node, launch_direction: Vector2, projectile_speed: float, projectile_lifetime: float, source_combo_part: int):
	owner_banshee = source_banshee
	direction = launch_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	speed = projectile_speed
	lifetime = projectile_lifetime
	combo_part = max(source_combo_part, 1)
	rotation = direction.angle()
	velocity = direction * speed


func configure_hit_box():
	if hit_box == null:
		return

	hit_box.monitoring = true
	hit_box.monitorable = true
	hit_box.collision_layer = 0
	hit_box.collision_mask = 2
	if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
		hit_box.area_entered.connect(_on_hit_box_area_entered)
	call_deferred("hit_current_overlaps")


func _physics_process(delta: float):
	if should_despawn_for_owner():
		queue_free()
		return

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	velocity = direction * speed
	move_and_slide()


func should_despawn_for_owner() -> bool:
	if owner_banshee == null:
		return true
	if not is_instance_valid(owner_banshee):
		return true
	if not owner_banshee.is_inside_tree():
		return true
	return bool(owner_banshee.get("dead"))


func _on_hit_box_area_entered(area: Area2D):
	if area == null or not area.is_in_group("player_hurtboxes"):
		return

	var target: Node = area.get_parent()
	if target == null or target in hit_targets:
		return

	hit_targets.append(target)
	if target.has_method("take_damage"):
		target.take_damage(0, combo_part > 1, owner_banshee)
	queue_free()


func hit_current_overlaps():
	if hit_box == null:
		return

	for area in hit_box.get_overlapping_areas():
		_on_hit_box_area_entered(area)
