extends Control

const SLOT_TYPE_STAT := "stat"
const SLOT_TYPE_GOD_ABILITY := "god_ability"
const SLOT_TYPE_WEAPON := "weapon"

@export var slot_id: StringName
@export_enum("stat", "god_ability", "weapon") var slot_type: String = SLOT_TYPE_STAT
@export var icon_animation: StringName = &""
@export var unlocked: bool = false
@export var level: int = 0
@export var max_level: int = 0
@export var segment_count: int = 0
@export var radius: float = 48.0
@export var border_width: float = 6.0
@export var icon_frames: SpriteFrames

@onready var icon: AnimatedSprite2D = $Icon

var empty_fill_color: Color = Color(0.03, 0.025, 0.025, 0.68)
var empty_border_color: Color = Color(0.44, 0.38, 0.3, 0.85)
var unlocked_border_color: Color = Color(0.82, 0.73, 0.49, 0.95)
var active_segment_color: Color = Color(0.28, 0.9, 0.46, 1.0)


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	refresh()


func configure(data: Dictionary):
	slot_id = StringName(str(data.get("slot_id", slot_id)))
	slot_type = str(data.get("slot_type", slot_type))
	icon_animation = StringName(str(data.get("icon_animation", icon_animation)))
	max_level = int(data.get("max_level", max_level))
	segment_count = int(data.get("segment_count", segment_count))
	radius = float(data.get("radius", radius))
	border_width = float(data.get("border_width", border_width))
	if data.has("icon_frames") and data["icon_frames"] is SpriteFrames:
		icon_frames = data["icon_frames"]
	refresh()


func apply_upgrade_state(upgrade_state: Dictionary):
	var unlocked_entries: Dictionary = get_dictionary(upgrade_state.get("unlocked", {}))
	var stat_levels: Dictionary = get_dictionary(upgrade_state.get("stat_levels", {}))
	var key: String = str(slot_id)

	unlocked = bool(unlocked_entries.get(key, false))
	level = clamp(int(stat_levels.get(key, 0)), 0, max_level)
	refresh()


func refresh():
	if icon == null:
		return

	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	icon.position = size * 0.5
	icon.visible = unlocked and icon_frames != null and icon_animation != &""
	icon.sprite_frames = icon_frames

	if icon.visible and icon.sprite_frames.has_animation(icon_animation):
		icon.play(icon_animation)
		rescale_icon()
	else:
		icon.stop()
		icon.visible = false

	queue_redraw()


func rescale_icon():
	var frame_texture: Texture2D = icon.sprite_frames.get_frame_texture(icon_animation, 0)
	if frame_texture == null:
		icon.scale = Vector2.ONE
		return

	var frame_size: Vector2 = frame_texture.get_size()
	var max_size: float = radius * 1.25
	var largest_axis: float = max(frame_size.x, frame_size.y)
	if largest_axis <= 0.0:
		icon.scale = Vector2.ONE
		return

	var scale_value: float = min(max_size / largest_axis, 1.0)
	icon.scale = Vector2(scale_value, scale_value)


func _draw():
	var center: Vector2 = size * 0.5
	draw_circle(center, radius - border_width * 0.5, empty_fill_color)

	var base_color: Color = unlocked_border_color if unlocked else empty_border_color
	if segment_count <= 1:
		draw_arc(center, radius - border_width * 0.5, 0.0, TAU, 96, base_color, border_width, true)
		return

	draw_segmented_border(center, base_color)


func draw_segmented_border(center: Vector2, base_color: Color):
	var draw_radius: float = radius - border_width * 0.5
	var gap: float = deg_to_rad(7.0)
	var segment_arc: float = TAU / float(segment_count)
	var lit_segments: int = clamp(level, 0, segment_count)

	for index in range(segment_count):
		var start_angle: float = -PI * 0.5 + segment_arc * index + gap * 0.5
		var end_angle: float = start_angle + segment_arc - gap
		var color: Color = active_segment_color if unlocked and index < lit_segments else base_color
		draw_arc(center, draw_radius, start_angle, end_angle, 32, color, border_width, true)


func get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value

	return {}
