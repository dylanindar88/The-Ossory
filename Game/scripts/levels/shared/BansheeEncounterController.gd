extends Node
class_name BansheeEncounterController

const BANSHEE_VARIANT_CORRUPTED_MELEE: String = "corrupted_melee"

@export var hostile_root_path: NodePath
@export var hidden_banshee_alpha: float = 0.2
@export var passive_banshee_alpha: float = 1.0
@export var respawn_delay_seconds: float = 10.0

var banshees: Array[Node] = []
var temporarily_cleared_banshee_paths: Dictionary = {}
var saved_banshee_states: Dictionary = {}
var route_exit_save_pending: bool = false
var state_generation: int = 0


func _ready():
	banshees = get_banshees()
	connect_banshees()
	apply_banshee_world_rules()


func collect_level_state() -> Dictionary:
	var temporary_paths: Array = []
	if not route_exit_save_pending:
		temporary_paths = temporarily_cleared_banshee_paths.keys()

	return {
		"state_version": 1,
		"temporarily_cleared_banshee_paths": temporary_paths,
		"banshees": collect_banshee_states(),
	}


func apply_level_state(state: Dictionary):
	state_generation += 1
	route_exit_save_pending = false
	temporarily_cleared_banshee_paths.clear()
	saved_banshee_states = {}
	if SaveManager != null:
		saved_banshee_states = SaveManager.parse_actor_snapshot_lookup(state.get("banshees", []))

	var saved_temporary_paths: Variant = state.get("temporarily_cleared_banshee_paths", [])
	if saved_temporary_paths is Array:
		for path in saved_temporary_paths:
			temporarily_cleared_banshee_paths[str(path)] = true

	apply_banshee_world_rules()
	saved_banshee_states.clear()


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	if not (state.get("temporarily_cleared_banshee_paths", []) is Array):
		messages.append("%s has malformed temporarily_cleared_banshee_paths." % name)
	if not (state.get("banshees", []) is Array):
		messages.append("%s has malformed banshee snapshot data." % name)
	return messages


func uses_level_owned_hostile_state() -> bool:
	return true


func prepare_for_route_exit():
	temporarily_cleared_banshee_paths.clear()
	route_exit_save_pending = true
	state_generation += 1
	apply_banshee_world_rules()


func get_banshees() -> Array[Node]:
	var found_banshees: Array[Node] = []
	var root: Node = get_node_or_null(hostile_root_path)
	if root == null:
		root = get_parent()
	collect_banshees_from(root, found_banshees)
	return found_banshees


func collect_banshees_from(root: Node, found_banshees: Array[Node]):
	if root == null:
		return

	for child in root.get_children():
		if child.is_in_group("hostile_npcs") and child.has_method("set_combat_variant"):
			found_banshees.append(child)
		collect_banshees_from(child, found_banshees)


func connect_banshees():
	for banshee in banshees:
		if banshee == null:
			continue
		if banshee.has_signal("defeated"):
			var defeated_callback: Callable = Callable(self, "_on_banshee_defeated")
			if not banshee.is_connected("defeated", defeated_callback):
				banshee.connect("defeated", defeated_callback)


func apply_banshee_world_rules():
	var rules: Dictionary = get_banshee_world_rules()
	var hostile_enabled: bool = bool(rules.get("banshees_hostile_enabled", false))
	var damage_enabled: bool = bool(rules.get("player_can_damage_banshees", false))
	var combat_variant: String = str(rules.get("combat_variant", BANSHEE_VARIANT_CORRUPTED_MELEE))

	for banshee in banshees:
		if banshee == null or not is_instance_valid(banshee):
			continue

		var banshee_path: String = get_relative_node_path(banshee)
		if temporarily_cleared_banshee_paths.has(banshee_path):
			apply_cleared_banshee_state(banshee)
			continue

		if banshee.has_method("set_combat_variant"):
			banshee.set_combat_variant(combat_variant)

		var saved_state: Dictionary = {}
		var raw_saved_state: Variant = saved_banshee_states.get(banshee_path, {})
		if raw_saved_state is Dictionary:
			saved_state = raw_saved_state

		if not saved_state.is_empty() and banshee.has_method("restore_from_story_save"):
			banshee.restore_from_story_save(saved_state, hidden_banshee_alpha, hostile_enabled, false)
		elif banshee.has_method("restore_after_load"):
			banshee.restore_after_load()

		apply_banshee_rules_to_actor(banshee, hostile_enabled, damage_enabled)


func get_banshee_world_rules() -> Dictionary:
	if SaveManager != null and SaveManager.has_method("get_banshee_world_rules"):
		return SaveManager.get_banshee_world_rules()

	return {
		"banshees_hostile_enabled": false,
		"player_can_damage_banshees": false,
		"wolf_permanent_clear_enabled": false,
		"combat_variant": BANSHEE_VARIANT_CORRUPTED_MELEE,
	}


func apply_banshee_rules_to_actor(banshee: Node, hostile_enabled: bool, damage_enabled: bool):
	if banshee.has_method("set_story_combat_enabled"):
		banshee.set_story_combat_enabled(hostile_enabled, hidden_banshee_alpha if hostile_enabled else passive_banshee_alpha)
	elif banshee.has_method("enable_story_combat") and hostile_enabled:
		banshee.enable_story_combat(hidden_banshee_alpha)
	elif banshee.has_method("disable_story_combat") and not hostile_enabled:
		banshee.disable_story_combat(passive_banshee_alpha)

	if banshee.has_method("set_damage_enabled"):
		banshee.set_damage_enabled(damage_enabled)


func _on_banshee_defeated(banshee: Node):
	if banshee == null or temporarily_cleared_banshee_paths.has(get_relative_node_path(banshee)):
		return

	var killed_by_wolf: bool = was_banshee_killed_by_wolf(banshee)
	var rules: Dictionary = get_banshee_world_rules()
	if killed_by_wolf and bool(rules.get("wolf_permanent_clear_enabled", false)):
		temporarily_cleared_banshee_paths[get_relative_node_path(banshee)] = true
		apply_cleared_banshee_state(banshee)
		return

	schedule_banshee_respawn(banshee)


func was_banshee_killed_by_wolf(banshee: Node) -> bool:
	var killer_form_id: StringName = StringName(str(banshee.get("last_killer_form_id")))
	if killer_form_id == &"wolf":
		return true

	var player: Node = get_tree().get_first_node_in_group("player")
	return player != null and player.has_method("get_current_form_id") and player.get_current_form_id() == &"wolf"


func apply_cleared_banshee_state(banshee: Node):
	if banshee.has_method("apply_cleared_story_state"):
		banshee.apply_cleared_story_state(hidden_banshee_alpha)
	elif banshee.has_method("hide_as_story_defeated"):
		banshee.hide_as_story_defeated(hidden_banshee_alpha)
	else:
		banshee.visible = false
		banshee.set("dead", true)
		if banshee.has_method("disable_combat_areas"):
			banshee.disable_combat_areas()


func schedule_banshee_respawn(banshee: Node):
	var scheduled_generation: int = state_generation
	await get_tree().create_timer(respawn_delay_seconds).timeout
	if scheduled_generation != state_generation:
		return
	if banshee == null or not is_instance_valid(banshee) or temporarily_cleared_banshee_paths.has(get_relative_node_path(banshee)):
		return

	apply_banshee_world_rules()


func collect_banshee_states() -> Array:
	var states: Array = []
	for banshee in banshees:
		if banshee == null:
			continue

		var banshee_path: String = get_relative_node_path(banshee)
		if banshee_path == "":
			continue

		var state: Dictionary = {}
		if banshee.has_method("collect_story_save_state"):
			var raw_state: Variant = banshee.collect_story_save_state()
			if raw_state is Dictionary:
				state = raw_state
		state["node_path"] = banshee_path
		states.append(state)

	return states


func get_relative_node_path(node: Node) -> String:
	var level: Node = get_parent()
	if level != null and level != node and level.is_ancestor_of(node):
		return str(level.get_path_to(node))

	return str(node.get_path())
