class_name EffectList
extends Node2D

const DEFAULT_EFFECT_SPRITE_FRAMES: SpriteFrames = preload("res://assets/effect icons/effects.tres")

@export var effect_sprite_frames: SpriteFrames = DEFAULT_EFFECT_SPRITE_FRAMES
@export var icon_spacing: float = 18.0
@export var icon_scale: Vector2 = Vector2(0.5, 0.5)

var effect_sprites: Dictionary = {}


func _ready():
	set_effects([])


func set_effects(active_effects: Array[String]):
	var active_lookup := {}
	visible = not active_effects.is_empty()

	for index in range(active_effects.size()):
		var anim_name: String = active_effects[index]
		var effect_sprite := get_effect_sprite(anim_name)
		if effect_sprite == null:
			continue

		active_lookup[anim_name] = true
		effect_sprite.position = Vector2(0, index * icon_spacing)
		effect_sprite.visible = true

		if effect_sprite.animation != anim_name or not effect_sprite.is_playing():
			effect_sprite.play(anim_name)

	for anim_name in effect_sprites.keys():
		if active_lookup.has(anim_name):
			continue

		var effect_sprite: AnimatedSprite2D = effect_sprites[anim_name]
		effect_sprite.stop()
		effect_sprite.visible = false


func clear_effects():
	set_effects([])


func get_effect_sprite(anim_name: String) -> AnimatedSprite2D:
	if effect_sprite_frames == null or not effect_sprite_frames.has_animation(anim_name):
		return null

	if effect_sprites.has(anim_name):
		return effect_sprites[anim_name]

	var effect_sprite := AnimatedSprite2D.new()
	effect_sprite.sprite_frames = effect_sprite_frames
	effect_sprite.scale = icon_scale
	effect_sprite.visible = false
	add_child(effect_sprite)
	effect_sprites[anim_name] = effect_sprite
	return effect_sprite
