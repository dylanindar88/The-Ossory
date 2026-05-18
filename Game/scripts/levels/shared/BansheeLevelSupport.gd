class_name BansheeLevelSupport
extends Node

const MODE_STORY_RULES := "story_rules"
const BANSHEE_ENCOUNTER_CONTROLLER_SCRIPT = preload("res://scripts/levels/shared/BansheeEncounterController.gd")

var level_root: Node
var hostile_root: Node
var encounter_controller: BansheeEncounterController


func configure(owner_level: Node, hostile_root_node: Node, _support_mode: String = MODE_STORY_RULES):
	level_root = owner_level
	hostile_root = hostile_root_node
	ensure_encounter_controller()
	refresh_wiring()


func collect_level_state() -> Dictionary:
	ensure_encounter_controller()
	if encounter_controller == null:
		return {}
	return encounter_controller.collect_level_state()


func apply_level_state(state: Dictionary):
	ensure_encounter_controller()
	if encounter_controller != null:
		encounter_controller.apply_level_state(state)


func validate_level_state(state: Dictionary) -> Array:
	ensure_encounter_controller()
	if encounter_controller == null:
		return []
	return encounter_controller.validate_level_state(state)


func uses_level_owned_hostile_state() -> bool:
	return true


func prepare_for_route_exit():
	if encounter_controller != null:
		encounter_controller.prepare_for_route_exit()


func get_encounter_controller() -> BansheeEncounterController:
	ensure_encounter_controller()
	return encounter_controller


func refresh_wiring():
	if encounter_controller != null:
		encounter_controller.refresh_wiring()


func ensure_encounter_controller():
	if encounter_controller == null:
		encounter_controller = BANSHEE_ENCOUNTER_CONTROLLER_SCRIPT.new()
		encounter_controller.name = "BansheeEncounterController"
		add_child(encounter_controller)

	configure_controller()


func configure_controller():
	if encounter_controller == null:
		return

	var resolved_level := get_valid_level_root()
	var resolved_hostile := get_valid_hostile_root(resolved_level)
	encounter_controller.state_root_path = get_controller_path_to(resolved_level)
	encounter_controller.hostile_root_path = get_controller_path_to(resolved_hostile)
	encounter_controller.use_save_manager_world_rules = true
	encounter_controller.default_banshees_hostile_enabled = false
	encounter_controller.default_player_can_damage_banshees = false
	encounter_controller.default_wolf_permanent_clear_enabled = false
	encounter_controller.default_bishop_defeated = false
	encounter_controller.default_combat_variant = BansheeEncounterController.BANSHEE_VARIANT_CORRUPTED_MELEE
	encounter_controller.default_vincent_upgrades_enabled = false


func get_valid_level_root() -> Node:
	if is_instance_valid(level_root):
		return level_root
	var parent := get_parent()
	if parent != null:
		return parent.get_parent() if parent.get_parent() != null else parent
	return null


func get_valid_hostile_root(fallback_root: Node) -> Node:
	if is_instance_valid(hostile_root):
		return hostile_root
	return fallback_root


func get_controller_path_to(target: Node) -> NodePath:
	if encounter_controller == null or target == null:
		return NodePath("")
	if not encounter_controller.is_inside_tree() or not target.is_inside_tree():
		return NodePath("")
	return encounter_controller.get_path_to(target)
