@tool
class_name AttackHitboxProfileAuthoring
extends Node

const DEFAULT_CONTEXT := &"default"
const DEFAULT_DIRECTION := &"right"
const MIRRORED_LEFT_DIRECTION := &"left"
const PROFILE_KEYS := ["size", "position", "rotation", "scale"]
const VALID_DIRECTIONS := [&"right", &"left", &"up", &"down", &"default"]

@export_group("Bindings")
@export var hitbox_area_path: NodePath = NodePath("../AttackBox")
@export var collision_shape_path: NodePath = NodePath("../AttackBox/CollisionShape2D")

@export_group("Profile Preview")
@export var preview_enabled: bool = true
@export var allowed_contexts: Array[StringName] = []
@export var selected_context: StringName = DEFAULT_CONTEXT
@export var selected_direction: StringName = DEFAULT_DIRECTION
@export_range(1, 8, 1) var selected_combo_part: int = 1
@export var mirror_left_from_right: bool = true
@export var force_unit_collision_shape_scale: bool = false
@export var normalize_rectangle_scale_into_size: bool = false
@export var profiles: Dictionary = {}

var _last_profile_key: String = ""
var _last_shape_profile: Dictionary = {}
var _last_selected_context: StringName = DEFAULT_CONTEXT
var _last_selected_direction: StringName = DEFAULT_DIRECTION
var _last_selected_combo_part: int = 1
var _applying_profile: bool = false


func _ready():
	if Engine.is_editor_hint():
		set_process(true)
		ensure_selected_profile_exists()
		apply_selected_profile_to_shape()
	else:
		set_process(false)


func _process(_delta: float):
	if not Engine.is_editor_hint() or not preview_enabled:
		return

	var profile_key: String = get_selected_profile_key()
	if profile_key != _last_profile_key:
		commit_visible_shape_to_last_profile()
		ensure_selected_profile_exists()
		apply_selected_profile_to_shape()
		return

	if _applying_profile:
		return

	var current_profile := read_profile_from_shape()
	if current_profile.is_empty():
		return

	if not profiles_are_equal(current_profile, _last_shape_profile):
		write_selected_profile(current_profile)
		_last_shape_profile = read_profile_from_shape()


func get_hitbox_area() -> Area2D:
	var node := get_node_or_null(hitbox_area_path)
	return node as Area2D


func get_collision_shape() -> CollisionShape2D:
	var node := get_node_or_null(collision_shape_path)
	if node is CollisionShape2D:
		return node as CollisionShape2D

	var area := get_hitbox_area()
	if area == null:
		return null

	for child in area.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null


func get_profile_set(context: StringName = DEFAULT_CONTEXT) -> Dictionary:
	var context_profiles := get_context_profiles(context)
	var result := context_profiles.duplicate(true)
	if mirror_left_from_right:
		result[MIRRORED_LEFT_DIRECTION] = build_mirrored_direction_profiles(result.get(DEFAULT_DIRECTION, {}))
	return result


func get_profile(context: StringName, direction: StringName, combo_part: int = 1) -> Dictionary:
	var context_profiles := get_context_profiles(context)
	var direction_name := normalize_direction_for_storage(direction)
	var direction_profiles: Dictionary = context_profiles.get(direction_name, {})
	if direction_profiles.is_empty() and direction_name != DEFAULT_DIRECTION:
		direction_profiles = context_profiles.get(DEFAULT_DIRECTION, {})

	var combo_key := get_combo_key(combo_part)
	var profile: Dictionary = direction_profiles.get(combo_key, {})
	if profile.is_empty():
		profile = direction_profiles.get("1", {})
	if profile.is_empty():
		return {}

	var normalized := profile.duplicate(true)
	if mirror_left_from_right and normalize_direction_for_preview(direction) == MIRRORED_LEFT_DIRECTION:
		normalized = mirror_profile(normalized)
	return normalized


func get_exact_profile(context: StringName, direction: StringName, combo_part: int = 1) -> Dictionary:
	var context_key: StringName = normalize_context_for_storage(context)
	if not profiles.has(context_key) or not (profiles[context_key] is Dictionary):
		return {}

	var context_profiles: Dictionary = profiles[context_key] as Dictionary
	var direction_name: StringName = normalize_direction_for_storage(direction)
	if not context_profiles.has(direction_name) or not (context_profiles[direction_name] is Dictionary):
		return {}

	var direction_profiles: Dictionary = context_profiles[direction_name] as Dictionary
	var profile: Variant = direction_profiles.get(get_combo_key(combo_part), {})
	if not (profile is Dictionary) or (profile as Dictionary).is_empty():
		return {}

	var normalized := (profile as Dictionary).duplicate(true)
	if mirror_left_from_right and normalize_direction_for_preview(direction) == MIRRORED_LEFT_DIRECTION:
		normalized = mirror_profile(normalized)
	return normalized


func get_context_profiles(context: StringName) -> Dictionary:
	var context_key: StringName = normalize_context_for_storage(context)
	if profiles.has(context_key):
		var data: Variant = profiles[context_key]
		if data is Dictionary:
			return (data as Dictionary).duplicate(true)
	if context_key != DEFAULT_CONTEXT and profiles.has(DEFAULT_CONTEXT):
		var fallback_data: Variant = profiles[DEFAULT_CONTEXT]
		if fallback_data is Dictionary:
			return (fallback_data as Dictionary).duplicate(true)
	return {}


func apply_profile_to_shape(context: StringName, direction: StringName, combo_part: int = 1):
	var profile := get_profile(context, direction, combo_part)
	if profile.is_empty():
		return
	apply_profile_dictionary_to_shape(profile)


func apply_selected_profile_to_shape():
	var profile := get_exact_profile(selected_context, selected_direction, selected_combo_part)
	if profile.is_empty():
		return
	_applying_profile = true
	apply_profile_dictionary_to_shape(profile)
	_last_profile_key = get_selected_profile_key()
	_last_shape_profile = read_profile_from_shape()
	_last_selected_context = normalize_context_for_storage(selected_context)
	_last_selected_direction = normalize_direction_for_preview(selected_direction)
	_last_selected_combo_part = selected_combo_part
	_applying_profile = false


func apply_profile_dictionary_to_shape(profile: Dictionary):
	var collision_shape: CollisionShape2D = get_collision_shape()
	if collision_shape == null:
		return

	if collision_shape.shape is RectangleShape2D and profile.has("size"):
		var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
		rectangle.size = profile["size"]
	if profile.has("position"):
		collision_shape.position = profile["position"]
	if profile.has("rotation"):
		collision_shape.rotation = float(profile["rotation"])
	if force_unit_collision_shape_scale:
		collision_shape.scale = Vector2.ONE
	elif profile.has("scale"):
		collision_shape.scale = profile["scale"]


func ensure_selected_profile_exists():
	if not is_selected_profile_writeable():
		return
	if not get_exact_profile(selected_context, selected_direction, selected_combo_part).is_empty():
		return
	var current_profile := read_profile_from_shape()
	if current_profile.is_empty():
		return
	write_selected_profile(current_profile)


func write_selected_profile(profile: Dictionary):
	if not is_selected_profile_writeable():
		return
	write_profile(selected_context, selected_direction, selected_combo_part, profile)


func write_profile(context: StringName, direction: StringName, combo_part: int, profile: Dictionary):
	var context_key: StringName = normalize_context_for_storage(context)
	var direction_key: StringName = normalize_direction_for_storage(direction)
	if not is_context_writeable(context_key) or not is_direction_writeable(direction_key):
		return

	var normalized_profile: Dictionary = normalize_profile_for_storage(profile)
	if mirror_left_from_right and normalize_direction_for_preview(direction) == MIRRORED_LEFT_DIRECTION:
		normalized_profile = mirror_profile(normalized_profile)

	var context_profiles: Dictionary = {}
	if profiles.has(context_key) and profiles[context_key] is Dictionary:
		context_profiles = (profiles[context_key] as Dictionary).duplicate(true)
	var direction_profiles: Dictionary = {}
	if context_profiles.has(direction_key) and context_profiles[direction_key] is Dictionary:
		direction_profiles = (context_profiles[direction_key] as Dictionary).duplicate(true)

	direction_profiles[get_combo_key(combo_part)] = normalized_profile
	context_profiles[direction_key] = direction_profiles
	profiles[context_key] = context_profiles


func commit_visible_shape_to_last_profile():
	if _applying_profile or _last_profile_key == "":
		return
	if not is_context_writeable(_last_selected_context) or not is_direction_writeable(_last_selected_direction):
		return

	var current_profile: Dictionary = read_profile_from_shape()
	if current_profile.is_empty():
		return

	if profiles_are_equal(current_profile, _last_shape_profile):
		return

	write_profile(_last_selected_context, _last_selected_direction, _last_selected_combo_part, current_profile)
	_last_shape_profile = current_profile.duplicate(true)


func read_profile_from_shape() -> Dictionary:
	var collision_shape: CollisionShape2D = get_collision_shape()
	if collision_shape == null:
		return {}
	if not (collision_shape.shape is RectangleShape2D):
		return {}
	if force_unit_collision_shape_scale and collision_shape.scale != Vector2.ONE:
		collision_shape.scale = Vector2.ONE

	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	var profile: Dictionary = {
		"size": rectangle.size,
		"position": collision_shape.position,
		"rotation": collision_shape.rotation,
		"scale": collision_shape.scale,
	}
	return normalize_profile_for_storage(profile)


func normalize_profile_for_storage(profile: Dictionary) -> Dictionary:
	var normalized: Dictionary = profile.duplicate(true)
	if force_unit_collision_shape_scale:
		normalized["scale"] = Vector2.ONE
		return normalized
	if not normalize_rectangle_scale_into_size:
		return normalized
	if not normalized.has("size"):
		return normalized

	var size: Vector2 = normalized["size"]
	var scale: Vector2 = normalized.get("scale", Vector2.ONE)
	normalized["size"] = Vector2(size.x * absf(scale.x), size.y * absf(scale.y))
	normalized["scale"] = Vector2.ONE
	return normalized


func normalize_context_for_storage(context: StringName) -> StringName:
	if str(context) == "":
		return DEFAULT_CONTEXT
	if is_context_writeable(context):
		return context
	var nearest_context: StringName = find_nearest_string_name(context, get_allowed_contexts(), context)
	if is_context_writeable(nearest_context):
		return nearest_context
	return context


func normalize_direction_for_preview(direction: StringName) -> StringName:
	if str(direction) == "":
		return DEFAULT_DIRECTION
	if is_valid_direction(direction):
		return direction
	var nearest_direction: StringName = find_nearest_string_name(direction, VALID_DIRECTIONS, direction)
	if is_valid_direction(nearest_direction):
		return nearest_direction
	return direction


func normalize_direction_for_storage(direction: StringName) -> StringName:
	var preview_direction: StringName = normalize_direction_for_preview(direction)
	if mirror_left_from_right and preview_direction == MIRRORED_LEFT_DIRECTION:
		return DEFAULT_DIRECTION
	return preview_direction


func is_selected_profile_writeable() -> bool:
	return is_context_writeable(selected_context) and is_direction_writeable(selected_direction)


func is_context_writeable(context: StringName) -> bool:
	var context_name: String = str(context)
	if context_name == "":
		return true
	return get_allowed_contexts().has(context)


func is_direction_writeable(direction: StringName) -> bool:
	var direction_name: String = str(direction)
	if direction_name == "":
		return true
	return is_valid_direction(direction)


func is_valid_direction(direction: StringName) -> bool:
	return VALID_DIRECTIONS.has(direction)


func get_allowed_contexts() -> Array[StringName]:
	var contexts: Array[StringName] = []
	for context in allowed_contexts:
		if not contexts.has(context):
			contexts.append(context)
	if contexts.is_empty():
		for key in profiles.keys():
			contexts.append(StringName(str(key)))
	if contexts.is_empty():
		contexts.append(DEFAULT_CONTEXT)
	return contexts


func find_nearest_string_name(value: StringName, candidates: Array, fallback: StringName) -> StringName:
	var raw_value: String = str(value)
	if raw_value == "":
		return fallback

	var best_match: StringName = fallback
	var best_length: int = -1
	for candidate_variant in candidates:
		var candidate := StringName(str(candidate_variant))
		var candidate_text: String = str(candidate)
		if candidate_text.begins_with(raw_value) and raw_value.length() > best_length:
			best_match = candidate
			best_length = raw_value.length()

	return best_match


func build_mirrored_direction_profiles(direction_profiles: Variant) -> Dictionary:
	if not (direction_profiles is Dictionary):
		return {}

	var mirrored := {}
	for combo_key in (direction_profiles as Dictionary).keys():
		var profile: Variant = (direction_profiles as Dictionary)[combo_key]
		if profile is Dictionary:
			mirrored[combo_key] = mirror_profile(profile as Dictionary)
	return mirrored


func mirror_profile(profile: Dictionary) -> Dictionary:
	var mirrored := profile.duplicate(true)
	if mirrored.has("position"):
		var position: Vector2 = mirrored["position"]
		position.x = -position.x
		mirrored["position"] = position
	return mirrored


func get_combo_key(combo_part: int) -> String:
	return str(maxi(combo_part, 1))


func get_selected_profile_key() -> String:
	return "%s:%s:%s" % [
		normalize_context_for_storage(selected_context),
		normalize_direction_for_preview(selected_direction),
		get_combo_key(selected_combo_part),
	]


func profiles_are_equal(first: Dictionary, second: Dictionary) -> bool:
	for key in PROFILE_KEYS:
		if first.get(key) != second.get(key):
			return false
	return true
