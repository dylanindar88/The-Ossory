extends Node

signal upgrade_state_changed

const SAVE_VERSION := 1
const SAVE_SLOT_COUNT := 3
const SAVE_PATH_FORMAT := "user://save_slot_%d.json"
const MAX_PLAYER_LIVES := 5
const LIFE_LOSS_EXTRA_INVULNERABILITY_TIME := 0.5

var active_slot: int = 1
var autosave_slot: int = 1
var has_autosave_target: bool = false
var player_lives: int = MAX_PLAYER_LIVES
var save_allowed: bool = true
var save_blockers: Dictionary = {}
var autosave_suppressed: bool = false
var current_level: Node
var last_error: String = ""
var upgrade_state: Dictionary = {
	"unlocked": {
		"health": true,
		"stamina": true,
		"dash_count": true,
	},
	"stat_levels": {},
	"equipped_weapon_id": "unarmed",
}


func set_active_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return false

	active_slot = slot
	autosave_slot = slot
	has_autosave_target = true
	last_error = ""
	return true


func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SAVE_SLOT_COUNT


func get_player_lives() -> int:
	return player_lives


func reset_player_lives():
	player_lives = MAX_PLAYER_LIVES


func reset_upgrade_state():
	upgrade_state = get_default_upgrade_state()
	upgrade_state_changed.emit()


func get_default_upgrade_state() -> Dictionary:
	return {
		"unlocked": {
			"health": true,
			"stamina": true,
			"dash_count": true,
		},
		"stat_levels": {},
		"equipped_weapon_id": "unarmed",
	}


func unlock_upgrade(upgrade_id: StringName) -> bool:
	var id := str(upgrade_id)
	if id == "":
		return false

	var unlocked: Dictionary = get_upgrade_unlocked()
	if bool(unlocked.get(id, false)):
		return false

	unlocked[id] = true
	upgrade_state["unlocked"] = unlocked
	upgrade_state_changed.emit()
	return true


func set_stat_level(stat_id: StringName, level: int) -> bool:
	var id := str(stat_id)
	if id == "":
		return false

	var stat_levels: Dictionary = get_upgrade_stat_levels()
	var clean_level: int = maxi(level, 0)
	if int(stat_levels.get(id, 0)) == clean_level:
		return false

	stat_levels[id] = clean_level
	upgrade_state["stat_levels"] = stat_levels
	upgrade_state_changed.emit()
	return true


func get_upgrade_state() -> Dictionary:
	return upgrade_state.duplicate(true)


func apply_upgrade_state(data: Variant):
	var default_state := get_default_upgrade_state()
	if data is Dictionary:
		var source: Dictionary = data
		var saved_unlocked: Variant = source.get("unlocked", {})
		if saved_unlocked is Dictionary:
			var merged_unlocked: Dictionary = default_state["unlocked"]
			for upgrade_id in saved_unlocked.keys():
				merged_unlocked[str(upgrade_id)] = bool(saved_unlocked[upgrade_id])
			default_state["unlocked"] = merged_unlocked
		default_state["stat_levels"] = source.get("stat_levels", {})
		default_state["equipped_weapon_id"] = str(source.get("equipped_weapon_id", "unarmed"))

	upgrade_state = default_state
	upgrade_state_changed.emit()


func get_upgrade_unlocked() -> Dictionary:
	var unlocked: Variant = upgrade_state.get("unlocked", {})
	if unlocked is Dictionary:
		return unlocked

	return {}


func get_upgrade_stat_levels() -> Dictionary:
	var stat_levels: Variant = upgrade_state.get("stat_levels", {})
	if stat_levels is Dictionary:
		return stat_levels

	return {}


func set_save_allowed(allowed: bool):
	save_allowed = allowed


func set_save_blocked(blocker: String, blocked: bool):
	if blocker == "":
		return

	if blocked:
		save_blockers[blocker] = true
	else:
		save_blockers.erase(blocker)


func is_save_allowed() -> bool:
	return save_allowed and save_blockers.is_empty()


func get_save_disabled_message() -> String:
	if save_blockers.has("combat"):
		return "Cannot save during combat"

	if not save_allowed:
		return "Saving is currently disabled."

	if not save_blockers.is_empty():
		return "Saving is currently disabled."

	return ""


func autosave_level_entered(level: Node) -> bool:
	current_level = level
	if should_skip_autosave("level_enter"):
		last_error = ""
		return false

	return save_game("level_enter", level)


func autosave_level_exiting(level: Node) -> bool:
	if should_skip_autosave("level_exit"):
		last_error = ""
		return false

	return save_game("level_exit", level)


func save_game(reason: String = "manual", level: Node = null) -> bool:
	if not ensure_autosave_target():
		return false

	return write_save_to_slot(autosave_slot, reason, level)


func ensure_autosave_target() -> bool:
	if has_autosave_target and is_valid_slot(autosave_slot):
		return true

	for slot in range(1, SAVE_SLOT_COUNT + 1):
		if not save_exists(slot):
			active_slot = slot
			autosave_slot = slot
			has_autosave_target = true
			return true

	last_error = "Autosave skipped because no save slot has been loaded or overwritten."
	return false


func save_game_to_slot(slot: int, reason: String = "manual", level: Node = null) -> bool:
	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return false

	var save_succeeded: bool = write_save_to_slot(slot, reason, level)
	if save_succeeded:
		active_slot = slot
		autosave_slot = slot
		has_autosave_target = true

	return save_succeeded


func write_save_to_slot(slot: int, reason: String = "manual", level: Node = null) -> bool:
	if not is_save_allowed():
		last_error = get_save_disabled_message()
		return false

	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return false

	var save_level := level if level != null else get_current_level()
	var save_path := get_save_path(slot)
	var save_data := build_save_data(reason, save_level, slot)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open %s for writing. Error: %s" % [save_path, error_string(FileAccess.get_open_error())]
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	last_error = ""
	return true


func load_slot_into_current_level(slot: int) -> bool:
	var data := load_game(slot)
	if data.is_empty():
		return false

	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return false

	var load_succeeded: bool = apply_save_to_current_level(data)
	if load_succeeded:
		set_active_slot(slot)

	return load_succeeded


func spend_life_and_respawn_player_in_place() -> bool:
	if player_lives <= 0:
		last_error = "No lives remaining."
		return false

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		last_error = "Could not find player for respawn."
		return false

	player_lives = max(player_lives - 1, 0)
	if player_lives <= 0:
		last_error = "No lives remaining."
		return false

	if CombatStateManager != null and CombatStateManager.has_method("clear_all"):
		CombatStateManager.clear_all()

	if player.has_method("soft_respawn_in_place"):
		player.soft_respawn_in_place(LIFE_LOSS_EXTRA_INVULNERABILITY_TIME)
	elif player.has_method("soft_respawn_at_position"):
		player.soft_respawn_at_position(player.global_position, LIFE_LOSS_EXTRA_INVULNERABILITY_TIME)
	else:
		if player.has_method("restore_after_load"):
			player.restore_after_load()

	last_error = ""
	return true


func delete_save(slot: int) -> bool:
	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return false

	if not save_exists(slot):
		last_error = ""
		return true

	var dir := DirAccess.open("user://")
	if dir == null:
		last_error = "Could not open the user save directory."
		return false

	var error := dir.remove(get_save_file_name(slot))
	if error != OK:
		last_error = "Could not delete save slot %d. Error: %s" % [slot, error_string(error)]
		return false

	last_error = ""
	return true


func save_exists(slot: int) -> bool:
	return is_valid_slot(slot) and FileAccess.file_exists(get_save_path(slot))


func get_slot_summary(slot: int) -> Dictionary:
	var summary := {
		"slot": slot,
		"exists": false,
		"saved_at_datetime": "",
		"level_path": "",
		"reason": "",
	}

	if not save_exists(slot):
		return summary

	var data := load_game(slot)
	if data.is_empty():
		return summary

	summary["exists"] = true
	summary["saved_at_datetime"] = str(data.get("saved_at_datetime", ""))
	summary["level_path"] = str(data.get("level_path", ""))
	summary["reason"] = str(data.get("reason", ""))
	return summary


func reset_current_level_for_dev() -> bool:
	var scene_path := get_level_path(get_current_level())
	if scene_path == "":
		last_error = "Could not reset the current level because it has no scene path."
		return false

	autosave_suppressed = true
	get_tree().paused = false
	var error := get_tree().reload_current_scene()
	if error != OK:
		autosave_suppressed = false
		last_error = "Could not reload current level. Error: %s" % error_string(error)
		return false

	last_error = ""
	return true


func should_skip_autosave(reason: String) -> bool:
	if not autosave_suppressed:
		return false

	if reason == "level_enter":
		autosave_suppressed = false

	return true


func load_game(slot: int = active_slot) -> Dictionary:
	if not is_valid_slot(slot):
		last_error = "Save slot %d is outside the supported range." % slot
		return {}

	var save_path := get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		last_error = "No save file exists for slot %d." % slot
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_error = "Could not open %s for reading. Error: %s" % [save_path, error_string(FileAccess.get_open_error())]
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		last_error = "Save file %s is not valid JSON save data." % save_path
		return {}

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		last_error = "Save file %s uses an unsupported version." % save_path
		return {}

	last_error = ""
	return data


func apply_save_to_current_level(data: Dictionary, preserve_current_lives: bool = false) -> bool:
	var level := get_current_level()
	if level == null or data.is_empty():
		return false

	var saved_level_path: String = str(data.get("level_path", ""))
	if saved_level_path != "" and saved_level_path != get_level_path(level):
		last_error = "Save data belongs to a different level."
		return false

	if CombatStateManager != null and CombatStateManager.has_method("clear_all"):
		CombatStateManager.clear_all()

	if not preserve_current_lives:
		player_lives = clamp(int(data.get("player_lives", MAX_PLAYER_LIVES)), 0, MAX_PLAYER_LIVES)

	apply_upgrade_state(data.get("upgrade_state", {}))
	apply_player_state(level, data.get("player", {}))
	if not uses_level_owned_hostile_state(level):
		apply_defeated_banshees(level, data.get("defeated_banshees", []))
	if not uses_level_owned_villager_state(level):
		apply_villager_states(level, data.get("villagers", []))
	apply_level_state(level, data.get("level_state", {}))
	last_error = ""
	return true


func get_save_path(slot: int = active_slot) -> String:
	return SAVE_PATH_FORMAT % clamp(slot, 1, SAVE_SLOT_COUNT)


func get_save_file_name(slot: int) -> String:
	return "save_slot_%d.json" % clamp(slot, 1, SAVE_SLOT_COUNT)


func get_current_level() -> Node:
	if current_level != null and is_instance_valid(current_level) and current_level.is_inside_tree():
		return current_level

	return get_tree().current_scene


func build_save_data(reason: String, level: Node, slot: int) -> Dictionary:
	var defeated_banshee_state: Array = []
	if not uses_level_owned_hostile_state(level):
		defeated_banshee_state = collect_defeated_banshees(level)

	var villager_state: Array = []
	if not uses_level_owned_villager_state(level):
		villager_state = collect_villager_states(level)

	return {
		"version": SAVE_VERSION,
		"slot": slot,
		"reason": reason,
		"player_lives": player_lives,
		"upgrade_state": get_upgrade_state(),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"saved_at_datetime": Time.get_datetime_string_from_system(),
		"level_path": get_level_path(level),
		"player": collect_player_state(level),
		"defeated_banshees": defeated_banshee_state,
		"villagers": villager_state,
		"level_state": collect_level_state(level),
	}


func get_level_path(level: Node) -> String:
	if level != null and level.scene_file_path != "":
		return level.scene_file_path

	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene.scene_file_path

	return ""


func collect_player_state(level: Node) -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return {}

	var health_node := player.get_node_or_null("Health")
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	var data := {
		"node_path": get_relative_node_path(level, player),
		"position": vector_to_data(player.global_position),
		"form_id": "human",
		"health": {},
		"stamina": {},
		"camera_zoom": 2.25,
	}

	if player.has_method("get_current_form_id"):
		data["form_id"] = str(player.get_current_form_id())

	if health_node != null:
		data["health"] = {
			"current": int(health_node.get("health")),
			"max": int(health_node.get("max_health")),
			"dead": bool(health_node.get("dead")),
		}
		data["stamina"] = {
			"current": float(health_node.get("stamina")),
			"max": float(health_node.get("max_stamina")),
		}

	if camera != null:
		data["camera_zoom"] = camera.zoom.x

	return data


func collect_defeated_banshees(level: Node) -> Array:
	var defeated: Array = []
	for hostile in get_tree().get_nodes_in_group("hostile_npcs"):
		if not is_node_in_level(level, hostile):
			continue

		var is_defeated: bool = bool(hostile.get("dead"))
		var health_node := hostile.get_node_or_null("Health")
		if health_node != null:
			is_defeated = is_defeated or bool(health_node.get("dead"))

		if is_defeated:
			defeated.append(get_relative_node_path(level, hostile))

	return defeated


func collect_villager_states(level: Node) -> Array:
	var villagers: Array = []
	for villager in get_tree().get_nodes_in_group("villagers"):
		if not is_node_in_level(level, villager):
			continue

		villagers.append({
			"node_path": get_relative_node_path(level, villager),
			"paused_by_external_actor": bool(villager.get("paused_by_external_actor")),
			"external_pause_completed": bool(villager.get("external_pause_completed")),
		})

	return villagers


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


func collect_level_state(level: Node) -> Dictionary:
	var provider: Node = get_level_state_provider(level)
	if provider == null:
		return {}

	var raw_state: Variant = provider.call("collect_level_state")
	if raw_state is Dictionary:
		return raw_state

	return {}


func uses_level_owned_hostile_state(level: Node) -> bool:
	var provider: Node = get_level_state_provider(level)
	if provider == null or not provider.has_method("uses_level_owned_hostile_state"):
		return false

	return bool(provider.call("uses_level_owned_hostile_state"))


func uses_level_owned_villager_state(level: Node) -> bool:
	var provider: Node = get_level_state_provider(level)
	if provider == null or not provider.has_method("uses_level_owned_villager_state"):
		return false

	return bool(provider.call("uses_level_owned_villager_state"))


func apply_level_state(level: Node, state_data: Variant):
	var provider: Node = get_level_state_provider(level)
	if provider == null:
		return

	var state: Dictionary = {}
	if state_data is Dictionary:
		state = state_data

	validate_level_state_if_debug(provider, state)
	provider.call("apply_level_state", state)


func validate_level_state_if_debug(provider: Node, state: Dictionary):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	if provider == null or not provider.has_method("validate_level_state"):
		return

	var raw_messages: Variant = provider.call("validate_level_state", state)
	if not (raw_messages is Array):
		return

	for message in raw_messages:
		push_warning(str(message))


func get_level_state_provider(level: Node) -> Node:
	if level == null:
		return null

	if level.has_method("collect_level_state") and level.has_method("apply_level_state"):
		return level

	for child in level.get_children():
		if child.has_method("collect_level_state") and child.has_method("apply_level_state"):
			return child

	return null


func apply_player_state(level: Node, player_data: Variant):
	if not (player_data is Dictionary):
		return

	var data: Dictionary = player_data
	var player := get_node_from_saved_path(level, str(data.get("node_path", ""))) as Node2D
	if player == null:
		return

	player.global_position = data_to_vector(data.get("position", {}), player.global_position)

	if player.has_method("set_form"):
		player.set_form(StringName(str(data.get("form_id", "human"))))

	var health_node := player.get_node_or_null("Health")
	var player_is_dead := false
	if health_node != null:
		var health_data: Dictionary = data.get("health", {})
		var stamina_data: Dictionary = data.get("stamina", {})
		health_node.set("health", clamp(int(health_data.get("current", health_node.get("health"))), 0, int(health_node.get("max_health"))))
		player_is_dead = bool(health_data.get("dead", false)) or int(health_node.get("health")) <= 0
		health_node.set("dead", player_is_dead)
		health_node.set("stamina", clamp(float(stamina_data.get("current", health_node.get("stamina"))), 0.0, float(health_node.get("max_stamina"))))
		if health_node.has_signal("health_changed"):
			health_node.emit_signal("health_changed", health_node.get("health"), health_node.get("max_health"))
		if health_node.has_signal("stamina_changed"):
			health_node.emit_signal("stamina_changed", health_node.get("stamina"), health_node.get("max_stamina"))

	if not player_is_dead and player.has_method("restore_after_load"):
		player.restore_after_load()

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		var zoom_value := float(data.get("camera_zoom", camera.zoom.x))
		if camera.has_method("change_zoom"):
			camera.change_zoom(zoom_value)
		else:
			camera.zoom = Vector2(zoom_value, zoom_value)


func apply_defeated_banshees(level: Node, defeated_paths: Variant):
	if not (defeated_paths is Array):
		return

	var defeated_lookup := {}
	for saved_path in defeated_paths:
		defeated_lookup[str(saved_path)] = true

	for hostile in get_tree().get_nodes_in_group("hostile_npcs"):
		if not is_node_in_level(level, hostile):
			continue

		var hostile_path := get_relative_node_path(level, hostile)
		if defeated_lookup.has(hostile_path):
			apply_defeated_hostile_state(hostile)
		else:
			apply_active_hostile_state(hostile)


func apply_defeated_hostile_state(hostile: Node):
	hostile.set("dead", true)
	var health_node := hostile.get_node_or_null("Health")
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


func apply_villager_states(level: Node, villager_states: Variant):
	if not (villager_states is Array):
		return

	for raw_state in villager_states:
		if not (raw_state is Dictionary):
			continue

		var state: Dictionary = raw_state
		var villager := get_node_from_saved_path(level, str(state.get("node_path", "")))
		if villager == null:
			continue

		var paused_by_external_actor: bool = bool(state.get("paused_by_external_actor", false))
		var external_pause_completed: bool = bool(state.get("external_pause_completed", false))
		if villager.has_method("apply_saved_story_pause_state"):
			villager.apply_saved_story_pause_state(paused_by_external_actor, external_pause_completed)
		else:
			villager.set("paused_by_external_actor", paused_by_external_actor)
			villager.set("external_pause_completed", external_pause_completed)
		if villager.has_method("play_idle_animation") and bool(state.get("external_pause_completed", false)):
			villager.play_idle_animation()


func get_relative_node_path(level: Node, node: Node) -> String:
	if level != null and is_instance_valid(level) and level != node and level.is_ancestor_of(node):
		return str(level.get_path_to(node))

	return str(node.get_path())


func get_node_from_saved_path(level: Node, saved_path: String) -> Node:
	if saved_path == "":
		return null

	if level != null:
		var relative_node := level.get_node_or_null(NodePath(saved_path))
		if relative_node != null:
			return relative_node

	return get_node_or_null(NodePath(saved_path))


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
