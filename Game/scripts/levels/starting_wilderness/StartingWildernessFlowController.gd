extends Node

const LEVEL_STATE_VERSION: int = 1
const BANSHEE_ENCOUNTER_CONTROLLER_SCRIPT = preload("res://scripts/levels/shared/BansheeEncounterController.gd")
const DEFAULT_STORY_DIALOGUE_PROFILE: DialogueProfile = preload("res://resources/dialogue/levels/starting_wilderness/starting_wilderness_villager_story_profile.tres")

const DIALOGUE_KEY_INTRO := &"intro"
const DIALOGUE_KEY_BANSHEES_ACTIVE := &"banshees_active"
const DIALOGUE_KEY_WOLF_UNLOCKED := &"wolf_unlocked"
const DIALOGUE_KEY_VINCENT_REVEALED := &"vincent_revealed"
const DIALOGUE_KEY_BISHOP_AVAILABLE := &"bishop_available"
const DIALOGUE_KEY_BISHOP_DEFEATED := &"bishop_defeated"

const QUEST_BANSHEE_VILLAGE_BISHOP: String = "banshee_village_bishop"
const QUEST_STAGE_BISHOP_DEFEATED: String = "bishop_defeated"
const QUEST_STAGE_REQUEST_AVAILABLE: String = "request_available"
const QUEST_STAGE_ACCEPTED: String = "accepted"
const STORY_FLAG_VINCENT_HOUSE_DIALOGUE_COMPLETED: String = "vincent_house_dialogue_completed"
const STORY_FLAG_WOLF_TRANSFORMATION_UNLOCKED: String = "wolf_transformation_unlocked_by_dulluhan"
const BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED: String = "corrupted_strong_ranged"
const BANSHEE_VARIANT_CORRUPTED_MELEE: String = "corrupted_melee"
const DEV_PRESET_INTRO: String = "intro"
const DEV_PRESET_BANSHEES_ACTIVE: String = "banshees_active"
const DEV_PRESET_WOLF_UNLOCKED: String = "wolf_unlocked"
const DEV_PRESET_VINCENT_REVEALED: String = "vincent_revealed"
const DEV_PRESET_BISHOP_AVAILABLE: String = "bishop_available"
const DEV_PRESET_BISHOP_DEFEATED: String = "bishop_defeated"
const VILLAGER_BANSHEE_DEFEAT_RESUME_PATROL: String = "resume_patrol"
const VILLAGER_BANSHEE_AGGRO_IGNORE: String = "ignore"

@export var villager_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs/MaleVillager")
@export var banshee_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/HostileNPCs/Banshee")
@export var npc_root_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs")
@export var hostile_root_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/HostileNPCs")
@export var patrol_path_from_villager: NodePath = NodePath("../../../../Markers/PatrolPaths/VillagerPath")
@export var patrol_path_from_banshee: NodePath = NodePath("../../../../Markers/PatrolPaths/VillagerPath")
@export var assigned_villager_path_from_banshee: NodePath = NodePath("../../NPCs/MaleVillager")
@export var hidden_banshee_alpha: float = 0.2
@export var passive_banshee_alpha: float = 0.2
@export var respawn_delay_seconds: float = 10.0
@export var story_dialogue_profile: DialogueProfile = DEFAULT_STORY_DIALOGUE_PROFILE

var villager: Node
var banshee: Node
var encounter_controller: BansheeEncounterController
var saved_villager_states: Dictionary = {}
var location_exit_save_pending: bool = false


func _ready():
	villager = get_node_or_null(villager_path)
	banshee = get_node_or_null(banshee_path)
	wire_patrol_nodes()
	setup_encounter_controller()
	apply_dev_start_preset()
	apply_story_dialogue()


func collect_level_state() -> Dictionary:
	var encounter_state: Dictionary = {}
	if encounter_controller != null:
		encounter_state = encounter_controller.collect_level_state()

	return {
		"state_version": LEVEL_STATE_VERSION,
		"dialogue_key": str(get_dialogue_key_for_story()),
		"encounter": encounter_state,
		"villagers": collect_villager_states(),
	}


func apply_level_state(state: Dictionary):
	location_exit_save_pending = false
	wire_patrol_nodes()
	ensure_encounter_controller()
	saved_villager_states = {}
	if SaveManager != null:
		saved_villager_states = SaveManager.parse_actor_snapshot_lookup(state.get("villagers", []))
	restore_saved_villager_states()

	var encounter_state: Dictionary = {}
	var raw_encounter_state: Variant = state.get("encounter", {})
	if raw_encounter_state is Dictionary:
		encounter_state = raw_encounter_state
	if encounter_controller != null:
		encounter_controller.apply_level_state(encounter_state)

	apply_starting_wilderness_villager_policy()
	apply_story_dialogue()


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	if int(state.get("state_version", 0)) > LEVEL_STATE_VERSION:
		messages.append("StartingWilderness save state version %d is newer than supported version %d." % [int(state.get("state_version", 0)), LEVEL_STATE_VERSION])
	if not (state.get("villagers", []) is Array):
		messages.append("StartingWilderness save has malformed villagers snapshot data.")
	var raw_encounter_state: Variant = state.get("encounter", {})
	if state.has("encounter") and not (raw_encounter_state is Dictionary):
		messages.append("StartingWilderness save has malformed encounter state.")
	if villager == null:
		messages.append("StartingWildernessFlowController could not find villager at %s." % villager_path)
	if banshee == null:
		messages.append("StartingWildernessFlowController could not find banshee at %s." % banshee_path)
	if encounter_controller != null and raw_encounter_state is Dictionary:
		var encounter_state: Dictionary = raw_encounter_state
		messages.append_array(encounter_controller.validate_level_state(encounter_state))
	return messages


func uses_level_owned_hostile_state() -> bool:
	return true


func uses_level_owned_villager_state() -> bool:
	return true


func prepare_for_route_exit():
	location_exit_save_pending = true
	if encounter_controller != null:
		encounter_controller.prepare_for_route_exit()


func handle_level_interaction(_interactable: Node2D, _player: Node2D) -> bool:
	return false


func apply_dev_start_preset() -> bool:
	if SaveManager == null or not SaveManager.has_method("consume_pending_dev_start_preset"):
		return false

	var preset: String = SaveManager.consume_pending_dev_start_preset(get_parent().scene_file_path)
	if preset == "":
		return false
	if not is_valid_dev_preset(preset):
		return false

	apply_dev_story_state(preset)
	apply_level_state(build_dev_level_state())
	return true


func is_valid_dev_preset(preset: String) -> bool:
	return [
		DEV_PRESET_INTRO,
		DEV_PRESET_BANSHEES_ACTIVE,
		DEV_PRESET_WOLF_UNLOCKED,
		DEV_PRESET_VINCENT_REVEALED,
		DEV_PRESET_BISHOP_AVAILABLE,
		DEV_PRESET_BISHOP_DEFEATED,
	].has(preset)


func apply_dev_story_state(preset: String):
	if SaveManager == null:
		return

	var banshees_active: bool = preset != DEV_PRESET_INTRO
	var wolf_unlocked: bool = [
		DEV_PRESET_WOLF_UNLOCKED,
		DEV_PRESET_VINCENT_REVEALED,
		DEV_PRESET_BISHOP_AVAILABLE,
		DEV_PRESET_BISHOP_DEFEATED,
	].has(preset)
	var vincent_revealed: bool = [
		DEV_PRESET_VINCENT_REVEALED,
		DEV_PRESET_BISHOP_AVAILABLE,
		DEV_PRESET_BISHOP_DEFEATED,
	].has(preset)
	var bishop_available: bool = preset == DEV_PRESET_BISHOP_AVAILABLE
	var bishop_defeated: bool = preset == DEV_PRESET_BISHOP_DEFEATED

	if SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(STORY_FLAG_WOLF_TRANSFORMATION_UNLOCKED, wolf_unlocked)
		SaveManager.set_story_flag(STORY_FLAG_VINCENT_HOUSE_DIALOGUE_COMPLETED, vincent_revealed)
	if SaveManager.has_method("unlock_upgrade") and SaveManager.has_method("lock_upgrade"):
		if wolf_unlocked:
			SaveManager.unlock_upgrade(&"wolf_transformation")
			if SaveManager.has_method("set_stat_level"):
				SaveManager.set_stat_level(&"wolf_transformation", 0)
		else:
			SaveManager.lock_upgrade(&"wolf_transformation")
	if SaveManager.has_method("set_quest_stage"):
		var bishop_stage: String = SaveManager.QUEST_STAGE_NOT_AVAILABLE
		if bishop_available:
			bishop_stage = SaveManager.QUEST_STAGE_REQUEST_AVAILABLE
		elif bishop_defeated:
			bishop_stage = SaveManager.QUEST_STAGE_BISHOP_DEFEATED
		SaveManager.set_quest_stage(QUEST_BANSHEE_VILLAGE_BISHOP, bishop_stage)
	if SaveManager.has_method("set_banshee_world_rule"):
		SaveManager.set_banshee_world_rule("banshees_hostile_enabled", banshees_active)
		SaveManager.set_banshee_world_rule("player_can_damage_banshees", banshees_active)
		SaveManager.set_banshee_world_rule("wolf_permanent_clear_enabled", wolf_unlocked)
		SaveManager.set_banshee_world_rule("combat_variant", BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED if vincent_revealed or bishop_defeated else BANSHEE_VARIANT_CORRUPTED_MELEE)
		SaveManager.set_banshee_world_rule("vincent_upgrades_enabled", vincent_revealed or bishop_defeated)


func build_dev_level_state() -> Dictionary:
	return {
		"state_version": LEVEL_STATE_VERSION,
		"dialogue_key": str(get_dialogue_key_for_story()),
		"encounter": {
			"state_version": 2,
			"temporarily_cleared_banshee_paths": [],
			"permanently_cleared_banshee_paths": [],
			"banshees": [],
		},
		"villagers": [],
	}


func wire_patrol_nodes():
	if villager == null:
		villager = get_node_or_null(villager_path)
	if banshee == null:
		banshee = get_node_or_null(banshee_path)

	if villager != null:
		villager.set("patrol_path", patrol_path_from_villager)
		villager.set("patrol_ping_pong", false)
		apply_starting_wilderness_villager_policy()
		if villager.has_method("refresh_patrol_points"):
			villager.refresh_patrol_points()

	if banshee != null:
		banshee.set("patrol_path", patrol_path_from_banshee)
		banshee.set("patrol_ping_pong", false)
		banshee.set("assigned_villager_path", assigned_villager_path_from_banshee)
		if banshee.has_method("setup_villager_stalk_behavior"):
			banshee.setup_villager_stalk_behavior()
		if banshee.has_method("refresh_patrol_points"):
			banshee.refresh_patrol_points()


func setup_encounter_controller():
	if encounter_controller != null:
		return

	encounter_controller = BANSHEE_ENCOUNTER_CONTROLLER_SCRIPT.new()
	encounter_controller.name = "BansheeEncounterController"
	encounter_controller.state_root_path = NodePath("../..")
	encounter_controller.hostile_root_path = NodePath("../../PlayableWorld/Environment/Characters/HostileNPCs")
	encounter_controller.hidden_banshee_alpha = hidden_banshee_alpha
	encounter_controller.passive_banshee_alpha = passive_banshee_alpha
	encounter_controller.respawn_delay_seconds = respawn_delay_seconds
	add_child(encounter_controller)


func ensure_encounter_controller():
	if encounter_controller == null:
		setup_encounter_controller()


func collect_villager_states() -> Array:
	if SaveManager == null or location_exit_save_pending:
		return []

	var npc_root: Node = get_node_or_null(npc_root_path)
	return SaveManager.collect_story_actor_states(get_parent(), npc_root, "villagers")


func restore_saved_villager_states():
	if SaveManager == null:
		return

	SaveManager.apply_story_actor_states(get_parent(), saved_villager_states)
	apply_starting_wilderness_villager_policy()


func apply_starting_wilderness_villager_policy():
	if villager == null:
		return

	villager.set("assigned_banshee_defeat_behavior", VILLAGER_BANSHEE_DEFEAT_RESUME_PATROL)
	villager.set("banshee_aggro_pause_behavior", VILLAGER_BANSHEE_AGGRO_IGNORE)
	if villager.has_method("reset_banshee_stalk_state"):
		villager.reset_banshee_stalk_state()


func apply_story_dialogue():
	if villager == null or story_dialogue_profile == null:
		return

	var sequence: DialogueSequence = story_dialogue_profile.get_sequence(get_dialogue_key_for_story())
	if sequence == null:
		return

	if villager.has_method("set_dialogue_override"):
		villager.set_dialogue_override(sequence)
	else:
		villager.set("dialogue_override_sequence", sequence)


func get_dialogue_key_for_story() -> StringName:
	if is_bishop_defeated():
		return DIALOGUE_KEY_BISHOP_DEFEATED
	if is_bishop_available():
		return DIALOGUE_KEY_BISHOP_AVAILABLE
	if is_vincent_revealed():
		return DIALOGUE_KEY_VINCENT_REVEALED
	if is_wolf_unlocked():
		return DIALOGUE_KEY_WOLF_UNLOCKED
	if are_banshees_active():
		return DIALOGUE_KEY_BANSHEES_ACTIVE

	return DIALOGUE_KEY_INTRO


func is_bishop_defeated() -> bool:
	return get_bishop_quest_stage() == QUEST_STAGE_BISHOP_DEFEATED


func is_bishop_available() -> bool:
	var stage: String = get_bishop_quest_stage()
	return stage == QUEST_STAGE_REQUEST_AVAILABLE or stage == QUEST_STAGE_ACCEPTED


func is_vincent_revealed() -> bool:
	if SaveManager != null and SaveManager.has_method("get_story_flag") and SaveManager.get_story_flag(STORY_FLAG_VINCENT_HOUSE_DIALOGUE_COMPLETED):
		return true

	var rules: Dictionary = get_banshee_world_rules()
	return str(rules.get("combat_variant", "")) == BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED


func is_wolf_unlocked() -> bool:
	if SaveManager == null:
		return false

	if SaveManager.has_method("get_story_flag") and SaveManager.get_story_flag(STORY_FLAG_WOLF_TRANSFORMATION_UNLOCKED):
		return true

	if SaveManager.has_method("get_upgrade_state"):
		var upgrade_state: Dictionary = SaveManager.get_upgrade_state()
		var unlocked: Variant = upgrade_state.get("unlocked", {})
		return unlocked is Dictionary and bool(unlocked.get("wolf_transformation", false))

	return false


func are_banshees_active() -> bool:
	return bool(get_banshee_world_rules().get("banshees_hostile_enabled", false))


func get_bishop_quest_stage() -> String:
	if SaveManager != null and SaveManager.has_method("get_quest_stage"):
		return str(SaveManager.get_quest_stage(QUEST_BANSHEE_VILLAGE_BISHOP))

	return ""


func get_banshee_world_rules() -> Dictionary:
	if SaveManager != null and SaveManager.has_method("get_banshee_world_rules"):
		return SaveManager.get_banshee_world_rules()

	return {}
