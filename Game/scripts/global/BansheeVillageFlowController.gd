extends Node

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
const DEFAULT_ELDER_POST_TRANSFORMATION_SEQUENCE: DialogueSequence = preload("res://resources/dialogue/banshee_village_elder_post_transformation.tres")
const DEFAULT_ELDER_WOLF_HUNT_CLEARED_SEQUENCE: DialogueSequence = preload("res://resources/dialogue/banshee_village_elder_village_cleared.tres")
const DEFAULT_ELDER_FINAL_DULLUHAN_COMPLETE_SEQUENCE: DialogueSequence = preload("res://resources/dialogue/banshee_village_elder_final_dulluhan_complete.tres")
const THIRD_WAVE_ELDER_DIALOGUE_TEXT = "Sorry to trouble you with this a third time but do you mind? Also be careful, these banshees seem stronger for some reason"
const SECOND_HUNT_ALREADY_CLEARED_DIALOGUE_TEXT = "You already took care of them? I was about to ask for your help again. Thank you. It looks like the village is finally quiet for now."
const THIRD_WAVE_ALREADY_CLEARED_DIALOGUE_TEXT = "You already did what I was going to ask? Thank you, and be careful. These banshees seemed stronger for some reason."
const BISHOP_DIRECTION_DIALOGUE_TEXT = "The bishop is south of here. If you want to stop whoever is corrupting these banshees, follow the southern path and confront him."
const BANSHEE_CLEAR_RESPAWN = "respawn"
const BANSHEE_CLEAR_TEMPORARY_WOLF = "temporary_wolf_clear"
const BANSHEE_CLEAR_PERMANENT_WOLF = "permanent_wolf_clear"
const BANSHEE_VARIANT_CORRUPTED_MELEE = "corrupted_melee"
const BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED = "corrupted_strong_ranged"
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
const LEVEL_STATE_VERSION = 5
const VINCENT_HOUSE_INTERIOR_ID = "vincent_house"
const VINCENT_HOUSE_DIALOGUE_FLAG = "vincent_house_dialogue_completed"
const BISHOP_CONFRONTATION_ACCEPTED_FLAG = "bishop_confrontation_accepted"
const WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG = "wolf_transformation_unlocked_by_dulluhan"
const DIALOGUE_CHOICE_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/DialogueChoiceBubble.tscn")
const BISHOP_CHOICE_PROMPT_TEXT = "Confront the bishop?"
const STORY_TRANSFORM_PROMPT_TEXT = "Press Q to transform."
const FINAL_WOLF_INSTRUCTION_TEXT = "You cannot hold the form forever.\nYour own transformations last 30 seconds.\nPress Tab to view transformation stats."

@export_enum(
	"none",
	"start",
	"elder_quest_accepted",
	"first_banshee_report_ready",
	"elder_report_complete_dulluhan_visible",
	"dulluhan_transformation_unlocked",
	"second_banshee_report_ready",
	"third_banshee_report_ready"
) var dev_start_preset: String = DEV_PRESET_NONE
@export var player_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/Saorise")
@export var npc_root_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs")
@export var hostile_root_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/HostileNPCs")
@export var elder_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs/ElderVillager")
@export var dulluhan_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs/Dulluhan")
@export var exterior_vincent_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs/Vincent")
@export var vincent_house_path: NodePath = NodePath("../PlayableWorld/Environment/Buildings/Houses/VincentHouse")
@export var west_route_exit_path: NodePath = NodePath("../PlayableWorld/Environment/Interactables/RouteExits/WestExit")
@export var south_route_exit_path: NodePath = NodePath("../PlayableWorld/Environment/Interactables/RouteExits/SouthExit")
@export var east_route_exit_path: NodePath = NodePath("../PlayableWorld/Environment/Interactables/RouteExits/EastExit")
@export var exterior_player_parent_path: NodePath = NodePath("../PlayableWorld/Environment/Characters")
@export var vincent_house_interior_path: NodePath = NodePath("../PlayableWorld/Environment/InteriorRooms/VincentHouseInterior")
@export var vincent_house_interior_player_parent_path: NodePath = NodePath("../PlayableWorld/Environment/InteriorRooms/VincentHouseInterior/PlayableWorld/Environment/Characters")
@export var vincent_house_return_marker_path: NodePath = NodePath("../PlayableWorld/Markers/Entrances/VincentHouseFront")
@export var kill_counter_path: NodePath = NodePath("../HUD/BansheeKillCounter")
@export var hidden_banshee_alpha: float = 0.2
@export var respawn_delay_seconds: float = 10.0
@export var report_kill_threshold: int = 10
@export var final_dulluhan_marker_path: NodePath = NodePath("../PlayableWorld/Markers/Entrances/VincentHouseFront")
@export var vincent_beside_elder_marker_path: NodePath = NodePath("../PlayableWorld/Markers/StoryPositions/VincentBesideElder")
@export var final_dulluhan_position: Vector2 = Vector2(1042, 577)
@export_enum("respawn", "temporary_wolf_clear", "permanent_wolf_clear") var transformed_banshee_clear_policy: String = BANSHEE_CLEAR_PERMANENT_WOLF
@export var elder_reveal_sequence: DialogueSequence
@export var elder_waiting_sequence: DialogueSequence
@export var elder_respawning_sequence: DialogueSequence
@export var elder_post_transformation_sequence: DialogueSequence = DEFAULT_ELDER_POST_TRANSFORMATION_SEQUENCE
@export var elder_wolf_hunt_cleared_sequence: DialogueSequence = DEFAULT_ELDER_WOLF_HUNT_CLEARED_SEQUENCE
@export var elder_final_dulluhan_complete_sequence: DialogueSequence = DEFAULT_ELDER_FINAL_DULLUHAN_COMPLETE_SEQUENCE
@export var male_stalked_sequence: DialogueSequence
@export var female_stalked_sequence: DialogueSequence
@export var male_clear_sequence: DialogueSequence
@export var female_clear_sequence: DialogueSequence

var quest_stage: String = STAGE_INTRO
var banshee_kill_count: int = 0
var cleared_villager_paths: Dictionary = {}
var revealed_banshee_paths: Dictionary = {}
var permanently_cleared_banshee_paths: Dictionary = {}
var defeated_banshees: Dictionary = {}
var saved_banshee_states: Dictionary = {}
var saved_villager_states: Dictionary = {}
var player: Node
var elder: Node
var dulluhan: Node
var exterior_vincent: Node2D
var vincent_house: Node2D
var vincent_house_interior: Node2D
var west_route_exit: Node
var south_route_exit: Node
var east_route_exit: Node
var elder_flag: EffectList
var dulluhan_flag: EffectList
var kill_counter: Label
var elder_choice_bubble: DialogueChoiceBubble
var banshees: Array[Node] = []
var state_generation: int = 0
var final_dulluhan_teaser_completed: bool = false
var story_transform_prompt_consumed: bool = false
var story_wolf_lock_active: bool = false
var final_wolf_instruction_shown: bool = false
var active_interior_id: String = ""
var third_wave_spawned: bool = false
var dulluhan_transformation_granted_for_level: bool = false
var vincent_house_dialogue_completed_for_level: bool = false
var bishop_confrontation_accepted_for_level: bool = false
var dulluhan_story_origin_position: Vector2 = Vector2.ZERO
var story_prompt_label: Label
var story_prompt_generation: int = 0


func _ready():
	player = get_node_or_null(player_path)
	elder = get_node_or_null(elder_path)
	dulluhan = get_node_or_null(dulluhan_path)
	exterior_vincent = get_node_or_null(exterior_vincent_path) as Node2D
	vincent_house = get_node_or_null(vincent_house_path) as Node2D
	vincent_house_interior = get_node_or_null(vincent_house_interior_path) as Node2D
	west_route_exit = get_node_or_null(west_route_exit_path)
	south_route_exit = get_node_or_null(south_route_exit_path)
	east_route_exit = get_node_or_null(east_route_exit_path)
	if elder != null:
		elder_flag = elder.get_node_or_null("Effects") as EffectList
		if elder_flag == null:
			elder_flag = elder.get_node_or_null("Flag") as EffectList
	if dulluhan != null:
		if dulluhan is Node2D:
			dulluhan_story_origin_position = (dulluhan as Node2D).global_position
		dulluhan_flag = dulluhan.get_node_or_null("Effects") as EffectList
		if dulluhan_flag == null:
			dulluhan_flag = dulluhan.get_node_or_null("Flag") as EffectList
	kill_counter = get_node_or_null(kill_counter_path) as Label
	banshees = get_banshees()

	connect_player_interactions()
	connect_elder_dialogue()
	connect_dulluhan_story()
	connect_exterior_vincent_dialogue()
	connect_vincent_house_interior()
	connect_banshees()
	set_interior_active(vincent_house_interior, false)
	if is_save_load_pending_for_this_level():
		return
	if not apply_dev_start_preset():
		apply_intro_defaults()


func collect_level_state() -> Dictionary:
	return {
		"state_version": LEVEL_STATE_VERSION,
		"quest_stage": quest_stage,
		"banshee_kill_count": banshee_kill_count,
		"revealed_banshee_paths": revealed_banshee_paths.keys(),
		"permanently_cleared_banshee_paths": permanently_cleared_banshee_paths.keys(),
		"final_dulluhan_teaser_completed": final_dulluhan_teaser_completed,
		"story_transform_prompt_consumed": story_transform_prompt_consumed,
		"story_wolf_lock_active": story_wolf_lock_active,
		"final_wolf_instruction_shown": final_wolf_instruction_shown,
		"active_interior_id": active_interior_id,
		"third_wave_spawned": third_wave_spawned,
		"dulluhan_transformation_granted_for_level": dulluhan_transformation_granted_for_level,
		"vincent_house_dialogue_completed_for_level": vincent_house_dialogue_completed_for_level,
		"bishop_confrontation_accepted_for_level": bishop_confrontation_accepted_for_level,
		"dulluhan": collect_dulluhan_state(),
		"banshees": collect_banshee_states(),
		"villagers": collect_villager_states(),
	}


func is_save_load_pending_for_this_level() -> bool:
	return SaveManager != null and SaveManager.has_method("is_scene_load_pending_for") and SaveManager.is_scene_load_pending_for(get_parent().scene_file_path)


func uses_level_owned_hostile_state() -> bool:
	return true


func uses_level_owned_villager_state() -> bool:
	return true


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	var state_version: int = int(state.get("state_version", 0))
	if state_version > LEVEL_STATE_VERSION:
		messages.append("BansheeVillage save state version %d is newer than supported version %d." % [state_version, LEVEL_STATE_VERSION])

	var saved_stage: String = str(state.get("quest_stage", STAGE_INTRO))
	if saved_stage != get_valid_stage(saved_stage):
		messages.append("BansheeVillage save has invalid quest_stage '%s'." % saved_stage)

	if not (state.get("banshees", []) is Array):
		messages.append("BansheeVillage save has malformed banshees snapshot data.")
	if not (state.get("villagers", []) is Array):
		messages.append("BansheeVillage save has malformed villagers snapshot data.")

	if elder == null:
		messages.append("BansheeVillageFlowController could not find elder at %s." % elder_path)
	if kill_counter == null:
		messages.append("BansheeVillageFlowController could not find kill counter at %s." % kill_counter_path)
	if dulluhan == null:
		messages.append("BansheeVillageFlowController could not find Dulluhan at %s." % dulluhan_path)
	if exterior_vincent == null:
		messages.append("BansheeVillageFlowController could not find exterior Vincent at %s." % exterior_vincent_path)
	if vincent_house == null:
		messages.append("BansheeVillageFlowController could not find VincentHouse at %s." % vincent_house_path)
	if vincent_house_interior == null:
		messages.append("BansheeVillageFlowController could not find VincentHouseInterior at %s." % vincent_house_interior_path)
	if west_route_exit == null:
		messages.append("BansheeVillageFlowController could not find west route exit at %s." % west_route_exit_path)
	if south_route_exit == null:
		messages.append("BansheeVillageFlowController could not find south route exit at %s." % south_route_exit_path)
	if east_route_exit == null:
		messages.append("BansheeVillageFlowController could not find east route exit at %s." % east_route_exit_path)
	if get_node_or_null(exterior_player_parent_path) == null:
		messages.append("BansheeVillageFlowController could not find exterior player parent at %s." % exterior_player_parent_path)
	if get_node_or_null(vincent_house_interior_player_parent_path) == null:
		messages.append("BansheeVillageFlowController could not find VincentHouse interior player parent at %s." % vincent_house_interior_player_parent_path)
	if get_node_or_null(vincent_house_return_marker_path) == null:
		messages.append("BansheeVillageFlowController could not find VincentHouse return marker at %s." % vincent_house_return_marker_path)
	if get_node_or_null(vincent_beside_elder_marker_path) == null:
		messages.append("BansheeVillageFlowController could not find Vincent beside elder marker at %s." % vincent_beside_elder_marker_path)

	append_missing_actor_path_warnings(messages, state.get("banshees", []), "banshee")
	append_missing_actor_path_warnings(messages, state.get("villagers", []), "villager")
	append_missing_assigned_villager_warnings(messages)
	return messages


func append_missing_actor_path_warnings(messages: Array, raw_states: Variant, actor_label: String):
	if not (raw_states is Array):
		return

	var level: Node = get_parent()
	if level == null:
		return

	for raw_state in raw_states:
		if not (raw_state is Dictionary):
			messages.append("BansheeVillage save has malformed %s snapshot entry." % actor_label)
			continue

		var state: Dictionary = raw_state
		var actor_path: String = str(state.get("node_path", ""))
		if actor_path == "":
			messages.append("BansheeVillage save has %s snapshot with no node_path." % actor_label)
		elif level.get_node_or_null(NodePath(actor_path)) == null:
			messages.append("BansheeVillage save references missing %s '%s'." % [actor_label, actor_path])


func append_missing_assigned_villager_warnings(messages: Array):
	for banshee in banshees:
		if banshee == null or not banshee.has_method("has_assigned_villager"):
			continue

		if str(banshee.get("assigned_villager_path")) != "" and not bool(banshee.call("has_assigned_villager")):
			messages.append("%s has assigned_villager_path '%s' but no resolved villager." % [banshee.name, banshee.get("assigned_villager_path")])


func apply_level_state(state: Dictionary):
	state_generation += 1
	var normalized_state: Dictionary = normalize_level_state(state)
	quest_stage = get_valid_stage(str(normalized_state.get("quest_stage", STAGE_INTRO)))
	banshee_kill_count = maxi(int(normalized_state.get("banshee_kill_count", 0)), 0)
	final_dulluhan_teaser_completed = bool(normalized_state.get("final_dulluhan_teaser_completed", false))
	story_transform_prompt_consumed = bool(normalized_state.get("story_transform_prompt_consumed", false))
	story_wolf_lock_active = bool(normalized_state.get("story_wolf_lock_active", false))
	final_wolf_instruction_shown = bool(normalized_state.get("final_wolf_instruction_shown", false))
	active_interior_id = str(normalized_state.get("active_interior_id", ""))
	third_wave_spawned = bool(normalized_state.get("third_wave_spawned", false))
	dulluhan_transformation_granted_for_level = get_saved_bool(normalized_state, "dulluhan_transformation_granted_for_level", infer_dulluhan_transformation_granted_from_stage(quest_stage))
	vincent_house_dialogue_completed_for_level = get_saved_bool(normalized_state, "vincent_house_dialogue_completed_for_level", infer_vincent_house_dialogue_completed_from_stage(quest_stage))
	bishop_confrontation_accepted_for_level = get_saved_bool(normalized_state, "bishop_confrontation_accepted_for_level", infer_bishop_confrontation_accepted_from_stage(quest_stage))
	cleared_villager_paths = {}
	defeated_banshees.clear()
	permanently_cleared_banshee_paths = {}
	saved_banshee_states = parse_saved_banshee_states(normalized_state.get("banshees", []))
	saved_villager_states = SaveManager.parse_actor_snapshot_lookup(normalized_state.get("villagers", []))

	revealed_banshee_paths = {}
	var saved_revealed_paths: Variant = normalized_state.get("revealed_banshee_paths", [])
	if saved_revealed_paths is Array:
		for path in saved_revealed_paths:
			revealed_banshee_paths[str(path)] = true

	var saved_permanent_paths: Variant = normalized_state.get("permanently_cleared_banshee_paths", [])
	if saved_permanent_paths is Array:
		for path in saved_permanent_paths:
			permanently_cleared_banshee_paths[str(path)] = true

	apply_dulluhan_level_state(normalized_state.get("dulluhan", {}))
	sync_local_progression_flags_to_globals()
	reconcile_wolf_transformation_unlock_with_local_story()
	if quest_stage == STAGE_WOLF_HUNT_CLEARED or quest_stage == STAGE_FINAL_DULLUHAN_READY:
		story_wolf_lock_active = false
		story_transform_prompt_consumed = true
	if is_third_wave_stage():
		third_wave_spawned = true
		story_wolf_lock_active = false
		story_transform_prompt_consumed = true

	restore_saved_villager_states()
	restore_stage_world_state()
	restore_story_transformation_state()
	sync_story_wolf_transformation_lock()
	restore_active_interior_state()
	saved_banshee_states.clear()
	saved_villager_states.clear()


func normalize_level_state(state: Dictionary) -> Dictionary:
	var normalized_state: Dictionary = state.duplicate(true)
	var state_version: int = int(normalized_state.get("state_version", 0))
	normalized_state["state_version"] = clamp(state_version, 0, LEVEL_STATE_VERSION)
	return normalized_state


func get_saved_bool(state: Dictionary, key: String, default_value: bool) -> bool:
	if state.has(key):
		return bool(state.get(key))

	return default_value


func infer_dulluhan_transformation_granted_from_stage(stage: String) -> bool:
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


func infer_vincent_house_dialogue_completed_from_stage(stage: String) -> bool:
	return (
		stage == STAGE_THIRD_WAVE_ELDER_READY
		or stage == STAGE_THIRD_WAVE_ACTIVE
		or stage == STAGE_THIRD_WAVE_CLEARED
		or stage == STAGE_BISHOP_PATH_READY
	)


func infer_bishop_confrontation_accepted_from_stage(stage: String) -> bool:
	return stage == STAGE_BISHOP_PATH_READY


func sync_local_progression_flags_to_globals():
	if SaveManager == null or not SaveManager.has_method("set_story_flag"):
		return

	SaveManager.set_story_flag(VINCENT_HOUSE_DIALOGUE_FLAG, vincent_house_dialogue_completed_for_level)
	SaveManager.set_story_flag(BISHOP_CONFRONTATION_ACCEPTED_FLAG, bishop_confrontation_accepted_for_level)


func reconcile_wolf_transformation_unlock_with_local_story():
	if SaveManager == null:
		return

	if dulluhan_transformation_granted_for_level:
		if SaveManager.has_method("set_story_flag"):
			SaveManager.set_story_flag(WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG, true)
		if SaveManager.has_method("unlock_upgrade"):
			SaveManager.unlock_upgrade(&"wolf_transformation")
		if SaveManager.has_method("set_stat_level"):
			SaveManager.set_stat_level(&"wolf_transformation", 0)
		return

	if SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG, false)
	if SaveManager.has_method("lock_upgrade"):
		SaveManager.lock_upgrade(&"wolf_transformation")
		if player != null and player.has_method("get_current_form_id") and player.get_current_form_id() == &"wolf" and player.has_method("end_transformation_immediately"):
			player.end_transformation_immediately()
		return

	var upgrade_state: Dictionary = SaveManager.get_upgrade_state()
	var unlocked: Variant = upgrade_state.get("unlocked", {})
	if unlocked is Dictionary and bool(unlocked.get("wolf_transformation", false)):
		push_warning("SaveManager is missing lock_upgrade(); cannot lock pre-Dulluhan wolf transformation.")


func apply_dev_start_preset() -> bool:
	var preset: String = get_valid_dev_start_preset(dev_start_preset)
	if SaveManager != null and SaveManager.has_method("consume_pending_dev_start_preset"):
		var pending_preset: String = SaveManager.consume_pending_dev_start_preset(get_parent().scene_file_path)
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
	apply_level_state(build_dev_level_state(preset))
	if preset == DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED or preset == DEV_PRESET_SECOND_BANSHEE_REPORT_READY or preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY:
		apply_dev_transformation_unlock()
	call_deferred("clear_dev_preset_combat_state")

	return true


func get_valid_dev_start_preset(preset: String) -> String:
	if preset == DEV_PRESET_START:
		return preset
	if preset == DEV_PRESET_ELDER_QUEST_ACCEPTED:
		return preset
	if preset == DEV_PRESET_FIRST_BANSHEE_REPORT_READY:
		return preset
	if preset == DEV_PRESET_ELDER_REPORT_COMPLETE_DULLUHAN_VISIBLE:
		return preset
	if preset == DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED:
		return preset
	if preset == DEV_PRESET_SECOND_BANSHEE_REPORT_READY:
		return preset
	if preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY:
		return preset

	return DEV_PRESET_NONE


func build_dev_level_state(preset: String) -> Dictionary:
	var stage: String = STAGE_INTRO
	var kill_count: int = 0
	var permanent_paths: Array = []
	if preset == DEV_PRESET_ELDER_QUEST_ACCEPTED:
		stage = STAGE_COMBAT_ACTIVE
	elif preset == DEV_PRESET_FIRST_BANSHEE_REPORT_READY:
		stage = STAGE_READY_TO_REPORT
		kill_count = report_kill_threshold
	elif preset == DEV_PRESET_ELDER_REPORT_COMPLETE_DULLUHAN_VISIBLE:
		stage = STAGE_DULLUHAN_AVAILABLE
		kill_count = report_kill_threshold
	elif preset == DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED:
		stage = STAGE_WOLF_HUNT_READY
		kill_count = report_kill_threshold
	elif preset == DEV_PRESET_SECOND_BANSHEE_REPORT_READY:
		stage = STAGE_WOLF_HUNT_CLEARED
		kill_count = report_kill_threshold + banshees.size()
		permanent_paths = get_all_banshee_paths()
	elif preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY:
		stage = STAGE_THIRD_WAVE_CLEARED
		kill_count = report_kill_threshold + banshees.size()
		permanent_paths = get_all_banshee_paths()
	var dev_dulluhan_transformation_granted: bool = is_dev_preset_after_dulluhan_unlock(preset)

	return {
		"state_version": LEVEL_STATE_VERSION,
		"quest_stage": stage,
		"banshee_kill_count": kill_count,
		"revealed_banshee_paths": [],
		"permanently_cleared_banshee_paths": permanent_paths,
		"final_dulluhan_teaser_completed": preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY,
		"story_transform_prompt_consumed": preset != DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED,
		"story_wolf_lock_active": false,
		"final_wolf_instruction_shown": false,
		"active_interior_id": "",
		"third_wave_spawned": preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY,
		"dulluhan_transformation_granted_for_level": dev_dulluhan_transformation_granted,
		"vincent_house_dialogue_completed_for_level": preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY,
		"bishop_confrontation_accepted_for_level": false,
		"dulluhan": {},
		"banshees": [],
		"villagers": [],
	}


func is_dev_preset_after_dulluhan_unlock(preset: String) -> bool:
	return (
		preset == DEV_PRESET_DULLUHAN_TRANSFORMATION_UNLOCKED
		or preset == DEV_PRESET_SECOND_BANSHEE_REPORT_READY
		or preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY
	)


func get_all_banshee_paths() -> Array:
	var paths: Array = []
	for banshee in banshees:
		var banshee_path: String = get_relative_node_path(banshee)
		if banshee_path != "":
			paths.append(banshee_path)

	return paths


func apply_dev_story_flags(preset: String):
	if SaveManager == null or not SaveManager.has_method("set_story_flag"):
		return

	if preset == DEV_PRESET_THIRD_BANSHEE_REPORT_READY:
		SaveManager.set_story_flag(VINCENT_HOUSE_DIALOGUE_FLAG, true)
		SaveManager.set_story_flag(BISHOP_CONFRONTATION_ACCEPTED_FLAG, false)
	SaveManager.set_story_flag(WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG, is_dev_preset_after_dulluhan_unlock(preset))


func apply_dev_transformation_unlock():
	if SaveManager == null:
		return

	SaveManager.unlock_upgrade(&"wolf_transformation")
	SaveManager.set_stat_level(&"wolf_transformation", 0)
	if SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG, true)
	dulluhan_transformation_granted_for_level = true
	if dulluhan != null:
		if dulluhan.has_method("set_transformation_granted_for_story_save"):
			dulluhan.call("set_transformation_granted_for_story_save", true)
		else:
			dulluhan.set("transformation_granted", true)
	refresh_quest_presentation()
	refresh_story_transform_prompt()


func clear_dev_preset_combat_state():
	await get_tree().physics_frame
	await get_tree().physics_frame
	if CombatStateManager != null and CombatStateManager.has_method("clear_all"):
		CombatStateManager.clear_all()


func connect_player_interactions():
	if player == null:
		return

	if player.has_signal("interaction_requested"):
		var callback: Callable = Callable(self, "_on_player_interaction_requested")
		if not player.is_connected("interaction_requested", callback):
			player.connect("interaction_requested", callback)

	if player.has_signal("transformation_state_changed"):
		var transform_callback: Callable = Callable(self, "_on_player_transformation_state_changed")
		if not player.is_connected("transformation_state_changed", transform_callback):
			player.connect("transformation_state_changed", transform_callback)


func connect_elder_dialogue():
	if elder == null:
		return

	if elder.has_signal("dialogue_finished"):
		var callback: Callable = Callable(self, "_on_elder_dialogue_finished")
		if not elder.is_connected("dialogue_finished", callback):
			elder.connect("dialogue_finished", callback)


func connect_dulluhan_story():
	if dulluhan == null:
		return

	if dulluhan.has_signal("transformation_granted_for_story"):
		var granted_callback: Callable = Callable(self, "_on_dulluhan_transformation_granted_for_story")
		if not dulluhan.is_connected("transformation_granted_for_story", granted_callback):
			dulluhan.connect("transformation_granted_for_story", granted_callback)

	if dulluhan.has_signal("final_teaser_completed"):
		var final_callback: Callable = Callable(self, "_on_dulluhan_final_teaser_completed")
		if not dulluhan.is_connected("final_teaser_completed", final_callback):
			dulluhan.connect("final_teaser_completed", final_callback)


func connect_exterior_vincent_dialogue():
	if exterior_vincent == null:
		return

	if exterior_vincent.has_signal("dialogue_finished"):
		var callback: Callable = Callable(self, "_on_exterior_vincent_dialogue_finished")
		if not exterior_vincent.is_connected("dialogue_finished", callback):
			exterior_vincent.connect("dialogue_finished", callback)


func connect_vincent_house_interior():
	if vincent_house_interior == null:
		return

	if vincent_house_interior.has_signal("exit_requested"):
		var callback: Callable = Callable(self, "_on_vincent_house_exit_requested")
		if not vincent_house_interior.is_connected("exit_requested", callback):
			vincent_house_interior.connect("exit_requested", callback)

	var interior_vincent: Node = get_interior_vincent()
	if interior_vincent != null and interior_vincent.has_signal("dialogue_finished"):
		var vincent_callback: Callable = Callable(self, "_on_interior_vincent_dialogue_finished")
		if not interior_vincent.is_connected("dialogue_finished", vincent_callback):
			interior_vincent.connect("dialogue_finished", vincent_callback)


func get_interior_vincent() -> Node:
	if vincent_house_interior == null:
		return null

	if vincent_house_interior.has_method("get_vincent"):
		var raw_vincent: Variant = vincent_house_interior.call("get_vincent")
		if raw_vincent is Node:
			return raw_vincent

	return vincent_house_interior.get_node_or_null("PlayableWorld/Environment/Characters/Vincent")


func connect_banshees():
	for banshee in banshees:
		if banshee == null:
			continue

		if banshee.has_signal("defeated"):
			var defeated_callback: Callable = Callable(self, "_on_banshee_defeated")
			if not banshee.is_connected("defeated", defeated_callback):
				banshee.connect("defeated", defeated_callback)

		if banshee.has_signal("player_detected_for_reveal"):
			var reveal_callback: Callable = Callable(self, "_on_banshee_detected_player_for_reveal")
			if not banshee.is_connected("player_detected_for_reveal", reveal_callback):
				banshee.connect("player_detected_for_reveal", reveal_callback)


func get_banshees() -> Array[Node]:
	var hostile_root: Node = get_node_or_null(hostile_root_path)
	var found_banshees: Array[Node] = []
	if hostile_root == null:
		return found_banshees

	for child in hostile_root.get_children():
		if child.is_in_group("hostile_npcs"):
			found_banshees.append(child)

	return found_banshees


func collect_banshee_states() -> Array:
	var hostile_root: Node = get_node_or_null(hostile_root_path)
	return SaveManager.collect_story_actor_states(get_parent(), hostile_root, "hostile_npcs")


func collect_villager_states() -> Array:
	var npc_root: Node = get_node_or_null(npc_root_path)
	return SaveManager.collect_story_actor_states(get_parent(), npc_root, "villagers")


func collect_dulluhan_state() -> Dictionary:
	if dulluhan == null or not dulluhan.has_method("collect_story_save_state"):
		return {}

	var raw_state: Variant = dulluhan.call("collect_story_save_state")
	if raw_state is Dictionary:
		return raw_state

	return {}


func apply_dulluhan_level_state(raw_state: Variant):
	if dulluhan == null:
		return

	if raw_state is Dictionary:
		var dulluhan_state: Dictionary = raw_state
		if not dulluhan_state.is_empty() and dulluhan.has_method("apply_story_save_state"):
			dulluhan.call("apply_story_save_state", dulluhan_state)

	if dulluhan.has_method("set_transformation_granted_for_story_save"):
		dulluhan.call("set_transformation_granted_for_story_save", dulluhan_transformation_granted_for_level)
	else:
		dulluhan.set("transformation_granted", dulluhan_transformation_granted_for_level)


func parse_saved_banshee_states(raw_states: Variant) -> Dictionary:
	return SaveManager.parse_actor_snapshot_lookup(raw_states)


func apply_intro_defaults():
	state_generation += 1
	quest_stage = STAGE_INTRO
	banshee_kill_count = 0
	final_dulluhan_teaser_completed = false
	story_transform_prompt_consumed = false
	story_wolf_lock_active = false
	final_wolf_instruction_shown = false
	active_interior_id = ""
	third_wave_spawned = false
	dulluhan_transformation_granted_for_level = false
	vincent_house_dialogue_completed_for_level = false
	bishop_confrontation_accepted_for_level = false
	sync_local_progression_flags_to_globals()
	restore_active_interior_state()
	hide_story_prompt()
	cleared_villager_paths.clear()
	revealed_banshee_paths.clear()
	permanently_cleared_banshee_paths.clear()
	defeated_banshees.clear()
	saved_banshee_states.clear()
	saved_villager_states.clear()
	set_all_banshee_combat_variants(BANSHEE_VARIANT_CORRUPTED_MELEE)
	update_exterior_vincent_presentation()
	restore_stage_world_state()


func restore_stage_world_state():
	# Full restore is for fresh init, save load, and first quest activation only.
	# Mid-quest UI/dialogue updates should call refresh_quest_presentation() instead.
	refresh_quest_presentation()

	if quest_stage == STAGE_INTRO:
		apply_banshee_villager_presentation(false)
		return

	apply_banshee_villager_presentation(true)


func refresh_quest_presentation():
	# Presentation refresh must not reset actor position, health, death, or patrol state.
	sync_global_story_progress()
	if quest_stage == STAGE_INTRO:
		set_elder_sequence(elder_reveal_sequence)
	elif quest_stage == STAGE_THIRD_WAVE_ELDER_READY:
		if are_all_banshees_permanently_cleared():
			set_elder_sequence(create_third_wave_already_cleared_with_bishop_sequence())
		else:
			set_elder_sequence(create_third_wave_elder_sequence())
	elif quest_stage == STAGE_THIRD_WAVE_ACTIVE:
		set_elder_sequence(elder_waiting_sequence)
	elif quest_stage == STAGE_THIRD_WAVE_CLEARED:
		if is_bishop_confrontation_accepted():
			set_elder_sequence(elder_waiting_sequence)
		else:
			set_elder_sequence(create_bishop_direction_sequence())
	elif quest_stage == STAGE_BISHOP_PATH_READY:
		set_elder_sequence(elder_waiting_sequence)
	elif final_dulluhan_teaser_completed:
		set_elder_sequence(elder_final_dulluhan_complete_sequence if elder_final_dulluhan_complete_sequence != null else elder_wolf_hunt_cleared_sequence)
	elif quest_stage == STAGE_WOLF_HUNT_CLEARED:
		set_elder_sequence(elder_wolf_hunt_cleared_sequence if elder_wolf_hunt_cleared_sequence != null else elder_waiting_sequence)
	elif quest_stage == STAGE_FINAL_DULLUHAN_READY:
		set_elder_sequence(elder_wolf_hunt_cleared_sequence if elder_wolf_hunt_cleared_sequence != null else elder_waiting_sequence)
	elif quest_stage == STAGE_WOLF_HUNT_READY:
		if are_all_banshees_permanently_cleared():
			set_elder_sequence(create_single_page_dialogue_sequence(SECOND_HUNT_ALREADY_CLEARED_DIALOGUE_TEXT))
		else:
			set_elder_sequence(elder_post_transformation_sequence if elder_post_transformation_sequence != null else elder_respawning_sequence)
	elif quest_stage == STAGE_READY_TO_REPORT:
		set_elder_sequence(elder_respawning_sequence)
	elif quest_stage == STAGE_DULLUHAN_AVAILABLE:
		set_elder_sequence(elder_respawning_sequence)
	else:
		set_elder_sequence(elder_waiting_sequence)

	update_elder_flag()
	update_exterior_vincent_presentation()
	sync_vincent_house_occupancy()
	update_route_exit_gates()
	update_kill_counter()
	update_dulluhan_visibility()
	update_dulluhan_flag()
	refresh_story_transform_prompt()


func sync_global_story_progress():
	if SaveManager == null:
		return

	var banshee_hostile_enabled: bool = quest_stage != STAGE_INTRO
	var strong_banshees_enabled: bool = third_wave_spawned or is_third_wave_stage()
	if SaveManager.has_method("set_banshee_world_rule"):
		SaveManager.set_banshee_world_rule("banshees_hostile_enabled", banshee_hostile_enabled)
		SaveManager.set_banshee_world_rule("player_can_damage_banshees", banshee_hostile_enabled)
		SaveManager.set_banshee_world_rule("wolf_permanent_clear_enabled", has_wolf_transformation_upgrade())
		SaveManager.set_banshee_world_rule("combat_variant", BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED if strong_banshees_enabled else BANSHEE_VARIANT_CORRUPTED_MELEE)

	if SaveManager.has_method("set_quest_stage"):
		var current_bishop_quest_stage: String = "not_available"
		if SaveManager.has_method("get_quest_stage"):
			current_bishop_quest_stage = str(SaveManager.get_quest_stage("banshee_village_bishop"))
		if current_bishop_quest_stage == "bishop_defeated" or current_bishop_quest_stage == "ready_to_report" or current_bishop_quest_stage == "reported" or current_bishop_quest_stage == "reward_claimed":
			return
		if is_bishop_confrontation_accepted() or quest_stage == STAGE_BISHOP_PATH_READY:
			SaveManager.set_quest_stage("banshee_village_bishop", "accepted")
		elif quest_stage == STAGE_THIRD_WAVE_CLEARED or (quest_stage == STAGE_THIRD_WAVE_ELDER_READY and are_all_banshees_permanently_cleared()):
			SaveManager.set_quest_stage("banshee_village_bishop", "request_available")
		else:
			SaveManager.set_quest_stage("banshee_village_bishop", "not_available")


func create_third_wave_elder_sequence() -> DialogueSequence:
	return create_single_page_dialogue_sequence(THIRD_WAVE_ELDER_DIALOGUE_TEXT)


func create_bishop_direction_sequence() -> DialogueSequence:
	return create_single_page_dialogue_sequence(BISHOP_DIRECTION_DIALOGUE_TEXT)


func create_third_wave_already_cleared_with_bishop_sequence() -> DialogueSequence:
	var sequence := DialogueSequence.new()
	sequence.pages.append(THIRD_WAVE_ALREADY_CLEARED_DIALOGUE_TEXT)
	sequence.pages.append(BISHOP_DIRECTION_DIALOGUE_TEXT)
	return sequence


func create_single_page_dialogue_sequence(text: String) -> DialogueSequence:
	var sequence := DialogueSequence.new()
	sequence.pages.append(text)
	return sequence


func restore_saved_villager_states():
	SaveManager.apply_story_actor_states(get_parent(), saved_villager_states)


func apply_banshee_villager_presentation(combat_enabled: bool):
	for banshee in banshees:
		var banshee_path: String = get_relative_node_path(banshee)
		var saved_state: Dictionary = {}
		if saved_banshee_states.has(banshee_path):
			var raw_saved_state: Variant = saved_banshee_states[banshee_path]
			if raw_saved_state is Dictionary:
				saved_state = raw_saved_state

		var villager: Node = get_banshee_assigned_villager(banshee)
		var villager_path: String = get_relative_node_path(villager)
		var permanent_clear: bool = permanently_cleared_banshee_paths.has(banshee_path)
		var villager_is_clear: bool = permanent_clear or cleared_villager_paths.has(villager_path)
		var saved_dead: bool = bool(saved_state.get("dead", false))

		if permanent_clear or saved_dead or villager_is_clear:
			set_villager_clear_sequence(villager)
			complete_villager_banshee_story(villager)
			apply_cleared_banshee_state(banshee, saved_state)
			defeated_banshees[banshee] = true
			if saved_dead and not permanent_clear:
				schedule_banshee_respawn(banshee)
			continue

		set_villager_stalked_sequence(villager)
		if saved_state.is_empty() and saved_villager_states.is_empty():
			reset_villager_stalk_state(villager)
		apply_active_banshee_state(banshee, combat_enabled, saved_state)


func apply_active_banshee_state(banshee: Node, combat_enabled: bool, saved_state: Dictionary = {}):
	if banshee == null:
		return

	if banshee.has_method("set_combat_variant"):
		banshee.set_combat_variant(get_banshee_combat_variant_for_story())

	var banshee_path: String = get_relative_node_path(banshee)
	var is_revealed: bool = combat_enabled and revealed_banshee_paths.has(banshee_path)
	if saved_state.has("revealed"):
		is_revealed = combat_enabled and bool(saved_state.get("revealed", false))

	var alpha: float = hidden_banshee_alpha
	if is_revealed:
		alpha = 1.0

	if not saved_state.is_empty() and banshee.has_method("restore_from_story_save"):
		if third_wave_spawned or is_third_wave_stage():
			saved_state["combat_variant"] = BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED
		banshee.restore_from_story_save(saved_state, hidden_banshee_alpha, combat_enabled, is_revealed)
		return

	if banshee.has_method("restore_for_story_load"):
		banshee.restore_for_story_load(hidden_banshee_alpha, combat_enabled, is_revealed)
		return

	if banshee.has_method("restore_after_load"):
		banshee.restore_after_load()

	if banshee.has_method("set_story_combat_enabled"):
		if combat_enabled and banshee.has_method("enable_story_combat"):
			banshee.enable_story_combat(alpha)
		elif not combat_enabled and banshee.has_method("disable_story_combat"):
			banshee.disable_story_combat(alpha)
		else:
			banshee.set_story_combat_enabled(combat_enabled, alpha)

	if banshee.has_method("set_story_revealed"):
		banshee.set_story_revealed(is_revealed, hidden_banshee_alpha)


func apply_cleared_banshee_state(banshee: Node, saved_state: Dictionary = {}):
	if banshee == null:
		return

	if banshee.has_method("set_combat_variant"):
		banshee.set_combat_variant(get_banshee_combat_variant_for_story())

	var banshee_path: String = get_relative_node_path(banshee)
	revealed_banshee_paths.erase(banshee_path)

	if not saved_state.is_empty() and banshee.has_method("restore_dead_from_story_save"):
		if third_wave_spawned or is_third_wave_stage():
			saved_state["combat_variant"] = BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED
		banshee.restore_dead_from_story_save(saved_state, hidden_banshee_alpha)
	elif banshee.has_method("hide_as_story_defeated"):
		banshee.hide_as_story_defeated(hidden_banshee_alpha)


func get_banshee_combat_variant_for_story() -> String:
	if third_wave_spawned or is_third_wave_stage():
		return BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED

	return BANSHEE_VARIANT_CORRUPTED_MELEE


func set_all_banshee_combat_variants(variant: String):
	for banshee in banshees:
		if banshee != null and banshee.has_method("set_combat_variant"):
			banshee.set_combat_variant(variant)


func set_elder_sequence(sequence: DialogueSequence):
	if elder != null:
		set_villager_dialogue_override(elder, sequence)


func set_villager_stalked_sequence(villager: Node):
	if villager == null or villager == elder:
		return

	set_villager_dialogue_override(villager, get_villager_sequence(villager, true))


func set_villager_clear_sequence(villager: Node):
	if villager == null or villager == elder:
		return

	set_villager_dialogue_override(villager, get_villager_sequence(villager, false))


func complete_villager_banshee_story(villager: Node):
	if villager == null or villager == elder:
		return

	if villager.has_method("on_assigned_banshee_defeated"):
		villager.on_assigned_banshee_defeated()
	elif villager.has_method("complete_story_pause"):
		villager.complete_story_pause()


func set_villager_dialogue_override(villager: Node, sequence: DialogueSequence):
	if villager == null:
		return

	if villager.has_method("set_dialogue_override"):
		villager.set_dialogue_override(sequence)
	else:
		villager.set("dialogue_override_sequence", sequence)


func reset_villager_stalk_state(villager: Node):
	if villager == null or villager == elder:
		return

	if villager.has_method("reset_banshee_stalk_state"):
		villager.reset_banshee_stalk_state()


func get_villager_sequence(villager: Node, is_stalked: bool) -> DialogueSequence:
	var lower_name: String = villager.name.to_lower()
	var is_female: bool = lower_name.contains("female")
	if is_stalked:
		if is_female:
			return female_stalked_sequence

		return male_stalked_sequence

	if is_female:
		return female_clear_sequence

	return male_clear_sequence


func get_banshee_assigned_villager(banshee: Node) -> Node:
	if banshee != null and banshee.has_method("get_assigned_villager"):
		return banshee.get_assigned_villager()

	return null


func is_banshee_defeated_or_waiting(banshee: Node) -> bool:
	if banshee == null:
		return false

	if defeated_banshees.has(banshee):
		return true

	if bool(banshee.get("dead")):
		return true

	var health_node: Node = banshee.get_node_or_null("Health")
	if health_node != null and bool(health_node.get("dead")):
		return true

	return false


func get_relative_node_path(node: Node) -> String:
	var level: Node = get_parent()
	if level != null and node != null and level.is_ancestor_of(node):
		return str(level.get_path_to(node))

	return ""


func get_valid_stage(stage: String) -> String:
	if stage == STAGE_VILLAGE_CLEARED_LEGACY:
		return STAGE_WOLF_HUNT_CLEARED
	if stage == STAGE_COMBAT_ACTIVE or stage == STAGE_READY_TO_REPORT or stage == STAGE_DULLUHAN_AVAILABLE or stage == STAGE_REPORT_COMPLETE or stage == STAGE_WOLF_HUNT_READY or stage == STAGE_WOLF_HUNT_CLEARED or stage == STAGE_FINAL_DULLUHAN_READY or stage == STAGE_VINCENT_HOUSE_AVAILABLE or stage == STAGE_THIRD_WAVE_ELDER_READY or stage == STAGE_THIRD_WAVE_ACTIVE or stage == STAGE_THIRD_WAVE_CLEARED or stage == STAGE_BISHOP_PATH_READY:
		return stage

	return STAGE_INTRO


func has_wolf_transformation_upgrade() -> bool:
	if SaveManager == null:
		return false

	var upgrade_state: Dictionary = SaveManager.get_upgrade_state()
	var unlocked: Variant = upgrade_state.get("unlocked", {})
	return unlocked is Dictionary and bool(unlocked.get("wolf_transformation", false))


func begin_combat_stage():
	close_elder_choice_prompt(false)
	state_generation += 1
	quest_stage = STAGE_COMBAT_ACTIVE
	banshee_kill_count = 0
	third_wave_spawned = false
	cleared_villager_paths.clear()
	revealed_banshee_paths.clear()
	permanently_cleared_banshee_paths.clear()
	defeated_banshees.clear()
	set_all_banshee_combat_variants(BANSHEE_VARIANT_CORRUPTED_MELEE)
	restore_stage_world_state()


func begin_ready_to_report_stage():
	quest_stage = STAGE_READY_TO_REPORT
	refresh_quest_presentation()


func complete_report_stage():
	close_elder_choice_prompt(false)
	quest_stage = STAGE_DULLUHAN_AVAILABLE
	refresh_quest_presentation()


func begin_wolf_hunt_ready_stage():
	if quest_stage == STAGE_WOLF_HUNT_CLEARED:
		return

	if are_all_banshees_permanently_cleared():
		begin_wolf_hunt_cleared_stage()
		save_wolf_clear_progress()
		return

	quest_stage = STAGE_WOLF_HUNT_READY
	dulluhan_transformation_granted_for_level = true
	story_transform_prompt_consumed = false
	refresh_quest_presentation()
	sync_story_wolf_transformation_lock()
	save_wolf_clear_progress()


func begin_wolf_hunt_stage():
	if are_all_banshees_permanently_cleared():
		begin_wolf_hunt_cleared_stage()
		save_wolf_clear_progress()
		return

	quest_stage = STAGE_REPORT_COMPLETE
	dulluhan_transformation_granted_for_level = true
	refresh_quest_presentation()
	sync_story_wolf_transformation_lock()
	save_wolf_clear_progress()


func begin_third_wave_elder_ready_stage():
	state_generation += 1
	quest_stage = STAGE_THIRD_WAVE_ELDER_READY
	third_wave_spawned = true
	vincent_house_dialogue_completed_for_level = true
	bishop_confrontation_accepted_for_level = false
	if SaveManager != null and SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(BISHOP_CONFRONTATION_ACCEPTED_FLAG, false)
	banshee_kill_count = 0
	story_wolf_lock_active = false
	story_transform_prompt_consumed = true
	cleared_villager_paths.clear()
	revealed_banshee_paths.clear()
	permanently_cleared_banshee_paths.clear()
	defeated_banshees.clear()
	set_all_banshee_combat_variants(BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED)
	restore_stage_world_state()
	sync_story_wolf_transformation_lock()
	save_third_wave_progress("banshee_third_wave_spawn")


func begin_third_wave_active_stage():
	if are_all_banshees_permanently_cleared():
		begin_third_wave_cleared_stage()
		save_third_wave_progress("banshee_third_wave_cleared")
		return

	quest_stage = STAGE_THIRD_WAVE_ACTIVE
	refresh_quest_presentation()
	save_third_wave_progress("banshee_third_wave_start")


func _on_player_interaction_requested(interactable: Node2D):
	if interactable == vincent_house and can_enter_vincent_house():
		enter_vincent_house()
		return

	if interactable == null or not interactable.has_method("interact"):
		return

	if is_route_exit_interactable(interactable):
		interactable.interact(player)
		return

	if player != null and player.has_method("can_current_form_talk") and not player.can_current_form_talk():
		return

	if interactable == elder and elder_choice_bubble != null and is_instance_valid(elder_choice_bubble):
		elder_choice_bubble.confirm_selection()
		return

	interactable.interact(player)


func is_route_exit_interactable(interactable: Node) -> bool:
	return interactable == west_route_exit or interactable == south_route_exit or interactable == east_route_exit


func _on_elder_dialogue_finished(_villager: Node):
	if quest_stage == STAGE_INTRO:
		begin_combat_stage()
		if SaveManager != null and SaveManager.has_method("save_game"):
			SaveManager.save_game("banshee_required_intro_started", get_parent())
	elif quest_stage == STAGE_READY_TO_REPORT:
		complete_report_stage()
	elif quest_stage == STAGE_WOLF_HUNT_READY:
		begin_wolf_hunt_stage()
	elif quest_stage == STAGE_WOLF_HUNT_CLEARED:
		begin_final_dulluhan_stage()
	elif quest_stage == STAGE_THIRD_WAVE_ELDER_READY:
		if are_all_banshees_permanently_cleared():
			quest_stage = STAGE_THIRD_WAVE_CLEARED
			refresh_quest_presentation()
			save_third_wave_progress("banshee_bishop_request_available")
			open_bishop_choice_prompt()
		else:
			begin_third_wave_active_stage()
	elif quest_stage == STAGE_THIRD_WAVE_CLEARED and not is_bishop_confrontation_accepted():
		open_bishop_choice_prompt()


func _on_exterior_vincent_dialogue_finished(_vincent: Node):
	if quest_stage == STAGE_THIRD_WAVE_CLEARED and not is_bishop_confrontation_accepted():
		open_bishop_choice_prompt()
	elif quest_stage == STAGE_THIRD_WAVE_ELDER_READY and are_all_banshees_permanently_cleared():
		quest_stage = STAGE_THIRD_WAVE_CLEARED
		refresh_quest_presentation()
		save_third_wave_progress("banshee_bishop_request_available")
		open_bishop_choice_prompt()


func open_bishop_choice_prompt():
	if elder == null:
		return

	if elder_choice_bubble != null and is_instance_valid(elder_choice_bubble):
		return

	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(true)
	if player != null and player.has_method("set_dialogue_input_locked"):
		player.set_dialogue_input_locked(true)

	elder_choice_bubble = DIALOGUE_CHOICE_BUBBLE_SCENE.instantiate() as DialogueChoiceBubble
	elder_choice_bubble.prompt_text = BISHOP_CHOICE_PROMPT_TEXT
	elder.add_child(elder_choice_bubble)

	var selected_callback: Callable = Callable(self, "_on_elder_choice_selected")
	if not elder_choice_bubble.choice_selected.is_connected(selected_callback):
		elder_choice_bubble.choice_selected.connect(selected_callback)

	var closed_callback: Callable = Callable(self, "_on_elder_choice_closed")
	if not elder_choice_bubble.closed.is_connected(closed_callback):
		elder_choice_bubble.closed.connect(closed_callback)

	elder_choice_bubble.open()


func close_elder_choice_prompt(accepted: bool):
	if elder_choice_bubble == null or not is_instance_valid(elder_choice_bubble):
		elder_choice_bubble = null
		return

	var bubble: DialogueChoiceBubble = elder_choice_bubble
	elder_choice_bubble = null
	bubble.close(accepted)
	if player != null and player.has_method("set_dialogue_input_locked"):
		player.set_dialogue_input_locked(false)
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(false)


func _on_elder_choice_selected(accepted: bool):
	if accepted:
		accept_bishop_confrontation()
	else:
		decline_bishop_confrontation()


func _on_elder_choice_closed(_accepted: bool):
	elder_choice_bubble = null
	if player != null and player.has_method("set_dialogue_input_locked"):
		player.set_dialogue_input_locked(false)
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(false)


func _on_dulluhan_transformation_granted_for_story():
	if quest_stage == STAGE_DULLUHAN_AVAILABLE or quest_stage == STAGE_REPORT_COMPLETE:
		dulluhan_transformation_granted_for_level = true
		begin_wolf_hunt_ready_stage()


func _on_dulluhan_final_teaser_completed():
	dulluhan_transformation_granted_for_level = true
	final_dulluhan_teaser_completed = true
	quest_stage = STAGE_VINCENT_HOUSE_AVAILABLE
	refresh_quest_presentation()
	save_wolf_clear_progress()


func _on_interior_vincent_dialogue_finished(_vincent: Node):
	vincent_house_dialogue_completed_for_level = true
	if SaveManager != null and SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(VINCENT_HOUSE_DIALOGUE_FLAG, true)
	refresh_quest_presentation()
	if SaveManager != null and SaveManager.has_method("save_game"):
		SaveManager.save_game("vincent_house_dialogue_completed", get_parent())


func can_enter_vincent_house() -> bool:
	return quest_stage == STAGE_VINCENT_HOUSE_AVAILABLE or is_third_wave_stage() or quest_stage == STAGE_BISHOP_PATH_READY


func enter_vincent_house():
	if player == null or vincent_house_interior == null:
		return

	active_interior_id = VINCENT_HOUSE_INTERIOR_ID
	set_interior_active(vincent_house_interior, true)
	sync_vincent_house_occupancy()
	reparent_player_to(get_node_or_null(vincent_house_interior_player_parent_path))
	move_player_to_interior(vincent_house_interior)


func move_player_to_interior(interior: Node2D):
	var entry_position: Vector2 = interior.global_position
	if interior.has_method("get_entry_position"):
		var raw_entry_position: Variant = interior.call("get_entry_position")
		if raw_entry_position is Vector2:
			entry_position = raw_entry_position

	move_player_to_position(entry_position)


func _on_vincent_house_exit_requested(_interior: Node2D):
	exit_vincent_house()


func exit_vincent_house():
	reparent_player_to(get_node_or_null(exterior_player_parent_path))
	var return_marker := get_node_or_null(vincent_house_return_marker_path) as Node2D
	if return_marker != null:
		move_player_to_position(return_marker.global_position)
	else:
		push_warning("Could not find VincentHouse return marker '%s'." % vincent_house_return_marker_path)

	active_interior_id = ""
	set_interior_active(vincent_house_interior, false)
	if should_start_third_wave_after_house_exit():
		begin_third_wave_elder_ready_stage()


func should_start_third_wave_after_house_exit() -> bool:
	return quest_stage == STAGE_VINCENT_HOUSE_AVAILABLE and not third_wave_spawned and is_vincent_house_dialogue_completed()


func is_vincent_house_dialogue_completed() -> bool:
	return vincent_house_dialogue_completed_for_level


func is_bishop_confrontation_accepted() -> bool:
	return bishop_confrontation_accepted_for_level


func move_player_to_position(target_position: Vector2):
	if player == null:
		return

	if player.has_method("clear_interaction_targets"):
		player.clear_interaction_targets()

	if player is Node2D:
		(player as Node2D).global_position = target_position
		(player as Node2D).set_deferred("velocity", Vector2.ZERO)

	if player.has_method("hold_dialogue_idle"):
		player.hold_dialogue_idle()


func set_interior_active(interior: Node2D, active: bool):
	if interior == null:
		return

	if interior.has_method("set_active_room"):
		interior.call("set_active_room", active)
	else:
		interior.visible = active
		interior.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func restore_active_interior_state():
	var inside_vincent_house := active_interior_id == VINCENT_HOUSE_INTERIOR_ID
	set_interior_active(vincent_house_interior, inside_vincent_house)
	sync_vincent_house_occupancy()
	if inside_vincent_house:
		reparent_player_to(get_node_or_null(vincent_house_interior_player_parent_path))
	else:
		reparent_player_to(get_node_or_null(exterior_player_parent_path))


func reparent_player_to(new_parent: Node):
	if player == null or new_parent == null or player.get_parent() == new_parent:
		return

	if player is Node2D:
		var player_node := player as Node2D
		var saved_global_position := player_node.global_position
		player.reparent(new_parent, true)
		player_node.global_position = saved_global_position
	else:
		player.reparent(new_parent, true)


func _on_banshee_defeated(banshee: Node):
	if quest_stage == STAGE_INTRO or defeated_banshees.has(banshee):
		return

	defeated_banshees[banshee] = true
	banshee_kill_count += 1
	var banshee_path: String = get_relative_node_path(banshee)
	revealed_banshee_paths.erase(banshee_path)
	var killed_by_wolf: bool = was_banshee_killed_by_wolf(banshee)

	var villager: Node = get_banshee_assigned_villager(banshee)
	var villager_path: String = get_relative_node_path(villager)
	if villager_path != "":
		cleared_villager_paths[villager_path] = true
	set_villager_clear_sequence(villager)

	if killed_by_wolf and transformed_banshee_clear_policy != BANSHEE_CLEAR_RESPAWN:
		if transformed_banshee_clear_policy == BANSHEE_CLEAR_PERMANENT_WOLF and banshee_path != "":
			permanently_cleared_banshee_paths[banshee_path] = true
		apply_cleared_banshee_state(banshee)
		update_kill_counter()
		if quest_stage == STAGE_REPORT_COMPLETE and are_all_banshees_permanently_cleared():
			begin_wolf_hunt_cleared_stage(true)
		elif quest_stage == STAGE_THIRD_WAVE_ACTIVE and are_all_banshees_permanently_cleared():
			begin_third_wave_cleared_stage()
		elif (quest_stage == STAGE_WOLF_HUNT_READY or quest_stage == STAGE_THIRD_WAVE_ELDER_READY) and are_all_banshees_permanently_cleared():
			refresh_quest_presentation()
		if is_third_wave_stage():
			save_third_wave_progress("banshee_third_wave_progress")
		else:
			save_wolf_clear_progress()
		return

	update_kill_counter()
	schedule_banshee_respawn(banshee)

	if quest_stage == STAGE_COMBAT_ACTIVE and banshee_kill_count >= report_kill_threshold:
		begin_ready_to_report_stage()

	if is_third_wave_combat_stage():
		save_third_wave_progress("banshee_third_wave_progress")


func was_banshee_killed_by_wolf(banshee: Node) -> bool:
	if banshee == null:
		return false

	var killer_form_id: StringName = StringName(str(banshee.get("last_killer_form_id")))
	if killer_form_id == &"wolf":
		return true

	if player != null and player.has_method("get_current_form_id"):
		return player.get_current_form_id() == &"wolf"

	return false


func are_all_banshees_permanently_cleared() -> bool:
	if banshees.is_empty():
		return false

	for banshee in banshees:
		var banshee_path: String = get_relative_node_path(banshee)
		if banshee_path == "" or not permanently_cleared_banshee_paths.has(banshee_path):
			return false

	return true


func is_wolf_hunt_stage() -> bool:
	return quest_stage == STAGE_WOLF_HUNT_READY or quest_stage == STAGE_REPORT_COMPLETE


func is_third_wave_stage() -> bool:
	return quest_stage == STAGE_THIRD_WAVE_ELDER_READY or quest_stage == STAGE_THIRD_WAVE_ACTIVE or quest_stage == STAGE_THIRD_WAVE_CLEARED or quest_stage == STAGE_BISHOP_PATH_READY


func is_third_wave_combat_stage() -> bool:
	return quest_stage == STAGE_THIRD_WAVE_ELDER_READY or quest_stage == STAGE_THIRD_WAVE_ACTIVE


func begin_wolf_hunt_cleared_stage(show_completion_prompt: bool = false):
	quest_stage = STAGE_WOLF_HUNT_CLEARED
	story_transform_prompt_consumed = true
	if story_wolf_lock_active or is_player_in_wolf_form():
		story_wolf_lock_active = false
		if player != null and player.has_method("end_story_wolf_transformation_lock"):
			player.end_story_wolf_transformation_lock(true)
	refresh_quest_presentation()
	if show_completion_prompt and not final_wolf_instruction_shown:
		final_wolf_instruction_shown = true
		show_story_prompt(FINAL_WOLF_INSTRUCTION_TEXT, 7.5)


func begin_final_dulluhan_stage():
	dulluhan_transformation_granted_for_level = true
	quest_stage = STAGE_FINAL_DULLUHAN_READY
	refresh_quest_presentation()
	save_wolf_clear_progress()


func begin_third_wave_cleared_stage():
	quest_stage = STAGE_THIRD_WAVE_CLEARED
	refresh_quest_presentation()


func accept_bishop_confrontation():
	bishop_confrontation_accepted_for_level = true
	if SaveManager != null and SaveManager.has_method("set_story_flag"):
		SaveManager.set_story_flag(BISHOP_CONFRONTATION_ACCEPTED_FLAG, true)
	quest_stage = STAGE_BISHOP_PATH_READY
	refresh_quest_presentation()
	save_third_wave_progress("banshee_bishop_confrontation_accept")


func decline_bishop_confrontation():
	refresh_quest_presentation()
	save_third_wave_progress("banshee_bishop_confrontation_decline")


func save_wolf_clear_progress():
	if SaveManager != null and SaveManager.has_method("save_game"):
		SaveManager.save_game("banshee_wolf_clear", get_parent())


func save_third_wave_progress(reason: String):
	if SaveManager != null and SaveManager.has_method("save_game"):
		SaveManager.save_game(reason, get_parent())


func _on_banshee_detected_player_for_reveal(banshee: Node):
	if quest_stage == STAGE_INTRO or banshee == null:
		return

	if defeated_banshees.has(banshee):
		return

	var banshee_path: String = get_relative_node_path(banshee)
	if banshee_path == "":
		return

	revealed_banshee_paths[banshee_path] = true
	if banshee.has_method("set_story_revealed"):
		banshee.set_story_revealed(true, hidden_banshee_alpha)


func schedule_banshee_respawn(banshee: Node):
	if banshee == null:
		return

	var scheduled_generation: int = state_generation
	await get_tree().create_timer(respawn_delay_seconds).timeout
	if scheduled_generation != state_generation:
		return

	respawn_banshee(banshee)


func respawn_banshee(banshee: Node):
	if quest_stage == STAGE_INTRO or banshee == null or not is_instance_valid(banshee):
		return

	if not defeated_banshees.has(banshee):
		return

	var banshee_path: String = get_relative_node_path(banshee)
	if permanently_cleared_banshee_paths.has(banshee_path):
		return

	defeated_banshees.erase(banshee)
	revealed_banshee_paths.erase(banshee_path)

	var villager: Node = get_banshee_assigned_villager(banshee)
	var villager_path: String = get_relative_node_path(villager)
	if villager_path != "":
		cleared_villager_paths.erase(villager_path)
	set_villager_stalked_sequence(villager)
	reset_villager_stalk_state(villager)

	if banshee.has_method("respawn_for_story"):
		if banshee.has_method("set_combat_variant"):
			banshee.set_combat_variant(get_banshee_combat_variant_for_story())
		banshee.respawn_for_story(hidden_banshee_alpha)
	elif banshee.has_method("restore_after_load"):
		if banshee.has_method("set_combat_variant"):
			banshee.set_combat_variant(get_banshee_combat_variant_for_story())
		banshee.restore_after_load()
		if banshee.has_method("enable_story_combat"):
			banshee.enable_story_combat(hidden_banshee_alpha)
		elif banshee.has_method("set_story_combat_enabled"):
			banshee.set_story_combat_enabled(true, hidden_banshee_alpha)


func update_kill_counter():
	if kill_counter == null:
		return

	kill_counter.visible = should_show_kill_counter()
	if not kill_counter.visible:
		return

	if quest_stage == STAGE_REPORT_COMPLETE or quest_stage == STAGE_THIRD_WAVE_ACTIVE:
		kill_counter.text = "Cleared: %d/%d" % [permanently_cleared_banshee_paths.size(), banshees.size()]
		return

	var shown_count: int = mini(banshee_kill_count, report_kill_threshold)
	kill_counter.text = "Banshees: %d/%d" % [shown_count, report_kill_threshold]


func should_show_kill_counter() -> bool:
	return (
		quest_stage == STAGE_COMBAT_ACTIVE
		or quest_stage == STAGE_READY_TO_REPORT
		or quest_stage == STAGE_REPORT_COMPLETE
		or quest_stage == STAGE_THIRD_WAVE_ACTIVE
	)


func update_exterior_vincent_presentation():
	if exterior_vincent == null:
		return

	var visible_for_story := should_show_exterior_vincent()
	exterior_vincent.visible = visible_for_story
	exterior_vincent.process_mode = Node.PROCESS_MODE_INHERIT if visible_for_story else Node.PROCESS_MODE_DISABLED
	if exterior_vincent.has_method("set_house_dialogue_enabled"):
		exterior_vincent.set_house_dialogue_enabled(false)
	if exterior_vincent.has_method("set_interaction_enabled"):
		exterior_vincent.set_interaction_enabled(visible_for_story)

	if visible_for_story:
		var marker := get_node_or_null(vincent_beside_elder_marker_path) as Node2D
		if marker != null:
			exterior_vincent.global_position = marker.global_position
		elif elder is Node2D:
			exterior_vincent.global_position = (elder as Node2D).global_position + Vector2(58.0, 0.0)

	if should_show_bishop_direction_progression():
		if exterior_vincent.has_method("set_level_dialogue_override"):
			exterior_vincent.set_level_dialogue_override(create_bishop_direction_sequence(), true)
	elif exterior_vincent.has_method("clear_level_dialogue_override"):
		exterior_vincent.clear_level_dialogue_override()


func sync_vincent_house_occupancy():
	if vincent_house_interior == null or not vincent_house_interior.has_method("set_vincent_present"):
		return

	vincent_house_interior.set_vincent_present(not should_show_exterior_vincent())
	var interior_vincent: Node = get_interior_vincent()
	if interior_vincent != null and interior_vincent.has_method("set_house_dialogue_completed_override"):
		interior_vincent.call("set_house_dialogue_completed_override", true, vincent_house_dialogue_completed_for_level)


func should_show_exterior_vincent() -> bool:
	return quest_stage == STAGE_THIRD_WAVE_CLEARED or quest_stage == STAGE_BISHOP_PATH_READY or (quest_stage == STAGE_THIRD_WAVE_ELDER_READY and are_all_banshees_permanently_cleared())


func should_show_bishop_direction_progression() -> bool:
	return not is_bishop_confrontation_accepted() and (quest_stage == STAGE_THIRD_WAVE_CLEARED or (quest_stage == STAGE_THIRD_WAVE_ELDER_READY and are_all_banshees_permanently_cleared()))


func update_route_exit_gates():
	set_route_exit_enabled(west_route_exit, true)
	set_route_exit_enabled(east_route_exit, is_third_hunt_completed_for_route_travel())
	set_route_exit_enabled(south_route_exit, is_bishop_confrontation_accepted() or quest_stage == STAGE_BISHOP_PATH_READY)


func set_route_exit_enabled(route_exit: Node, enabled: bool):
	if route_exit == null:
		return

	if route_exit.has_method("set_travel_enabled"):
		route_exit.set_travel_enabled(enabled)
	else:
		route_exit.set("travel_enabled", enabled)


func is_third_hunt_completed_for_route_travel() -> bool:
	return quest_stage == STAGE_THIRD_WAVE_CLEARED or quest_stage == STAGE_BISHOP_PATH_READY


func update_elder_flag():
	if elder_flag == null:
		return

	if should_show_bishop_direction_progression():
		elder_flag.set_effects(["flag"])
		return

	if quest_stage == STAGE_THIRD_WAVE_ELDER_READY:
		elder_flag.set_effects(["flag"])
		return

	if final_dulluhan_teaser_completed:
		elder_flag.clear_effects()
		return

	if quest_stage == STAGE_INTRO or quest_stage == STAGE_READY_TO_REPORT or quest_stage == STAGE_WOLF_HUNT_READY or quest_stage == STAGE_WOLF_HUNT_CLEARED:
		elder_flag.set_effects(["flag"])
	else:
		elder_flag.clear_effects()


func update_dulluhan_flag():
	if dulluhan_flag == null:
		return

	if final_dulluhan_teaser_completed:
		dulluhan_flag.clear_effects()
		return

	if quest_stage == STAGE_DULLUHAN_AVAILABLE and not is_dulluhan_transformation_granted():
		dulluhan_flag.set_effects(["flag"])
	elif quest_stage == STAGE_FINAL_DULLUHAN_READY:
		dulluhan_flag.set_effects(["flag"])
	else:
		dulluhan_flag.clear_effects()


func update_dulluhan_visibility():
	if dulluhan == null:
		return

	if is_third_wave_combat_stage():
		if dulluhan is Node2D:
			(dulluhan as Node2D).global_position = dulluhan_story_origin_position
		if dulluhan.has_method("set_waiting_for_story_progress"):
			dulluhan.set_waiting_for_story_progress(true)
		elif dulluhan.has_method("set_story_visible"):
			dulluhan.set_story_visible(true)
		else:
			dulluhan.visible = true
		return

	if final_dulluhan_teaser_completed:
		if dulluhan.has_method("set_final_teaser_completed"):
			dulluhan.set_final_teaser_completed(true)
		elif dulluhan.has_method("set_story_visible"):
			dulluhan.set_story_visible(false)
		else:
			dulluhan.visible = false
		return

	if quest_stage == STAGE_FINAL_DULLUHAN_READY:
		if dulluhan.has_method("start_final_teaser"):
			dulluhan.start_final_teaser(get_final_dulluhan_position())
		elif dulluhan.has_method("set_story_visible"):
			if dulluhan is Node2D:
				(dulluhan as Node2D).global_position = get_final_dulluhan_position()
			dulluhan.set_story_visible(true)
		else:
			if dulluhan is Node2D:
				(dulluhan as Node2D).global_position = get_final_dulluhan_position()
			dulluhan.visible = true
		return

	if quest_stage == STAGE_DULLUHAN_AVAILABLE and not is_dulluhan_transformation_granted():
		if dulluhan.has_method("set_story_visible"):
			dulluhan.set_story_visible(true)
		else:
			dulluhan.visible = true
	elif is_dulluhan_transformation_granted() and (quest_stage == STAGE_WOLF_HUNT_READY or quest_stage == STAGE_REPORT_COMPLETE or quest_stage == STAGE_WOLF_HUNT_CLEARED):
		if dulluhan.has_method("set_waiting_for_story_progress"):
			dulluhan.set_waiting_for_story_progress(true)
		elif dulluhan.has_method("set_story_visible"):
			dulluhan.set_story_visible(true)
	else:
		if dulluhan.has_method("set_story_visible"):
			dulluhan.set_story_visible(false)
		else:
			dulluhan.visible = false


func is_dulluhan_transformation_granted() -> bool:
	return dulluhan_transformation_granted_for_level


func get_final_dulluhan_position() -> Vector2:
	var marker: Node2D = get_node_or_null(final_dulluhan_marker_path) as Node2D
	if marker != null:
		return marker.global_position

	return final_dulluhan_position


func restore_story_transformation_state():
	if story_wolf_lock_active and is_wolf_hunt_stage():
		story_transform_prompt_consumed = true
		hide_story_prompt()
		if player != null and player.has_method("restore_story_wolf_transformation_lock"):
			player.restore_story_wolf_transformation_lock()
		return

	if player != null and player.has_method("is_story_wolf_transformation_locked") and bool(player.call("is_story_wolf_transformation_locked")):
		if player.has_method("end_story_wolf_transformation_lock"):
			player.end_story_wolf_transformation_lock(false)

	refresh_story_transform_prompt()


func sync_story_wolf_transformation_lock():
	if player == null:
		return

	if not is_wolf_hunt_stage():
		story_wolf_lock_active = false
		if is_player_story_wolf_transformation_locked() and player.has_method("end_story_wolf_transformation_lock"):
			player.end_story_wolf_transformation_lock(false)
		return

	if not story_wolf_lock_active:
		return

	story_transform_prompt_consumed = true
	hide_story_prompt()
	if is_player_in_wolf_form() and not is_player_story_wolf_transformation_locked() and player.has_method("start_story_wolf_transformation_lock"):
		player.start_story_wolf_transformation_lock()


func refresh_story_transform_prompt():
	if should_show_story_transform_prompt():
		show_story_prompt(STORY_TRANSFORM_PROMPT_TEXT)
	else:
		hide_story_prompt()
	sync_story_wolf_transformation_lock()


func should_show_story_transform_prompt() -> bool:
	return quest_stage == STAGE_WOLF_HUNT_READY and has_wolf_transformation_upgrade() and not story_transform_prompt_consumed and not story_wolf_lock_active


func _on_player_transformation_state_changed(active: bool):
	if not active:
		if story_wolf_lock_active:
			if not is_wolf_hunt_stage():
				story_wolf_lock_active = false
				return
			if is_player_life_respawn_pending():
				return
			call_deferred("restore_story_wolf_transformation_lock_after_unexpected_end")
		return

	if not is_wolf_hunt_stage():
		sync_story_wolf_transformation_lock()
		return

	story_transform_prompt_consumed = true
	story_wolf_lock_active = true
	hide_story_prompt()
	if player != null and player.has_method("start_story_wolf_transformation_lock"):
		player.start_story_wolf_transformation_lock()
	save_wolf_clear_progress()


func restore_story_wolf_transformation_lock_after_unexpected_end():
	if not story_wolf_lock_active or not is_wolf_hunt_stage() or is_player_life_respawn_pending():
		return

	if player != null and player.has_method("restore_story_wolf_transformation_lock"):
		player.restore_story_wolf_transformation_lock()
	save_wolf_clear_progress()


func is_player_in_wolf_form() -> bool:
	return player != null and player.has_method("get_current_form_id") and player.get_current_form_id() == &"wolf"


func is_player_life_respawn_pending() -> bool:
	return player != null and player.has_method("is_life_respawn_pending") and bool(player.call("is_life_respawn_pending"))


func is_player_story_wolf_transformation_locked() -> bool:
	return player != null and player.has_method("is_story_wolf_transformation_locked") and bool(player.call("is_story_wolf_transformation_locked"))


func show_story_prompt(text: String, timeout_seconds: float = 0.0):
	var label := get_story_prompt_label()
	if label == null:
		return

	story_prompt_generation += 1
	label.text = text
	label.visible = true
	if timeout_seconds > 0.0:
		hide_story_prompt_after_delay(story_prompt_generation, timeout_seconds)


func hide_story_prompt():
	story_prompt_generation += 1
	if story_prompt_label != null and is_instance_valid(story_prompt_label):
		story_prompt_label.visible = false


func hide_story_prompt_after_delay(generation: int, timeout_seconds: float):
	await get_tree().create_timer(timeout_seconds).timeout
	if generation == story_prompt_generation:
		hide_story_prompt()


func get_story_prompt_label() -> Label:
	if player == null:
		return null

	if story_prompt_label != null and is_instance_valid(story_prompt_label):
		return story_prompt_label

	story_prompt_label = Label.new()
	story_prompt_label.name = "BansheeVillageStoryPrompt"
	story_prompt_label.z_as_relative = false
	story_prompt_label.z_index = 250
	story_prompt_label.position = Vector2(-120.0, -120.0)
	story_prompt_label.size = Vector2(240.0, 58.0)
	story_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_prompt_label.add_theme_font_size_override("font_size", 9)
	story_prompt_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	story_prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	story_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	story_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	story_prompt_label.visible = false
	player.add_child(story_prompt_label)
	return story_prompt_label
