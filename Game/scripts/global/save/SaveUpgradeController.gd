class_name SaveUpgradeController
extends RefCounted

var save_manager


func setup(owner_save_manager):
	save_manager = owner_save_manager


func get_player_lives() -> int:
	return save_manager.player_lives


func get_max_player_lives() -> int:
	var health_level: int = int(get_upgrade_stat_levels().get("health", 0))
	return clamp(save_manager.BASE_PLAYER_LIVES + health_level, save_manager.BASE_PLAYER_LIVES, save_manager.MAX_PLAYER_LIVES)


func reset_player_lives():
	save_manager.player_lives = get_max_player_lives()
	save_manager.player_lives_changed.emit(save_manager.player_lives, get_max_player_lives())


func set_player_lives_for_dev(lives: int):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	save_manager.player_lives = clamp(lives, 0, get_max_player_lives())
	save_manager.player_lives_changed.emit(save_manager.player_lives, get_max_player_lives())


func reset_upgrade_state():
	var previous_max_lives: int = get_max_player_lives()
	save_manager.upgrade_state = get_default_upgrade_state()
	reconcile_player_lives_after_max_change(previous_max_lives, false)
	save_manager.upgrade_state_changed.emit()


func get_default_upgrade_state() -> Dictionary:
	return {
		"unlocked": {
			"attack": true,
			"health": true,
			"stamina": true,
			"dash_count": true,
		},
		"stat_levels": {},
		"equipped_weapon_id": "unarmed",
	}


func unlock_upgrade(upgrade_id: StringName) -> bool:
	var id: String = str(upgrade_id)
	if id == "":
		return false

	var unlocked: Dictionary = get_upgrade_unlocked()
	if bool(unlocked.get(id, false)):
		return false

	unlocked[id] = true
	save_manager.upgrade_state["unlocked"] = unlocked
	save_manager.upgrade_state_changed.emit()
	return true


func lock_upgrade(upgrade_id: StringName) -> bool:
	var id: String = str(upgrade_id)
	if id == "":
		return false

	var changed: bool = false
	var unlocked: Dictionary = get_upgrade_unlocked()
	if unlocked.has(id):
		unlocked.erase(id)
		save_manager.upgrade_state["unlocked"] = unlocked
		changed = true

	var stat_levels: Dictionary = get_upgrade_stat_levels()
	if stat_levels.has(id):
		stat_levels.erase(id)
		save_manager.upgrade_state["stat_levels"] = stat_levels
		changed = true

	if changed:
		save_manager.upgrade_state_changed.emit()
	return changed


func set_stat_level(stat_id: StringName, level: int) -> bool:
	var id: String = str(stat_id)
	if id == "":
		return false

	var previous_max_lives: int = get_max_player_lives()
	var stat_levels: Dictionary = get_upgrade_stat_levels()
	var clean_level: int = maxi(level, 0)
	if int(stat_levels.get(id, 0)) == clean_level:
		return false

	stat_levels[id] = clean_level
	save_manager.upgrade_state["stat_levels"] = stat_levels
	if id == "health":
		reconcile_player_lives_after_max_change(previous_max_lives, true)
	save_manager.upgrade_state_changed.emit()
	return true


func get_upgrade_state() -> Dictionary:
	return save_manager.upgrade_state.duplicate(true)


func apply_upgrade_state(data: Variant):
	var previous_max_lives: int = get_max_player_lives()
	var default_state: Dictionary = get_default_upgrade_state()
	if data is Dictionary:
		var source: Dictionary = data
		var saved_unlocked: Variant = source.get("unlocked", {})
		if saved_unlocked is Dictionary:
			var merged_unlocked: Dictionary = default_state["unlocked"]
			for upgrade_id in saved_unlocked.keys():
				merged_unlocked[str(upgrade_id)] = bool(saved_unlocked[upgrade_id])
			default_state["unlocked"] = merged_unlocked
		default_state["stat_levels"] = source.get("stat_levels", {})
		default_state["equipped_weapon_id"] = str(source.get("equipped_weapon_id", "unarmed"))

	save_manager.upgrade_state = default_state
	reconcile_player_lives_after_max_change(previous_max_lives, false)
	save_manager.upgrade_state_changed.emit()


func reconcile_player_lives_after_max_change(previous_max_lives: int, grant_new_lives: bool):
	var current_max_lives: int = get_max_player_lives()
	if grant_new_lives and current_max_lives > previous_max_lives:
		save_manager.player_lives += current_max_lives - previous_max_lives

	save_manager.player_lives = clamp(save_manager.player_lives, 0, current_max_lives)
	save_manager.player_lives_changed.emit(save_manager.player_lives, current_max_lives)


func get_upgrade_unlocked() -> Dictionary:
	var unlocked: Variant = save_manager.upgrade_state.get("unlocked", {})
	if unlocked is Dictionary:
		return unlocked

	return {}


func get_upgrade_stat_levels() -> Dictionary:
	var stat_levels: Variant = save_manager.upgrade_state.get("stat_levels", {})
	if stat_levels is Dictionary:
		return stat_levels

	return {}
