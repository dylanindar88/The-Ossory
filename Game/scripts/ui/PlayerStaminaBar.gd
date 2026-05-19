@tool
extends Node2D

const GAUGE_STAMINA := "stamina"
const GAUGE_TRANSFORMATION := "transformation"

@export var gauge_preview_settings: PlayerGaugePreviewSettings:
	set(value):
		gauge_preview_settings = value
		refresh_editor_preview_if_needed()

@onready var player_node: Node = get_parent()
@onready var health_node: Node = player_node.get_node_or_null("Health") if player_node != null else null
@onready var gauge_stack: Control = $PlayerGaugeStack
@onready var stamina_row: Control = $PlayerGaugeStack/StaminaGauge
@onready var stamina_bar: TextureProgressBar = $PlayerGaugeStack/StaminaGauge/Bar
@onready var transformation_row: Control = $PlayerGaugeStack/TransformationGauge
@onready var transformation_bar: TextureProgressBar = $PlayerGaugeStack/TransformationGauge/Bar

var showing_transformation_timer: bool = false
var stamina_progress_texture: Texture2D
var transformation_progress_texture: Texture2D
var cooldown_progress_texture: Texture2D
var stamina_current: float = 0.0
var stamina_max: float = 0.0
var transformation_current: float = 0.0
var transformation_max: float = 0.0
var cooldown_current: float = 0.0
var cooldown_max: float = 0.0
var cooldown_active: bool = false
var player_gauges_enabled: bool = true


func _ready():
	if Engine.is_editor_hint():
		call_deferred("setup_editor_preview")
		return

	visible = false
	player_gauges_enabled = should_show_player_gauges()
	cache_gauge_textures()

	if health_node != null:
		stamina_max = health_node.max_stamina
		stamina_current = health_node.stamina

		if not health_node.stamina_changed.is_connected(_on_stamina_changed):
			health_node.stamina_changed.connect(_on_stamina_changed)

	if player_node != null and player_node.has_signal("transformation_timer_changed"):
		var timer_callback: Callable = Callable(self, "_on_transformation_timer_changed")
		if not player_node.is_connected("transformation_timer_changed", timer_callback):
			player_node.connect("transformation_timer_changed", timer_callback)

	if player_node != null and player_node.has_signal("transformation_cooldown_changed"):
		var cooldown_callback: Callable = Callable(self, "_on_transformation_cooldown_changed")
		if not player_node.is_connected("transformation_cooldown_changed", cooldown_callback):
			player_node.connect("transformation_cooldown_changed", cooldown_callback)

	if SaveManager != null and SaveManager.has_signal("gauge_display_settings_changed"):
		var settings_callback: Callable = Callable(self, "_on_gauge_display_settings_changed")
		if not SaveManager.is_connected("gauge_display_settings_changed", settings_callback):
			SaveManager.connect("gauge_display_settings_changed", settings_callback)

	update_display()


func setup_editor_preview():
	cache_gauge_textures()
	visible = true
	if stamina_row != null:
		stamina_row.visible = should_show_stamina_preview()
		configure_gauge_bar(stamina_bar, get_stamina_preview_value(), get_preview_max_value(), stamina_progress_texture)
	if transformation_row != null:
		transformation_row.visible = should_show_transformation_preview()
		configure_gauge_bar(transformation_bar, get_wolf_preview_value(), get_preview_max_value(), get_wolf_preview_texture())
	apply_visible_gauge_positions([GAUGE_STAMINA, GAUGE_TRANSFORMATION], true)


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


func _on_gauge_display_settings_changed(_show_hud_gauges: bool, show_player_gauges: bool):
	player_gauges_enabled = show_player_gauges
	update_display()


func update_display():
	if not player_gauges_enabled:
		visible = false
		return

	if not has_gauge_rows():
		visible = false
		return

	cache_gauge_textures()
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
		visible = false
		return

	visible = not visible_gauges.is_empty()
	stamina_row.visible = false
	transformation_row.visible = false
	apply_visible_gauge_positions(visible_gauges, false)


func apply_visible_gauge_positions(visible_gauges: Array[String], editor_preview: bool):
	var row_index := 0
	for gauge_id in visible_gauges:
		var row := get_gauge_row(gauge_id)
		if row == null:
			continue
		if editor_preview and gauge_id == GAUGE_STAMINA and not should_show_stamina_preview():
			continue
		if editor_preview and gauge_id == GAUGE_TRANSFORMATION and not should_show_transformation_preview():
			continue

		row.position.y = float(row_index) * get_row_spacing()
		row.visible = true
		row_index += 1


func get_gauge_row(gauge_id: String) -> Control:
	if gauge_id == GAUGE_STAMINA:
		return stamina_row
	if gauge_id == GAUGE_TRANSFORMATION:
		return transformation_row
	return null


func configure_gauge_bar(bar: TextureProgressBar, current: float, max_amount: float, progress_texture: Texture2D):
	if bar == null:
		return

	var safe_max: float = maxf(max_amount, 1.0)
	bar.min_value = get_preview_min_value() if Engine.is_editor_hint() else 0.0
	bar.max_value = safe_max
	bar.step = get_preview_step() if Engine.is_editor_hint() else bar.step
	bar.value = clamp(current, 0.0, safe_max)
	if progress_texture != null:
		bar.texture_progress = progress_texture


func has_gauge_rows() -> bool:
	return stamina_row != null and transformation_row != null and stamina_bar != null and transformation_bar != null


func cache_gauge_textures():
	if stamina_progress_texture == null and stamina_bar != null:
		stamina_progress_texture = stamina_bar.texture_progress
	if transformation_progress_texture == null:
		transformation_progress_texture = create_transformation_progress_texture()
	if cooldown_progress_texture == null and transformation_bar != null:
		cooldown_progress_texture = transformation_bar.texture_progress


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
	gradient_texture.width = 139
	return gradient_texture


func should_show_player_gauges() -> bool:
	if SaveManager != null and SaveManager.has_method("get_gauge_display_settings"):
		var settings: Dictionary = SaveManager.get_gauge_display_settings()
		return bool(settings.get("show_player_gauges", true))

	return true


func refresh_editor_preview_if_needed():
	if Engine.is_editor_hint() and is_inside_tree():
		call_deferred("setup_editor_preview")


func get_preview_min_value() -> float:
	return gauge_preview_settings.preview_min_value if gauge_preview_settings != null else 0.0


func get_preview_max_value() -> float:
	return gauge_preview_settings.preview_max_value if gauge_preview_settings != null else 100.0


func get_preview_step() -> float:
	return gauge_preview_settings.preview_step if gauge_preview_settings != null else 1.0


func get_stamina_preview_value() -> float:
	return gauge_preview_settings.stamina_preview_value if gauge_preview_settings != null else 65.0


func get_wolf_preview_value() -> float:
	if gauge_preview_settings == null:
		return 45.0
	if gauge_preview_settings.wolf_preview_mode == "transformation":
		return gauge_preview_settings.transformation_preview_value
	if gauge_preview_settings.wolf_preview_mode == "full":
		return gauge_preview_settings.preview_max_value
	return gauge_preview_settings.cooldown_preview_value


func get_wolf_preview_texture() -> Texture2D:
	if gauge_preview_settings != null and gauge_preview_settings.wolf_preview_mode == "transformation":
		return transformation_progress_texture
	return cooldown_progress_texture


func should_show_stamina_preview() -> bool:
	return gauge_preview_settings == null or gauge_preview_settings.show_stamina_preview


func should_show_transformation_preview() -> bool:
	return gauge_preview_settings == null or gauge_preview_settings.show_transformation_preview


func get_row_spacing() -> float:
	return gauge_preview_settings.row_spacing if gauge_preview_settings != null else 28.0
