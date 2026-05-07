extends RefCounted
class_name BansheeVillageStageRules

const STAGE_INTRO = "intro"
const STAGE_COMBAT_ACTIVE = "combat_active"
const STAGE_READY_TO_REPORT = "ready_to_report"
const STAGE_DULLUHAN_AVAILABLE = "dulluhan_available"
const STAGE_REPORT_COMPLETE = "report_complete"
const STAGE_WOLF_HUNT_READY = "wolf_hunt_ready"
const STAGE_WOLF_HUNT_CLEARED = "wolf_hunt_cleared"
const STAGE_VILLAGE_CLEARED_LEGACY = "village_cleared"
const STAGE_FINAL_DULLUHAN_READY = "final_dulluhan_ready"
const STAGE_VINCENT_HOUSE_AVAILABLE = "vincent_house_available"
const STAGE_THIRD_WAVE_ELDER_READY = "third_wave_elder_ready"
const STAGE_THIRD_WAVE_ACTIVE = "third_wave_active"
const STAGE_THIRD_WAVE_CLEARED = "third_wave_cleared"
const STAGE_BISHOP_PATH_READY = "bishop_path_ready"


static func get_valid_stage(stage: String) -> String:
	if stage == STAGE_VILLAGE_CLEARED_LEGACY:
		return STAGE_WOLF_HUNT_CLEARED
	if (
		stage == STAGE_COMBAT_ACTIVE
		or stage == STAGE_READY_TO_REPORT
		or stage == STAGE_DULLUHAN_AVAILABLE
		or stage == STAGE_REPORT_COMPLETE
		or stage == STAGE_WOLF_HUNT_READY
		or stage == STAGE_WOLF_HUNT_CLEARED
		or stage == STAGE_FINAL_DULLUHAN_READY
		or stage == STAGE_VINCENT_HOUSE_AVAILABLE
		or stage == STAGE_THIRD_WAVE_ELDER_READY
		or stage == STAGE_THIRD_WAVE_ACTIVE
		or stage == STAGE_THIRD_WAVE_CLEARED
		or stage == STAGE_BISHOP_PATH_READY
	):
		return stage

	return STAGE_INTRO


static func infer_dulluhan_transformation_granted_from_stage(stage: String) -> bool:
	return (
		stage == STAGE_WOLF_HUNT_READY
		or stage == STAGE_REPORT_COMPLETE
		or stage == STAGE_WOLF_HUNT_CLEARED
		or stage == STAGE_FINAL_DULLUHAN_READY
		or stage == STAGE_VINCENT_HOUSE_AVAILABLE
		or stage == STAGE_THIRD_WAVE_ELDER_READY
		or stage == STAGE_THIRD_WAVE_ACTIVE
		or stage == STAGE_THIRD_WAVE_CLEARED
		or stage == STAGE_BISHOP_PATH_READY
	)


static func infer_vincent_house_dialogue_completed_from_stage(stage: String) -> bool:
	return (
		stage == STAGE_THIRD_WAVE_ELDER_READY
		or stage == STAGE_THIRD_WAVE_ACTIVE
		or stage == STAGE_THIRD_WAVE_CLEARED
		or stage == STAGE_BISHOP_PATH_READY
	)


static func infer_bishop_confrontation_accepted_from_stage(stage: String) -> bool:
	return stage == STAGE_BISHOP_PATH_READY


static func is_wolf_hunt_stage(stage: String) -> bool:
	return stage == STAGE_WOLF_HUNT_READY or stage == STAGE_REPORT_COMPLETE


static func is_third_wave_stage(stage: String) -> bool:
	return (
		stage == STAGE_THIRD_WAVE_ELDER_READY
		or stage == STAGE_THIRD_WAVE_ACTIVE
		or stage == STAGE_THIRD_WAVE_CLEARED
		or stage == STAGE_BISHOP_PATH_READY
	)


static func is_third_wave_combat_stage(stage: String) -> bool:
	return stage == STAGE_THIRD_WAVE_ELDER_READY or stage == STAGE_THIRD_WAVE_ACTIVE
