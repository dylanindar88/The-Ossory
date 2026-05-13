extends Node

const STATE_VERSION := 1


func collect_level_state() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
	}


func apply_level_state(state: Dictionary):
	if not (state is Dictionary):
		return


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	if not (state is Dictionary):
		messages.append("Weeping Woods level state must be a dictionary.")
		return messages
	return messages


func uses_level_owned_hostile_state() -> bool:
	return false


func uses_level_owned_non_hostile_npc_state() -> bool:
	return false
