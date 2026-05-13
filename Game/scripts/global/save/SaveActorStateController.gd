class_name SaveActorStateController
extends RefCounted

var save_manager


func setup(owner_save_manager):
	save_manager = owner_save_manager


func collect_player_state(level: Node) -> Dictionary:
	var player: Node2D = save_manager.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return {}

	var health_node: Node = player.get_node_or_null("Health")
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D

	var data: Dictionary = {
		"node_path": get_relative_node_path(level, player),
		"position": vector_to_data(player.global_position),
		"form_id": "human",
		"health": {},
		"stamina": {},
		"camera_zoom": 2.25,
	}

	if player.has_method("get_save_form_id"):
		data["form_id"] = str(player.get_save_form_id())
	elif player.has_method("get_current_form_id"):
		data["form_id"] = str(player.get_current_form_id())

	if health_node != null:
		var max_health: int = maxi(int(health_node.get("max_health")), 1)
		var current_health: int = clamp(int(health_node.get("health")), 1, max_health)
		var current_stamina: float = float(health_node.get("stamina"))
		if bool(health_node.get("dead")) or int(health_node.get("health")) <= 0:
			current_health = max_health
			current_stamina = float(health_node.get("max_stamina"))
		data["health"] = {
			"current": current_health,
			"max": max_health,
			"dead": false,
		}
		data["stamina"] = {
			"current": current_stamina,
			"max": float(health_node.get("max_stamina")),
		}

	if camera != null:
		data["camera_zoom"] = camera.zoom.x

	return data


func apply_player_state(level: Node, player_data: Variant):
	if not (player_data is Dictionary):
		return

	var data: Dictionary = player_data
	var player: Node2D = get_node_from_saved_path(level, str(data.get("node_path", ""))) as Node2D
	if player == null:
		player = save_manager.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	player.global_position = data_to_vector(data.get("position", {}), player.global_position)

	if player.has_method("set_form"):
		player.set_form(StringName(str(data.get("form_id", "human"))))

	var health_node: Node = player.get_node_or_null("Health")
	var repaired_dead_player_save: bool = false
	if health_node != null:
		var health_data: Dictionary = data.get("health", {})
		var stamina_data: Dictionary = data.get("stamina", {})
		var max_health: int = maxi(int(health_node.get("max_health")), 1)
		var saved_health: int = int(health_data.get("current", health_node.get("health")))
		var saved_dead: bool = bool(health_data.get("dead", false))
		repaired_dead_player_save = saved_dead or saved_health <= 0
		var applied_health: int = max_health if repaired_dead_player_save else clamp(saved_health, 1, max_health)
		var applied_stamina: float = float(health_node.get("max_stamina")) if repaired_dead_player_save else clamp(float(stamina_data.get("current", health_node.get("stamina"))), 0.0, float(health_node.get("max_stamina")))
		health_node.set("health", applied_health)
		health_node.set("dead", false)
		health_node.set("stamina", applied_stamina)
		if health_node.has_signal("health_changed"):
			health_node.emit_signal("health_changed", health_node.get("health"), health_node.get("max_health"))
		if health_node.has_signal("stamina_changed"):
			health_node.emit_signal("stamina_changed", health_node.get("stamina"), health_node.get("max_stamina"))

	if repaired_dead_player_save and OS.is_debug_build():
		print_verbose("Loaded player save had dead/zero-health state; repaired to alive full health.")

	if player.has_method("restore_after_load"):
		player.restore_after_load()

	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		var zoom_value: float = float(data.get("camera_zoom", camera.zoom.x))
		if camera.has_method("change_zoom"):
			camera.change_zoom(zoom_value)
		else:
			camera.zoom = Vector2(zoom_value, zoom_value)


func is_saved_player_dead(player_data: Variant) -> bool:
	if not (player_data is Dictionary):
		return false

	var data: Dictionary = player_data
	var raw_health_data: Variant = data.get("health", {})
	if not (raw_health_data is Dictionary):
		return false

	var health_data: Dictionary = raw_health_data
	return bool(health_data.get("dead", false)) or int(health_data.get("current", 1)) <= 0


func collect_defeated_hostiles(level: Node) -> Array:
	var defeated: Array = []
	for hostile in save_manager.get_tree().get_nodes_in_group("hostile_npcs"):
		if not is_node_in_level(level, hostile):
			continue

		var is_defeated: bool = bool(hostile.get("dead"))
		var health_node: Node = hostile.get_node_or_null("Health")
		if health_node != null:
			is_defeated = is_defeated or bool(health_node.get("dead"))

		if is_defeated:
			defeated.append(get_relative_node_path(level, hostile))

	return defeated


func apply_defeated_hostiles(level: Node, defeated_paths: Variant):
	if not (defeated_paths is Array):
		return

	var defeated_lookup: Dictionary = {}
	for saved_path in defeated_paths:
		defeated_lookup[str(saved_path)] = true

	for hostile in save_manager.get_tree().get_nodes_in_group("hostile_npcs"):
		if not is_node_in_level(level, hostile):
			continue

		var hostile_path: String = get_relative_node_path(level, hostile)
		if defeated_lookup.has(hostile_path):
			apply_defeated_hostile_state(hostile)
		else:
			apply_active_hostile_state(hostile)


func apply_defeated_hostile_state(hostile: Node):
	hostile.set("dead", true)
	var health_node: Node = hostile.get_node_or_null("Health")
	if health_node != null:
		health_node.set("dead", true)
		health_node.set("health", 0)
	if hostile.has_method("disable_combat_areas"):
		hostile.disable_combat_areas()
	hostile.visible = false


func apply_active_hostile_state(hostile: Node):
	if hostile.has_method("restore_after_load"):
		hostile.restore_after_load()
		return

	hostile.visible = true
	hostile.set("dead", false)
	hostile.set_physics_process(true)


func collect_non_hostile_npc_states(level: Node) -> Array:
	var npc_states: Array = []
	for npc in save_manager.get_tree().get_nodes_in_group("non_hostile_npcs"):
		if not is_node_in_level(level, npc):
			continue

		npc_states.append({
			"node_path": get_relative_node_path(level, npc),
			"paused_by_external_actor": bool(npc.get("paused_by_external_actor")),
			"external_pause_completed": bool(npc.get("external_pause_completed")),
		})

	return npc_states


func apply_non_hostile_npc_states(level: Node, npc_states: Variant):
	if not (npc_states is Array):
		return

	for raw_state in npc_states:
		if not (raw_state is Dictionary):
			continue

		var state: Dictionary = raw_state
		var npc: Node = get_node_from_saved_path(level, str(state.get("node_path", "")))
		if npc == null:
			continue

		var paused_by_external_actor: bool = bool(state.get("paused_by_external_actor", false))
		var external_pause_completed: bool = bool(state.get("external_pause_completed", false))
		if npc.has_method("apply_saved_story_pause_state"):
			npc.apply_saved_story_pause_state(paused_by_external_actor, external_pause_completed)
		else:
			npc.set("paused_by_external_actor", paused_by_external_actor)
			npc.set("external_pause_completed", external_pause_completed)
		if npc.has_method("play_idle_animation") and bool(state.get("external_pause_completed", false)):
			npc.play_idle_animation()


func collect_story_actor_states(level: Node, root: Node, required_group: String = "") -> Array:
	var states: Array = []
	if root == null:
		return states

	collect_story_actor_states_from(level, root, required_group, states)
	return states


func collect_story_actor_states_from(level: Node, root: Node, required_group: String, states: Array):
	for child in root.get_children():
		var should_collect: bool = required_group == "" or child.is_in_group(required_group)
		if should_collect:
			collect_one_story_actor_state(level, child, states)

		collect_story_actor_states_from(level, child, required_group, states)


func collect_one_story_actor_state(level: Node, actor: Node, states: Array):
	var actor_path: String = get_relative_node_path(level, actor)
	if actor_path == "":
		return

	var state: Dictionary = {}
	if actor.has_method("collect_story_save_state"):
		var raw_state: Variant = actor.call("collect_story_save_state")
		if raw_state is Dictionary:
			state = raw_state
	elif actor is Node2D:
		var actor_node: Node2D = actor as Node2D
		state = {
			"position": vector_to_data(actor_node.global_position),
		}

	state["node_path"] = actor_path
	states.append(state)


func parse_actor_snapshot_lookup(raw_states: Variant) -> Dictionary:
	var parsed_states: Dictionary = {}
	if not (raw_states is Array):
		return parsed_states

	for raw_state in raw_states:
		if not (raw_state is Dictionary):
			continue

		var state: Dictionary = raw_state
		var actor_path: String = str(state.get("node_path", ""))
		if actor_path == "":
			continue

		parsed_states[actor_path] = state

	return parsed_states


func apply_story_actor_states(level: Node, actor_states: Dictionary):
	if level == null:
		return

	for actor_path in actor_states.keys():
		var actor: Node = level.get_node_or_null(NodePath(str(actor_path)))
		if actor == null:
			continue

		var raw_state: Variant = actor_states[actor_path]
		if not (raw_state is Dictionary):
			continue

		if actor.has_method("apply_story_save_state"):
			actor.call("apply_story_save_state", raw_state)


func get_relative_node_path(level: Node, node: Node) -> String:
	if level != null and is_instance_valid(level) and level != node and level.is_ancestor_of(node):
		return str(level.get_path_to(node))

	return str(node.get_path())


func get_node_from_saved_path(level: Node, saved_path: String) -> Node:
	if saved_path == "":
		return null

	if level != null:
		var relative_node: Node = level.get_node_or_null(NodePath(saved_path))
		if relative_node != null:
			return relative_node

	return save_manager.get_node_or_null(NodePath(saved_path))


func is_node_in_level(level: Node, node: Node) -> bool:
	if level == null:
		return true

	return level == node or level.is_ancestor_of(node)


func vector_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func data_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	if not (value is Dictionary):
		return fallback

	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
