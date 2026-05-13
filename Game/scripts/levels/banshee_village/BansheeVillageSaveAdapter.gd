extends RefCounted
class_name BansheeVillageSaveAdapter

const STAGE_RULES = preload("res://scripts/levels/banshee_village/BansheeVillageStageRules.gd")

var flow


func setup(controller):
	flow = controller


func collect_level_state() -> Dictionary:
	return {
		"state_version": flow.LEVEL_STATE_VERSION,
		"quest_stage": flow.quest_stage,
		"banshee_kill_count": flow.banshee_kill_count,
		"revealed_banshee_paths": flow.revealed_banshee_paths.keys(),
		"temporarily_cleared_banshee_paths": flow.temporarily_cleared_banshee_paths.keys(),
		"permanently_cleared_banshee_paths": flow.permanently_cleared_banshee_paths.keys(),
		"final_dulluhan_teaser_completed": flow.final_dulluhan_teaser_completed,
		"story_transform_prompt_consumed": flow.story_transform_prompt_consumed,
		"story_wolf_lock_active": flow.story_wolf_lock_active,
		"final_wolf_instruction_shown": flow.final_wolf_instruction_shown,
		"active_interior_id": flow.active_interior_id,
		"third_wave_spawned": flow.third_wave_spawned,
		"dulluhan_transformation_granted_for_level": flow.dulluhan_transformation_granted_for_level,
		"vincent_house_dialogue_completed_for_level": flow.vincent_house_dialogue_completed_for_level,
		"bishop_confrontation_accepted_for_level": flow.bishop_confrontation_accepted_for_level,
		"dulluhan": collect_dulluhan_state(),
		"banshees": collect_banshee_states(),
		"villagers": collect_villager_states(),
	}


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	var state_version: int = int(state.get("state_version", 0))
	if state_version > flow.LEVEL_STATE_VERSION:
		messages.append("BansheeVillage save state version %d is newer than supported version %d." % [state_version, flow.LEVEL_STATE_VERSION])

	var saved_stage: String = str(state.get("quest_stage", STAGE_RULES.STAGE_INTRO))
	if saved_stage != STAGE_RULES.get_valid_stage(saved_stage):
		messages.append("BansheeVillage save has invalid quest_stage '%s'." % saved_stage)

	if not (state.get("banshees", []) is Array):
		messages.append("BansheeVillage save has malformed banshees snapshot data.")
	if not (state.get("villagers", []) is Array):
		messages.append("BansheeVillage save has malformed villagers snapshot data.")
	if not (state.get("temporarily_cleared_banshee_paths", []) is Array):
		messages.append("BansheeVillage save has malformed temporarily_cleared_banshee_paths.")

	append_missing_node_warnings(messages)
	append_missing_actor_path_warnings(messages, state.get("banshees", []), "banshee")
	append_missing_actor_path_warnings(messages, state.get("villagers", []), "villager")
	append_missing_assigned_villager_warnings(messages)
	return messages


func apply_level_state(state: Dictionary):
	flow.location_exit_save_pending = false
	flow.state_generation += 1
	var normalized_state: Dictionary = normalize_level_state(state)
	flow.quest_stage = STAGE_RULES.get_valid_stage(str(normalized_state.get("quest_stage", STAGE_RULES.STAGE_INTRO)))
	flow.banshee_kill_count = maxi(int(normalized_state.get("banshee_kill_count", 0)), 0)
	flow.final_dulluhan_teaser_completed = bool(normalized_state.get("final_dulluhan_teaser_completed", false))
	flow.story_transform_prompt_consumed = bool(normalized_state.get("story_transform_prompt_consumed", false))
	flow.story_wolf_lock_active = bool(normalized_state.get("story_wolf_lock_active", false))
	flow.final_wolf_instruction_shown = bool(normalized_state.get("final_wolf_instruction_shown", false))
	flow.active_interior_id = str(normalized_state.get("active_interior_id", ""))
	flow.third_wave_spawned = bool(normalized_state.get("third_wave_spawned", false))
	flow.dulluhan_transformation_granted_for_level = get_saved_bool(normalized_state, "dulluhan_transformation_granted_for_level", STAGE_RULES.infer_dulluhan_transformation_granted_from_stage(flow.quest_stage))
	flow.vincent_house_dialogue_completed_for_level = get_saved_bool(normalized_state, "vincent_house_dialogue_completed_for_level", STAGE_RULES.infer_vincent_house_dialogue_completed_from_stage(flow.quest_stage))
	flow.bishop_confrontation_accepted_for_level = get_saved_bool(normalized_state, "bishop_confrontation_accepted_for_level", STAGE_RULES.infer_bishop_confrontation_accepted_from_stage(flow.quest_stage))
	flow.cleared_villager_paths = {}
	flow.defeated_banshees.clear()
	flow.temporarily_cleared_banshee_paths = {}
	flow.permanently_cleared_banshee_paths = {}
	flow.saved_banshee_states = parse_saved_banshee_states(normalized_state.get("banshees", []))
	flow.saved_villager_states = SaveManager.parse_actor_snapshot_lookup(normalized_state.get("villagers", []))

	flow.revealed_banshee_paths = {}
	apply_path_lookup(flow.revealed_banshee_paths, normalized_state.get("revealed_banshee_paths", []))
	apply_path_lookup(flow.temporarily_cleared_banshee_paths, normalized_state.get("temporarily_cleared_banshee_paths", []))
	apply_path_lookup(flow.permanently_cleared_banshee_paths, normalized_state.get("permanently_cleared_banshee_paths", []))

	apply_dulluhan_level_state(normalized_state.get("dulluhan", {}))
	flow.sync_local_progression_flags_to_globals()
	flow.reconcile_wolf_transformation_unlock_with_local_story()
	if flow.quest_stage == STAGE_RULES.STAGE_WOLF_HUNT_CLEARED or flow.quest_stage == STAGE_RULES.STAGE_FINAL_DULLUHAN_READY:
		flow.story_wolf_lock_active = false
		flow.story_transform_prompt_consumed = true
	if STAGE_RULES.is_third_wave_stage(flow.quest_stage):
		flow.third_wave_spawned = true
		flow.story_wolf_lock_active = false
		flow.story_transform_prompt_consumed = true

	flow.restore_saved_villager_states()
	flow.restore_stage_world_state()
	flow.restore_story_transformation_state()
	flow.sync_story_wolf_transformation_lock()
	flow.restore_active_interior_state()
	flow.saved_banshee_states.clear()
	flow.saved_villager_states.clear()


func normalize_level_state(state: Dictionary) -> Dictionary:
	var normalized_state: Dictionary = state.duplicate(true)
	var state_version: int = int(normalized_state.get("state_version", 0))
	normalized_state["state_version"] = clamp(state_version, 0, flow.LEVEL_STATE_VERSION)
	return normalized_state


func get_saved_bool(state: Dictionary, key: String, default_value: bool) -> bool:
	if state.has(key):
		return bool(state.get(key))

	return default_value


func collect_banshee_states() -> Array:
	if flow.location_exit_save_pending:
		return []

	var hostile_root: Node = flow.get_node_or_null(flow.hostile_root_path)
	return SaveManager.collect_story_actor_states(flow.get_parent(), hostile_root, "hostile_npcs")


func collect_villager_states() -> Array:
	if flow.location_exit_save_pending:
		return []

	var npc_root: Node = flow.get_node_or_null(flow.npc_root_path)
	return SaveManager.collect_story_actor_states(flow.get_parent(), npc_root, "villagers")


func collect_dulluhan_state() -> Dictionary:
	if flow.dulluhan == null or not flow.dulluhan.has_method("collect_story_save_state"):
		return {}

	var raw_state: Variant = flow.dulluhan.call("collect_story_save_state")
	if raw_state is Dictionary:
		return raw_state

	return {}


func apply_dulluhan_level_state(raw_state: Variant):
	if flow.dulluhan == null:
		return

	if raw_state is Dictionary:
		var dulluhan_state: Dictionary = raw_state
		if not dulluhan_state.is_empty() and flow.dulluhan.has_method("apply_story_save_state"):
			flow.dulluhan.call("apply_story_save_state", dulluhan_state)

	if flow.dulluhan.has_method("set_transformation_granted_for_story_save"):
		flow.dulluhan.call("set_transformation_granted_for_story_save", flow.dulluhan_transformation_granted_for_level)
	else:
		flow.dulluhan.set("transformation_granted", flow.dulluhan_transformation_granted_for_level)


func parse_saved_banshee_states(raw_states: Variant) -> Dictionary:
	return SaveManager.parse_actor_snapshot_lookup(raw_states)


func apply_path_lookup(target: Dictionary, raw_paths: Variant):
	if not (raw_paths is Array):
		return

	for path in raw_paths:
		target[str(path)] = true


func append_missing_node_warnings(messages: Array):
	if flow.elder == null:
		messages.append("BansheeVillageFlowController could not find elder at %s." % flow.elder_path)
	if flow.kill_counter == null:
		messages.append("BansheeVillageFlowController could not find kill counter at %s." % flow.kill_counter_path)
	if flow.dulluhan == null:
		messages.append("BansheeVillageFlowController could not find Dulluhan at %s." % flow.dulluhan_path)
	if flow.exterior_vincent == null:
		messages.append("BansheeVillageFlowController could not find exterior Vincent at %s." % flow.exterior_vincent_path)
	if flow.vincent_house == null:
		messages.append("BansheeVillageFlowController could not find VincentHouse at %s." % flow.vincent_house_path)
	if flow.vincent_house_interior == null:
		messages.append("BansheeVillageFlowController could not find VincentHouseInterior at %s." % flow.vincent_house_interior_path)
	if flow.west_route_exit == null:
		messages.append("BansheeVillageFlowController could not find west route exit at %s." % flow.west_route_exit_path)
	if flow.south_route_exit == null:
		messages.append("BansheeVillageFlowController could not find south route exit at %s." % flow.south_route_exit_path)
	if flow.east_route_exit == null:
		messages.append("BansheeVillageFlowController could not find east route exit at %s." % flow.east_route_exit_path)
	if flow.get_node_or_null(flow.exterior_player_parent_path) == null:
		messages.append("BansheeVillageFlowController could not find exterior player parent at %s." % flow.exterior_player_parent_path)
	if flow.get_node_or_null(flow.vincent_house_interior_player_parent_path) == null:
		messages.append("BansheeVillageFlowController could not find VincentHouse interior player parent at %s." % flow.vincent_house_interior_player_parent_path)
	if flow.get_node_or_null(flow.vincent_house_return_marker_path) == null:
		messages.append("BansheeVillageFlowController could not find VincentHouse return marker at %s." % flow.vincent_house_return_marker_path)
	if flow.get_node_or_null(flow.vincent_beside_elder_marker_path) == null:
		messages.append("BansheeVillageFlowController could not find Vincent beside elder marker at %s." % flow.vincent_beside_elder_marker_path)


func append_missing_actor_path_warnings(messages: Array, raw_states: Variant, actor_label: String):
	if not (raw_states is Array):
		return

	var level: Node = flow.get_parent()
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
	for banshee in flow.banshees:
		if banshee == null or not banshee.has_method("has_assigned_villager"):
			continue

		if str(banshee.get("assigned_villager_path")) != "" and not bool(banshee.call("has_assigned_villager")):
			messages.append("%s has assigned_villager_path '%s' but no resolved villager." % [banshee.name, banshee.get("assigned_villager_path")])
