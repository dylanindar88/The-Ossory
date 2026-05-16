class_name KnightCampEncounterController
extends Node

@export var state_root_path: NodePath
@export var hostile_root_path: NodePath
@export var campfire_root_path: NodePath

var knights: Array[Node] = []
var campfires: Array[Node] = []
var destroyed_campfire_ids: Dictionary = {}
var camp_aggro_by_id: Dictionary = {}
var camp_barked_by_id: Dictionary = {}
var route_exit_save_pending: bool = false
var state_generation: int = 0


func _ready():
	refresh_members()
	connect_campfires()
	connect_knights()
	apply_campfire_rules()


func refresh_members():
	knights = get_knights()
	campfires = get_campfires()


func collect_level_state() -> Dictionary:
	return {
		"state_version": 1,
		"destroyed_campfire_ids": [] if route_exit_save_pending else destroyed_campfire_ids.keys(),
		"campfires": collect_campfire_states(),
		"knights": [] if route_exit_save_pending else collect_knight_states(),
	}


func apply_level_state(state: Dictionary):
	state_generation += 1
	route_exit_save_pending = false
	destroyed_campfire_ids.clear()
	camp_aggro_by_id.clear()
	camp_barked_by_id.clear()
	refresh_members()

	var saved_destroyed: Variant = state.get("destroyed_campfire_ids", [])
	if saved_destroyed is Array:
		for campfire_id in saved_destroyed:
			destroyed_campfire_ids[str(campfire_id)] = true

	apply_campfire_states(state.get("campfires", []))
	refresh_members()
	apply_knight_states(state.get("knights", []))
	connect_campfires()
	connect_knights()
	apply_campfire_rules()


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	if not (state.get("destroyed_campfire_ids", []) is Array):
		messages.append("%s has malformed destroyed_campfire_ids." % name)
	if not (state.get("campfires", []) is Array):
		messages.append("%s has malformed campfire state." % name)
	if not (state.get("knights", []) is Array):
		messages.append("%s has malformed knight state." % name)
	return messages


func uses_level_owned_hostile_state() -> bool:
	return true


func prepare_for_route_exit():
	route_exit_save_pending = true
	destroyed_campfire_ids.clear()
	camp_aggro_by_id.clear()
	camp_barked_by_id.clear()
	state_generation += 1
	for campfire in campfires:
		if campfire != null and bool(campfire.get("dead")) and campfire.has_method("reset_for_level_entry"):
			campfire.reset_for_level_entry()
	for knight in knights:
		if knight != null and knight.has_method("reset_for_level_entry"):
			knight.reset_for_level_entry()
	apply_campfire_rules()


func reset_for_level_entry():
	route_exit_save_pending = false
	destroyed_campfire_ids.clear()
	camp_aggro_by_id.clear()
	camp_barked_by_id.clear()
	state_generation += 1
	for campfire in campfires:
		if campfire != null and campfire.has_method("reset_for_level_entry"):
			campfire.reset_for_level_entry()
	for knight in knights:
		if knight != null and knight.has_method("reset_for_level_entry"):
			knight.reset_for_level_entry()
	apply_campfire_rules()


func connect_campfires():
	for campfire in campfires:
		if campfire == null:
			continue
		if campfire.has_signal("destroyed"):
			var destroyed_callback := Callable(self, "_on_campfire_destroyed")
			if not campfire.is_connected("destroyed", destroyed_callback):
				campfire.connect("destroyed", destroyed_callback)
		if campfire.has_signal("player_detected"):
			var detected_callback := Callable(self, "_on_campfire_player_detected")
			if not campfire.is_connected("player_detected", detected_callback):
				campfire.connect("player_detected", detected_callback)


func connect_knights():
	for knight in knights:
		if knight == null:
			continue
		connect_knight_signal(knight, "defeated", "_on_knight_defeated")
		connect_knight_signal(knight, "player_tracking_changed", "_on_knight_tracking_changed")


func connect_knight_signal(knight: Node, signal_name: StringName, method_name: String):
	if not knight.has_signal(signal_name):
		return
	var callback := Callable(self, method_name)
	if not knight.is_connected(signal_name, callback):
		knight.connect(signal_name, callback)


func _on_campfire_destroyed(campfire: Node):
	var campfire_id := get_campfire_id(campfire)
	if campfire_id == "":
		return
	destroyed_campfire_ids[campfire_id] = true
	camp_aggro_by_id.erase(campfire_id)
	camp_barked_by_id.erase(campfire_id)
	apply_campfire_rules()


func _on_knight_defeated(knight: Node):
	schedule_knight_respawn(knight)


func _on_campfire_player_detected(campfire: Node, detected_player: Node):
	if campfire == null:
		return
	var campfire_id := get_campfire_id(campfire)
	if campfire_id == "" or destroyed_campfire_ids.has(campfire_id):
		return

	camp_aggro_by_id[campfire_id] = true
	if not camp_barked_by_id.has(campfire_id):
		camp_barked_by_id[campfire_id] = true
		var bark_knight := get_first_live_linked_knight(campfire)
		if bark_knight != null and bark_knight.has_method("try_start_encounter_dialogue"):
			bark_knight.try_start_encounter_dialogue()
	for linked_knight in get_linked_knights(campfire):
		if linked_knight != null and linked_knight.has_method("force_aggro"):
			linked_knight.force_aggro(detected_player)


func _on_knight_tracking_changed(knight: Node):
	var campfire := get_linked_campfire(knight)
	if campfire == null:
		return
	var campfire_id := get_campfire_id(campfire)
	if campfire_id == "" or not camp_aggro_by_id.has(campfire_id):
		return

	if any_linked_knight_tracking_player(campfire):
		return

	camp_aggro_by_id.erase(campfire_id)
	camp_barked_by_id.erase(campfire_id)
	for linked_knight in get_linked_knights(campfire):
		if linked_knight != null and linked_knight.has_method("clear_active_dialogue_bubble"):
			linked_knight.clear_active_dialogue_bubble()
		if linked_knight != null and linked_knight.has_method("return_to_camp"):
			linked_knight.return_to_camp()


func schedule_knight_respawn(knight: Node):
	if knight == null:
		return

	var generation := state_generation
	var delay := get_knight_respawn_delay(knight)
	await get_tree().create_timer(delay).timeout
	if generation != state_generation:
		return
	if can_respawn_knight(knight) and knight.has_method("respawn_at"):
		knight.respawn_at(get_knight_home_position(knight))


func apply_campfire_rules():
	for knight in knights:
		if knight == null:
			continue

		var campfire := get_linked_campfire(knight)
		var respawn_enabled := campfire == null or not destroyed_campfire_ids.has(get_campfire_id(campfire))
		if knight.has_method("set_respawn_enabled"):
			knight.set_respawn_enabled(respawn_enabled)


func can_respawn_knight(knight: Node) -> bool:
	if knight == null or not bool(knight.get("respawn_enabled")):
		return false

	var campfire := get_linked_campfire(knight)
	if campfire == null:
		return true
	var campfire_id := get_campfire_id(campfire)
	if destroyed_campfire_ids.has(campfire_id):
		return false

	var max_count := get_camp_max_knight_count(campfire)
	return max_count <= 0 or get_live_linked_knight_count(campfire) < max_count


func get_knight_respawn_delay(knight: Node) -> float:
	var tuning: Resource = knight.get("tuning") as Resource
	if tuning != null:
		return maxf(float(tuning.get("respawn_delay_seconds")), 0.01)
	return 10.0


func get_knight_home_position(knight: Node) -> Vector2:
	if knight != null and knight.has_method("get_home_position"):
		return knight.get_home_position()
	return knight.global_position if knight is Node2D else Vector2.ZERO


func get_camp_max_knight_count(campfire: Node) -> int:
	if campfire != null and campfire.has_method("get_max_knight_count"):
		return int(campfire.get_max_knight_count())
	return 0


func get_live_linked_knight_count(campfire: Node) -> int:
	var count := 0
	for knight in get_linked_knights(campfire):
		if knight != null and not bool(knight.get("dead")):
			count += 1
	return count


func get_first_live_linked_knight(campfire: Node) -> Node:
	for knight in get_linked_knights(campfire):
		if knight != null and not bool(knight.get("dead")):
			return knight
	return null


func get_linked_knights(campfire: Node) -> Array[Node]:
	var linked: Array[Node] = []
	for knight in knights:
		if knight != null and get_linked_campfire(knight) == campfire:
			linked.append(knight)
	return linked


func any_linked_knight_tracking_player(campfire: Node) -> bool:
	for knight in get_linked_knights(campfire):
		if knight != null and knight.has_method("has_active_player_tracking") and knight.has_active_player_tracking():
			return true
	return false


func collect_knight_states() -> Array:
	var states: Array = []
	for knight in knights:
		if knight == null:
			continue
		var state: Dictionary = {}
		if knight.has_method("collect_story_save_state"):
			var raw_state: Variant = knight.collect_story_save_state()
			if raw_state is Dictionary:
				state = raw_state
		state["node_path"] = get_relative_node_path(knight)
		states.append(state)
	return states


func collect_campfire_states() -> Array:
	var states: Array = []
	for campfire in campfires:
		if campfire == null:
			continue
		var state: Dictionary = {}
		if campfire.has_method("collect_story_save_state"):
			var raw_state: Variant = campfire.collect_story_save_state()
			if raw_state is Dictionary:
				state = raw_state
		state["node_path"] = get_relative_node_path(campfire)
		states.append(state)
	return states


func apply_knight_states(states: Variant):
	var lookup := parse_snapshot_lookup(states)
	for knight in knights:
		var path := get_relative_node_path(knight)
		if lookup.has(path) and knight.has_method("apply_story_save_state"):
			knight.apply_story_save_state(lookup[path])


func apply_campfire_states(states: Variant):
	var lookup := parse_snapshot_lookup(states)
	for campfire in campfires:
		var path := get_relative_node_path(campfire)
		if lookup.has(path) and campfire.has_method("apply_story_save_state"):
			campfire.apply_story_save_state(lookup[path])
			if bool(campfire.get("dead")):
				destroyed_campfire_ids[get_campfire_id(campfire)] = true


func parse_snapshot_lookup(states: Variant) -> Dictionary:
	var lookup: Dictionary = {}
	if not (states is Array):
		return lookup

	for raw_state in states:
		if not (raw_state is Dictionary):
			continue
		var state: Dictionary = raw_state
		var node_path := str(state.get("node_path", ""))
		if node_path != "":
			lookup[node_path] = state
	return lookup


func get_knights() -> Array[Node]:
	var found: Array[Node] = []
	collect_group_members_from(get_configured_root(hostile_root_path), "hostile_npcs", found, "set_respawn_enabled")
	return found


func get_campfires() -> Array[Node]:
	var found: Array[Node] = []
	collect_group_members_from(get_configured_root(campfire_root_path), "campfire_bases", found)
	return found


func collect_group_members_from(root: Node, group_name: String, found: Array[Node], required_method: String = ""):
	if root == null:
		return

	for child in root.get_children():
		if child.is_in_group(group_name) and (required_method == "" or child.has_method(required_method)):
			found.append(child)
		collect_group_members_from(child, group_name, found, required_method)


func get_linked_campfire(knight: Node) -> Node:
	if knight == null:
		return null

	var path := NodePath(str(knight.get("campfire_base_path")))
	if str(path) != "":
		var linked := knight.get_node_or_null(path)
		if linked != null:
			return linked
	return null


func get_campfire_id(campfire: Node) -> String:
	if campfire == null:
		return ""
	return str(campfire.get("campfire_id"))


func get_configured_root(path: NodePath) -> Node:
	if str(path) != "":
		var root := get_node_or_null(path)
		if root != null:
			return root
	return get_state_root()


func get_relative_node_path(node: Node) -> String:
	var root := get_state_root()
	if root != null and root != node and root.is_ancestor_of(node):
		return str(root.get_path_to(node))
	return str(node.get_path())


func get_state_root() -> Node:
	if str(state_root_path) != "":
		var root := get_node_or_null(state_root_path)
		if root != null:
			return root
	return get_parent()
