class_name CampfireBaseTent
extends StaticBody2D

signal destroyed(tent: Node)
signal health_changed(current_health: int, max_health: int)

const WEAK_TO_WOLF_EFFECT := "weak_to_wolf"

@export var tent_id: StringName = &"tent"
@export var max_health: int = 24

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hurt_box: Area2D = get_node_or_null("HurtBox") as Area2D
@onready var effects: EffectList = get_node_or_null("Effects") as EffectList

var health: int = max_health
var dead: bool = false
var weak_to_wolf_effect_visible: bool = false


func _ready():
	add_to_group("campfire_base_tents")
	configure_hurt_box()
	health = max_health
	play_alive_visual()
	health_changed.emit(health, max_health)
	update_wolf_weakness_effect()


func _process(_delta: float):
	update_wolf_weakness_effect()


func configure_hurt_box():
	if hurt_box == null:
		return

	hurt_box.add_to_group("enemies")
	hurt_box.monitoring = true
	hurt_box.monitorable = true
	hurt_box.collision_layer = 4
	hurt_box.collision_mask = 0


func take_damage(amount: int, _ignore_invulnerability: bool = false, damage_source: Node = null):
	if dead or not can_take_damage_from(damage_source):
		return

	health = clamp(health - maxi(amount, 0), 0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0:
		destroy()


func can_take_damage_from(damage_source: Node) -> bool:
	if damage_source != null and damage_source.has_method("get_current_form_id"):
		return damage_source.get_current_form_id() == &"wolf"

	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.has_method("get_current_form_id") and player.get_current_form_id() == &"wolf"


func destroy():
	if dead:
		return

	dead = true
	health = 0
	set_hurt_box_enabled(false)
	play_destroyed_visual()
	health_changed.emit(health, max_health)
	update_wolf_weakness_effect()
	destroyed.emit(self)


func restore_alive(restored_health: int = -1):
	dead = false
	health = max_health if restored_health < 0 else clamp(restored_health, 1, max_health)
	set_hurt_box_enabled(true)
	play_alive_visual()
	health_changed.emit(health, max_health)
	update_wolf_weakness_effect()


func set_hurt_box_enabled(enabled: bool):
	if hurt_box == null:
		return

	hurt_box.set_deferred("monitoring", enabled)
	hurt_box.set_deferred("monitorable", enabled)
	for child in hurt_box.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not enabled)
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).set_deferred("disabled", not enabled)


func is_hurt_box_enabled() -> bool:
	if hurt_box == null:
		return false
	if not hurt_box.monitoring or not hurt_box.monitorable:
		return false

	for child in hurt_box.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).disabled:
			return false
		if child is CollisionPolygon2D and (child as CollisionPolygon2D).disabled:
			return false
	return true


func collect_story_save_state() -> Dictionary:
	return {
		"tent_id": get_tent_id(),
		"dead": dead,
		"health": health,
	}


func apply_story_save_state(state: Dictionary):
	if bool(state.get("dead", false)) or int(state.get("health", max_health)) <= 0:
		destroy()
		return

	restore_alive(int(state.get("health", max_health)))


func get_tent_id() -> String:
	var id := str(tent_id)
	return name if id == "" else id


func play_alive_visual():
	play_first_existing_animation(get_alive_animation_priority())


func play_destroyed_visual():
	play_first_existing_animation(get_destroyed_animation_priority())


func get_alive_animation_priority() -> Array[String]:
	if prefers_flipped_visuals():
		return ["alive_flipped", "alive", "idle"]
	return ["alive", "alive_flipped", "idle"]


func get_destroyed_animation_priority() -> Array[String]:
	if prefers_flipped_visuals():
		return ["destroyed_flipped", "destroyed", "dead", "idle"]
	return ["destroyed", "destroyed_flipped", "dead", "idle"]


func prefers_flipped_visuals() -> bool:
	if sprite != null and str(sprite.animation).ends_with("_flipped"):
		return true
	return scene_file_path.ends_with("CampfireBaseTentFlipped.tscn")


func play_first_existing_animation(animation_names: Array[String]):
	if sprite == null or sprite.sprite_frames == null:
		return

	for animation_name in animation_names:
		if sprite.sprite_frames.has_animation(animation_name) and sprite.sprite_frames.get_frame_count(animation_name) > 0:
			sprite.play(animation_name)
			return


func update_wolf_weakness_effect():
	var should_show := should_show_wolf_weakness_effect()
	if effects == null:
		weak_to_wolf_effect_visible = should_show
		return

	if should_show == weak_to_wolf_effect_visible:
		return

	weak_to_wolf_effect_visible = should_show
	if should_show:
		effects.set_effects([WEAK_TO_WOLF_EFFECT])
	else:
		effects.clear_effects()


func should_show_wolf_weakness_effect() -> bool:
	if dead or not visible or not is_hurt_box_enabled():
		return false

	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.has_method("get_current_form_id") and player.get_current_form_id() == &"wolf"
