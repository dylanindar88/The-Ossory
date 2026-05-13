extends RefCounted
class_name BansheeVillageDevPresetBuilder

const DEV_PRESET_NONE = "none"
const DEV_PRESET_START = "start"
const DEV_PRESET_ELDER_QUEST_ACCEPTED = "elder_quest_accepted"
const DEV_PRESET_FIRST_BANSHEE_REPORT_READY = "first_banshee_report_ready"
const DEV_PRESET_ELDER_REPORT_COMPLETE_DULLUHAN_VISIBLE = "elder_report_complete_dulluhan_visible"
const DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED = "dulluhan_transformation_unlocked"
const DEV_PRESET_SECOND_BANSHEE_REPORT_READY = "second_banshee_report_ready"
const DEV_PRESET_THIRD_BANSHEE_REPORT_READY = "third_banshee_report_ready"
const DEV_PRESET_AUTOSAVE_BLOCKER = "banshee_village_dev_preset"
const DEV_PRESET_SAVE_WRITE_BLOCKER = "banshee_village_dev_preset"
const VALID_DEV_PRESETS: Array[String] = [
	DEV_PRESET_NONE,
	DEV_PRESET_START,
	DEV_PRESET_ELDER_QUEST_ACCEPTED,
	DEV_PRESET_FIRST_BANSHEE_REPORT_READY,
	DEV_PRESET_ELDER_REPORT_COMPLETE_DULLUHAN_VISIBLE,
	DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED,
	DEV_PRESET_SECOND_BANSHEE_REPORT_READY,
	DEV_PRESET_THIRD_BANSHEE_REPORT_READY,
]
const WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG = "wolf_transformation_unlocked_by_dulluhan"
const VINCENT_HOUSE_DIALOGUE_FLAG = "vincent_house_dialogue_completed"
const BISHOP_CONFRONTATION_ACCEPTED_FLAG = "bishop_confrontation_accepted"
const LEVEL_STATE_VERSION = 6
const STAGE_RULES = preload("res://scripts/levels/banshee_village/BansheeVillageStageRules.gd")

var flow


func setup(controller):
	flow = controller


func apply_dev_start_preset() -> bool:
	var preset: String = get_valid_dev_start_preset(str(flow.get("dev_start_preset")))
	if SaveManager != null and SaveManager.has_method("consume_pending_dev_start_preset"):
		var pending_preset: String = SaveManager.consume_pending_dev_start_preset(flow.get_parent().scene_file_path)
		if pending_preset != "":
			preset = get_valid_dev_start_preset(pending_preset)
	if preset == DEV_PRESET_NONE:
		if SaveManager != null and SaveManager.has_method("set_autosave_blocked"):
			SaveManager.set_autosave_blocked(DEV_PRESET_AUTOSAVE_BLOCKER, false)
		if SaveManager != null and SaveManager.has_method("set_save_write_blocked"):
			SaveManager.set_save_write_blocked(DEV_PRESET_SAVE_WRITE_BLOCKER, false)
		return false

	# Dev presets are temporary boot states for testing; skip the level-enter autosave
	# without using the normal save blocker that also gates menus and interactions.
	if SaveManager != null:
		if SaveManager.has_method("set_autosave_blocked"):
			SaveManager.set_autosave_blocked(DEV_PRESET_AUTOSAVE_BLOCKER, true)
		else:
			SaveManager.autosave_suppressed = true

	apply_dev_story_flags(preset)
	flow.apply_level_state(build_dev_level_state(preset))
	if does_preset_unlock_wolf_transformation(preset):
		apply_dev_transformation_unlock()
	call_deferred("clear_dev_preset_combat_state")

	return true


func get_valid_dev_start_preset(preset: String) -> String:
	if VALID_DEV_PRESETS.has(preset):
		return preset

	return DEV_PRESET_NONE


func get_dev_preset_options() -> Array[String]:
	var options: Array[String] = VALID_DEV_PRESETS.duplicate()
	options.erase(DEV_PRESET_NONE)
	return options


func build_dev_level_state(preset: String) -> Dictionary:
	var stage: String = STAGE_RULES.STAGE_INTRO
	var kill_count: int = 0
	var temporary_paths: Array = []
	var permanent_paths: Array = []
	if preset == DEV_PRESET_ELDER_QUEST_ACCEPTED:
		stage = STAGE_RULES.STAGE_COMBAT_ACTIVE
	elif preset == DEV_PRESET_FIRST_BANSHEE_REPORT_READY:
		stage = STAGE_RULES.STAGE_READY_TO_REPORT
		kill_count = int(flow.get("report_kill_threshold"))
	elif preset == DEV_PRESET_ELDER_REPORT_COMPLETE_DULLUHAN_VISIBLE:
		stage = STAGE_RULES.STAGE_DULLUHAN_AVAILABLE
		kill_count = int(flow.get("report_kill_threshold"))
	elif preset == DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED:
		stage = STAGE_RULES.STAGE_WOLF_HUNT_READY
		kill_count = int(flow.get("report_kill_threshold"))
	elif preset == DEV_PRESET_SECOND_BANSHEE_REPORT_READY:
		stage = STAGE_RULES.STAGE_WOLF_HUNT_CLEARED
		kill_count = int(flow.get("report_kill_threshold")) + get_banshees().size()
		temporary_paths = get_all_banshee_paths()
	elif preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY:
		stage = STAGE_RULES.STAGE_THIRD_WAVE_CLEARED
		kill_count = int(flow.get("report_kill_threshold")) + get_banshees().size()
		temporary_paths = get_all_banshee_paths()
	var dev_dulluhan_transformation_granted: bool = does_preset_unlock_wolf_transformation(preset)

	return {
		"state_version": LEVEL_STATE_VERSION,
		"quest_stage": stage,
		"banshee_kill_count": kill_count,
		"revealed_banshee_paths": [],
		"temporarily_cleared_banshee_paths": temporary_paths,
		"permanently_cleared_banshee_paths": permanent_paths,
		"final_dulluhan_teaser_completed": does_preset_start_after_final_dulluhan_teaser(preset),
		"story_transform_prompt_consumed": preset != DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED,
		"story_wolf_lock_active": false,
		"final_wolf_instruction_shown": false,
		"active_interior_id": "",
		"third_wave_spawned": does_preset_start_after_third_wave(preset),
		"dulluhan_transformation_granted_for_level": dev_dulluhan_transformation_granted,
		"vincent_house_dialogue_completed_for_level": does_preset_complete_vincent_house_dialogue(preset),
		"bishop_confrontation_accepted_for_level": false,
		"dulluhan": {},
		"banshees": [],
		"villagers": [],
	}


func is_dev_preset_after_dulluhan_unlock(preset: String) -> bool:
	return does_preset_unlock_wolf_transformation(preset)


func does_preset_unlock_wolf_transformation(preset: String) -> bool:
	return (
		preset == DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED
		or preset == DEV_PRESET_SECOND_BANSHEE_REPORT_READY
		or preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY
	)


func does_preset_start_after_final_dulluhan_teaser(preset: String) -> bool:
	return preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY


func does_preset_start_after_third_wave(preset: String) -> bool:
	return preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY


func does_preset_complete_vincent_house_dialogue(preset: String) -> bool:
	return preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY


func get_all_banshee_paths() -> Array:
	var paths: Array = []
	for banshee in get_banshees():
		var banshee_path: String = flow.get_relative_node_path(banshee)
		if banshee_path != "":
			paths.append(banshee_path)

	return paths


func apply_dev_story_flags(preset: String):
	if SaveManager == null or not SaveManager.has_method("set_story_flag"):
		return

	if does_preset_complete_vincent_house_dialogue(preset):
		SaveManager.set_story_flag(VINCENT_HOUSE_DIALOGUE_FLAG, true)
		SaveManager.set_story_flag(BISHOP_CONFRONTATION_ACCEPTED_FLAG, false)
	SaveManager.set_story_flag(WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG, does_preset_unlock_wolf_transformation(preset))


func apply_dev_transformation_unlock():
	if SaveManager == null:
		return

	SaveManager.unlock_upgrade(&"wolf_transformation")
	SaveManager.set_stat_level(&"wolf_transformation", 0)
	if SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG, true)
	flow.set("dulluhan_transformation_granted_for_level", true)
	var dulluhan: Node = flow.get("dulluhan") as Node
	if dulluhan != null:
		if dulluhan.has_method("set_transformation_granted_for_story_save"):
			dulluhan.call("set_transformation_granted_for_story_save", true)
		else:
			dulluhan.set("transformation_granted", true)
	flow.refresh_quest_presentation()
	flow.refresh_story_transform_prompt()


func clear_dev_preset_combat_state():
	await flow.get_tree().physics_frame
	await flow.get_tree().physics_frame
	if CombatStateManager != null and CombatStateManager.has_method("clear_all"):
		CombatStateManager.clear_all()


func get_banshees() -> Array:
	var raw_banshees: Variant = flow.get("banshees")
	if raw_banshees is Array:
		return raw_banshees

	return []
