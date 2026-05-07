class_name SaveQuestController
extends RefCounted

var save_manager


func setup(owner_save_manager):
	save_manager = owner_save_manager


func set_story_flag(flag_name: String, enabled: bool):
	if flag_name == "":
		return

	if enabled:
		save_manager.story_flags[flag_name] = true
	else:
		save_manager.story_flags.erase(flag_name)


func get_story_flag(flag_name: String) -> bool:
	return bool(save_manager.story_flags.get(flag_name, false))


func get_story_flags() -> Dictionary:
	return save_manager.story_flags.duplicate(true)


func apply_story_flags(data: Variant):
	save_manager.story_flags.clear()
	if not (data is Dictionary):
		return

	var source: Dictionary = data
	for flag_name in source.keys():
		save_manager.story_flags[str(flag_name)] = bool(source[flag_name])


func get_default_quest_state(stage: String = "") -> Dictionary:
	return {
		"stage": stage,
		"flags": {},
	}


func get_quest_state(quest_id: String) -> Dictionary:
	var raw_state: Variant = save_manager.quest_states.get(quest_id, {})
	if raw_state is Dictionary:
		var source: Dictionary = raw_state
		var flags: Dictionary = {}
		var raw_flags: Variant = source.get("flags", {})
		if raw_flags is Dictionary:
			flags = raw_flags.duplicate(true)
		return {
			"stage": str(source.get("stage", save_manager.QUEST_STAGE_NOT_AVAILABLE)),
			"flags": flags,
		}

	return get_default_quest_state(save_manager.QUEST_STAGE_NOT_AVAILABLE)


func set_quest_state(quest_id: String, state: Dictionary):
	if quest_id == "":
		return

	var flags: Dictionary = {}
	var raw_flags: Variant = state.get("flags", {})
	if raw_flags is Dictionary:
		flags = raw_flags.duplicate(true)
	save_manager.quest_states[quest_id] = {
		"stage": str(state.get("stage", save_manager.QUEST_STAGE_NOT_AVAILABLE)),
		"flags": flags,
	}


func get_quest_stage(quest_id: String) -> String:
	return str(get_quest_state(quest_id).get("stage", save_manager.QUEST_STAGE_NOT_AVAILABLE))


func set_quest_stage(quest_id: String, stage: String):
	var state: Dictionary = get_quest_state(quest_id)
	state["stage"] = stage
	set_quest_state(quest_id, state)


func get_quest_flag(quest_id: String, flag_name: String) -> bool:
	var state: Dictionary = get_quest_state(quest_id)
	var flags: Dictionary = state.get("flags", {})
	return bool(flags.get(flag_name, false))


func set_quest_flag(quest_id: String, flag_name: String, enabled: bool):
	if flag_name == "":
		return

	var state: Dictionary = get_quest_state(quest_id)
	var flags: Dictionary = state.get("flags", {})
	if enabled:
		flags[flag_name] = true
	else:
		flags.erase(flag_name)
	state["flags"] = flags
	set_quest_state(quest_id, state)


func get_quest_states() -> Dictionary:
	return save_manager.quest_states.duplicate(true)


func apply_quest_states(data: Variant):
	save_manager.quest_states.clear()
	if not (data is Dictionary):
		return

	var source: Dictionary = data
	for quest_id in source.keys():
		var raw_state: Variant = source[quest_id]
		if raw_state is Dictionary:
			set_quest_state(str(quest_id), raw_state)


func set_banshee_world_rule(rule_name: String, value: Variant):
	if rule_name == "":
		return

	var state: Dictionary = get_quest_state(save_manager.QUEST_BANSHEE_WORLD)
	var flags: Dictionary = state.get("flags", {})
	flags[rule_name] = value
	state["flags"] = flags
	set_quest_state(save_manager.QUEST_BANSHEE_WORLD, state)


func get_banshee_world_rules() -> Dictionary:
	var flags: Dictionary = get_quest_state(save_manager.QUEST_BANSHEE_WORLD).get("flags", {})
	var variant: String = str(flags.get("combat_variant", save_manager.BANSHEE_VARIANT_CORRUPTED_MELEE))
	if variant != save_manager.BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED:
		variant = save_manager.BANSHEE_VARIANT_CORRUPTED_MELEE

	return {
		"banshees_hostile_enabled": bool(flags.get("banshees_hostile_enabled", false)),
		"player_can_damage_banshees": bool(flags.get("player_can_damage_banshees", false)),
		"wolf_permanent_clear_enabled": bool(flags.get("wolf_permanent_clear_enabled", false)),
		"combat_variant": variant,
	}
