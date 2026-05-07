extends RefCounted
class_name BansheeVillageEncounterController

const STAGE_RULES = preload("res://scripts/levels/banshee_village/BansheeVillageStageRules.gd")
const BANSHEE_VARIANT_CORRUPTED_MELEE = "corrupted_melee"
const BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED = "corrupted_strong_ranged"

var flow


func setup(controller):
	flow = controller


func apply_banshee_villager_presentation(combat_enabled: bool):
	for banshee in flow.banshees:
		var banshee_path: String = flow.get_relative_node_path(banshee)
		var saved_state: Dictionary = {}
		if flow.saved_banshee_states.has(banshee_path):
			var raw_saved_state: Variant = flow.saved_banshee_states[banshee_path]
			if raw_saved_state is Dictionary:
				saved_state = raw_saved_state

		var villager: Node = flow.get_banshee_assigned_villager(banshee)
		var villager_path: String = flow.get_relative_node_path(villager)
		var permanent_clear: bool = flow.permanently_cleared_banshee_paths.has(banshee_path)
		var villager_is_clear: bool = permanent_clear or flow.cleared_villager_paths.has(villager_path)
		var saved_dead: bool = bool(saved_state.get("dead", false))

		if permanent_clear or saved_dead or villager_is_clear:
			flow.set_villager_clear_sequence(villager)
			flow.complete_villager_banshee_story(villager)
			apply_cleared_banshee_state(banshee, saved_state)
			flow.defeated_banshees[banshee] = true
			if saved_dead and not permanent_clear:
				schedule_banshee_respawn(banshee)
			continue

		flow.set_villager_stalked_sequence(villager)
		if saved_state.is_empty() and flow.saved_villager_states.is_empty():
			flow.reset_villager_stalk_state(villager)
		apply_active_banshee_state(banshee, combat_enabled, saved_state)


func apply_active_banshee_state(banshee: Node, combat_enabled: bool, saved_state: Dictionary = {}):
	if banshee == null:
		return

	if banshee.has_method("set_combat_variant"):
		banshee.set_combat_variant(get_banshee_combat_variant_for_story())

	var banshee_path: String = flow.get_relative_node_path(banshee)
	var is_revealed: bool = combat_enabled and flow.revealed_banshee_paths.has(banshee_path)
	if saved_state.has("revealed"):
		is_revealed = combat_enabled and bool(saved_state.get("revealed", false))

	var alpha: float = flow.hidden_banshee_alpha
	if is_revealed:
		alpha = 1.0

	if not saved_state.is_empty() and banshee.has_method("restore_from_story_save"):
		if flow.third_wave_spawned or flow.is_third_wave_stage():
			saved_state["combat_variant"] = BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED
		banshee.restore_from_story_save(saved_state, flow.hidden_banshee_alpha, combat_enabled, is_revealed)
		return

	if banshee.has_method("restore_for_story_load"):
		banshee.restore_for_story_load(flow.hidden_banshee_alpha, combat_enabled, is_revealed)
		return

	if banshee.has_method("restore_after_load"):
		banshee.restore_after_load()

	if banshee.has_method("set_story_combat_enabled"):
		if combat_enabled and banshee.has_method("enable_story_combat"):
			banshee.enable_story_combat(alpha)
		elif not combat_enabled and banshee.has_method("disable_story_combat"):
			banshee.disable_story_combat(alpha)
		else:
			banshee.set_story_combat_enabled(combat_enabled, alpha)

	if banshee.has_method("set_story_revealed"):
		banshee.set_story_revealed(is_revealed, flow.hidden_banshee_alpha)


func apply_cleared_banshee_state(banshee: Node, saved_state: Dictionary = {}):
	if banshee == null:
		return

	if banshee.has_method("set_combat_variant"):
		banshee.set_combat_variant(get_banshee_combat_variant_for_story())

	var banshee_path: String = flow.get_relative_node_path(banshee)
	flow.revealed_banshee_paths.erase(banshee_path)

	if not saved_state.is_empty() and banshee.has_method("restore_dead_from_story_save"):
		if flow.third_wave_spawned or flow.is_third_wave_stage():
			saved_state["combat_variant"] = BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED
		banshee.restore_dead_from_story_save(saved_state, flow.hidden_banshee_alpha)
	elif banshee.has_method("hide_as_story_defeated"):
		banshee.hide_as_story_defeated(flow.hidden_banshee_alpha)


func get_banshee_combat_variant_for_story() -> String:
	if flow.third_wave_spawned or flow.is_third_wave_stage():
		return BANSHEE_VARIANT_CORRUPTED_STRONG_RANGED

	return BANSHEE_VARIANT_CORRUPTED_MELEE


func set_all_banshee_combat_variants(variant: String):
	for banshee in flow.banshees:
		if banshee != null and banshee.has_method("set_combat_variant"):
			banshee.set_combat_variant(variant)


func handle_banshee_detected_player_for_reveal(banshee: Node):
	if flow.quest_stage == STAGE_RULES.STAGE_INTRO or banshee == null:
		return

	if flow.defeated_banshees.has(banshee):
		return

	var banshee_path: String = flow.get_relative_node_path(banshee)
	if banshee_path == "":
		return

	flow.revealed_banshee_paths[banshee_path] = true
	if banshee.has_method("set_story_revealed"):
		banshee.set_story_revealed(true, flow.hidden_banshee_alpha)


func schedule_banshee_respawn(banshee: Node):
	if banshee == null:
		return

	var scheduled_generation: int = flow.state_generation
	await flow.get_tree().create_timer(flow.respawn_delay_seconds).timeout
	if scheduled_generation != flow.state_generation:
		return

	respawn_banshee(banshee)


func respawn_banshee(banshee: Node):
	if flow.quest_stage == STAGE_RULES.STAGE_INTRO or banshee == null or not is_instance_valid(banshee):
		return

	if not flow.defeated_banshees.has(banshee):
		return

	var banshee_path: String = flow.get_relative_node_path(banshee)
	if flow.permanently_cleared_banshee_paths.has(banshee_path):
		return

	flow.defeated_banshees.erase(banshee)
	flow.revealed_banshee_paths.erase(banshee_path)

	var villager: Node = flow.get_banshee_assigned_villager(banshee)
	var villager_path: String = flow.get_relative_node_path(villager)
	if villager_path != "":
		flow.cleared_villager_paths.erase(villager_path)
	flow.set_villager_stalked_sequence(villager)
	flow.reset_villager_stalk_state(villager)

	if banshee.has_method("respawn_for_story"):
		if banshee.has_method("set_combat_variant"):
			banshee.set_combat_variant(get_banshee_combat_variant_for_story())
		banshee.respawn_for_story(flow.hidden_banshee_alpha)
	elif banshee.has_method("restore_after_load"):
		if banshee.has_method("set_combat_variant"):
			banshee.set_combat_variant(get_banshee_combat_variant_for_story())
		banshee.restore_after_load()
		if banshee.has_method("enable_story_combat"):
			banshee.enable_story_combat(flow.hidden_banshee_alpha)
		elif banshee.has_method("set_story_combat_enabled"):
			banshee.set_story_combat_enabled(true, flow.hidden_banshee_alpha)
