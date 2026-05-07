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
var settings_controller := SaveSettingsController.new()
var upgrade_controller := SaveUpgradeController.new()
var quest_controller := SaveQuestController.new()
var file_controller := SaveFileController.new()
var actor_state_controller := SaveActorStateController.new()


func _ready():
	settings_controller.setup(self)
	upgrade_controller.setup(self)
	quest_controller.setup(self)
	file_controller.setup(self)
	actor_state_controller.setup(self)
	load_settings()


func load_settings():
	settings_controller.load_settings()


func save_settings():
	settings_controller.save_settings()


func get_gauge_display_settings() -> Dictionary:
	return settings_controller.get_gauge_display_settings()


func set_gauge_display_settings(show_hud: bool, show_player: bool):
	settings_controller.set_gauge_display_settings(show_hud, show_player)


func get_default_camera_zoom() -> float:
	return settings_controller.get_default_camera_zoom()


func set_default_camera_zoom(value: float):
	settings_controller.set_default_camera_zoom(value)


func set_active_slot(slot: int) -> bool:
	return file_controller.set_active_slot(slot)


func is_valid_slot(slot: int) -> bool:
	return file_controller.is_valid_slot(slot)


func is_manual_save_slot(slot: int) -> bool:
	return file_controller.is_manual_save_slot(slot)


func is_autosave_slot(slot: int) -> bool:
	return file_controller.is_autosave_slot(slot)


func get_player_lives() -> int:
	return upgrade_controller.get_player_lives()


func get_max_player_lives() -> int:
	return upgrade_controller.get_max_player_lives()


func reset_player_lives():
	upgrade_controller.reset_player_lives()


func set_player_lives_for_dev(lives: int):
	upgrade_controller.set_player_lives_for_dev(lives)


func reset_upgrade_state():
	upgrade_controller.reset_upgrade_state()


func get_default_upgrade_state() -> Dictionary:
	return upgrade_controller.get_default_upgrade_state()


func unlock_upgrade(upgrade_id: StringName) -> bool:
	return upgrade_controller.unlock_upgrade(upgrade_id)


func lock_upgrade(upgrade_id: StringName) -> bool:
	return upgrade_controller.lock_upgrade(upgrade_id)


func set_stat_level(stat_id: StringName, level: int) -> bool:
	return upgrade_controller.set_stat_level(stat_id, level)


func get_upgrade_state() -> Dictionary:
	return upgrade_controller.get_upgrade_state()


func set_story_flag(flag_name: String, enabled: bool):
	quest_controller.set_story_flag(flag_name, enabled)


func get_story_flag(flag_name: String) -> bool:
	return quest_controller.get_story_flag(flag_name)


func get_story_flags() -> Dictionary:
	return quest_controller.get_story_flags()


func apply_story_flags(data: Variant):
	quest_controller.apply_story_flags(data)


func get_default_quest_state(stage: String = QUEST_STAGE_NOT_AVAILABLE) -> Dictionary:
	return quest_controller.get_default_quest_state(stage)


func get_quest_state(quest_id: String) -> Dictionary:
	return quest_controller.get_quest_state(quest_id)


func set_quest_state(quest_id: String, state: Dictionary):
	quest_controller.set_quest_state(quest_id, state)


func get_quest_stage(quest_id: String) -> String:
	return quest_controller.get_quest_stage(quest_id)


func set_quest_stage(quest_id: String, stage: String):
	quest_controller.set_quest_stage(quest_id, stage)


func get_quest_flag(quest_id: String, flag_name: String) -> bool:
	return quest_controller.get_quest_flag(quest_id, flag_name)


func set_quest_flag(quest_id: String, flag_name: String, enabled: bool):
	quest_controller.set_quest_flag(quest_id, flag_name, enabled)


func get_quest_states() -> Dictionary:
	return quest_controller.get_quest_states()


func apply_quest_states(data: Variant):
	quest_controller.apply_quest_states(data)


func set_banshee_world_rule(rule_name: String, value: Variant):
	quest_controller.set_banshee_world_rule(rule_name, value)


func get_banshee_world_rules() -> Dictionary:
	return quest_controller.get_banshee_world_rules()


func apply_upgrade_state(data: Variant):
	upgrade_controller.apply_upgrade_state(data)


func reconcile_player_lives_after_max_change(previous_max_lives: int, grant_new_lives: bool):
	upgrade_controller.reconcile_player_lives_after_max_change(previous_max_lives, grant_new_lives)


func get_upgrade_unlocked() -> Dictionary:
	return upgrade_controller.get_upgrade_unlocked()


func get_upgrade_stat_levels() -> Dictionary:
	return upgrade_controller.get_upgrade_stat_levels()


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
	var save_data: Dictionary = build_save_data(reason, save_level, slot)
	return file_controller.write_save_data(slot, save_data)


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
	return file_controller.delete_save(slot)


func save_exists(slot: int) -> bool:
	return file_controller.save_exists(slot)


func get_slot_summary(slot: int) -> Dictionary:
	return file_controller.get_slot_summary(slot)


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
	return file_controller.load_game(slot)


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
	return actor_state_controller.is_saved_player_dead(player_data)


func get_save_path(slot: int = active_slot) -> String:
	return file_controller.get_save_path(slot)


func get_save_file_name(slot: int) -> String:
	return file_controller.get_save_file_name(slot)


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
	return actor_state_controller.collect_player_state(level)


func collect_defeated_banshees(level: Node) -> Array:
	return actor_state_controller.collect_defeated_banshees(level)


func collect_villager_states(level: Node) -> Array:
	return actor_state_controller.collect_villager_states(level)


func collect_story_actor_states(level: Node, root: Node, required_group: String = "") -> Array:
	return actor_state_controller.collect_story_actor_states(level, root, required_group)


func collect_story_actor_states_from(level: Node, root: Node, required_group: String, states: Array):
	actor_state_controller.collect_story_actor_states_from(level, root, required_group, states)


func collect_one_story_actor_state(level: Node, actor: Node, states: Array):
	actor_state_controller.collect_one_story_actor_state(level, actor, states)


func parse_actor_snapshot_lookup(raw_states: Variant) -> Dictionary:
	return actor_state_controller.parse_actor_snapshot_lookup(raw_states)


func apply_story_actor_states(level: Node, actor_states: Dictionary):
	actor_state_controller.apply_story_actor_states(level, actor_states)


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
	actor_state_controller.apply_player_state(level, player_data)


func apply_defeated_banshees(level: Node, defeated_paths: Variant):
	actor_state_controller.apply_defeated_banshees(level, defeated_paths)


func apply_defeated_hostile_state(hostile: Node):
	actor_state_controller.apply_defeated_hostile_state(hostile)


func apply_active_hostile_state(hostile: Node):
	actor_state_controller.apply_active_hostile_state(hostile)


func apply_villager_states(level: Node, villager_states: Variant):
	actor_state_controller.apply_villager_states(level, villager_states)


func get_relative_node_path(level: Node, node: Node) -> String:
	return actor_state_controller.get_relative_node_path(level, node)


func get_node_from_saved_path(level: Node, saved_path: String) -> Node:
	return actor_state_controller.get_node_from_saved_path(level, saved_path)


func is_node_in_level(level: Node, node: Node) -> bool:
	return actor_state_controller.is_node_in_level(level, node)


func vector_to_data(value: Vector2) -> Dictionary:
	return actor_state_controller.vector_to_data(value)


func data_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	return actor_state_controller.data_to_vector(value, fallback)
