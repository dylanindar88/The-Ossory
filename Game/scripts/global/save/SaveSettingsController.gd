class_name SaveSettingsController
extends RefCounted

var save_manager


func setup(owner_save_manager):
	save_manager = owner_save_manager


func load_settings():
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(save_manager.SETTINGS_PATH)
	if error != OK:
		save_manager.show_hud_gauges = true
		save_manager.show_player_gauges = true
		return

	save_manager.show_hud_gauges = bool(config.get_value("ui", save_manager.SETTING_SHOW_HUD_GAUGES, true))
	save_manager.show_player_gauges = bool(config.get_value("ui", save_manager.SETTING_SHOW_PLAYER_GAUGES, true))
	save_manager.default_camera_zoom = clamp(float(config.get_value("ui", save_manager.SETTING_DEFAULT_CAMERA_ZOOM, 2.25)), 1.75, 3.0)
	if not save_manager.show_hud_gauges and not save_manager.show_player_gauges:
		save_manager.show_hud_gauges = true
		save_manager.show_player_gauges = true


func save_settings():
	var config: ConfigFile = ConfigFile.new()
	config.set_value("ui", save_manager.SETTING_SHOW_HUD_GAUGES, save_manager.show_hud_gauges)
	config.set_value("ui", save_manager.SETTING_SHOW_PLAYER_GAUGES, save_manager.show_player_gauges)
	config.set_value("ui", save_manager.SETTING_DEFAULT_CAMERA_ZOOM, save_manager.default_camera_zoom)
	config.save(save_manager.SETTINGS_PATH)


func get_gauge_display_settings() -> Dictionary:
	return {
		"show_hud_gauges": save_manager.show_hud_gauges,
		"show_player_gauges": save_manager.show_player_gauges,
	}


func set_gauge_display_settings(show_hud: bool, show_player: bool):
	if not show_hud and not show_player:
		return

	if save_manager.show_hud_gauges == show_hud and save_manager.show_player_gauges == show_player:
		return

	save_manager.show_hud_gauges = show_hud
	save_manager.show_player_gauges = show_player
	save_settings()
	save_manager.gauge_display_settings_changed.emit(save_manager.show_hud_gauges, save_manager.show_player_gauges)


func get_default_camera_zoom() -> float:
	return save_manager.default_camera_zoom


func set_default_camera_zoom(value: float):
	var clean_value: float = clamp(value, 1.75, 3.0)
	if is_equal_approx(save_manager.default_camera_zoom, clean_value):
		return

	save_manager.default_camera_zoom = clean_value
	save_settings()
