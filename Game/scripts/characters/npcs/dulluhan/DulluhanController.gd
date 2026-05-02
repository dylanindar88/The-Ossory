extends CharacterBody2D

@export var hidden_alpha: float = 0.35

@onready var sprite: AnimatedSprite2D = $Body
@onready var proximity_area: Area2D = get_node_or_null("PlayerProximityArea") as Area2D
@onready var player_detection_area: Area2D = get_node_or_null("PlayerDetectionArea") as Area2D

var story_visible: bool = true
var revealed: bool = false


func _ready():
	configure_detection_area()
	play_idle()
	apply_story_alpha()


func set_story_visible(should_show: bool):
	story_visible = should_show
	visible = should_show
	set_collision_enabled(should_show)
	if should_show:
		revealed = false
		apply_story_alpha()
		play_idle()
		call_deferred("refresh_player_detection")


func show_for_story():
	set_story_visible(true)


func hide_for_story():
	set_story_visible(false)


func interact(_player: Node2D):
	pass


func play_idle():
	if sprite == null:
		return

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func configure_detection_area():
	if player_detection_area == null:
		return

	player_detection_area.monitoring = true
	player_detection_area.monitorable = true
	player_detection_area.collision_layer = 0
	player_detection_area.collision_mask = 2

	if not player_detection_area.body_entered.is_connected(_on_player_detection_body_entered):
		player_detection_area.body_entered.connect(_on_player_detection_body_entered)


func refresh_player_detection():
	if not story_visible or player_detection_area == null:
		return

	for raw_body in player_detection_area.get_overlapping_bodies():
		if not (raw_body is Node2D):
			continue

		var body: Node2D = raw_body as Node2D
		if body.is_in_group("player"):
			reveal_for_player_approach()
			return


func reveal_for_player_approach():
	if not story_visible or revealed:
		return

	revealed = true
	apply_story_alpha()


func apply_story_alpha():
	if not story_visible:
		return

	modulate.a = 1.0 if revealed else hidden_alpha


func set_collision_enabled(enabled: bool):
	if proximity_area != null:
		proximity_area.monitoring = enabled
		proximity_area.monitorable = enabled
	if player_detection_area != null:
		player_detection_area.monitoring = enabled
		player_detection_area.monitorable = enabled

	for child in get_children():
		if child is CollisionShape2D:
			var collision_shape: CollisionShape2D = child as CollisionShape2D
			collision_shape.set_deferred("disabled", not enabled)
		elif child is Area2D:
			set_area_collision_enabled(child as Area2D, enabled)


func set_area_collision_enabled(area: Area2D, enabled: bool):
	area.monitoring = enabled
	area.monitorable = enabled
	for child in area.get_children():
		if child is CollisionShape2D:
			var collision_shape: CollisionShape2D = child as CollisionShape2D
			collision_shape.set_deferred("disabled", not enabled)


func _on_player_detection_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	reveal_for_player_approach()
