extends Label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if SaveManager != null and SaveManager.has_signal("current_level_changed"):
		var callback := Callable(self, "_on_current_level_changed")
		if not SaveManager.is_connected("current_level_changed", callback):
			SaveManager.connect("current_level_changed", callback)

	refresh_location()


func refresh_location():
	if SaveManager == null or not SaveManager.has_method("get_level_location_label"):
		visible = false
		return

	var level_path: String = SaveManager.get_level_path(SaveManager.get_current_level())
	var location_name: String = SaveManager.get_level_location_label(level_path, false)
	text = location_name
	visible = location_name != ""


func _on_current_level_changed(_level_path: String, _metadata: Dictionary):
	refresh_location()
