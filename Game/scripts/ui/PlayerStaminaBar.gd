extends TextureProgressBar

const GAUGE_STAMINA := "stamina"
const GAUGE_TRANSFORMATION := "transformation"
const COOLDOWN_ROW_GAP := 4.0

@onready var stamina_container: Node2D = get_parent() as Node2D
@onready var player_node: Node = stamina_container.get_parent()
@onready var health_node: Node = player_node.get_node_or_null("Health")
@onready var template_border: TextureRect = stamina_container.get_node_or_null("StaminaBarBorder") as TextureRect

var showing_transformation_timer: bool = false
var stamina_progress_texture: Texture2D
var transformation_progress_texture: Texture2D
var cooldown_progress_texture: Texture2D
var under_texture: Texture2D
var border_texture: Texture2D
var stamina_current: float = 0.0
var stamina_max: float = 0.0
var transformation_current: float = 0.0
var transformation_max: float = 0.0
var cooldown_current: float = 0.0
var cooldown_max: float = 0.0
var cooldown_active: bool = false
var row_spacing: float = 16.0

var template_bar_left: float = 0.0
var template_bar_top: float = 0.0
var template_bar_right: float = 0.0
var template_bar_bottom: float = 0.0
var template_border_left: float = 0.0
var template_border_top: float = 0.0
var template_border_right: float = 0.0
var template_border_bottom: float = 0.0
var template_border_scale: Vector2 = Vector2.ONE
var template_border_texture_filter: int = CanvasItem.TEXTURE_FILTER_PARENT_NODE

var stamina_row: Node2D
var stamina_bar: TextureProgressBar
var stamina_gauge_border: TextureRect
var transformation_row: Node2D
var transformation_bar: TextureProgressBar
var transformation_gauge_border: TextureRect


func _ready():
	stamina_container.visible = false
	cache_template_values()
	transformation_progress_texture = create_transformation_progress_texture()
	cooldown_progress_texture = create_cooldown_progress_texture()
	hide_template_nodes()

	if health_node != null:
		stamina_max = health_node.max_stamina
		stamina_current = health_node.stamina

		if not health_node.stamina_changed.is_connected(_on_stamina_changed):
			health_node.stamina_changed.connect(_on_stamina_changed)

	if player_node.has_signal("transformation_timer_changed"):
		var timer_callback: Callable = Callable(self, "_on_transformation_timer_changed")
		if not player_node.is_connected("transformation_timer_changed", timer_callback):
			player_node.connect("transformation_timer_changed", timer_callback)

	if player_node.has_signal("transformation_cooldown_changed"):
		var cooldown_callback: Callable = Callable(self, "_on_transformation_cooldown_changed")
		if not player_node.is_connected("transformation_cooldown_changed", cooldown_callback):
			player_node.connect("transformation_cooldown_changed", cooldown_callback)

	call_deferred("finish_gauge_setup")


func finish_gauge_setup():
	create_gauge_rows()
	update_display()


func _on_stamina_changed(current_stamina: float, max_stamina: float):
	stamina_current = current_stamina
	stamina_max = max_stamina
	if not showing_transformation_timer:
		update_display()


func _on_transformation_timer_changed(current_time: float, max_time: float, active: bool):
	showing_transformation_timer = active
	transformation_current = current_time
	transformation_max = max_time
	update_display()


func _on_transformation_cooldown_changed(current: float, max_cooldown: float, active: bool):
	cooldown_current = current
	cooldown_max = max_cooldown
	cooldown_active = active
	if not showing_transformation_timer:
		update_display()


func update_display():
	if not has_gauge_rows():
		stamina_container.visible = false
		return

	var visible_gauges: Array[String] = []

	if showing_transformation_timer:
		configure_gauge_bar(transformation_bar, transformation_current, transformation_max, transformation_progress_texture)
		visible_gauges.append(GAUGE_TRANSFORMATION)
	else:
		var stamina_visible := stamina_max > 0.0 and stamina_current < stamina_max
		var cooldown_visible := cooldown_active and cooldown_max > 0.0

		if stamina_visible:
			configure_gauge_bar(stamina_bar, stamina_current, stamina_max, stamina_progress_texture)
			visible_gauges.append(GAUGE_STAMINA)

		if cooldown_visible:
			configure_gauge_bar(transformation_bar, cooldown_current, cooldown_max, cooldown_progress_texture)
			visible_gauges.append(GAUGE_TRANSFORMATION)

	set_visible_gauges(visible_gauges)


func set_visible_gauges(visible_gauges: Array[String]):
	if not has_gauge_rows():
		stamina_container.visible = false
		return

	stamina_container.visible = not visible_gauges.is_empty()
	stamina_row.visible = false
	transformation_row.visible = false

	for index in range(visible_gauges.size()):
		var gauge_id: String = visible_gauges[index]
		var row := get_gauge_row(gauge_id)
		if row == null:
			continue

		row.position = Vector2(0.0, float(index) * row_spacing)
		row.visible = true


func get_gauge_row(gauge_id: String) -> Node2D:
	if gauge_id == GAUGE_STAMINA:
		return stamina_row
	if gauge_id == GAUGE_TRANSFORMATION:
		return transformation_row

	return null


func configure_gauge_bar(bar: TextureProgressBar, current: float, max_amount: float, progress_texture: Texture2D):
	if bar == null:
		return

	bar.min_value = 0.0
	bar.max_value = max_amount
	bar.value = current
	bar.texture_progress = progress_texture


func has_gauge_rows() -> bool:
	return stamina_row != null and transformation_row != null


func cache_template_values():
	stamina_progress_texture = texture_progress
	under_texture = texture_under
	template_bar_left = offset_left
	template_bar_top = offset_top
	template_bar_right = offset_right
	template_bar_bottom = offset_bottom

	if template_border == null:
		row_spacing = template_bar_bottom - template_bar_top + COOLDOWN_ROW_GAP
		return

	border_texture = template_border.texture
	template_border_left = template_border.offset_left
	template_border_top = template_border.offset_top
	template_border_right = template_border.offset_right
	template_border_bottom = template_border.offset_bottom
	template_border_scale = template_border.scale
	template_border_texture_filter = template_border.texture_filter

	var border_height: float = (template_border_bottom - template_border_top) * template_border_scale.y
	var bar_height: float = template_bar_bottom - template_bar_top
	row_spacing = maxf(border_height, bar_height) + COOLDOWN_ROW_GAP


func create_gauge_rows():
	stamina_row = create_gauge_row("StaminaGauge", stamina_progress_texture)
	stamina_bar = stamina_row.get_node("Bar") as TextureProgressBar
	stamina_gauge_border = stamina_row.get_node("Border") as TextureRect

	transformation_row = create_gauge_row("TransformationGauge", cooldown_progress_texture)
	transformation_bar = transformation_row.get_node("Bar") as TextureProgressBar
	transformation_gauge_border = transformation_row.get_node("Border") as TextureRect


func create_gauge_row(row_name: String, progress_texture: Texture2D) -> Node2D:
	var row := Node2D.new()
	row.name = row_name
	row.visible = false
	stamina_container.add_child(row)

	var bar := TextureProgressBar.new()
	bar.name = "Bar"
	bar.z_as_relative = true
	bar.z_index = 1
	bar.offset_left = template_bar_left
	bar.offset_top = template_bar_top
	bar.offset_right = template_bar_right
	bar.offset_bottom = template_bar_bottom
	bar.rounded = rounded
	bar.nine_patch_stretch = nine_patch_stretch
	bar.texture_under = under_texture
	bar.texture_progress = progress_texture
	row.add_child(bar)

	var border := TextureRect.new()
	border.name = "Border"
	border.z_as_relative = true
	border.z_index = 2
	border.offset_left = template_border_left
	border.offset_top = template_border_top
	border.offset_right = template_border_right
	border.offset_bottom = template_border_bottom
	border.scale = template_border_scale
	border.texture_filter = template_border_texture_filter
	border.texture = border_texture
	row.add_child(border)

	return row


func hide_template_nodes():
	visible = false
	if template_border != null:
		template_border.visible = false


func create_transformation_progress_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.45, 0.0, 0.02, 1.0),
		Color(0.9, 0.05, 0.05, 1.0),
		Color(1.0, 0.32, 0.12, 1.0),
	])

	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 44
	return gradient_texture


func create_cooldown_progress_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.55, 0.12, 0.0, 1.0),
		Color(0.95, 0.36, 0.04, 1.0),
		Color(1.0, 0.62, 0.12, 1.0),
	])

	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 44
	return gradient_texture
