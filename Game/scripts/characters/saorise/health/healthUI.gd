@tool
extends Control

const HEALTH_BAR_COLOR = preload("res://scripts/ui/HealthBarColor.gd")
const STOCK_ICON_FRAME_SECONDS := 0.28
const STOCK_ICON_SPENT_ALPHA := 0.25
const STOCK_ICON_SIZE := Vector2(16.0, 16.0)
const STOCK_ICON_CLUSTER_CENTER := Vector2(24.0, 24.0)
const STOCK_ICON_RADIUS := 16.0

@export_range(1.0, 30.0, 0.5) var stock_center_fps: float = 8.0

@onready var health_bar: TextureProgressBar = $HealthBar
@onready var stamina_gauge: Control = $HudStaminaGauge
@onready var stamina_bar: TextureProgressBar = $HudStaminaGauge/Bar
@onready var wolf_gauge: Control = $HudWolfGauge
@onready var wolf_bar: TextureProgressBar = $HudWolfGauge/Bar
@onready var stock_icon_cluster: Control = $StockIconCluster
@onready var stock_center: TextureRect = $StockIconCluster/StockCenter

var health_node: Node
var player: Node
var stamina_progress_texture: Texture2D
var transformation_progress_texture: Texture2D
var cooldown_progress_texture: Texture2D
var gauge_under_texture: Texture2D
var stamina_current: float = 0.0
var stamina_max: float = 0.0
var transformation_current: float = 0.0
var transformation_max: float = 0.0
var cooldown_current: float = 0.0
var cooldown_max: float = 0.0
var showing_transformation_timer: bool = false
var cooldown_active: bool = false
var stock_icons: Array[TextureRect] = []
var stock_frame_textures: Array[Texture2D] = []
var stock_center_frame_textures: Array[Texture2D] = []
var animated_stock_index: int = -1
var stock_animation_timer: float = 0.0
var stock_animation_frame: int = 0
var stock_center_animation_active: bool = false
var stock_center_animation_timer: float = 0.0
var stock_center_animation_frame: int = 0
var hud_gauges_enabled: bool = true

func _ready():
	set_process(false)
	create_gauge_textures()
	configure_hud_gauge_bars()
	setup_stock_icons(Engine.is_editor_hint())

	if Engine.is_editor_hint():
		setup_editor_preview()
		return

	hud_gauges_enabled = should_show_hud_gauges()
	player = get_tree().get_first_node_in_group("player")

	if player == null:
		update_hud_gauges()
		return

	health_node = player.get_node_or_null("Health")

	if health_node == null:
		update_hud_gauges()
		return

	setup_health_bar()
	setup_hud_gauges()


func _process(delta: float):
	if animated_stock_index >= 0 and stock_frame_textures.size() >= 2:
		stock_animation_timer -= delta
		if stock_animation_timer <= 0.0:
			stock_animation_timer = STOCK_ICON_FRAME_SECONDS
			stock_animation_frame = (stock_animation_frame + 1) % stock_frame_textures.size()
			update_animated_stock_frame()

	if stock_center_animation_active and stock_center_frame_textures.size() >= 2:
		stock_center_animation_timer -= delta
		if stock_center_animation_timer <= 0.0:
			stock_center_animation_timer = get_stock_center_frame_seconds()
			stock_center_animation_frame = (stock_center_animation_frame + 1) % stock_center_frame_textures.size()
			update_stock_center_frame()


func _unhandled_input(event: InputEvent):
	if Engine.is_editor_hint():
		return

	if not is_debug_stock_test_event(event):
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return

	if key_event.keycode == KEY_L:
		cycle_dev_stock_shape()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_K:
		cycle_dev_stock_lives()
		get_viewport().set_input_as_handled()


func setup_health_bar():
	health_bar.min_value = 0
	health_bar.max_value = int(health_node.get("max_health"))
	health_bar.value = int(health_node.get("health"))
	update_health_bar_color()

	var health_callback: Callable = Callable(self, "_on_health_changed")
	if health_node.has_signal("health_changed") and not health_node.is_connected("health_changed", health_callback):
		health_node.connect("health_changed", health_callback)


func setup_hud_gauges():
	stamina_max = float(health_node.get("max_stamina"))
	stamina_current = float(health_node.get("stamina"))

	var stamina_callback: Callable = Callable(self, "_on_stamina_changed")
	if health_node.has_signal("stamina_changed") and not health_node.is_connected("stamina_changed", stamina_callback):
		health_node.connect("stamina_changed", stamina_callback)

	if player.has_signal("transformation_timer_changed"):
		var timer_callback: Callable = Callable(self, "_on_transformation_timer_changed")
		if not player.is_connected("transformation_timer_changed", timer_callback):
			player.connect("transformation_timer_changed", timer_callback)

	if player.has_signal("transformation_cooldown_changed"):
		var cooldown_callback: Callable = Callable(self, "_on_transformation_cooldown_changed")
		if not player.is_connected("transformation_cooldown_changed", cooldown_callback):
			player.connect("transformation_cooldown_changed", cooldown_callback)

	var upgrade_callback: Callable = Callable(self, "_on_upgrade_state_changed")
	if SaveManager != null and SaveManager.has_signal("upgrade_state_changed") and not SaveManager.is_connected("upgrade_state_changed", upgrade_callback):
		SaveManager.connect("upgrade_state_changed", upgrade_callback)

	var gauge_settings_callback: Callable = Callable(self, "_on_gauge_display_settings_changed")
	if SaveManager != null and SaveManager.has_signal("gauge_display_settings_changed") and not SaveManager.is_connected("gauge_display_settings_changed", gauge_settings_callback):
		SaveManager.connect("gauge_display_settings_changed", gauge_settings_callback)

	update_hud_gauges()


func setup_stock_icons(editor_preview: bool = false):
	stock_icons.clear()
	var stock_icon_count: int = 6
	if not editor_preview and SaveManager != null:
		stock_icon_count = int(SaveManager.MAX_PLAYER_LIVES)
	for icon_index in range(1, stock_icon_count + 1):
		var icon: TextureRect = get_node_or_null("StockIconCluster/Stock%d" % icon_index) as TextureRect
		if icon != null:
			stock_icons.append(icon)

	cache_stock_frame_textures()
	cache_stock_center_frame_textures()
	if editor_preview:
		update_stock_icons(3, 3)
		return

	var lives_callback: Callable = Callable(self, "_on_player_lives_changed")
	if SaveManager != null and SaveManager.has_signal("player_lives_changed") and not SaveManager.is_connected("player_lives_changed", lives_callback):
		SaveManager.connect("player_lives_changed", lives_callback)

	var current_lives: int = 0
	var max_lives: int = stock_icons.size()
	if SaveManager != null:
		if SaveManager.has_method("get_player_lives"):
			current_lives = SaveManager.get_player_lives()
		if SaveManager.has_method("get_max_player_lives"):
			max_lives = SaveManager.get_max_player_lives()
		else:
			max_lives = int(SaveManager.MAX_PLAYER_LIVES)
	update_stock_icons(current_lives, max_lives)


func setup_editor_preview():
	hud_gauges_enabled = true
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	update_health_bar_color()

	if stamina_gauge != null:
		stamina_gauge.visible = true
	configure_hud_gauge_bar(stamina_bar, 1.0, 1.0, stamina_progress_texture)

	if wolf_gauge != null:
		wolf_gauge.visible = true
	configure_hud_gauge_bar(wolf_bar, 1.0, 1.0, cooldown_progress_texture)


func _on_health_changed(current_health: int, max_health: int):
	health_bar.max_value = max_health
	health_bar.value = current_health
	update_health_bar_color()


func _on_stamina_changed(current_stamina: float, max_stamina: float):
	stamina_current = current_stamina
	stamina_max = max_stamina
	update_hud_gauges()


func _on_transformation_timer_changed(current_time: float, max_time: float, active: bool):
	showing_transformation_timer = active
	transformation_current = current_time
	transformation_max = max_time
	update_hud_gauges()


func _on_transformation_cooldown_changed(current: float, max_cooldown: float, active: bool):
	cooldown_current = current
	cooldown_max = max_cooldown
	cooldown_active = active
	update_hud_gauges()


func _on_upgrade_state_changed():
	update_hud_gauges()


func _on_gauge_display_settings_changed(show_hud_gauges: bool, _show_player_gauges: bool):
	hud_gauges_enabled = show_hud_gauges
	update_hud_gauges()


func _on_player_lives_changed(current_lives: int, max_lives: int):
	update_stock_icons(current_lives, max_lives)


func update_health_bar_color():
	HEALTH_BAR_COLOR.apply_to_bar(health_bar, float(health_bar.value), float(health_bar.max_value))


func configure_hud_gauge_bars():
	configure_static_bar(stamina_bar, stamina_progress_texture)
	configure_static_bar(wolf_bar, cooldown_progress_texture)


func configure_static_bar(bar: TextureProgressBar, progress_texture: Texture2D):
	if bar == null:
		return

	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.rounded = true
	bar.nine_patch_stretch = true
	bar.texture_under = gauge_under_texture
	bar.texture_progress = progress_texture


func update_hud_gauges():
	if not hud_gauges_enabled:
		if stamina_gauge != null:
			stamina_gauge.visible = false
		if wolf_gauge != null:
			wolf_gauge.visible = false
		return

	update_stamina_gauge()
	update_wolf_gauge()


func update_stock_icons(current_lives: int, max_lives: int):
	if stock_icon_cluster == null:
		return

	var visible_stock_count: int = mini(maxi(max_lives, 0), stock_icons.size())
	var active_stock_count: int = mini(maxi(current_lives, 0), visible_stock_count)
	stock_icon_cluster.visible = visible_stock_count > 0
	animated_stock_index = active_stock_count - 1
	stock_animation_timer = STOCK_ICON_FRAME_SECONDS
	stock_animation_frame = 0
	update_stock_center_icon(active_stock_count, visible_stock_count)

	for index in range(stock_icons.size()):
		var icon: TextureRect = stock_icons[index]
		icon.visible = index < visible_stock_count
		if icon.visible:
			icon.position = get_stock_icon_position(visible_stock_count, index)
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if index < active_stock_count else STOCK_ICON_SPENT_ALPHA)
		if not stock_frame_textures.is_empty():
			icon.texture = stock_frame_textures[0]

	update_animated_stock_frame()
	update_stock_process()


func get_stock_icon_position(visible_stock_count: int, index: int) -> Vector2:
	var start_angle: float = -PI * 0.5
	var angle: float = start_angle + TAU * float(index) / float(maxi(visible_stock_count, 1))
	return STOCK_ICON_CLUSTER_CENTER + Vector2(cos(angle), sin(angle)) * STOCK_ICON_RADIUS - STOCK_ICON_SIZE * 0.5


func is_debug_stock_test_event(event: InputEvent) -> bool:
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return false

	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return false

	return (
		key_event.pressed
		and not key_event.echo
		and key_event.ctrl_pressed
		and key_event.shift_pressed
		and (key_event.keycode == KEY_L or key_event.keycode == KEY_K)
	)


func cycle_dev_stock_shape():
	if SaveManager == null or not SaveManager.has_method("set_stat_level"):
		return

	var stat_levels: Dictionary = {}
	if SaveManager.has_method("get_upgrade_stat_levels"):
		stat_levels = SaveManager.get_upgrade_stat_levels()
	var current_health_level: int = int(stat_levels.get("health", 0))
	var next_health_level: int = (current_health_level + 1) % 4
	SaveManager.set_stat_level(&"health", next_health_level)
	if SaveManager.has_method("set_player_lives_for_dev") and SaveManager.has_method("get_max_player_lives"):
		SaveManager.set_player_lives_for_dev(SaveManager.get_max_player_lives())


func cycle_dev_stock_lives():
	if SaveManager == null or not SaveManager.has_method("set_player_lives_for_dev") or not SaveManager.has_method("get_max_player_lives"):
		return

	var current_lives: int = 0
	if SaveManager.has_method("get_player_lives"):
		current_lives = SaveManager.get_player_lives()
	if current_lives <= 0:
		SaveManager.set_player_lives_for_dev(SaveManager.get_max_player_lives())
	else:
		SaveManager.set_player_lives_for_dev(current_lives - 1)


func cache_stock_frame_textures():
	stock_frame_textures.clear()
	if stock_icons.is_empty():
		return

	var first_texture: Texture2D = stock_icons[0].texture
	if first_texture is AtlasTexture:
		var first_frame: AtlasTexture = first_texture as AtlasTexture
		var atlas_texture: Texture2D = first_frame.atlas
		var frame_region: Rect2 = first_frame.region
		for frame_index in range(2):
			var frame_texture: AtlasTexture = AtlasTexture.new()
			frame_texture.atlas = atlas_texture
			frame_texture.region = Rect2(frame_region.position + Vector2(frame_region.size.x * float(frame_index), 0.0), frame_region.size)
			stock_frame_textures.append(frame_texture)
		return

	stock_frame_textures.append(first_texture)


func cache_stock_center_frame_textures():
	stock_center_frame_textures.clear()
	if stock_center == null or stock_center.texture == null:
		return

	var first_texture: Texture2D = stock_center.texture
	if first_texture is AtlasTexture:
		var first_frame: AtlasTexture = first_texture as AtlasTexture
		var atlas_texture: Texture2D = first_frame.atlas
		var frame_region: Rect2 = Rect2(Vector2.ZERO, first_frame.region.size)
		var frame_count: int = maxi(1, int(floor(float(atlas_texture.get_width()) / frame_region.size.x)))
		for frame_index in range(frame_count):
			var frame_texture: AtlasTexture = AtlasTexture.new()
			frame_texture.atlas = atlas_texture
			frame_texture.region = Rect2(frame_region.position + Vector2(frame_region.size.x * float(frame_index), 0.0), frame_region.size)
			stock_center_frame_textures.append(frame_texture)
		return

	stock_center_frame_textures.append(first_texture)


func update_animated_stock_frame():
	if animated_stock_index < 0 or animated_stock_index >= stock_icons.size() or stock_frame_textures.is_empty():
		return

	var icon: TextureRect = stock_icons[animated_stock_index]
	if icon.visible:
		icon.texture = stock_frame_textures[stock_animation_frame]


func update_stock_center_icon(active_stock_count: int, visible_stock_count: int):
	if stock_center == null:
		return

	stock_center.visible = visible_stock_count > 0
	stock_center.position = STOCK_ICON_CLUSTER_CENTER - STOCK_ICON_SIZE * 0.5
	stock_center_animation_active = active_stock_count > 0
	stock_center_animation_timer = get_stock_center_frame_seconds()
	stock_center_animation_frame = 0
	stock_center.modulate = Color(1.0, 1.0, 1.0, 1.0 if stock_center_animation_active else STOCK_ICON_SPENT_ALPHA)
	update_stock_center_frame()


func update_stock_center_frame():
	if stock_center == null or stock_center_frame_textures.is_empty():
		return

	var frame_index: int = stock_center_animation_frame if stock_center_animation_active else 0
	stock_center.texture = stock_center_frame_textures[frame_index]


func update_stock_process():
	var stock_icon_animating: bool = animated_stock_index >= 0 and stock_frame_textures.size() > 1
	var stock_center_animating: bool = stock_center_animation_active and stock_center_frame_textures.size() > 1
	set_process(stock_icon_animating or stock_center_animating)


func get_stock_center_frame_seconds() -> float:
	return 1.0 / maxf(stock_center_fps, 1.0)


func update_stamina_gauge():
	if stamina_gauge == null or stamina_bar == null:
		return

	stamina_gauge.visible = true
	configure_hud_gauge_bar(stamina_bar, stamina_current, stamina_max, stamina_progress_texture)


func update_wolf_gauge():
	if wolf_gauge == null or wolf_bar == null:
		return

	var wolf_unlocked: bool = has_wolf_transformation_upgrade()
	wolf_gauge.visible = wolf_unlocked
	if not wolf_unlocked:
		return

	if showing_transformation_timer and transformation_max > 0.0:
		configure_hud_gauge_bar(wolf_bar, transformation_current, transformation_max, transformation_progress_texture)
	elif cooldown_active and cooldown_max > 0.0:
		configure_hud_gauge_bar(wolf_bar, cooldown_current, cooldown_max, cooldown_progress_texture)
	else:
		configure_hud_gauge_bar(wolf_bar, 1.0, 1.0, cooldown_progress_texture)


func configure_hud_gauge_bar(bar: TextureProgressBar, current: float, max_amount: float, progress_texture: Texture2D):
	if bar == null:
		return

	var safe_max: float = maxf(max_amount, 1.0)
	bar.min_value = 0.0
	bar.max_value = safe_max
	bar.value = clamp(current, 0.0, safe_max)
	bar.texture_progress = progress_texture


func has_wolf_transformation_upgrade() -> bool:
	if SaveManager == null or not SaveManager.has_method("get_upgrade_state"):
		return false

	var upgrade_state: Dictionary = SaveManager.get_upgrade_state()
	var unlocked: Variant = upgrade_state.get("unlocked", {})
	return unlocked is Dictionary and bool(unlocked.get("wolf_transformation", false))


func create_gauge_textures():
	stamina_progress_texture = create_stamina_progress_texture()
	transformation_progress_texture = create_transformation_progress_texture()
	cooldown_progress_texture = create_cooldown_progress_texture()
	gauge_under_texture = create_under_texture()


func create_under_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.609195])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 1)])

	var gradient_texture: GradientTexture2D = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 139
	return gradient_texture


func create_stamina_progress_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.00574713, 0.494253, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.0470588, 0.313726, 1.0, 1.0),
		Color(0.0470588, 0.780392, 1.0, 1.0),
		Color(0.282353, 1.0, 0.870588, 1.0),
	])

	var gradient_texture: GradientTexture2D = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 139
	return gradient_texture


func create_transformation_progress_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.45, 0.0, 0.02, 1.0),
		Color(0.9, 0.05, 0.05, 1.0),
		Color(1.0, 0.32, 0.12, 1.0),
	])

	var gradient_texture: GradientTexture2D = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 139
	return gradient_texture


func create_cooldown_progress_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.55, 0.12, 0.0, 1.0),
		Color(0.95, 0.36, 0.04, 1.0),
		Color(1.0, 0.62, 0.12, 1.0),
	])

	var gradient_texture: GradientTexture2D = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 139
	return gradient_texture


func should_show_hud_gauges() -> bool:
	if SaveManager != null and SaveManager.has_method("get_gauge_display_settings"):
		var settings: Dictionary = SaveManager.get_gauge_display_settings()
		return bool(settings.get("show_hud_gauges", true))

	return true
