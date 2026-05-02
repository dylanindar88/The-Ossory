class_name EffectList
extends Node2D

const DEFAULT_EFFECT_SPRITE_FRAMES: SpriteFrames = preload("res://resources/icons/effects.tres")

@export var effect_sprite_frames: SpriteFrames = DEFAULT_EFFECT_SPRITE_FRAMES
@export var icon_spacing: float = 18.0
@export var icon_scale: Vector2 = Vector2(0.5, 0.5)
@export var always_visible_z_index: int = 100

var effect_sprites: Dictionary = {}


func _ready():
	apply_always_visible_rendering()
	set_effects([])


func set_effects(active_effects: Array[String], controlled_frames: Dictionary = {}):
	var active_lookup: Dictionary = {}
	var visible_effects: Array[String] = []

	for anim_name in active_effects:
		if effect_sprite_frames != null and effect_sprite_frames.has_animation(anim_name):
			visible_effects.append(anim_name)

	visible = not visible_effects.is_empty()
	var list_width: float = float(visible_effects.size() - 1) * icon_spacing

	for index in range(visible_effects.size()):
		var anim_name: String = visible_effects[index]
		var effect_sprite: AnimatedSprite2D = get_effect_sprite(anim_name)

		active_lookup[anim_name] = true
		effect_sprite.position = Vector2(index * icon_spacing - list_width * 0.5, 0)
		effect_sprite.visible = true

		if controlled_frames.has(anim_name):
			set_controlled_effect_frame(effect_sprite, anim_name, int(controlled_frames[anim_name]))
		elif effect_sprite.animation != anim_name or not effect_sprite.is_playing():
			effect_sprite.play(anim_name)

	for anim_name in effect_sprites.keys():
		if active_lookup.has(anim_name):
			continue

		var effect_sprite: AnimatedSprite2D = effect_sprites[anim_name]
		effect_sprite.stop()
		effect_sprite.visible = false


func clear_effects():
	set_effects([])


func set_controlled_effect_frame(effect_sprite: AnimatedSprite2D, anim_name: String, frame_index: int):
	if effect_sprite.animation != anim_name:
		effect_sprite.animation = anim_name

	var frame_count: int = effect_sprite.sprite_frames.get_frame_count(anim_name)
	effect_sprite.stop()
	effect_sprite.frame = clamp(frame_index, 0, max(frame_count - 1, 0))
	effect_sprite.frame_progress = 0.0


func get_effect_sprite(anim_name: String) -> AnimatedSprite2D:
	if effect_sprite_frames == null or not effect_sprite_frames.has_animation(anim_name):
		return null

	if effect_sprites.has(anim_name):
		var existing_effect_sprite: AnimatedSprite2D = effect_sprites[anim_name]
		apply_always_visible_rendering(existing_effect_sprite)
		return existing_effect_sprite

	var effect_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	effect_sprite.sprite_frames = effect_sprite_frames
	effect_sprite.scale = icon_scale
	effect_sprite.visible = false
	apply_always_visible_rendering(effect_sprite)
	add_child(effect_sprite)
	effect_sprites[anim_name] = effect_sprite
	return effect_sprite


func apply_always_visible_rendering(canvas_item: CanvasItem = null):
	if canvas_item == null:
		canvas_item = self

	canvas_item.y_sort_enabled = false
	canvas_item.z_as_relative = false
	canvas_item.z_index = always_visible_z_index
