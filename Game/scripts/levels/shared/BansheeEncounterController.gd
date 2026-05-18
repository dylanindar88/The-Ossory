extends Node
class_name BansheeEncounterController

const BANSHEE_VARIANT_CORRUPTED_MELEE: String = "corrupted_melee"
const BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED: String = "corrupted_strong_ranged"
const BANSHEE_TUNING: BansheeTuning = preload("res://resources/characters/hostile_npcs/banshees/banshee_tuning.tres")

@export var state_root_path: NodePath
@export var hostile_root_path: NodePath
@export var use_save_manager_world_rules: bool = true
@export var default_banshees_hostile_enabled: bool = false
@export var default_player_can_damage_banshees: bool = false
@export var default_wolf_permanent_clear_enabled: bool = false
@export var default_bishop_defeated: bool = false
@export var default_combat_variant: String = BANSHEE_VARIANT_CORRUPTED_MELEE
@export var default_vincent_upgrades_enabled: bool = false

var banshees: Array[Node] = []
var temporarily_cleared_banshee_paths: Dictionary = {}
var permanently_cleared_banshee_paths: Dictionary = {}
var saved_banshee_states: Dictionary = {}
var route_exit_save_pending: bool = false
var state_generation: int = 0


func _ready():
	refresh_wiring()


func refresh_wiring():
	refresh_members()
	apply_banshee_world_rules()


func refresh_members():
	banshees = get_banshees()
	assign_banshee_indexes()
	connect_banshees()


func collect_level_state() -> Dictionary:
	var temporary_paths: Array = []
	if not route_exit_save_pending:
		temporary_paths = temporarily_cleared_banshee_paths.keys()

	return {
		"state_version": 2,
		"temporarily_cleared_banshee_paths": temporary_paths,
		"permanently_cleared_banshee_paths": permanently_cleared_banshee_paths.keys(),
		"banshees": [] if route_exit_save_pending else collect_banshee_states(),
	}


func apply_level_state(state: Dictionary):
	state_generation += 1
	route_exit_save_pending = false
	temporarily_cleared_banshee_paths.clear()
	permanently_cleared_banshee_paths.clear()
	saved_banshee_states = {}
	refresh_members()
	if SaveManager != null:
		saved_banshee_states = SaveManager.parse_actor_snapshot_lookup(state.get("banshees", []))

	var saved_temporary_paths: Variant = state.get("temporarily_cleared_banshee_paths", [])
	if saved_temporary_paths is Array:
		for path in saved_temporary_paths:
			temporarily_cleared_banshee_paths[str(path)] = true

	var saved_permanent_paths: Variant = state.get("permanently_cleared_banshee_paths", [])
	if saved_permanent_paths is Array:
		for path in saved_permanent_paths:
			permanently_cleared_banshee_paths[str(path)] = true

	apply_banshee_world_rules()
	saved_banshee_states.clear()


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	if not (state.get("temporarily_cleared_banshee_paths", []) is Array):
		messages.append("%s has malformed temporarily_cleared_banshee_paths." % name)
	if not (state.get("permanently_cleared_banshee_paths", []) is Array):
		messages.append("%s has malformed permanently_cleared_banshee_paths." % name)
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
		root = get_state_root()
	collect_banshees_from(root, found_banshees)
	return found_banshees


func assign_banshee_indexes():
	for index in range(banshees.size()):
		var banshee := banshees[index]
		if banshee != null:
			banshee.set("banshee_index", index)


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
	var wolf_weakness_effect_enabled: bool = bool(rules.get("wolf_permanent_clear_enabled", false))
	var upgrades_available: bool = are_banshee_upgrades_available(rules)

	for banshee in banshees:
		if banshee == null or not is_instance_valid(banshee):
			continue

		set_banshee_wolf_weakness_effect_enabled(banshee, wolf_weakness_effect_enabled)
		var banshee_path: String = get_relative_node_path(banshee)
		if permanently_cleared_banshee_paths.has(banshee_path):
			apply_cleared_banshee_state(banshee)
			continue
		if temporarily_cleared_banshee_paths.has(banshee_path):
			apply_cleared_banshee_state(banshee)
			continue

		apply_story_variant_to_banshee(banshee, upgrades_available)

		var saved_state: Dictionary = {}
		var raw_saved_state: Variant = saved_banshee_states.get(banshee_path, {})
		if raw_saved_state is Dictionary:
			saved_state = (raw_saved_state as Dictionary).duplicate(true)
			sanitize_saved_banshee_variant(saved_state, banshee, upgrades_available)

		if is_saved_banshee_defeated(banshee, saved_state):
			apply_saved_defeated_banshee_state(banshee, saved_state)
			schedule_banshee_respawn(banshee)
			continue

		var restored_from_saved_state: bool = false
		if not saved_state.is_empty() and banshee.has_method("restore_from_story_save"):
			banshee.restore_from_story_save(saved_state, get_hidden_banshee_alpha(), hostile_enabled, false)
			restored_from_saved_state = true
		elif banshee.has_method("restore_after_load"):
			banshee.restore_after_load()

		apply_banshee_rules_to_actor(banshee, hostile_enabled, damage_enabled)
		if hostile_enabled and not restored_from_saved_state and banshee.has_method("begin_assigned_villager_catchup_if_needed"):
			banshee.begin_assigned_villager_catchup_if_needed()


func get_banshee_world_rules() -> Dictionary:
	if use_save_manager_world_rules and SaveManager != null and SaveManager.has_method("get_banshee_world_rules"):
		return SaveManager.get_banshee_world_rules()

	return {
		"banshees_hostile_enabled": default_banshees_hostile_enabled,
		"player_can_damage_banshees": default_player_can_damage_banshees,
		"wolf_permanent_clear_enabled": default_wolf_permanent_clear_enabled,
		"bishop_defeated": default_bishop_defeated,
		"combat_variant": default_combat_variant,
		"vincent_upgrades_enabled": default_vincent_upgrades_enabled,
	}


func apply_banshee_rules_to_actor(banshee: Node, hostile_enabled: bool, damage_enabled: bool):
	if banshee.has_method("set_story_combat_enabled"):
		banshee.set_story_combat_enabled(hostile_enabled, get_hidden_banshee_alpha() if hostile_enabled else get_passive_banshee_alpha())
	elif banshee.has_method("enable_story_combat") and hostile_enabled:
		banshee.enable_story_combat(get_hidden_banshee_alpha())
	elif banshee.has_method("disable_story_combat") and not hostile_enabled:
		banshee.disable_story_combat(get_passive_banshee_alpha())

	if banshee.has_method("set_damage_enabled"):
		banshee.set_damage_enabled(hostile_enabled and damage_enabled)


func get_hidden_banshee_alpha() -> float:
	if BANSHEE_TUNING == null:
		return 0.2
	return clampf(float(BANSHEE_TUNING.hidden_banshee_alpha), 0.0, 1.0)


func get_passive_banshee_alpha() -> float:
	if BANSHEE_TUNING == null:
		return 0.2
	return clampf(float(BANSHEE_TUNING.passive_banshee_alpha), 0.0, 1.0)


func get_story_respawn_delay_seconds() -> float:
	if BANSHEE_TUNING == null:
		return 10.0
	return maxf(float(BANSHEE_TUNING.story_respawn_delay_seconds), 0.01)


func set_banshee_wolf_weakness_effect_enabled(banshee: Node, enabled: bool):
	if banshee != null and banshee.has_method("set_wolf_weakness_effect_enabled"):
		banshee.set_wolf_weakness_effect_enabled(enabled)


func are_banshee_upgrades_available(rules: Dictionary) -> bool:
	return bool(rules.get("vincent_upgrades_enabled", false)) or str(rules.get("combat_variant", BANSHEE_VARIANT_CORRUPTED_MELEE)) == BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED


func apply_story_variant_to_banshee(banshee: Node, upgrades_available: bool):
	if banshee.has_method("apply_story_combat_variant"):
		banshee.apply_story_combat_variant(upgrades_available)
	elif banshee.has_method("set_combat_variant"):
		banshee.set_combat_variant(BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED if upgrades_available else BANSHEE_VARIANT_CORRUPTED_MELEE)


func get_story_variant_for_banshee(banshee: Node, upgrades_available: bool) -> String:
	if banshee.has_method("resolve_combat_variant_for_story"):
		return str(banshee.resolve_combat_variant_for_story(upgrades_available))

	return BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED if upgrades_available else BANSHEE_VARIANT_CORRUPTED_MELEE


func sanitize_saved_banshee_variant(saved_state: Dictionary, banshee: Node, upgrades_available: bool):
	saved_state["combat_variant"] = get_story_variant_for_banshee(banshee, upgrades_available)


func _on_banshee_defeated(banshee: Node):
	if banshee == null:
		return

	var banshee_path: String = get_relative_node_path(banshee)
	if temporarily_cleared_banshee_paths.has(banshee_path) or permanently_cleared_banshee_paths.has(banshee_path):
		return

	var killed_by_wolf: bool = was_banshee_killed_by_wolf(banshee)
	var rules: Dictionary = get_banshee_world_rules()
	if bool(rules.get("bishop_defeated", false)):
		permanently_cleared_banshee_paths[banshee_path] = true
		apply_cleared_banshee_state(banshee)
		return

	if killed_by_wolf and bool(rules.get("wolf_permanent_clear_enabled", false)):
		temporarily_cleared_banshee_paths[banshee_path] = true
		apply_cleared_banshee_state(banshee)
		return

	schedule_banshee_respawn(banshee)


func was_banshee_killed_by_wolf(banshee: Node) -> bool:
	var killer_form_id: StringName = StringName(str(banshee.get("last_killer_form_id")))
	if killer_form_id == &"wolf":
		return true

	if not is_inside_tree():
		return false
	var player: Node = get_tree().get_first_node_in_group("player")
	return player != null and player.has_method("get_current_form_id") and player.get_current_form_id() == &"wolf"


func apply_cleared_banshee_state(banshee: Node):
	if banshee.has_method("apply_cleared_story_state"):
		banshee.apply_cleared_story_state(get_hidden_banshee_alpha())
	elif banshee.has_method("hide_as_story_defeated"):
		banshee.hide_as_story_defeated(get_hidden_banshee_alpha())
	else:
		banshee.visible = false
		banshee.set("dead", true)
		if banshee.has_method("disable_combat_areas"):
			banshee.disable_combat_areas()


func apply_saved_defeated_banshee_state(banshee: Node, saved_state: Dictionary):
	if banshee.has_method("restore_dead_from_story_save"):
		banshee.restore_dead_from_story_save(saved_state, get_hidden_banshee_alpha())
	elif banshee.has_method("hide_as_story_defeated"):
		banshee.hide_as_story_defeated(get_hidden_banshee_alpha())
	else:
		apply_cleared_banshee_state(banshee)


func is_saved_banshee_defeated(banshee: Node, saved_state: Dictionary) -> bool:
	if saved_state.is_empty():
		return false

	if banshee != null and banshee.has_method("is_saved_defeated_story_state"):
		return bool(banshee.call("is_saved_defeated_story_state", saved_state))

	return bool(saved_state.get("dead", false)) or int(saved_state.get("health", 1)) <= 0


func schedule_banshee_respawn(banshee: Node):
	var scheduled_generation: int = state_generation
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(get_story_respawn_delay_seconds()).timeout
	if not is_inside_tree():
		return
	if scheduled_generation != state_generation:
		return
	if banshee == null or not is_instance_valid(banshee):
		return

	respawn_banshee(banshee)


func respawn_banshee(banshee: Node):
	if banshee == null or not is_instance_valid(banshee):
		return

	var banshee_path: String = get_relative_node_path(banshee)
	if temporarily_cleared_banshee_paths.has(banshee_path) or permanently_cleared_banshee_paths.has(banshee_path):
		return

	var rules: Dictionary = get_banshee_world_rules()
	var hostile_enabled: bool = bool(rules.get("banshees_hostile_enabled", false))
	var damage_enabled: bool = bool(rules.get("player_can_damage_banshees", false))
	var wolf_weakness_effect_enabled: bool = bool(rules.get("wolf_permanent_clear_enabled", false))
	var upgrades_available: bool = are_banshee_upgrades_available(rules)

	apply_story_variant_to_banshee(banshee, upgrades_available)
	set_banshee_wolf_weakness_effect_enabled(banshee, wolf_weakness_effect_enabled)
	if banshee.has_method("respawn_for_story"):
		banshee.respawn_for_story(get_hidden_banshee_alpha())
	elif banshee.has_method("restore_after_load"):
		banshee.restore_after_load()
		if banshee.has_method("begin_assigned_villager_catchup_if_needed"):
			banshee.begin_assigned_villager_catchup_if_needed()

	apply_banshee_rules_to_actor(banshee, hostile_enabled, damage_enabled)


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
	var level: Node = get_state_root()
	if level != null and level != node and level.is_ancestor_of(node):
		return str(level.get_path_to(node))

	return str(node.get_path())


func get_state_root() -> Node:
	if str(state_root_path) != "":
		var root: Node = get_node_or_null(state_root_path)
		if root != null:
			return root

	return get_parent()
