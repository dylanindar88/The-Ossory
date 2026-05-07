extends Node

signal upgrade_state_changed
signal player_lives_changed(current_lives: int, max_lives: int)
signal gauge_display_settings_changed(show_hud_gauges: bool, show_player_gauges: bool)

const SAVE_VERSION := 1
const MANUAL_SAVE_SLOT_COUNT := 3
const AUTOSAVE_SLOT := 4
const SAVE_SLOT_COUNT := 4
const SAVE_PATH_FORMAT := "user://save_slot_%d.json"
const SETTINGS_PATH := "user://settings.cfg"
const SETTING_SHOW_HUD_GAUGES := "show_hud_gauges"
const SETTING_SHOW_PLAYER_GAUGES := "show_player_gauges"
const SETTING_DEFAULT_CAMERA_ZOOM := "default_camera_zoom"
const BASE_PLAYER_LIVES := 3
const MAX_PLAYER_LIVES := 6
const LIFE_LOSS_EXTRA_INVULNERABILITY_TIME := 0.5
const PENDING_SCENE_LOAD_AUTOSAVE_BLOCKER := "pending_scene_load"
const NEW_GAME_AUTOSAVE_BLOCKER := "new_game"
const QUEST_BANSHEE_WORLD := "banshee_world"
const QUEST_BANSHEE_VILLAGE_BISHOP := "banshee_village_bishop"
const QUEST_STAGE_NOT_AVAILABLE := "not_available"
const QUEST_STAGE_REQUEST_AVAILABLE := "request_available"
const QUEST_STAGE_ACCEPTED := "accepted"
const QUEST_STAGE_BISHOP_DEFEATED := "bishop_defeated"
const QUEST_STAGE_READY_TO_REPORT := "ready_to_report"
const QUEST_STAGE_REPORTED := "reported"
const QUEST_STAGE_REWARD_CLAIMED := "reward_claimed"
const BANSHEE_VARIANT_CORRUPTED_MELEE := "corrupted_melee"
const BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED := "corrupted_strong_ranged"
const BANSHEE_VILLAGE_SCENE := "res://scenes/levels/BansheeVillage.tscn"
const INITIAL_SPAWN_SCENE := "res://scenes/levels/InitialSpawn.tscn"
const LEVEL_DISPLAY_REGISTRY := {
	BANSHEE_VILLAGE_SCENE: {
		"display_name": "Banshee Village",
		"progression_state_key": "quest_stage",
		"progression_names": {
			"intro": "Banshee Village Arrival",
			"combat_active": "First Banshee Hunt",
			"ready_to_report": "First Hunt Report",
			"dulluhan_available": "Dulluhan Meeting",
			"report_complete": "Second Banshee Hunt",
			"wolf_hunt_ready": "Wolf Hunt Available",
			"wolf_hunt_cleared": "Second Hunt Report",
			"final_dulluhan_ready": "Vincent House Lead",
			"vincent_house_available": "Vincent House",
			"third_wave_elder_ready": "Third Hunt Available",
			"third_wave_active": "Third Banshee Hunt",
			"third_wave_cleared": "Bishop Request",
			"bishop_path_ready": "Bishop Path Ready",
		},
		"dev_presets": [
			{"label": "Start", "preset": "start"},
			{"label": "First Report", "preset": "first_banshee_report_ready"},
			{"label": "Second Report", "preset": "second_banshee_report_ready"},
			{"label": "Third Report", "preset": "third_banshee_report_ready"},
		],
	},
	INITIAL_SPAWN_SCENE: {
		"display_name": "Initial Spawn",
		"progression_state_key": "",
		"progression_names": {},
		"dev_presets": [
			{"label": "Start", "preset": ""},
		],
	},
}

var show_hud_gauges: bool = true
var show_player_gauges: bool = true
var default_camera_zoom: float = 2.25
var active_slot: int = 1
var autosave_slot: int = AUTOSAVE_SLOT
var player_lives: int = BASE_PLAYER_LIVES
var save_allowed: bool = true
var save_blockers: Dictionary = {}
var save_write_blockers: Dictionary = {}
var autosave_suppressed: bool = false
var autosave_blockers: Dictionary = {}
var current_level: Node
var last_error: String = ""
var story_flags: Dictionary = {}
var quest_states: Dictionary = {}
var level_states_by_path: Dictionary = {}
var pending_scene_load_slot: int = -1
var pending_scene_load_scene_path: String = ""
var pending_scene_load_preserve_story_flags: bool = false
var pending_scene_load_save_reason: String = ""
var pending_scene_load_entry_marker_path: NodePath
var respawn_load_pending: bool = false
var pending_new_game_slot: int = -1
var pending_dev_start_scene_path: String = ""
var pending_dev_start_preset: String = ""
var upgrade_state: Dictionary = {
	"unlocked": {
		"attack": true,
		"health": true,
		"stamina": true,
		"dash_count": true,
	},
	"stat_levels": {},
	"equipped_weapon_id": "unarmed",
}


func _ready():
	load_settings()


func load_settings():
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(SETTINGS_PATH)
	if error != OK:
		show_hud_gauges = true
		show_player_gauges = true
		return

	show_hud_gauges = bool(config.get_value("ui", SETTING_SHOW_HUD_GAUGES, true))
	show_player_gauges = bool(config.get_value("ui", SETTING_SHOW_PLAYER_GAUGES, true))
	default_camera_zoom = clamp(float(config.get_value("ui", SETTING_DEFAULT_CAMERA_ZOOM, 2.25)), 1.75, 3.0)
	if not show_hud_gauges and not show_player_gauges:
		show_hud_gauges = true
		show_player_gauges = true


func save_settings():
	var config: ConfigFile = ConfigFile.new()
	config.set_value("ui", SETTING_SHOW_HUD_GAUGES, show_hud_gauges)
	config.set_value("ui", SETTING_SHOW_PLAYER_GAUGES, show_player_gauges)
	config.set_value("ui", SETTING_DEFAULT_CAMERA_ZOOM, default_camera_zoom)
	config.save(SETTINGS_PATH)


func get_gauge_display_settings() -> Dictionary:
	return {
		"show_hud_gauges": show_hud_gauges,
		"show_player_gauges": show_player_gauges,
	}


func set_gauge_display_settings(show_hud: bool, show_player: bool):
	if not show_hud and not show_player:
		return

	if show_hud_gauges == show_hud and show_player_gauges == show_player:
		return

	show_hud_gauges = show_hud
	show_player_gauges = show_player
	save_settings()
	gauge_display_settings_changed.emit(show_hud_gauges, show_player_gauges)


func get_default_camera_zoom() -> float:
	return default_camera_zoom


func set_default_camera_zoom(value: float):
	var clean_value: float = clamp(value, 1.75, 3.0)
	if is_equal_approx(default_camera_zoom, clean_value):
		return

	default_camera_zoom = clean_value
	save_settings()


func set_active_slot(slot: int) -> bool:
	if not is_manual_save_slot(slot):
		last_error = "Save slot %d is not a manual save slot." % slot
		return false

	active_slot = slot
	last_error = ""
	return true


func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SAVE_SLOT_COUNT


func is_manual_save_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MANUAL_SAVE_SLOT_COUNT


func is_autosave_slot(slot: int) -> bool:
	return slot == AUTOSAVE_SLOT


func get_player_lives() -> int:
	return player_lives


func get_max_player_lives() -> int:
	var health_level: int = int(get_upgrade_stat_levels().get("health", 0))
	return clamp(BASE_PLAYER_LIVES + health_level, BASE_PLAYER_LIVES, MAX_PLAYER_LIVES)


func reset_player_lives():
	player_lives = get_max_player_lives()
	player_lives_changed.emit(player_lives, get_max_player_lives())


func set_player_lives_for_dev(lives: int):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	player_lives = clamp(lives, 0, get_max_player_lives())
	player_lives_changed.emit(player_lives, get_max_player_lives())


func reset_upgrade_state():
	var previous_max_lives: int = get_max_player_lives()
	upgrade_state = get_default_upgrade_state()
	reconcile_player_lives_after_max_change(previous_max_lives, false)
	upgrade_state_changed.emit()


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
	upgrade_state["unlocked"] = unlocked
	upgrade_state_changed.emit()
	return true


func lock_upgrade(upgrade_id: StringName) -> bool:
	var id: String = str(upgrade_id)
	if id == "":
		return false

	var changed: bool = false
	var unlocked: Dictionary = get_upgrade_unlocked()
	if unlocked.has(id):
		unlocked.erase(id)
		upgrade_state["unlocked"] = unlocked
		changed = true

	var stat_levels: Dictionary = get_upgrade_stat_levels()
	if stat_levels.has(id):
		stat_levels.erase(id)
		upgrade_state["stat_levels"] = stat_levels
		changed = true

	if changed:
		upgrade_state_changed.emit()
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
	upgrade_state["stat_levels"] = stat_levels
	if id == "health":
		reconcile_player_lives_after_max_change(previous_max_lives, true)
	upgrade_state_changed.emit()
	return true


func get_upgrade_state() -> Dictionary:
	return upgrade_state.duplicate(true)


func set_story_flag(flag_name: String, enabled: bool):
	if flag_name == "":
		return

	if enabled:
		story_flags[flag_name] = true
	else:
		story_flags.erase(flag_name)


func get_story_flag(flag_name: String) -> bool:
	return bool(story_flags.get(flag_name, false))


func get_story_flags() -> Dictionary:
	return story_flags.duplicate(true)


func apply_story_flags(data: Variant):
	story_flags.clear()
	if not (data is Dictionary):
		return

	var source: Dictionary = data
	for flag_name in source.keys():
		story_flags[str(flag_name)] = bool(source[flag_name])


func get_default_quest_state(stage: String = QUEST_STAGE_NOT_AVAILABLE) -> Dictionary:
	return {
		"stage": stage,
		"flags": {},
	}


func get_quest_state(quest_id: String) -> Dictionary:
	var raw_state: Variant = quest_states.get(quest_id, {})
	if raw_state is Dictionary:
		var source: Dictionary = raw_state
		var flags: Dictionary = {}
		var raw_flags: Variant = source.get("flags", {})
		if raw_flags is Dictionary:
			flags = raw_flags.duplicate(true)
		return {
			"stage": str(source.get("stage", QUEST_STAGE_NOT_AVAILABLE)),
			"flags": flags,
		}

	return get_default_quest_state()


func set_quest_state(quest_id: String, state: Dictionary):
	if quest_id == "":
		return

	var flags: Dictionary = {}
	var raw_flags: Variant = state.get("flags", {})
	if raw_flags is Dictionary:
		flags = raw_flags.duplicate(true)
	quest_states[quest_id] = {
		"stage": str(state.get("stage", QUEST_STAGE_NOT_AVAILABLE)),
		"flags": flags,
	}


func get_quest_stage(quest_id: String) -> String:
	return str(get_quest_state(quest_id).get("stage", QUEST_STAGE_NOT_AVAILABLE))


func set_quest_stage(quest_id: String, stage: String):
	var state: Dictionary = get_quest_state(quest_id)
	state["stage"] = stage
	set_quest_state(quest_id, state)


func get_quest_flag(quest_id: String, flag_name: String) -> bool:
	var state: Dictionary = get_quest_state(quest_id)
	var flags: Dictionary = state.get("flags", {})
	return bool(flags.get(flag_name, false))


func set_quest_flag(quest_id: String, flag_name: String, enabled: bool):
	if flag_name == "":
		return

	var state: Dictionary = get_quest_state(quest_id)
	var flags: Dictionary = state.get("flags", {})
	if enabled:
		flags[flag_name] = true
	else:
		flags.erase(flag_name)
	state["flags"] = flags
	set_quest_state(quest_id, state)


func get_quest_states() -> Dictionary:
	return quest_states.duplicate(true)


func apply_quest_states(data: Variant):
	quest_states.clear()
	if not (data is Dictionary):
		return

	var source: Dictionary = data
	for quest_id in source.keys():
		var raw_state: Variant = source[quest_id]
		if raw_state is Dictionary:
			set_quest_state(str(quest_id), raw_state)


func set_banshee_world_rule(rule_name: String, value: Variant):
	if rule_name == "":
		return

	var state: Dictionary = get_quest_state(QUEST_BANSHEE_WORLD)
	var flags: Dictionary = state.get("flags", {})
	flags[rule_name] = value
	state["flags"] = flags
	set_quest_state(QUEST_BANSHEE_WORLD, state)


func get_banshee_world_rules() -> Dictionary:
	var flags: Dictionary = get_quest_state(QUEST_BANSHEE_WORLD).get("flags", {})
	var variant: String = str(flags.get("combat_variant", BANSHEE_VARIANT_CORRUPTED_MELEE))
	if variant != BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED:
		variant = BANSHEE_VARIANT_CORRUPTED_MELEE

	return {
		"banshees_hostile_enabled": bool(flags.get("banshees_hostile_enabled", false)),
		"player_can_damage_banshees": bool(flags.get("player_can_damage_banshees", false)),
		"wolf_permanent_clear_enabled": bool(flags.get("wolf_permanent_clear_enabled", false)),
		"combat_variant": variant,
	}


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

	upgrade_state = default_state
	reconcile_player_lives_after_max_change(previous_max_lives, false)
	upgrade_state_changed.emit()


func reconcile_player_lives_after_max_change(previous_max_lives: int, grant_new_lives: bool):
	var current_max_lives: int = get_max_player_lives()
	if grant_new_lives and current_max_lives > previous_max_lives:
		player_lives += current_max_lives - previous_max_lives

	player_lives = clamp(player_lives, 0, current_max_lives)
	player_lives_changed.emit(player_lives, current_max_lives)


func get_upgrade_unlocked() -> Dictionary:
	var unlocked: Variant = upgrade_state.get("unlocked", {})
	if unlocked is Dictionary:
		return unlocked

	return {}


func get_upgrade_stat_levels() -> Dictionary:
	var stat_levels: Variant = upgrade_state.get("stat_levels", {})
	if stat_levels is Dictionary:
		return stat_levels

	return {}


func set_save_allowed(allowed: bool):
	save_allowed = allowed


func set_save_blocked(blocker: String, blocked: bool):
	if blocker == "":
		return

	if blocked:
		save_blockers[blocker] = true
	else:
		save_blockers.erase(blocker)


func set_save_write_blocked(blocker: String, blocked: bool):
	if blocker == "":
		return

	if blocked:
		save_write_blockers[blocker] = true
	else:
		save_write_blockers.erase(blocker)


func set_autosave_blocked(blocker: String, blocked: bool):
	if blocker == "":
		return

	if blocked:
		autosave_blockers[blocker] = true
	else:
		autosave_blockers.erase(blocker)


func is_save_allowed() -> bool:
	return save_allowed and save_blockers.is_empty()


func is_save_write_allowed() -> bool:
	return is_save_allowed() and save_write_blockers.is_empty()


func get_save_disabled_message() -> String:
	if save_blockers.has("combat"):
		return "Cannot save during combat"

	if not save_allowed:
		return "Saving is currently disabled."

	if not save_blockers.is_empty():
		return "Saving is currently disabled."

	if not save_write_blockers.is_empty():
		return "Saving is disabled for this dev preset."

	return ""


func autosave_level_entered(level: Node) -> bool:
	current_level = level
	if should_skip_autosave("level_enter"):
		last_error = ""
		return false

	return save_game("level_enter", level)


func autosave_level_exiting(level: Node) -> bool:
	if should_skip_autosave("level_exit"):
		last_error = ""
		return false

	return save_game("level_exit", level)


func save_game(reason: String = "manual", level: Node = null) -> bool:
	return write_save_to_slot(AUTOSAVE_SLOT, reason, level)


func save_game_to_slot(slot: int, reason: String = "manual", level: Node = null) -> bool:
	if not is_manual_save_slot(slot):
		last_error = "Save slot %d is not a manual save slot." % slot
		return false

	var save_succeeded: bool = write_save_to_slot(slot, reason, level)
	if save_succeeded:
		active_slot = slot

	return save_succeeded


func write_save_to_slot(slot: int, reason: String = "manual", level: Node = null) -> bool:
	if is_autosave_slot(slot) and not autosave_blockers.is_empty():
		last_error = ""
		return false

	var blocked_by_death: bool = should_block_player_death_save()
	if blocked_by_death:
		last_error = "" if is_autosave_slot(slot) else "Cannot save while dead."
		return false

	if not is_save_write_allowed():
		last_error = get_save_disabled_message()
		return false

	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return false

	var save_level: Node = level if level != null else get_current_level()
	remember_level_state(save_level)
	var save_path: String = get_save_path(slot)
	var save_data: Dictionary = build_save_data(reason, save_level, slot)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open %s for writing. Error: %s" % [save_path, error_string(FileAccess.get_open_error())]
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	last_error = ""
	return true


func should_block_player_death_save() -> bool:
	if player_lives <= 0:
		return true

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return false

	if player.has_method("is_life_respawn_pending") and bool(player.call("is_life_respawn_pending")):
		return true

	if bool(player.get("dead")):
		return true

	if player is CanvasItem and not (player as CanvasItem).visible:
		return true

	var health_node: Node = player.get_node_or_null("Health")
	if health_node == null:
		return false

	return bool(health_node.get("dead")) or int(health_node.get("health")) <= 0


func change_scene_to_file_and_load(scene_path: String, slot: int = AUTOSAVE_SLOT, preserve_current_story_flags: bool = false, save_after_load_reason: String = "", entry_marker_path: NodePath = NodePath("")) -> Error:
	pending_scene_load_slot = slot
	pending_scene_load_scene_path = scene_path
	pending_scene_load_preserve_story_flags = preserve_current_story_flags
	pending_scene_load_save_reason = save_after_load_reason
	pending_scene_load_entry_marker_path = entry_marker_path
	set_autosave_blocked(PENDING_SCENE_LOAD_AUTOSAVE_BLOCKER, true)

	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		clear_pending_scene_load()
		last_error = "Could not change scene to %s. Error: %s" % [scene_path, error_string(error)]
		return error

	call_deferred("apply_pending_scene_load")
	return OK


func is_scene_load_pending() -> bool:
	return pending_scene_load_slot >= 0


func is_scene_load_pending_for(scene_path: String) -> bool:
	return pending_scene_load_slot >= 0 and scene_path != "" and pending_scene_load_scene_path == scene_path


func is_respawn_load_pending() -> bool:
	return respawn_load_pending or is_scene_load_pending()


func apply_pending_scene_load():
	await get_tree().process_frame
	await get_tree().process_frame

	if pending_scene_load_slot < 0:
		clear_pending_scene_load()
		return

	var preserved_story_flags: Dictionary = story_flags.duplicate(true)
	var preserved_quest_states: Dictionary = quest_states.duplicate(true)
	var load_slot: int = pending_scene_load_slot
	var load_succeeded: bool = load_slot_into_current_level(load_slot)
	if not load_succeeded:
		warn_pending_scene_load_failed(load_slot)
		clear_pending_scene_load()
		respawn_load_pending = false
		return
	if pending_scene_load_preserve_story_flags:
		for flag_name in preserved_story_flags.keys():
			if bool(preserved_story_flags[flag_name]):
				story_flags[str(flag_name)] = true
		for quest_id in preserved_quest_states.keys():
			var raw_state: Variant = preserved_quest_states[quest_id]
			if raw_state is Dictionary:
				set_quest_state(str(quest_id), raw_state)
	apply_pending_scene_entry_marker(get_current_level())

	var save_reason: String = pending_scene_load_save_reason
	clear_pending_scene_load()
	respawn_load_pending = false
	if save_reason != "":
		save_game(save_reason, get_current_level())


func apply_pending_scene_entry_marker(level: Node):
	if level == null or pending_scene_load_entry_marker_path.is_empty():
		return

	var marker: Node2D = level.get_node_or_null(pending_scene_load_entry_marker_path) as Node2D
	if marker == null:
		push_warning("Could not find scene transition entry marker '%s' in %s." % [pending_scene_load_entry_marker_path, level.scene_file_path])
		return

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_warning("Could not place player at scene transition entry marker '%s' because no player was found." % pending_scene_load_entry_marker_path)
		return

	player.global_position = marker.global_position


func clear_pending_scene_load():
	pending_scene_load_slot = -1
	pending_scene_load_scene_path = ""
	pending_scene_load_preserve_story_flags = false
	pending_scene_load_save_reason = ""
	pending_scene_load_entry_marker_path = NodePath("")
	set_autosave_blocked(PENDING_SCENE_LOAD_AUTOSAVE_BLOCKER, false)


func start_new_game(slot: int, start_scene_path: String) -> bool:
	if not is_manual_save_slot(slot):
		last_error = "Save slot %d is not a manual save slot." % slot
		return false
	if start_scene_path == "":
		last_error = "New game start scene is missing."
		return false

	clear_pending_scene_load()
	respawn_load_pending = false
	pending_new_game_slot = slot
	active_slot = slot
	story_flags.clear()
	quest_states.clear()
	level_states_by_path.clear()
	reset_upgrade_state()
	reset_player_lives()
	if CombatStateManager != null and CombatStateManager.has_method("clear_all"):
		CombatStateManager.clear_all()

	set_autosave_blocked(NEW_GAME_AUTOSAVE_BLOCKER, true)
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(start_scene_path)
	if error != OK:
		pending_new_game_slot = -1
		set_autosave_blocked(NEW_GAME_AUTOSAVE_BLOCKER, false)
		last_error = "Could not start new game at %s. Error: %s" % [start_scene_path, error_string(error)]
		return false

	call_deferred("apply_pending_new_game_save")
	last_error = ""
	return true


func apply_pending_new_game_save():
	await get_tree().process_frame
	await get_tree().process_frame

	var slot: int = pending_new_game_slot
	pending_new_game_slot = -1
	set_autosave_blocked(NEW_GAME_AUTOSAVE_BLOCKER, false)
	if not is_manual_save_slot(slot):
		return

	var level: Node = get_current_level()
	save_game_to_slot(slot, "new_game", level)
	save_game("new_game", level)


func remember_level_state(level: Node):
	var level_path: String = get_level_path(level)
	if level_path == "":
		return

	level_states_by_path[level_path] = collect_level_state(level)


func prepare_current_level_for_route_exit():
	for provider in get_level_state_providers(get_current_level()):
		if provider.has_method("prepare_for_route_exit"):
			provider.call("prepare_for_route_exit")


func get_saved_level_state_for_path(level_path: String, fallback_state: Dictionary = {}) -> Dictionary:
	var raw_state: Variant = level_states_by_path.get(level_path, fallback_state)
	if raw_state is Dictionary:
		var typed_state: Dictionary = raw_state
		return typed_state.duplicate(true)

	return fallback_state.duplicate(true)


func apply_level_states_by_path(data: Variant, saved_level_path: String = "", legacy_level_state: Variant = {}):
	level_states_by_path.clear()
	if data is Dictionary:
		var source: Dictionary = data
		for level_path in source.keys():
			var raw_state: Variant = source[level_path]
			if raw_state is Dictionary:
				var typed_state: Dictionary = raw_state
				level_states_by_path[str(level_path)] = typed_state.duplicate(true)

	if saved_level_path != "" and legacy_level_state is Dictionary and not level_states_by_path.has(saved_level_path):
		var typed_legacy_state: Dictionary = legacy_level_state
		level_states_by_path[saved_level_path] = typed_legacy_state.duplicate(true)


func get_level_state_for_current_load(current_level_path: String, saved_level_path: String, legacy_level_state: Variant) -> Dictionary:
	var current_state: Dictionary = get_saved_level_state_for_path(current_level_path)
	if not current_state.is_empty():
		return current_state

	var saved_state: Dictionary = get_saved_level_state_for_path(saved_level_path)
	if not saved_state.is_empty():
		return saved_state

	if legacy_level_state is Dictionary:
		var typed_legacy_state: Dictionary = legacy_level_state
		if not typed_legacy_state.is_empty():
			return typed_legacy_state.duplicate(true)

	return {}


func has_saved_scene_local_state(saved_level_path: String, legacy_level_state: Variant) -> bool:
	if saved_level_path != "" and not get_saved_level_state_for_path(saved_level_path).is_empty():
		return true

	if legacy_level_state is Dictionary:
		var typed_legacy_state: Dictionary = legacy_level_state
		return not typed_legacy_state.is_empty()

	return false


func warn_level_state_load_mismatch(current_level_path: String, saved_level_path: String):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	var available_paths: Array = level_states_by_path.keys()
	push_warning("Could not resolve local level state for current scene '%s' while loading save for '%s'. Available saved level paths: %s." % [current_level_path, saved_level_path, available_paths])


func warn_pending_scene_load_failed(slot: int):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	var load_error: String = last_error
	var data: Dictionary = load_game(slot)
	var saved_level_path: String = str(data.get("level_path", ""))
	var current_level_path: String = get_level_path(get_current_level())
	var saved_quest_stage: String = get_quest_stage_from_state(get_level_state_from_save_data(data, saved_level_path))
	last_error = load_error
	push_warning("Pending save load failed for slot %d. Saved scene: '%s'. Current scene: '%s'. Saved quest_stage: '%s'. Error: %s" % [slot, saved_level_path, current_level_path, saved_quest_stage, load_error])


func get_level_state_source_for_current_load(current_level_path: String, saved_level_path: String, legacy_level_state: Variant) -> String:
	if current_level_path != "" and not get_saved_level_state_for_path(current_level_path).is_empty():
		return "current_scene_path"
	if saved_level_path != "" and not get_saved_level_state_for_path(saved_level_path).is_empty():
		return "saved_scene_path"
	if legacy_level_state is Dictionary:
		var typed_legacy_state: Dictionary = legacy_level_state
		if not typed_legacy_state.is_empty():
			return "legacy_level_state"
	return "empty"


func get_quest_stage_from_state(state: Dictionary) -> String:
	if state.has("quest_stage"):
		return str(state.get("quest_stage", ""))

	var raw_provider_states: Variant = state.get("_providers", {})
	if state.has("_providers") and raw_provider_states is Dictionary:
		var provider_states: Dictionary = raw_provider_states
		for provider_key in provider_states.keys():
			var raw_provider_state: Variant = provider_states[provider_key]
			if raw_provider_state is Dictionary and raw_provider_state.has("quest_stage"):
				return str(raw_provider_state.get("quest_stage", ""))

	return ""


func warn_level_state_restore_source(slot: int, current_level_path: String, saved_level_path: String, source: String, state: Dictionary):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	print_verbose("Applying save slot %d local state from %s. Saved scene: '%s'. Current scene: '%s'. quest_stage: '%s'." % [slot, source, saved_level_path, current_level_path, get_quest_stage_from_state(state)])


func verify_level_state_after_apply(level: Node, expected_state: Dictionary, slot: int, source: String) -> bool:
	var expected_stage: String = get_quest_stage_from_state(expected_state)
	if expected_stage == "" or expected_stage == "intro":
		return true

	var applied_state: Dictionary = collect_level_state(level)
	var applied_stage: String = get_quest_stage_from_state(applied_state)
	if applied_stage == expected_stage:
		return true

	if OS.is_debug_build() or Engine.is_editor_hint():
		push_warning("Save slot %d local state did not stick after apply. Source: %s. Expected quest_stage '%s', got '%s'." % [slot, source, expected_stage, applied_stage])
	last_error = "Save data did not restore the saved level progression."
	return false


func set_pending_dev_start(scene_path: String, preset: String = ""):
	pending_dev_start_scene_path = scene_path
	pending_dev_start_preset = preset


func consume_pending_dev_start_preset(scene_path: String) -> String:
	if pending_dev_start_scene_path == "":
		return ""
	if scene_path != "" and pending_dev_start_scene_path != scene_path:
		return ""

	var preset: String = pending_dev_start_preset
	pending_dev_start_scene_path = ""
	pending_dev_start_preset = ""
	return preset


func start_dev_scene(scene_path: String, preset: String = "") -> bool:
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return false
	if scene_path == "":
		last_error = "Dev start scene is missing."
		return false

	set_pending_dev_start(scene_path, preset)
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		set_pending_dev_start("", "")
		last_error = "Could not start dev scene %s. Error: %s" % [scene_path, error_string(error)]
		return false

	last_error = ""
	return true


func load_slot_into_current_level(slot: int) -> bool:
	var data: Dictionary = load_game(slot)
	if data.is_empty():
		return false

	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return false

	var load_succeeded: bool = apply_save_to_current_level(data)
	if load_succeeded and is_manual_save_slot(slot):
		set_active_slot(slot)

	return load_succeeded


func get_most_recent_save_slot(include_autosave: bool = true) -> int:
	var newest_slot: int = -1
	var newest_time: float = -1.0
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		if not include_autosave and is_autosave_slot(slot):
			continue
		if not save_exists(slot):
			continue

		var data: Dictionary = load_game(slot)
		if data.is_empty():
			continue

		var saved_at_unix: float = float(data.get("saved_at_unix", 0.0))
		if newest_slot < 0 or saved_at_unix > newest_time:
			newest_slot = slot
			newest_time = saved_at_unix

	if newest_slot >= 0:
		last_error = ""

	return newest_slot


func load_save_slot_from_any_level(slot: int) -> bool:
	var data: Dictionary = load_game(slot)
	if data.is_empty():
		return false

	var saved_level_path: String = str(data.get("level_path", ""))
	var current_level_path: String = get_level_path(get_current_level())
	if saved_level_path != "" and saved_level_path != current_level_path:
		return change_scene_to_file_and_load(saved_level_path, slot) == OK

	return load_slot_into_current_level(slot)


func load_most_recent_save(include_autosave: bool = true) -> bool:
	var slot: int = get_most_recent_save_slot(include_autosave)
	if slot < 0:
		last_error = "No save file exists."
		return false

	respawn_load_pending = true
	var load_succeeded: bool = load_save_slot_from_any_level(slot)
	if not is_scene_load_pending():
		respawn_load_pending = false
	if not load_succeeded:
		respawn_load_pending = false

	return load_succeeded


func spend_life_and_respawn_player_in_place() -> bool:
	if player_lives <= 0:
		last_error = "No lives remaining."
		return false

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		last_error = "Could not find player for respawn."
		return false

	player_lives = max(player_lives - 1, 0)
	player_lives_changed.emit(player_lives, get_max_player_lives())
	if player_lives <= 0:
		last_error = "No lives remaining."
		return false

	if player.has_method("soft_respawn_in_place"):
		player.soft_respawn_in_place(LIFE_LOSS_EXTRA_INVULNERABILITY_TIME)
	elif player.has_method("soft_respawn_at_position"):
		player.soft_respawn_at_position(player.global_position, LIFE_LOSS_EXTRA_INVULNERABILITY_TIME)
	else:
		if player.has_method("restore_after_load"):
			player.restore_after_load()

	last_error = ""
	return true


func delete_save(slot: int) -> bool:
	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return false

	if not save_exists(slot):
		last_error = ""
		return true

	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		last_error = "Could not open the user save directory."
		return false

	var error: Error = dir.remove(get_save_file_name(slot))
	if error != OK:
		last_error = "Could not delete save slot %d. Error: %s" % [slot, error_string(error)]
		return false

	last_error = ""
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
	var level_state: Dictionary = get_level_state_from_save_data(data, level_path)
	summary["saved_at_datetime"] = saved_at_datetime
	summary["timestamp_text"] = saved_at_datetime
	summary["level_path"] = level_path
	summary["reason"] = str(data.get("reason", ""))
	summary["display_name"] = get_save_display_name(level_path, level_state, data.get("quest_states", {}))
	return summary


func get_level_state_from_save_data(data: Dictionary, level_path: String) -> Dictionary:
	var raw_states: Variant = data.get("level_states_by_path", {})
	if raw_states is Dictionary:
		var states_by_path: Dictionary = raw_states
		var raw_state: Variant = states_by_path.get(level_path, {})
		if raw_state is Dictionary:
			return raw_state

	var raw_fallback_state: Variant = data.get("level_state", {})
	if raw_fallback_state is Dictionary:
		return raw_fallback_state

	return {}


func get_save_display_name(level_path: String, level_state: Dictionary, _saved_quest_states: Variant = {}) -> String:
	var raw_entry: Variant = LEVEL_DISPLAY_REGISTRY.get(level_path, {})
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
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


func get_level_display_name_fallback(level_path: String) -> String:
	if level_path == "":
		return "Unknown Location"

	var file_name: String = level_path.get_file().get_basename()
	if file_name == "":
		return level_path

	return file_name.capitalize()


func get_title_dev_level_entries() -> Array:
	var entries: Array = []
	for level_path in LEVEL_DISPLAY_REGISTRY.keys():
		var raw_entry: Variant = LEVEL_DISPLAY_REGISTRY[level_path]
		if not (raw_entry is Dictionary):
			continue

		var entry: Dictionary = raw_entry
		var raw_presets: Variant = entry.get("dev_presets", [])
		if not (raw_presets is Array):
			continue

		entries.append({
			"scene_path": str(level_path),
			"display_name": str(entry.get("display_name", get_level_display_name_fallback(str(level_path)))),
			"dev_presets": raw_presets,
		})

	return entries


func reset_current_level_for_dev() -> bool:
	var scene_path: String = get_level_path(get_current_level())
	if scene_path == "":
		last_error = "Could not reset the current level because it has no scene path."
		return false

	autosave_suppressed = true
	get_tree().paused = false
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		autosave_suppressed = false
		last_error = "Could not reload current level. Error: %s" % error_string(error)
		return false

	last_error = ""
	return true


func should_skip_autosave(reason: String) -> bool:
	if not autosave_blockers.is_empty():
		return true

	if not autosave_suppressed:
		return false

	if reason == "level_enter":
		autosave_suppressed = false

	return true


func load_game(slot: int = active_slot) -> Dictionary:
	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return {}

	var save_path: String = get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		last_error = "No save file exists for slot %d." % slot
		return {}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_error = "Could not open %s for reading. Error: %s" % [save_path, error_string(FileAccess.get_open_error())]
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		last_error = "Save file %s is not valid JSON save data." % save_path
		return {}

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		last_error = "Save file %s uses an unsupported version." % save_path
		return {}

	last_error = ""
	return data


func apply_save_to_current_level(data: Dictionary, preserve_current_lives: bool = false) -> bool:
	var level: Node = get_current_level()
	if level == null or data.is_empty():
		return false

	var saved_level_path: String = str(data.get("level_path", ""))
	var current_level_path: String = get_level_path(level)
	var raw_saved_level_states: Variant = data.get("level_states_by_path", {})
	var has_multi_level_state: bool = raw_saved_level_states is Dictionary
	if current_level_path != "" and saved_level_path != "" and saved_level_path != current_level_path and not has_multi_level_state:
		last_error = "Save data belongs to a different level."
		return false

	var legacy_level_state: Variant = data.get("level_state", {})
	apply_level_states_by_path(raw_saved_level_states, saved_level_path, legacy_level_state)
	if current_level_path != "" and saved_level_path != "" and saved_level_path != current_level_path and get_saved_level_state_for_path(current_level_path).is_empty():
		warn_level_state_load_mismatch(current_level_path, saved_level_path)
		last_error = "Save data belongs to a different level."
		return false
	var current_level_state: Dictionary = get_level_state_for_current_load(current_level_path, saved_level_path, legacy_level_state)
	if current_level_state.is_empty() and has_saved_scene_local_state(saved_level_path, legacy_level_state):
		warn_level_state_load_mismatch(current_level_path, saved_level_path)
		last_error = "Save data could not be applied to the current level state."
		return false
	var current_level_state_source: String = get_level_state_source_for_current_load(current_level_path, saved_level_path, legacy_level_state)
	warn_level_state_restore_source(int(data.get("slot", 0)), current_level_path, saved_level_path, current_level_state_source, current_level_state)

	if CombatStateManager != null and CombatStateManager.has_method("clear_all"):
		CombatStateManager.clear_all()

	apply_upgrade_state(data.get("upgrade_state", {}))
	apply_story_flags(data.get("story_flags", {}))
	apply_quest_states(data.get("quest_states", {}))
	var repaired_dead_player_save: bool = is_saved_player_dead(data.get("player", {}))
	if not preserve_current_lives:
		var saved_lives: int = int(data.get("player_lives", get_max_player_lives()))
		player_lives = clamp(saved_lives, 0, get_max_player_lives())
		if repaired_dead_player_save and player_lives <= 0:
			player_lives = 1
		player_lives_changed.emit(player_lives, get_max_player_lives())
	apply_player_state(level, data.get("player", {}))
	if not uses_level_owned_hostile_state(level):
		apply_defeated_banshees(level, data.get("defeated_banshees", []))
	if not uses_level_owned_villager_state(level):
		apply_villager_states(level, data.get("villagers", []))
	apply_level_state(level, current_level_state)
	if not verify_level_state_after_apply(level, current_level_state, int(data.get("slot", 0)), current_level_state_source):
		return false
	last_error = ""
	return true


func is_saved_player_dead(player_data: Variant) -> bool:
	if not (player_data is Dictionary):
		return false

	var data: Dictionary = player_data
	var raw_health_data: Variant = data.get("health", {})
	if not (raw_health_data is Dictionary):
		return false

	var health_data: Dictionary = raw_health_data
	return bool(health_data.get("dead", false)) or int(health_data.get("current", 1)) <= 0


func get_save_path(slot: int = active_slot) -> String:
	return SAVE_PATH_FORMAT % clamp(slot, 1, SAVE_SLOT_COUNT)


func get_save_file_name(slot: int) -> String:
	return "save_slot_%d.json" % clamp(slot, 1, SAVE_SLOT_COUNT)


func get_current_level() -> Node:
	if current_level != null and is_instance_valid(current_level) and current_level.is_inside_tree():
		return current_level

	return get_tree().current_scene


func build_save_data(reason: String, level: Node, slot: int) -> Dictionary:
	var level_path: String = get_level_path(level)
	var current_level_state: Dictionary = collect_level_state(level)
	if level_path != "":
		level_states_by_path[level_path] = current_level_state

	var defeated_banshee_state: Array = []
	if not uses_level_owned_hostile_state(level):
		defeated_banshee_state = collect_defeated_banshees(level)

	var villager_state: Array = []
	if not uses_level_owned_villager_state(level):
		villager_state = collect_villager_states(level)

	return {
		"version": SAVE_VERSION,
		"slot": slot,
		"reason": reason,
		"player_lives": player_lives,
		"upgrade_state": get_upgrade_state(),
		"story_flags": get_story_flags(),
		"quest_states": get_quest_states(),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"saved_at_datetime": Time.get_datetime_string_from_system(),
		"level_path": level_path,
		"player": collect_player_state(level),
		"defeated_banshees": defeated_banshee_state,
		"villagers": villager_state,
		"level_state": current_level_state,
		"level_states_by_path": level_states_by_path.duplicate(true),
	}


func get_level_path(level: Node) -> String:
	if level != null and level.scene_file_path != "":
		return level.scene_file_path

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		return current_scene.scene_file_path

	return ""


func collect_player_state(level: Node) -> Dictionary:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return {}

	var health_node: Node = player.get_node_or_null("Health")
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D

	var data: Dictionary = {
		"node_path": get_relative_node_path(level, player),
		"position": vector_to_data(player.global_position),
		"form_id": "human",
		"health": {},
		"stamina": {},
		"camera_zoom": 2.25,
	}

	if player.has_method("get_save_form_id"):
		data["form_id"] = str(player.get_save_form_id())
	elif player.has_method("get_current_form_id"):
		data["form_id"] = str(player.get_current_form_id())

	if health_node != null:
		var max_health: int = maxi(int(health_node.get("max_health")), 1)
		var current_health: int = clamp(int(health_node.get("health")), 1, max_health)
		var current_stamina: float = float(health_node.get("stamina"))
		if bool(health_node.get("dead")) or int(health_node.get("health")) <= 0:
			current_health = max_health
			current_stamina = float(health_node.get("max_stamina"))
		data["health"] = {
			"current": current_health,
			"max": max_health,
			"dead": false,
		}
		data["stamina"] = {
			"current": current_stamina,
			"max": float(health_node.get("max_stamina")),
		}

	if camera != null:
		data["camera_zoom"] = camera.zoom.x

	return data


func collect_defeated_banshees(level: Node) -> Array:
	var defeated: Array = []
	for hostile in get_tree().get_nodes_in_group("hostile_npcs"):
		if not is_node_in_level(level, hostile):
			continue

		var is_defeated: bool = bool(hostile.get("dead"))
		var health_node: Node = hostile.get_node_or_null("Health")
		if health_node != null:
			is_defeated = is_defeated or bool(health_node.get("dead"))

		if is_defeated:
			defeated.append(get_relative_node_path(level, hostile))

	return defeated


func collect_villager_states(level: Node) -> Array:
	var villagers: Array = []
	for villager in get_tree().get_nodes_in_group("villagers"):
		if not is_node_in_level(level, villager):
			continue

		villagers.append({
			"node_path": get_relative_node_path(level, villager),
			"paused_by_external_actor": bool(villager.get("paused_by_external_actor")),
			"external_pause_completed": bool(villager.get("external_pause_completed")),
		})

	return villagers


func collect_story_actor_states(level: Node, root: Node, required_group: String = "") -> Array:
	var states: Array = []
	if root == null:
		return states

	collect_story_actor_states_from(level, root, required_group, states)
	return states


func collect_story_actor_states_from(level: Node, root: Node, required_group: String, states: Array):
	for child in root.get_children():
		var should_collect: bool = required_group == "" or child.is_in_group(required_group)
		if should_collect:
			collect_one_story_actor_state(level, child, states)

		collect_story_actor_states_from(level, child, required_group, states)


func collect_one_story_actor_state(level: Node, actor: Node, states: Array):
	var actor_path: String = get_relative_node_path(level, actor)
	if actor_path == "":
		return

	var state: Dictionary = {}
	if actor.has_method("collect_story_save_state"):
		var raw_state: Variant = actor.call("collect_story_save_state")
		if raw_state is Dictionary:
			state = raw_state
	elif actor is Node2D:
		var actor_node: Node2D = actor as Node2D
		state = {
			"position": vector_to_data(actor_node.global_position),
		}

	state["node_path"] = actor_path
	states.append(state)


func parse_actor_snapshot_lookup(raw_states: Variant) -> Dictionary:
	var parsed_states: Dictionary = {}
	if not (raw_states is Array):
		return parsed_states

	for raw_state in raw_states:
		if not (raw_state is Dictionary):
			continue

		var state: Dictionary = raw_state
		var actor_path: String = str(state.get("node_path", ""))
		if actor_path == "":
			continue

		parsed_states[actor_path] = state

	return parsed_states


func apply_story_actor_states(level: Node, actor_states: Dictionary):
	if level == null:
		return

	for actor_path in actor_states.keys():
		var actor: Node = level.get_node_or_null(NodePath(str(actor_path)))
		if actor == null:
			continue

		var raw_state: Variant = actor_states[actor_path]
		if not (raw_state is Dictionary):
			continue

		if actor.has_method("apply_story_save_state"):
			actor.call("apply_story_save_state", raw_state)


func collect_level_state(level: Node) -> Dictionary:
	var providers: Array[Node] = get_level_state_providers(level)
	if providers.is_empty():
		return {}

	if providers.size() == 1:
		var single_raw_state: Variant = providers[0].call("collect_level_state")
		if single_raw_state is Dictionary:
			return single_raw_state
		return {}

	var provider_states: Dictionary = {}
	for provider in providers:
		var raw_state: Variant = provider.call("collect_level_state")
		if raw_state is Dictionary:
			provider_states[get_provider_save_key(level, provider)] = raw_state

	return {
		"_providers": provider_states,
	}


func uses_level_owned_hostile_state(level: Node) -> bool:
	for provider in get_level_state_providers(level):
		if provider.has_method("uses_level_owned_hostile_state") and bool(provider.call("uses_level_owned_hostile_state")):
			return true

	return false


func uses_level_owned_villager_state(level: Node) -> bool:
	for provider in get_level_state_providers(level):
		if provider.has_method("uses_level_owned_villager_state") and bool(provider.call("uses_level_owned_villager_state")):
			return true

	return false


func apply_level_state(level: Node, state_data: Variant):
	var providers: Array[Node] = get_level_state_providers(level)
	if providers.is_empty():
		return

	var state: Dictionary = {}
	if state_data is Dictionary:
		state = state_data

	var raw_provider_states: Variant = state.get("_providers", {})
	if state.has("_providers") and raw_provider_states is Dictionary:
		var provider_states: Dictionary = raw_provider_states
		for provider in providers:
			var provider_state: Dictionary = {}
			var raw_provider_state: Variant = provider_states.get(get_provider_save_key(level, provider), {})
			if raw_provider_state is Dictionary:
				provider_state = raw_provider_state
			validate_level_state_if_debug(provider, provider_state)
			provider.call("apply_level_state", provider_state)
		return

	for index in range(providers.size()):
		var provider: Node = providers[index]
		var provider_state: Dictionary = state if index == 0 else {}
		validate_level_state_if_debug(provider, provider_state)
		provider.call("apply_level_state", provider_state)


func validate_level_state_if_debug(provider: Node, state: Dictionary):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	if provider == null or not provider.has_method("validate_level_state"):
		return

	var raw_messages: Variant = provider.call("validate_level_state", state)
	if not (raw_messages is Array):
		return

	for message in raw_messages:
		push_warning(str(message))


func get_level_state_provider(level: Node) -> Node:
	var providers: Array[Node] = get_level_state_providers(level)
	if providers.is_empty():
		return null

	return providers[0]


func get_level_state_providers(level: Node) -> Array[Node]:
	var providers: Array[Node] = []
	if level == null:
		return providers

	if level.has_method("collect_level_state") and level.has_method("apply_level_state"):
		providers.append(level)

	for child in level.get_children():
		if child.has_method("collect_level_state") and child.has_method("apply_level_state"):
			providers.append(child)

	return providers


func get_provider_save_key(level: Node, provider: Node) -> String:
	if provider == null:
		return ""
	if level != null and level == provider:
		return "."
	if level != null and level.is_ancestor_of(provider):
		return str(level.get_path_to(provider))

	return str(provider.get_path())


func apply_player_state(level: Node, player_data: Variant):
	if not (player_data is Dictionary):
		return

	var data: Dictionary = player_data
	var player: Node2D = get_node_from_saved_path(level, str(data.get("node_path", ""))) as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	player.global_position = data_to_vector(data.get("position", {}), player.global_position)

	if player.has_method("set_form"):
		player.set_form(StringName(str(data.get("form_id", "human"))))

	var health_node: Node = player.get_node_or_null("Health")
	var repaired_dead_player_save: bool = false
	if health_node != null:
		var health_data: Dictionary = data.get("health", {})
		var stamina_data: Dictionary = data.get("stamina", {})
		var max_health: int = maxi(int(health_node.get("max_health")), 1)
		var saved_health: int = int(health_data.get("current", health_node.get("health")))
		var saved_dead: bool = bool(health_data.get("dead", false))
		repaired_dead_player_save = saved_dead or saved_health <= 0
		var applied_health: int = max_health if repaired_dead_player_save else clamp(saved_health, 1, max_health)
		var applied_stamina: float = float(health_node.get("max_stamina")) if repaired_dead_player_save else clamp(float(stamina_data.get("current", health_node.get("stamina"))), 0.0, float(health_node.get("max_stamina")))
		health_node.set("health", applied_health)
		health_node.set("dead", false)
		health_node.set("stamina", applied_stamina)
		if health_node.has_signal("health_changed"):
			health_node.emit_signal("health_changed", health_node.get("health"), health_node.get("max_health"))
		if health_node.has_signal("stamina_changed"):
			health_node.emit_signal("stamina_changed", health_node.get("stamina"), health_node.get("max_stamina"))

	if repaired_dead_player_save and OS.is_debug_build():
		print_verbose("Loaded player save had dead/zero-health state; repaired to alive full health.")

	if player.has_method("restore_after_load"):
		player.restore_after_load()

	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		var zoom_value: float = float(data.get("camera_zoom", camera.zoom.x))
		if camera.has_method("change_zoom"):
			camera.change_zoom(zoom_value)
		else:
			camera.zoom = Vector2(zoom_value, zoom_value)


func apply_defeated_banshees(level: Node, defeated_paths: Variant):
	if not (defeated_paths is Array):
		return

	var defeated_lookup: Dictionary = {}
	for saved_path in defeated_paths:
		defeated_lookup[str(saved_path)] = true

	for hostile in get_tree().get_nodes_in_group("hostile_npcs"):
		if not is_node_in_level(level, hostile):
			continue

		var hostile_path: String = get_relative_node_path(level, hostile)
		if defeated_lookup.has(hostile_path):
			apply_defeated_hostile_state(hostile)
		else:
			apply_active_hostile_state(hostile)


func apply_defeated_hostile_state(hostile: Node):
	hostile.set("dead", true)
	var health_node: Node = hostile.get_node_or_null("Health")
	if health_node != null:
		health_node.set("dead", true)
		health_node.set("health", 0)
	if hostile.has_method("disable_combat_areas"):
		hostile.disable_combat_areas()
	hostile.visible = false


func apply_active_hostile_state(hostile: Node):
	if hostile.has_method("restore_after_load"):
		hostile.restore_after_load()
		return

	hostile.visible = true
	hostile.set("dead", false)
	hostile.set_physics_process(true)


func apply_villager_states(level: Node, villager_states: Variant):
	if not (villager_states is Array):
		return

	for raw_state in villager_states:
		if not (raw_state is Dictionary):
			continue

		var state: Dictionary = raw_state
		var villager: Node = get_node_from_saved_path(level, str(state.get("node_path", "")))
		if villager == null:
			continue

		var paused_by_external_actor: bool = bool(state.get("paused_by_external_actor", false))
		var external_pause_completed: bool = bool(state.get("external_pause_completed", false))
		if villager.has_method("apply_saved_story_pause_state"):
			villager.apply_saved_story_pause_state(paused_by_external_actor, external_pause_completed)
		else:
			villager.set("paused_by_external_actor", paused_by_external_actor)
			villager.set("external_pause_completed", external_pause_completed)
		if villager.has_method("play_idle_animation") and bool(state.get("external_pause_completed", false)):
			villager.play_idle_animation()


func get_relative_node_path(level: Node, node: Node) -> String:
	if level != null and is_instance_valid(level) and level != node and level.is_ancestor_of(node):
		return str(level.get_path_to(node))

	return str(node.get_path())


func get_node_from_saved_path(level: Node, saved_path: String) -> Node:
	if saved_path == "":
		return null

	if level != null:
		var relative_node: Node = level.get_node_or_null(NodePath(saved_path))
		if relative_node != null:
			return relative_node

	return get_node_or_null(NodePath(saved_path))


func is_node_in_level(level: Node, node: Node) -> bool:
	if level == null:
		return true

	return level == node or level.is_ancestor_of(node)


func vector_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func data_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	if not (value is Dictionary):
		return fallback

	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
