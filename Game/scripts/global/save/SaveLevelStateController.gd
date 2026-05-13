class_name SaveLevelStateController
extends RefCounted

var save_manager


func setup(owner_save_manager):
	save_manager = owner_save_manager


func remember_level_state(level: Node):
	var level_path: String = save_manager.get_level_path(level)
	if level_path == "":
		return

	save_manager.level_states_by_path[level_path] = collect_level_state(level)


func prepare_current_level_for_route_exit():
	for provider in get_level_state_providers(save_manager.get_current_level()):
		if provider.has_method("prepare_for_route_exit"):
			provider.call("prepare_for_route_exit")


func get_saved_level_state_for_path(level_path: String, fallback_state: Dictionary = {}) -> Dictionary:
	var raw_state: Variant = save_manager.level_states_by_path.get(level_path, fallback_state)
	if raw_state is Dictionary:
		var typed_state: Dictionary = raw_state
		return typed_state.duplicate(true)

	return fallback_state.duplicate(true)


func apply_level_states_by_path(data: Variant):
	save_manager.level_states_by_path.clear()
	if data is Dictionary:
		var source: Dictionary = data
		for level_path in source.keys():
			var raw_state: Variant = source[level_path]
			if raw_state is Dictionary:
				var typed_state: Dictionary = raw_state
				save_manager.level_states_by_path[str(level_path)] = typed_state.duplicate(true)


func get_level_state_for_current_load(current_level_path: String, saved_level_path: String) -> Dictionary:
	var current_state: Dictionary = get_saved_level_state_for_path(current_level_path)
	if not current_state.is_empty():
		return current_state

	var saved_state: Dictionary = get_saved_level_state_for_path(saved_level_path)
	if not saved_state.is_empty():
		return saved_state

	return {}


func has_saved_scene_local_state(saved_level_path: String) -> bool:
	if saved_level_path != "" and not get_saved_level_state_for_path(saved_level_path).is_empty():
		return true

	return false


func warn_level_state_load_mismatch(current_level_path: String, saved_level_path: String):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	var available_paths: Array = save_manager.level_states_by_path.keys()
	push_warning("Could not resolve local level state for current scene '%s' while loading save for '%s'. Available saved level paths: %s." % [current_level_path, saved_level_path, available_paths])


func warn_pending_scene_load_failed(slot: int):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	var load_error: String = save_manager.last_error
	var data: Dictionary = save_manager.load_game(slot)
	var saved_level_path: String = str(data.get("level_path", ""))
	var current_level_path: String = save_manager.get_level_path(save_manager.get_current_level())
	var saved_quest_stage: String = get_quest_stage_from_state(save_manager.get_level_state_from_save_data(data, saved_level_path))
	save_manager.last_error = load_error
	push_warning("Pending save load failed for slot %d. Saved scene: '%s'. Current scene: '%s'. Saved quest_stage: '%s'. Error: %s" % [slot, saved_level_path, current_level_path, saved_quest_stage, load_error])


func get_level_state_source_for_current_load(current_level_path: String, saved_level_path: String) -> String:
	if current_level_path != "" and not get_saved_level_state_for_path(current_level_path).is_empty():
		return "current_scene_path"
	if saved_level_path != "" and not get_saved_level_state_for_path(saved_level_path).is_empty():
		return "saved_scene_path"
	return "empty"


func get_quest_stage_from_state(state: Dictionary) -> String:
	if state.has("quest_stage"):
		return str(state.get("quest_stage", ""))

	var raw_provider_states: Variant = state.get("_providers", {})
	if state.has("_providers") and raw_provider_states is Dictionary:
		var provider_states: Dictionary = raw_provider_states
		for provider_key in provider_states.keys():
			var raw_provider_state: Variant = provider_states[provider_key]
			if raw_provider_state is Dictionary and raw_provider_state.has("quest_stage"):
				return str(raw_provider_state.get("quest_stage", ""))

	return ""


func warn_level_state_restore_source(slot: int, current_level_path: String, saved_level_path: String, source: String, state: Dictionary):
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	print_verbose("Applying save slot %d local state from %s. Saved scene: '%s'. Current scene: '%s'. quest_stage: '%s'." % [slot, source, saved_level_path, current_level_path, get_quest_stage_from_state(state)])


func verify_level_state_after_apply(level: Node, expected_state: Dictionary, slot: int, source: String) -> bool:
	var expected_stage: String = get_quest_stage_from_state(expected_state)
	if expected_stage == "" or expected_stage == "intro":
		return true

	var applied_state: Dictionary = collect_level_state(level)
	var applied_stage: String = get_quest_stage_from_state(applied_state)
	if applied_stage == expected_stage:
		return true

	if OS.is_debug_build() or Engine.is_editor_hint():
		push_warning("Save slot %d local state did not stick after apply. Source: %s. Expected quest_stage '%s', got '%s'." % [slot, source, expected_stage, applied_stage])
	save_manager.last_error = "Save data did not restore the saved level progression."
	return false


func collect_level_state(level: Node) -> Dictionary:
	var providers: Array[Node] = get_level_state_providers(level)
	if providers.is_empty():
		return {}

	if providers.size() == 1:
		var single_raw_state: Variant = providers[0].call("collect_level_state")
		if single_raw_state is Dictionary:
			return single_raw_state
		return {}

	var provider_states: Dictionary = {}
	for provider in providers:
		var raw_state: Variant = provider.call("collect_level_state")
		if raw_state is Dictionary:
			provider_states[get_provider_save_key(level, provider)] = raw_state

	return {
		"_providers": provider_states,
	}


func uses_level_owned_hostile_state(level: Node) -> bool:
	for provider in get_level_state_providers(level):
		if provider.has_method("uses_level_owned_hostile_state") and bool(provider.call("uses_level_owned_hostile_state")):
			return true

	return false


func uses_level_owned_non_hostile_npc_state(level: Node) -> bool:
	for provider in get_level_state_providers(level):
		if provider.has_method("uses_level_owned_non_hostile_npc_state") and bool(provider.call("uses_level_owned_non_hostile_npc_state")):
			return true

	return false


func apply_level_state(level: Node, state_data: Variant):
	var providers: Array[Node] = get_level_state_providers(level)
	if providers.is_empty():
		return

	var state: Dictionary = {}
	if state_data is Dictionary:
		state = state_data

	var raw_provider_states: Variant = state.get("_providers", {})
	if state.has("_providers") and raw_provider_states is Dictionary:
		var provider_states: Dictionary = raw_provider_states
		for provider in providers:
			var provider_state: Dictionary = {}
			var raw_provider_state: Variant = provider_states.get(get_provider_save_key(level, provider), {})
			if raw_provider_state is Dictionary:
				provider_state = raw_provider_state
			validate_level_state_if_debug(provider, provider_state)
			provider.call("apply_level_state", provider_state)
		return

	for index in range(providers.size()):
		var provider: Node = providers[index]
		var provider_state: Dictionary = state if index == 0 else {}
		validate_level_state_if_debug(provider, provider_state)
		provider.call("apply_level_state", provider_state)


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
	var providers: Array[Node] = get_level_state_providers(level)
	if providers.is_empty():
		return null

	return providers[0]


func get_level_state_providers(level: Node) -> Array[Node]:
	var providers: Array[Node] = []
	if level == null:
		return providers

	if level.has_method("collect_level_state") and level.has_method("apply_level_state"):
		providers.append(level)

	for child in level.get_children():
		if child.has_method("collect_level_state") and child.has_method("apply_level_state"):
			providers.append(child)

	return providers


func get_provider_save_key(level: Node, provider: Node) -> String:
	if provider == null:
		return ""
	if level != null and level == provider:
		return "."
	if level != null and level.is_ancestor_of(provider):
		return str(level.get_path_to(provider))

	return str(provider.get_path())
