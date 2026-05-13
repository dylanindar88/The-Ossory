class_name SaveLevelMetadataController
extends RefCounted

var save_manager


func setup(owner_save_manager):
	save_manager = owner_save_manager


func get_save_display_name(level_path: String, level_state: Dictionary, _saved_quest_states: Variant = {}) -> String:
	var entry: Dictionary = get_level_metadata(level_path)
	if not entry.is_empty():
		var display_name: String = str(entry.get("display_name", get_level_display_name_fallback(level_path)))
		var progression_state_key: String = str(entry.get("progression_state_key", ""))
		var raw_progression_names: Variant = entry.get("progression_names", {})
		if progression_state_key != "" and raw_progression_names is Dictionary:
			var progression_names: Dictionary = raw_progression_names
			var progression_key: String = str(level_state.get(progression_state_key, ""))
			if progression_names.has(progression_key):
				return str(progression_names[progression_key])
		return display_name

	return get_level_display_name_fallback(level_path)


func get_level_metadata(level_path: String) -> Dictionary:
	var raw_entry: Variant = save_manager.LEVEL_DISPLAY_REGISTRY.get(level_path, {})
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		return entry.duplicate(true)

	return {}


func get_current_level_metadata() -> Dictionary:
	return get_level_metadata(save_manager.get_level_path(save_manager.get_current_level()))


func get_level_location_label(level_path: String, include_index: bool = false) -> String:
	var metadata: Dictionary = get_level_metadata(level_path)
	var display_name: String = str(metadata.get("display_name", get_level_display_name_fallback(level_path)))
	if include_index:
		var level_index: int = int(metadata.get("level_index", 0))
		if level_index > 0:
			return "%02d - %s" % [level_index, display_name]

	return display_name


func get_level_display_name_fallback(level_path: String) -> String:
	if level_path == "":
		return "Unknown Location"

	var file_name: String = level_path.get_file().get_basename()
	if file_name == "":
		return level_path

	return file_name.capitalize()


func get_title_dev_level_entries() -> Array:
	var entries: Array = []
	for level_path in save_manager.LEVEL_DISPLAY_REGISTRY.keys():
		var raw_entry: Variant = save_manager.LEVEL_DISPLAY_REGISTRY[level_path]
		if not (raw_entry is Dictionary):
			continue

		var entry: Dictionary = raw_entry
		var raw_presets: Variant = entry.get("dev_presets", [])
		if not (raw_presets is Array):
			continue

		entries.append({
			"scene_path": str(level_path),
			"level_index": int(entry.get("level_index", 0)),
			"display_name": get_level_location_label(str(level_path), true),
			"dev_presets": raw_presets,
		})

	entries.sort_custom(Callable(self, "sort_dev_level_entry_by_index"))
	return entries


func sort_dev_level_entry_by_index(a: Dictionary, b: Dictionary) -> bool:
	var a_index: int = int(a.get("level_index", 0))
	var b_index: int = int(b.get("level_index", 0))
	if a_index == b_index:
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))

	return a_index < b_index
