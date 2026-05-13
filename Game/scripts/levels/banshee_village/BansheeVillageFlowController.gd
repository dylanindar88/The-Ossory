extends Node

const DEFAULT_STORY_DIALOGUE_PROFILE: DialogueProfile = preload("res://resources/dialogue/levels/banshee_village/banshee_village_story_profile.tres")
const DEFAULT_ELDER_POST_TRANSFORMATION_SEQUENCE: DialogueSequence = preload("res://resources/dialogue/levels/banshee_village/banshee_village_elder_post_transformation.tres")
const DEFAULT_ELDER_WOLF_HUNT_CLEARED_SEQUENCE: DialogueSequence = preload("res://resources/dialogue/levels/banshee_village/banshee_village_elder_village_cleared.tres")
const DEFAULT_ELDER_FINAL_DULLUHAN_COMPLETE_SEQUENCE: DialogueSequence = preload("res://resources/dialogue/levels/banshee_village/banshee_village_elder_final_dulluhan_complete.tres")
const DIALOGUE_KEY_THIRD_WAVE_ELDER := &"third_wave_elder"
const DIALOGUE_KEY_SECOND_HUNT_ALREADY_CLEARED := &"second_hunt_already_cleared"
const DIALOGUE_KEY_BISHOP_DIRECTION := &"bishop_direction"
const DIALOGUE_KEY_THIRD_WAVE_ALREADY_CLEARED_WITH_BISHOP := &"third_wave_already_cleared_with_bishop"
const BANSHEE_CLEAR_RESPAWN = "respawn"
const BANSHEE_CLEAR_TEMPORARY_WOLF = "temporary_wolf_clear"
const BANSHEE_VARIANT_CORRUPTED_MELEE = "corrupted_melee"
const BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED = "corrupted_strong_ranged"
const LEVEL_STATE_VERSION = 6
const VINCENT_HOUSE_INTERIOR_ID = "vincent_house"
const VINCENT_HOUSE_DIALOGUE_FLAG = "vincent_house_dialogue_completed"
const BISHOP_CONFRONTATION_ACCEPTED_FLAG = "bishop_confrontation_accepted"
const WOLF_TRANSFORMATION_DULLUHAN_UNLOCK_FLAG = "wolf_transformation_unlocked_by_dulluhan"
const DIALOGUE_CHOICE_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/DialogueChoiceBubble.tscn")
# Internal delegates only. This controller remains the public level-state provider.
const STAGE_RULES_SCRIPT = preload("res://scripts/levels/banshee_village/BansheeVillageStageRules.gd")
const DEV_PRESET_BUILDER_SCRIPT = preload("res://scripts/levels/banshee_village/BansheeVillageDevPresetBuilder.gd")
const PROGRESSION_CONTROLLER_SCRIPT = preload("res://scripts/levels/banshee_village/BansheeVillageProgressionController.gd")
const INTERIOR_TRAVEL_CONTROLLER_SCRIPT = preload("res://scripts/levels/banshee_village/BansheeVillageInteriorTravelController.gd")
const STORY_PROMPT_CONTROLLER_SCRIPT = preload("res://scripts/levels/banshee_village/BansheeVillageStoryPromptController.gd")
const PRESENTATION_CONTROLLER_SCRIPT = preload("res://scripts/levels/banshee_village/BansheeVillagePresentationController.gd")
const ENCOUNTER_CONTROLLER_SCRIPT = preload("res://scripts/levels/banshee_village/BansheeVillageEncounterController.gd")
const SAVE_ADAPTER_SCRIPT = preload("res://scripts/levels/banshee_village/BansheeVillageSaveAdapter.gd")
const BISHOP_CHOICE_PROMPT_TEXT = "Confront the bishop?"
const STORY_TRANSFORM_PROMPT_TEXT = "Press Q to transform."
const FINAL_WOLF_INSTRUCTION_TEXT = "You cannot hold the form forever.\nYour own transformations last 30 seconds.\nPress Tab to view transformation stats."

# Dev preset validation and behavior are owned by BansheeVillageDevPresetBuilder.
@export_enum(
	"none",
	"start",
	"elder_quest_accepted",
	"first_banshee_report_ready",
	"elder_report_complete_dulluhan_visible",
	"dulluhan_transformation_unlocked",
	"second_banshee_report_ready",
	"third_banshee_report_ready"
) var dev_start_preset: String = DEV_PRESET_BUILDER_SCRIPT.DEV_PRESET_NONE
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
@export var final_dulluhan_marker_path: NodePath = NodePath("../PlayableWorld/Markers/StoryPositions/DulluhanVincentHouseFront")
@export var vincent_beside_elder_marker_path: NodePath = NodePath("../PlayableWorld/Markers/StoryPositions/VincentBesideElder")
@export var final_dulluhan_position: Vector2 = Vector2(1042, 577)
@export_enum("respawn", "temporary_wolf_clear") var transformed_banshee_clear_policy: String = BANSHEE_CLEAR_TEMPORARY_WOLF
@export var story_dialogue_profile: DialogueProfile = DEFAULT_STORY_DIALOGUE_PROFILE
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

var quest_stage: String = STAGE_RULES_SCRIPT.STAGE_INTRO
var banshee_kill_count: int = 0
var cleared_villager_paths: Dictionary = {}
var revealed_banshee_paths: Dictionary = {}
var temporarily_cleared_banshee_paths: Dictionary = {}
var permanently_cleared_banshee_paths: Dictionary = {}
var defeated_banshee_nodes: Dictionary = {}
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
var dev_preset_builder
var progression_controller
var interior_travel_controller
var story_prompt_controller
var presentation_controller
var encounter_controller
var save_adapter
var location_exit_save_pending: bool = false


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
	dev_preset_builder = DEV_PRESET_BUILDER_SCRIPT.new()
	dev_preset_builder.setup(self)
	progression_controller = PROGRESSION_CONTROLLER_SCRIPT.new()
	progression_controller.setup(self)
	interior_travel_controller = INTERIOR_TRAVEL_CONTROLLER_SCRIPT.new()
	interior_travel_controller.setup(self)
	story_prompt_controller = STORY_PROMPT_CONTROLLER_SCRIPT.new()
	story_prompt_controller.setup(self)
	presentation_controller = PRESENTATION_CONTROLLER_SCRIPT.new()
	presentation_controller.setup(self)
	encounter_controller = ENCOUNTER_CONTROLLER_SCRIPT.new()
	encounter_controller.setup(self)
	save_adapter = SAVE_ADAPTER_SCRIPT.new()
	save_adapter.setup(self)

	connect_player_story_signals()
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
	return save_adapter.collect_level_state()


func is_save_load_pending_for_this_level() -> bool:
	return SaveManager != null and SaveManager.has_method("is_scene_load_pending_for") and SaveManager.is_scene_load_pending_for(get_parent().scene_file_path)


func uses_level_owned_hostile_state() -> bool:
	return true


func uses_level_owned_non_hostile_npc_state() -> bool:
	return true


func validate_level_state(state: Dictionary) -> Array:
	return save_adapter.validate_level_state(state)


func append_missing_actor_path_warnings(messages: Array, raw_states: Variant, actor_label: String):
	save_adapter.append_missing_actor_path_warnings(messages, raw_states, actor_label)


func append_missing_assigned_villager_warnings(messages: Array):
	save_adapter.append_missing_assigned_villager_warnings(messages)


func apply_level_state(state: Dictionary):
	save_adapter.apply_level_state(state)


func normalize_level_state(state: Dictionary) -> Dictionary:
	return save_adapter.normalize_level_state(state)


func get_saved_bool(state: Dictionary, key: String, default_value: bool) -> bool:
	return save_adapter.get_saved_bool(state, key, default_value)


func infer_dulluhan_transformation_granted_from_stage(stage: String) -> bool:
	return STAGE_RULES_SCRIPT.infer_dulluhan_transformation_granted_from_stage(stage)


func infer_vincent_house_dialogue_completed_from_stage(stage: String) -> bool:
	return STAGE_RULES_SCRIPT.infer_vincent_house_dialogue_completed_from_stage(stage)


func infer_bishop_confrontation_accepted_from_stage(stage: String) -> bool:
	return STAGE_RULES_SCRIPT.infer_bishop_confrontation_accepted_from_stage(stage)


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
	return dev_preset_builder != null and dev_preset_builder.apply_dev_start_preset()


func connect_player_story_signals():
	if player == null:
		return

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
	return save_adapter.collect_banshee_states()


func collect_non_hostile_npc_states() -> Array:
	return save_adapter.collect_non_hostile_npc_states()


func collect_dulluhan_state() -> Dictionary:
	return save_adapter.collect_dulluhan_state()


func apply_dulluhan_level_state(raw_state: Variant):
	save_adapter.apply_dulluhan_level_state(raw_state)


func parse_saved_banshee_states(raw_states: Variant) -> Dictionary:
	return save_adapter.parse_saved_banshee_states(raw_states)


func apply_intro_defaults():
	state_generation += 1
	quest_stage = STAGE_RULES_SCRIPT.STAGE_INTRO
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
	temporarily_cleared_banshee_paths.clear()
	permanently_cleared_banshee_paths.clear()
	defeated_banshee_nodes.clear()
	saved_banshee_states.clear()
	saved_villager_states.clear()
	set_all_banshee_combat_variants(BANSHEE_VARIANT_CORRUPTED_MELEE)
	update_exterior_vincent_presentation()
	restore_stage_world_state()


func restore_stage_world_state():
	# Full restore is for fresh init, save load, and first quest activation only.
	# Mid-quest UI/dialogue updates should call refresh_quest_presentation() instead.
	refresh_quest_presentation()

	if quest_stage == STAGE_RULES_SCRIPT.STAGE_INTRO:
		apply_banshee_villager_presentation(false)
		return

	apply_banshee_villager_presentation(true)


func refresh_quest_presentation():
	# Presentation refresh must not reset actor position, health, death, or patrol state.
	sync_global_story_progress()
	if quest_stage == STAGE_RULES_SCRIPT.STAGE_INTRO:
		set_elder_sequence(elder_reveal_sequence)
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_ELDER_READY:
		if are_all_banshees_cleared_for_current_visit():
			set_elder_sequence(get_story_dialogue_sequence(DIALOGUE_KEY_THIRD_WAVE_ALREADY_CLEARED_WITH_BISHOP))
		else:
			set_elder_sequence(get_story_dialogue_sequence(DIALOGUE_KEY_THIRD_WAVE_ELDER))
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_ACTIVE:
		set_elder_sequence(elder_waiting_sequence)
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_CLEARED:
		if is_bishop_confrontation_accepted():
			set_elder_sequence(elder_waiting_sequence)
		else:
			set_elder_sequence(get_story_dialogue_sequence(DIALOGUE_KEY_BISHOP_DIRECTION))
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_BISHOP_PATH_READY:
		set_elder_sequence(elder_waiting_sequence)
	elif final_dulluhan_teaser_completed:
		set_elder_sequence(elder_final_dulluhan_complete_sequence if elder_final_dulluhan_complete_sequence != null else elder_wolf_hunt_cleared_sequence)
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_WOLF_HUNT_CLEARED:
		set_elder_sequence(elder_wolf_hunt_cleared_sequence if elder_wolf_hunt_cleared_sequence != null else elder_waiting_sequence)
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_FINAL_DULLUHAN_READY:
		set_elder_sequence(elder_wolf_hunt_cleared_sequence if elder_wolf_hunt_cleared_sequence != null else elder_waiting_sequence)
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_WOLF_HUNT_READY:
		if are_all_banshees_cleared_for_current_visit():
			set_elder_sequence(get_story_dialogue_sequence(DIALOGUE_KEY_SECOND_HUNT_ALREADY_CLEARED))
		else:
			set_elder_sequence(elder_post_transformation_sequence if elder_post_transformation_sequence != null else elder_respawning_sequence)
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_READY_TO_REPORT:
		set_elder_sequence(elder_respawning_sequence)
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_DULLUHAN_AVAILABLE:
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

	var banshee_hostile_enabled: bool = quest_stage != STAGE_RULES_SCRIPT.STAGE_INTRO
	var strong_banshees_enabled: bool = third_wave_spawned or is_third_wave_stage()
	if SaveManager.has_method("set_banshee_world_rule"):
		SaveManager.set_banshee_world_rule("banshees_hostile_enabled", banshee_hostile_enabled)
		SaveManager.set_banshee_world_rule("player_can_damage_banshees", banshee_hostile_enabled)
		SaveManager.set_banshee_world_rule("wolf_permanent_clear_enabled", has_wolf_transformation_upgrade())
		SaveManager.set_banshee_world_rule("combat_variant", BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED if strong_banshees_enabled else BANSHEE_VARIANT_CORRUPTED_MELEE)
		SaveManager.set_banshee_world_rule("vincent_upgrades_enabled", strong_banshees_enabled)

	if SaveManager.has_method("set_quest_stage"):
		var current_bishop_quest_stage: String = "not_available"
		if SaveManager.has_method("get_quest_stage"):
			current_bishop_quest_stage = str(SaveManager.get_quest_stage("banshee_village_bishop"))
		if current_bishop_quest_stage == "bishop_defeated" or current_bishop_quest_stage == "ready_to_report" or current_bishop_quest_stage == "reported" or current_bishop_quest_stage == "reward_claimed":
			return
		if is_bishop_confrontation_accepted() or quest_stage == STAGE_RULES_SCRIPT.STAGE_BISHOP_PATH_READY:
			SaveManager.set_quest_stage("banshee_village_bishop", "accepted")
		elif quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_CLEARED or (quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_ELDER_READY and are_all_banshees_cleared_for_current_visit()):
			SaveManager.set_quest_stage("banshee_village_bishop", "request_available")
		else:
			SaveManager.set_quest_stage("banshee_village_bishop", "not_available")


func create_bishop_direction_sequence() -> DialogueSequence:
	return get_story_dialogue_sequence(DIALOGUE_KEY_BISHOP_DIRECTION)


func create_third_wave_already_cleared_with_bishop_sequence() -> DialogueSequence:
	return get_story_dialogue_sequence(DIALOGUE_KEY_THIRD_WAVE_ALREADY_CLEARED_WITH_BISHOP)


func get_story_dialogue_sequence(key: StringName) -> DialogueSequence:
	if story_dialogue_profile == null:
		return null

	return story_dialogue_profile.get_sequence(key)


func restore_saved_villager_states():
	SaveManager.apply_story_actor_states(get_parent(), saved_villager_states)


func apply_banshee_villager_presentation(combat_enabled: bool):
	encounter_controller.apply_banshee_villager_presentation(combat_enabled)


func apply_active_banshee_state(banshee: Node, combat_enabled: bool, saved_state: Dictionary = {}):
	encounter_controller.apply_active_banshee_state(banshee, combat_enabled, saved_state)


func apply_cleared_banshee_state(banshee: Node, saved_state: Dictionary = {}):
	encounter_controller.apply_cleared_banshee_state(banshee, saved_state)


func get_banshee_combat_variant_for_story() -> String:
	return encounter_controller.get_banshee_combat_variant_for_story()


func set_all_banshee_combat_variants(variant: String):
	encounter_controller.set_all_banshee_combat_variants(variant)


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

	if defeated_banshee_nodes.has(banshee):
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
	return STAGE_RULES_SCRIPT.get_valid_stage(stage)


func has_wolf_transformation_upgrade() -> bool:
	if SaveManager == null:
		return false

	var upgrade_state: Dictionary = SaveManager.get_upgrade_state()
	var unlocked: Variant = upgrade_state.get("unlocked", {})
	return unlocked is Dictionary and bool(unlocked.get("wolf_transformation", false))


func begin_combat_stage():
	progression_controller.begin_combat_stage()


func begin_ready_to_report_stage():
	progression_controller.begin_ready_to_report_stage()


func complete_report_stage():
	progression_controller.complete_report_stage()


func begin_wolf_hunt_ready_stage():
	progression_controller.begin_wolf_hunt_ready_stage()


func begin_wolf_hunt_stage():
	progression_controller.begin_wolf_hunt_stage()


func begin_third_wave_elder_ready_stage():
	progression_controller.begin_third_wave_elder_ready_stage()


func begin_third_wave_active_stage():
	progression_controller.begin_third_wave_active_stage()


func _on_player_interaction_requested(interactable: Node2D):
	handle_level_interaction(interactable, player)


func handle_level_interaction(interactable: Node2D, interaction_player: Node2D) -> bool:
	if interaction_player != null:
		player = interaction_player

	if interactable == vincent_house and can_enter_vincent_house():
		enter_vincent_house()
		return true

	if interactable == null or not interactable.has_method("interact"):
		return false

	if is_route_exit_interactable(interactable):
		interactable.interact(player)
		return true

	if player != null and player.has_method("can_current_form_talk") and not player.can_current_form_talk():
		return true

	if interactable == elder and elder_choice_bubble != null and is_instance_valid(elder_choice_bubble):
		elder_choice_bubble.confirm_selection()
		return true

	interactable.interact(player)
	return true


func is_route_exit_interactable(interactable: Node) -> bool:
	return interactable == west_route_exit or interactable == south_route_exit or interactable == east_route_exit


func _on_elder_dialogue_finished(_villager: Node):
	if quest_stage == STAGE_RULES_SCRIPT.STAGE_INTRO:
		begin_combat_stage()
		if SaveManager != null and SaveManager.has_method("save_game"):
			SaveManager.save_game("banshee_required_intro_started", get_parent())
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_READY_TO_REPORT:
		complete_report_stage()
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_WOLF_HUNT_READY:
		begin_wolf_hunt_stage()
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_WOLF_HUNT_CLEARED:
		begin_final_dulluhan_stage()
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_ELDER_READY:
		if are_all_banshees_cleared_for_current_visit():
			quest_stage = STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_CLEARED
			refresh_quest_presentation()
			save_third_wave_progress("banshee_bishop_request_available")
			open_bishop_choice_prompt()
		else:
			begin_third_wave_active_stage()
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_CLEARED and not is_bishop_confrontation_accepted():
		open_bishop_choice_prompt()


func _on_exterior_vincent_dialogue_finished(_vincent: Node):
	if quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_CLEARED and not is_bishop_confrontation_accepted():
		open_bishop_choice_prompt()
	elif quest_stage == STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_ELDER_READY and are_all_banshees_cleared_for_current_visit():
		quest_stage = STAGE_RULES_SCRIPT.STAGE_THIRD_WAVE_CLEARED
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
	if quest_stage == STAGE_RULES_SCRIPT.STAGE_DULLUHAN_AVAILABLE or quest_stage == STAGE_RULES_SCRIPT.STAGE_REPORT_COMPLETE:
		dulluhan_transformation_granted_for_level = true
		begin_wolf_hunt_ready_stage()


func _on_dulluhan_final_teaser_completed():
	dulluhan_transformation_granted_for_level = true
	final_dulluhan_teaser_completed = true
	quest_stage = STAGE_RULES_SCRIPT.STAGE_VINCENT_HOUSE_AVAILABLE
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
	return interior_travel_controller.can_enter_vincent_house()


func enter_vincent_house():
	interior_travel_controller.enter_vincent_house()


func move_player_to_interior(interior: Node2D):
	interior_travel_controller.move_player_to_interior(interior)


func _on_vincent_house_exit_requested(_interior: Node2D):
	exit_vincent_house()


func exit_vincent_house():
	interior_travel_controller.exit_vincent_house()


func should_start_third_wave_after_house_exit() -> bool:
	return interior_travel_controller.should_start_third_wave_after_house_exit()


func is_vincent_house_dialogue_completed() -> bool:
	return vincent_house_dialogue_completed_for_level


func is_bishop_confrontation_accepted() -> bool:
	return bishop_confrontation_accepted_for_level


func move_player_to_position(target_position: Vector2):
	interior_travel_controller.move_player_to_position(target_position)


func set_interior_active(interior: Node2D, active: bool):
	interior_travel_controller.set_interior_active(interior, active)


func restore_active_interior_state():
	interior_travel_controller.restore_active_interior_state()


func reparent_player_to(new_parent: Node):
	interior_travel_controller.reparent_player_to(new_parent)


func _on_banshee_defeated(banshee: Node):
	progression_controller.handle_banshee_defeated(banshee)


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


func are_all_banshees_cleared_for_current_visit() -> bool:
	if banshees.is_empty():
		return false

	for banshee in banshees:
		var banshee_path: String = get_relative_node_path(banshee)
		if banshee_path == "":
			return false
		if not permanently_cleared_banshee_paths.has(banshee_path) and not temporarily_cleared_banshee_paths.has(banshee_path):
			return false

	return true


func get_current_visit_banshee_clear_count() -> int:
	var count: int = 0
	for banshee in banshees:
		var banshee_path: String = get_relative_node_path(banshee)
		if banshee_path != "" and (permanently_cleared_banshee_paths.has(banshee_path) or temporarily_cleared_banshee_paths.has(banshee_path)):
			count += 1
	return count


func should_make_banshee_clears_permanent() -> bool:
	if SaveManager == null or not SaveManager.has_method("get_quest_stage"):
		return false

	return str(SaveManager.get_quest_stage("banshee_village_bishop")) == "bishop_defeated"


func prepare_for_route_exit():
	location_exit_save_pending = true
	if story_wolf_lock_active and is_wolf_hunt_stage():
		story_wolf_lock_active = false
		story_transform_prompt_consumed = true
		if player != null and player.has_method("convert_story_wolf_lock_to_timed_wolf"):
			player.convert_story_wolf_lock_to_timed_wolf()
		if SaveManager != null and SaveManager.has_method("set_pending_player_travel_message"):
			SaveManager.set_pending_player_travel_message(FINAL_WOLF_INSTRUCTION_TEXT, 7.5)
		final_wolf_instruction_shown = true

	temporarily_cleared_banshee_paths.clear()
	for banshee in banshees:
		var banshee_path: String = get_relative_node_path(banshee)
		if banshee_path != "" and permanently_cleared_banshee_paths.has(banshee_path):
			continue

		defeated_banshee_nodes.erase(banshee)
		var villager: Node = get_banshee_assigned_villager(banshee)
		var villager_path: String = get_relative_node_path(villager)
		if villager_path != "":
			cleared_villager_paths.erase(villager_path)
	state_generation += 1
	restore_stage_world_state()


func is_wolf_hunt_stage() -> bool:
	return STAGE_RULES_SCRIPT.is_wolf_hunt_stage(quest_stage)


func is_third_wave_stage() -> bool:
	return STAGE_RULES_SCRIPT.is_third_wave_stage(quest_stage)


func is_third_wave_combat_stage() -> bool:
	return STAGE_RULES_SCRIPT.is_third_wave_combat_stage(quest_stage)


func begin_wolf_hunt_cleared_stage(show_completion_prompt: bool = false):
	progression_controller.begin_wolf_hunt_cleared_stage(show_completion_prompt)


func begin_final_dulluhan_stage():
	progression_controller.begin_final_dulluhan_stage()


func begin_third_wave_cleared_stage():
	progression_controller.begin_third_wave_cleared_stage()


func accept_bishop_confrontation():
	progression_controller.accept_bishop_confrontation()


func decline_bishop_confrontation():
	progression_controller.decline_bishop_confrontation()


func save_wolf_clear_progress():
	progression_controller.save_wolf_clear_progress()


func save_third_wave_progress(reason: String):
	progression_controller.save_third_wave_progress(reason)


func _on_banshee_detected_player_for_reveal(banshee: Node):
	encounter_controller.handle_banshee_detected_player_for_reveal(banshee)


func schedule_banshee_respawn(banshee: Node):
	encounter_controller.schedule_banshee_respawn(banshee)


func respawn_banshee(banshee: Node):
	encounter_controller.respawn_banshee(banshee)


func update_kill_counter():
	presentation_controller.update_kill_counter()


func should_show_kill_counter() -> bool:
	return presentation_controller.should_show_kill_counter()


func update_exterior_vincent_presentation():
	presentation_controller.update_exterior_vincent_presentation()


func sync_vincent_house_occupancy():
	presentation_controller.sync_vincent_house_occupancy()


func should_show_exterior_vincent() -> bool:
	return presentation_controller.should_show_exterior_vincent()


func should_show_bishop_direction_progression() -> bool:
	return presentation_controller.should_show_bishop_direction_progression()


func update_route_exit_gates():
	presentation_controller.update_route_exit_gates()


func set_route_exit_enabled(route_exit: Node, enabled: bool):
	presentation_controller.set_route_exit_enabled(route_exit, enabled)


func is_third_hunt_completed_for_route_travel() -> bool:
	return presentation_controller.is_third_hunt_completed_for_route_travel()


func update_elder_flag():
	presentation_controller.update_elder_flag()


func update_dulluhan_flag():
	presentation_controller.update_dulluhan_flag()


func update_dulluhan_visibility():
	presentation_controller.update_dulluhan_visibility()


func is_dulluhan_transformation_granted() -> bool:
	return dulluhan_transformation_granted_for_level


func get_final_dulluhan_position() -> Vector2:
	return presentation_controller.get_final_dulluhan_position()


func restore_story_transformation_state():
	story_prompt_controller.restore_story_transformation_state()


func sync_story_wolf_transformation_lock():
	story_prompt_controller.sync_story_wolf_transformation_lock()


func refresh_story_transform_prompt():
	story_prompt_controller.refresh_story_transform_prompt()


func should_show_story_transform_prompt() -> bool:
	return story_prompt_controller.should_show_story_transform_prompt()


func _on_player_transformation_state_changed(active: bool):
	story_prompt_controller.handle_player_transformation_state_changed(active)


func restore_story_wolf_transformation_lock_after_unexpected_end():
	story_prompt_controller.restore_story_wolf_transformation_lock_after_unexpected_end()


func is_player_in_wolf_form() -> bool:
	return player != null and player.has_method("get_current_form_id") and player.get_current_form_id() == &"wolf"


func is_player_life_respawn_pending() -> bool:
	return player != null and player.has_method("is_life_respawn_pending") and bool(player.call("is_life_respawn_pending"))


func is_player_story_wolf_transformation_locked() -> bool:
	return player != null and player.has_method("is_story_wolf_transformation_locked") and bool(player.call("is_story_wolf_transformation_locked"))


func show_story_prompt(text: String, timeout_seconds: float = 0.0):
	story_prompt_controller.show_story_prompt(text, timeout_seconds)


func hide_story_prompt():
	story_prompt_controller.hide_story_prompt()


func hide_story_prompt_after_delay(generation: int, timeout_seconds: float):
	story_prompt_controller.hide_story_prompt_after_delay(generation, timeout_seconds)


func get_story_prompt_label() -> Label:
	return story_prompt_controller.get_story_prompt_label()
