extends Node

const STATE_VERSION := 1
const KNIGHT_CAMP_LEVEL_SUPPORT_SCRIPT = preload("res://scripts/levels/shared/KnightCampLevelSupport.gd")
const BANSHEE_LEVEL_SUPPORT_SCRIPT = preload("res://scripts/levels/shared/BansheeLevelSupport.gd")

@export var hostile_root_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/HostileNPCs")

var banshee_support: BansheeLevelSupport
var banshee_encounter_controller: BansheeEncounterController
var knight_camp_support: KnightCampLevelSupport
var knight_camp_controller: KnightCampEncounterController


func _ready():
	setup_banshee_encounter_controller()
	setup_knight_camp_controller()


func collect_level_state() -> Dictionary:
	var banshee_encounter_state: Dictionary = {}
	if banshee_encounter_controller != null:
		banshee_encounter_state = banshee_encounter_controller.collect_level_state()
	var knight_camp_state: Dictionary = {}
	if knight_camp_controller != null:
		knight_camp_state = knight_camp_controller.collect_level_state()

	return {
		"state_version": STATE_VERSION,
		"banshee_encounter": banshee_encounter_state,
		"knight_camps": knight_camp_state,
	}


func apply_level_state(state: Dictionary):
	if not (state is Dictionary):
		return
	ensure_banshee_encounter_controller()
	ensure_knight_camp_controller()
	var banshee_encounter_state: Dictionary = {}
	var raw_banshee_encounter_state: Variant = state.get("banshee_encounter", {})
	if raw_banshee_encounter_state is Dictionary:
		banshee_encounter_state = raw_banshee_encounter_state
	if banshee_encounter_controller != null:
		banshee_encounter_controller.apply_level_state(banshee_encounter_state)
	var knight_camp_state: Dictionary = {}
	var raw_knight_camp_state: Variant = state.get("knight_camps", {})
	if raw_knight_camp_state is Dictionary:
		knight_camp_state = raw_knight_camp_state
	if knight_camp_controller != null:
		knight_camp_controller.apply_level_state(knight_camp_state)


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	if not (state is Dictionary):
		messages.append("Weeping Woods level state must be a dictionary.")
		return messages
	if int(state.get("state_version", 0)) > STATE_VERSION:
		messages.append("Weeping Woods save state version %d is newer than supported version %d." % [int(state.get("state_version", 0)), STATE_VERSION])
	var raw_banshee_encounter_state: Variant = state.get("banshee_encounter", {})
	if state.has("banshee_encounter") and not (raw_banshee_encounter_state is Dictionary):
		messages.append("Weeping Woods save has malformed banshee encounter state.")
	if banshee_encounter_controller != null and raw_banshee_encounter_state is Dictionary:
		var banshee_encounter_state: Dictionary = raw_banshee_encounter_state
		messages.append_array(banshee_encounter_controller.validate_level_state(banshee_encounter_state))
	var raw_knight_camp_state: Variant = state.get("knight_camps", {})
	if state.has("knight_camps") and not (raw_knight_camp_state is Dictionary):
		messages.append("Weeping Woods save has malformed knight camp state.")
	if knight_camp_controller != null and raw_knight_camp_state is Dictionary:
		var knight_camp_state: Dictionary = raw_knight_camp_state
		messages.append_array(knight_camp_controller.validate_level_state(knight_camp_state))
	return messages


func uses_level_owned_hostile_state() -> bool:
	return (
		(banshee_encounter_controller != null and not banshee_encounter_controller.banshees.is_empty())
		or (knight_camp_controller != null and not knight_camp_controller.campfires.is_empty())
	)


func uses_level_owned_non_hostile_npc_state() -> bool:
	return false


func prepare_for_route_exit():
	if banshee_encounter_controller != null:
		banshee_encounter_controller.prepare_for_route_exit()
	if knight_camp_controller != null:
		knight_camp_controller.prepare_for_route_exit()


func setup_banshee_encounter_controller():
	if banshee_encounter_controller != null:
		return

	if banshee_support == null:
		banshee_support = BANSHEE_LEVEL_SUPPORT_SCRIPT.new()
		banshee_support.name = "BansheeLevelSupport"
		add_child(banshee_support)

	var level_root := get_parent()
	var hostile_root := get_node_or_null(hostile_root_path)
	banshee_support.configure(level_root, hostile_root, BansheeLevelSupport.MODE_STORY_RULES)
	banshee_encounter_controller = banshee_support.get_encounter_controller()


func ensure_banshee_encounter_controller():
	if banshee_encounter_controller == null:
		setup_banshee_encounter_controller()


func setup_knight_camp_controller():
	if knight_camp_controller != null:
		return

	if knight_camp_support == null:
		knight_camp_support = KNIGHT_CAMP_LEVEL_SUPPORT_SCRIPT.new()
		knight_camp_support.name = "KnightCampLevelSupport"
		add_child(knight_camp_support)

	var level_root := get_parent()
	var hostile_root := get_node_or_null(hostile_root_path)
	knight_camp_support.configure(level_root, hostile_root, hostile_root)
	knight_camp_controller = knight_camp_support.get_knight_camp_controller()


func ensure_knight_camp_controller():
	if knight_camp_controller == null:
		setup_knight_camp_controller()
