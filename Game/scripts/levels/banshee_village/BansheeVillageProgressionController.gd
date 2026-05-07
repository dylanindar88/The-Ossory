extends RefCounted
class_name BansheeVillageProgressionController

const BANSHEE_VARIANT_CORRUPTED_MELEE = "corrupted_melee"
const BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED = "corrupted_strong_ranged"
const BISHOP_CONFRONTATION_ACCEPTED_FLAG = "bishop_confrontation_accepted"
const BANSHEE_CLEAR_RESPAWN = "respawn"
const BANSHEE_CLEAR_PERMANENT_WOLF = "permanent_wolf_clear"
const FINAL_WOLF_INSTRUCTION_TEXT = "You cannot hold the form forever.\nYour own transformations last 30 seconds.\nPress Tab to view transformation stats."
const STAGE_RULES = preload("res://scripts/levels/banshee_village/BansheeVillageStageRules.gd")

var flow


func setup(controller):
	flow = controller


func begin_combat_stage():
	flow.close_elder_choice_prompt(false)
	flow.state_generation += 1
	flow.quest_stage = STAGE_RULES.STAGE_COMBAT_ACTIVE
	flow.banshee_kill_count = 0
	flow.third_wave_spawned = false
	flow.cleared_villager_paths.clear()
	flow.revealed_banshee_paths.clear()
	flow.permanently_cleared_banshee_paths.clear()
	flow.defeated_banshees.clear()
	flow.set_all_banshee_combat_variants(BANSHEE_VARIANT_CORRUPTED_MELEE)
	flow.restore_stage_world_state()


func begin_ready_to_report_stage():
	flow.quest_stage = STAGE_RULES.STAGE_READY_TO_REPORT
	flow.refresh_quest_presentation()


func complete_report_stage():
	flow.close_elder_choice_prompt(false)
	flow.quest_stage = STAGE_RULES.STAGE_DULLUHAN_AVAILABLE
	flow.refresh_quest_presentation()


func begin_wolf_hunt_ready_stage():
	if flow.quest_stage == STAGE_RULES.STAGE_WOLF_HUNT_CLEARED:
		return

	if flow.are_all_banshees_permanently_cleared():
		begin_wolf_hunt_cleared_stage()
		save_wolf_clear_progress()
		return

	flow.quest_stage = STAGE_RULES.STAGE_WOLF_HUNT_READY
	flow.dulluhan_transformation_granted_for_level = true
	flow.story_transform_prompt_consumed = false
	flow.refresh_quest_presentation()
	flow.sync_story_wolf_transformation_lock()
	save_wolf_clear_progress()


func begin_wolf_hunt_stage():
	if flow.are_all_banshees_permanently_cleared():
		begin_wolf_hunt_cleared_stage()
		save_wolf_clear_progress()
		return

	flow.quest_stage = STAGE_RULES.STAGE_REPORT_COMPLETE
	flow.dulluhan_transformation_granted_for_level = true
	flow.refresh_quest_presentation()
	flow.sync_story_wolf_transformation_lock()
	save_wolf_clear_progress()


func begin_third_wave_elder_ready_stage():
	flow.state_generation += 1
	flow.quest_stage = STAGE_RULES.STAGE_THIRD_WAVE_ELDER_READY
	flow.third_wave_spawned = true
	flow.vincent_house_dialogue_completed_for_level = true
	flow.bishop_confrontation_accepted_for_level = false
	if SaveManager != null and SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(BISHOP_CONFRONTATION_ACCEPTED_FLAG, false)
	flow.banshee_kill_count = 0
	flow.story_wolf_lock_active = false
	flow.story_transform_prompt_consumed = true
	flow.cleared_villager_paths.clear()
	flow.revealed_banshee_paths.clear()
	flow.permanently_cleared_banshee_paths.clear()
	flow.defeated_banshees.clear()
	flow.set_all_banshee_combat_variants(BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED)
	flow.restore_stage_world_state()
	flow.sync_story_wolf_transformation_lock()
	save_third_wave_progress("banshee_third_wave_spawn")


func begin_third_wave_active_stage():
	if flow.are_all_banshees_permanently_cleared():
		begin_third_wave_cleared_stage()
		save_third_wave_progress("banshee_third_wave_cleared")
		return

	flow.quest_stage = STAGE_RULES.STAGE_THIRD_WAVE_ACTIVE
	flow.refresh_quest_presentation()
	save_third_wave_progress("banshee_third_wave_start")


func begin_wolf_hunt_cleared_stage(show_completion_prompt: bool = false):
	flow.quest_stage = STAGE_RULES.STAGE_WOLF_HUNT_CLEARED
	flow.story_transform_prompt_consumed = true
	if flow.story_wolf_lock_active or flow.is_player_in_wolf_form():
		flow.story_wolf_lock_active = false
		if flow.player != null and flow.player.has_method("end_story_wolf_transformation_lock"):
			flow.player.end_story_wolf_transformation_lock(true)
	flow.refresh_quest_presentation()
	if show_completion_prompt and not flow.final_wolf_instruction_shown:
		flow.final_wolf_instruction_shown = true
		flow.show_story_prompt(FINAL_WOLF_INSTRUCTION_TEXT, 7.5)


func begin_final_dulluhan_stage():
	flow.dulluhan_transformation_granted_for_level = true
	flow.quest_stage = STAGE_RULES.STAGE_FINAL_DULLUHAN_READY
	flow.refresh_quest_presentation()
	save_wolf_clear_progress()


func begin_third_wave_cleared_stage():
	flow.quest_stage = STAGE_RULES.STAGE_THIRD_WAVE_CLEARED
	flow.refresh_quest_presentation()


func accept_bishop_confrontation():
	flow.bishop_confrontation_accepted_for_level = true
	if SaveManager != null and SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(BISHOP_CONFRONTATION_ACCEPTED_FLAG, true)
	flow.quest_stage = STAGE_RULES.STAGE_BISHOP_PATH_READY
	flow.refresh_quest_presentation()
	save_third_wave_progress("banshee_bishop_confrontation_accept")


func decline_bishop_confrontation():
	flow.refresh_quest_presentation()
	save_third_wave_progress("banshee_bishop_confrontation_decline")


func handle_banshee_defeated(banshee: Node):
	if flow.quest_stage == STAGE_RULES.STAGE_INTRO or flow.defeated_banshees.has(banshee):
		return

	flow.defeated_banshees[banshee] = true
	flow.banshee_kill_count += 1
	var banshee_path: String = flow.get_relative_node_path(banshee)
	flow.revealed_banshee_paths.erase(banshee_path)
	var killed_by_wolf: bool = flow.was_banshee_killed_by_wolf(banshee)

	var villager: Node = flow.get_banshee_assigned_villager(banshee)
	var villager_path: String = flow.get_relative_node_path(villager)
	if villager_path != "":
		flow.cleared_villager_paths[villager_path] = true
	flow.set_villager_clear_sequence(villager)

	if killed_by_wolf and flow.transformed_banshee_clear_policy != BANSHEE_CLEAR_RESPAWN:
		if flow.transformed_banshee_clear_policy == BANSHEE_CLEAR_PERMANENT_WOLF and banshee_path != "":
			flow.permanently_cleared_banshee_paths[banshee_path] = true
		flow.apply_cleared_banshee_state(banshee)
		flow.update_kill_counter()
		if flow.quest_stage == STAGE_RULES.STAGE_REPORT_COMPLETE and flow.are_all_banshees_permanently_cleared():
			begin_wolf_hunt_cleared_stage(true)
		elif flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_ACTIVE and flow.are_all_banshees_permanently_cleared():
			begin_third_wave_cleared_stage()
		elif (
			flow.quest_stage == STAGE_RULES.STAGE_WOLF_HUNT_READY
			or flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_ELDER_READY
		) and flow.are_all_banshees_permanently_cleared():
			flow.refresh_quest_presentation()
		if flow.is_third_wave_stage():
			save_third_wave_progress("banshee_third_wave_progress")
		else:
			save_wolf_clear_progress()
		return

	flow.update_kill_counter()
	flow.schedule_banshee_respawn(banshee)

	if flow.quest_stage == STAGE_RULES.STAGE_COMBAT_ACTIVE and flow.banshee_kill_count >= flow.report_kill_threshold:
		begin_ready_to_report_stage()

	if flow.is_third_wave_combat_stage():
		save_third_wave_progress("banshee_third_wave_progress")


func save_wolf_clear_progress():
	if SaveManager != null and SaveManager.has_method("save_game"):
		SaveManager.save_game("banshee_wolf_clear", flow.get_parent())


func save_third_wave_progress(reason: String):
	if SaveManager != null and SaveManager.has_method("save_game"):
		SaveManager.save_game(reason, flow.get_parent())
