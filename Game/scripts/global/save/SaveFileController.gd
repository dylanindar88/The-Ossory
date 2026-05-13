class_name SaveFileController
extends RefCounted

var save_manager
var save_path_format_override: String = ""


func setup(owner_save_manager):
	save_manager = owner_save_manager


func set_active_slot(slot: int) -> bool:
	if not is_manual_save_slot(slot):
		save_manager.last_error = "Save slot %d is not a manual save slot." % slot
		return false

	save_manager.active_slot = slot
	save_manager.last_error = ""
	return true


func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= save_manager.SAVE_SLOT_COUNT


func is_manual_save_slot(slot: int) -> bool:
	return slot >= 1 and slot <= save_manager.MANUAL_SAVE_SLOT_COUNT


func is_autosave_slot(slot: int) -> bool:
	return slot == save_manager.AUTOSAVE_SLOT


func get_save_path(slot: int) -> String:
	var path_format: String = save_path_format_override if save_path_format_override != "" else save_manager.SAVE_PATH_FORMAT
	return path_format % clamp(slot, 1, save_manager.SAVE_SLOT_COUNT)


func set_save_path_format_override(path_format: String):
	save_path_format_override = path_format


func clear_save_path_format_override():
	save_path_format_override = ""


func get_save_file_name(slot: int) -> String:
	return "save_slot_%d.json" % clamp(slot, 1, save_manager.SAVE_SLOT_COUNT)


func write_save_data(slot: int, save_data: Dictionary) -> bool:
	var save_path: String = get_save_path(slot)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		save_manager.last_error = "Could not open %s for writing. Error: %s" % [save_path, error_string(FileAccess.get_open_error())]
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	save_manager.last_error = ""
	return true


func load_game(slot: int) -> Dictionary:
	if not is_valid_slot(slot):
		save_manager.last_error = "Save slot %d is outside the supported range." % slot
		return {}

	var save_path: String = get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		save_manager.last_error = "No save file exists for slot %d." % slot
		return {}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		save_manager.last_error = "Could not open %s for reading. Error: %s" % [save_path, error_string(FileAccess.get_open_error())]
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		save_manager.last_error = "Save file %s is not valid JSON save data." % save_path
		return {}

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != save_manager.SAVE_VERSION:
		save_manager.last_error = "Save file %s uses an unsupported version." % save_path
		return {}

	save_manager.last_error = ""
	return data


func delete_save(slot: int) -> bool:
	if not is_valid_slot(slot):
		save_manager.last_error = "Save slot %d is outside the supported range." % slot
		return false

	if not save_exists(slot):
		save_manager.last_error = ""
		return true

	var save_path: String = get_save_path(slot)
	var save_dir_path: String = save_path.get_base_dir() if save_path_format_override != "" else "user://"
	var save_file_name: String = save_path.get_file() if save_path_format_override != "" else get_save_file_name(slot)
	var dir: DirAccess = DirAccess.open(save_dir_path)
	if dir == null:
		save_manager.last_error = "Could not open the user save directory."
		return false

	var error: Error = dir.remove(save_file_name)
	if error != OK:
		save_manager.last_error = "Could not delete save slot %d. Error: %s" % [slot, error_string(error)]
		return false

	save_manager.last_error = ""
	return true


func save_exists(slot: int) -> bool:
	return is_valid_slot(slot) and FileAccess.file_exists(get_save_path(slot))


func get_slot_summary(slot: int) -> Dictionary:
	var summary: Dictionary = {
		"slot": slot,
		"exists": false,
		"saved_at_datetime": "",
		"timestamp_text": "",
		"level_path": "",
		"reason": "",
		"display_name": "Autosave" if is_autosave_slot(slot) else "Slot %d" % slot,
	}

	if not save_exists(slot):
		return summary

	var data: Dictionary = load_game(slot)
	if data.is_empty():
		return summary

	summary["exists"] = true
	var saved_at_datetime: String = str(data.get("saved_at_datetime", ""))
	var level_path: String = str(data.get("level_path", ""))
	var level_state: Dictionary = save_manager.get_level_state_from_save_data(data, level_path)
	summary["saved_at_datetime"] = saved_at_datetime
	summary["timestamp_text"] = saved_at_datetime
	summary["level_path"] = level_path
	summary["reason"] = str(data.get("reason", ""))
	summary["display_name"] = save_manager.get_save_display_name(level_path, level_state, data.get("quest_states", {}))
	return summary
