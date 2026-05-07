extends RefCounted
class_name BansheeVillagePresentationController

const STAGE_RULES = preload("res://scripts/levels/banshee_village/BansheeVillageStageRules.gd")
const FLAG_EFFECTS: Array[String] = ["flag"]

var flow


func setup(controller):
	flow = controller


func update_kill_counter():
	if flow.kill_counter == null:
		return

	flow.kill_counter.visible = should_show_kill_counter()
	if not flow.kill_counter.visible:
		return

	if flow.quest_stage == STAGE_RULES.STAGE_REPORT_COMPLETE or flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_ACTIVE:
		flow.kill_counter.text = "Cleared: %d/%d" % [flow.permanently_cleared_banshee_paths.size(), flow.banshees.size()]
		return

	var shown_count: int = mini(flow.banshee_kill_count, flow.report_kill_threshold)
	flow.kill_counter.text = "Banshees: %d/%d" % [shown_count, flow.report_kill_threshold]


func should_show_kill_counter() -> bool:
	return (
		flow.quest_stage == STAGE_RULES.STAGE_COMBAT_ACTIVE
		or flow.quest_stage == STAGE_RULES.STAGE_READY_TO_REPORT
		or flow.quest_stage == STAGE_RULES.STAGE_REPORT_COMPLETE
		or flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_ACTIVE
	)


func update_exterior_vincent_presentation():
	if flow.exterior_vincent == null:
		return

	var visible_for_story := should_show_exterior_vincent()
	flow.exterior_vincent.visible = visible_for_story
	flow.exterior_vincent.process_mode = Node.PROCESS_MODE_INHERIT if visible_for_story else Node.PROCESS_MODE_DISABLED
	if flow.exterior_vincent.has_method("set_house_dialogue_enabled"):
		flow.exterior_vincent.set_house_dialogue_enabled(false)
	if flow.exterior_vincent.has_method("set_interaction_enabled"):
		flow.exterior_vincent.set_interaction_enabled(visible_for_story)

	if visible_for_story:
		var marker := flow.get_node_or_null(flow.vincent_beside_elder_marker_path) as Node2D
		if marker != null:
			flow.exterior_vincent.global_position = marker.global_position
		elif flow.elder is Node2D:
			flow.exterior_vincent.global_position = (flow.elder as Node2D).global_position + Vector2(58.0, 0.0)

	if should_show_bishop_direction_progression():
		if flow.exterior_vincent.has_method("set_level_dialogue_override"):
			flow.exterior_vincent.set_level_dialogue_override(flow.create_bishop_direction_sequence(), true)
	elif flow.exterior_vincent.has_method("clear_level_dialogue_override"):
		flow.exterior_vincent.clear_level_dialogue_override()


func sync_vincent_house_occupancy():
	if flow.vincent_house_interior == null or not flow.vincent_house_interior.has_method("set_vincent_present"):
		return

	flow.vincent_house_interior.set_vincent_present(not should_show_exterior_vincent())
	var interior_vincent: Node = flow.get_interior_vincent()
	if interior_vincent != null and interior_vincent.has_method("set_house_dialogue_completed_override"):
		interior_vincent.call("set_house_dialogue_completed_override", true, flow.vincent_house_dialogue_completed_for_level)


func should_show_exterior_vincent() -> bool:
	return (
		flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_CLEARED
		or flow.quest_stage == STAGE_RULES.STAGE_BISHOP_PATH_READY
		or (
			flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_ELDER_READY
			and flow.are_all_banshees_permanently_cleared()
		)
	)


func should_show_bishop_direction_progression() -> bool:
	return (
		not flow.is_bishop_confrontation_accepted()
		and (
			flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_CLEARED
			or (
				flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_ELDER_READY
				and flow.are_all_banshees_permanently_cleared()
			)
		)
	)


func update_route_exit_gates():
	set_route_exit_enabled(flow.west_route_exit, true)
	set_route_exit_enabled(flow.east_route_exit, is_third_hunt_completed_for_route_travel())
	set_route_exit_enabled(flow.south_route_exit, flow.is_bishop_confrontation_accepted() or flow.quest_stage == STAGE_RULES.STAGE_BISHOP_PATH_READY)


func set_route_exit_enabled(route_exit: Node, enabled: bool):
	if route_exit == null:
		return

	if route_exit.has_method("set_travel_enabled"):
		route_exit.set_travel_enabled(enabled)
	else:
		route_exit.set("travel_enabled", enabled)


func is_third_hunt_completed_for_route_travel() -> bool:
	return flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_CLEARED or flow.quest_stage == STAGE_RULES.STAGE_BISHOP_PATH_READY


func update_elder_flag():
	if flow.elder_flag == null:
		return

	if should_show_bishop_direction_progression():
		flow.elder_flag.set_effects(FLAG_EFFECTS)
		return

	if flow.quest_stage == STAGE_RULES.STAGE_THIRD_WAVE_ELDER_READY:
		flow.elder_flag.set_effects(FLAG_EFFECTS)
		return

	if flow.final_dulluhan_teaser_completed:
		flow.elder_flag.clear_effects()
		return

	if (
		flow.quest_stage == STAGE_RULES.STAGE_INTRO
		or flow.quest_stage == STAGE_RULES.STAGE_READY_TO_REPORT
		or flow.quest_stage == STAGE_RULES.STAGE_WOLF_HUNT_READY
		or flow.quest_stage == STAGE_RULES.STAGE_WOLF_HUNT_CLEARED
	):
		flow.elder_flag.set_effects(FLAG_EFFECTS)
	else:
		flow.elder_flag.clear_effects()


func update_dulluhan_flag():
	if flow.dulluhan_flag == null:
		return

	if flow.final_dulluhan_teaser_completed:
		flow.dulluhan_flag.clear_effects()
		return

	if flow.quest_stage == STAGE_RULES.STAGE_DULLUHAN_AVAILABLE and not flow.is_dulluhan_transformation_granted():
		flow.dulluhan_flag.set_effects(FLAG_EFFECTS)
	elif flow.quest_stage == STAGE_RULES.STAGE_FINAL_DULLUHAN_READY:
		flow.dulluhan_flag.set_effects(FLAG_EFFECTS)
	else:
		flow.dulluhan_flag.clear_effects()


func update_dulluhan_visibility():
	if flow.dulluhan == null:
		return

	if flow.is_third_wave_combat_stage():
		if flow.dulluhan is Node2D:
			(flow.dulluhan as Node2D).global_position = flow.dulluhan_story_origin_position
		if flow.dulluhan.has_method("set_waiting_for_story_progress"):
			flow.dulluhan.set_waiting_for_story_progress(true)
		elif flow.dulluhan.has_method("set_story_visible"):
			flow.dulluhan.set_story_visible(true)
		else:
			flow.dulluhan.visible = true
		return

	if flow.final_dulluhan_teaser_completed:
		if flow.dulluhan.has_method("set_final_teaser_completed"):
			flow.dulluhan.set_final_teaser_completed(true)
		elif flow.dulluhan.has_method("set_story_visible"):
			flow.dulluhan.set_story_visible(false)
		else:
			flow.dulluhan.visible = false
		return

	if flow.quest_stage == STAGE_RULES.STAGE_FINAL_DULLUHAN_READY:
		if flow.dulluhan.has_method("start_final_teaser"):
			flow.dulluhan.start_final_teaser(get_final_dulluhan_position())
		elif flow.dulluhan.has_method("set_story_visible"):
			if flow.dulluhan is Node2D:
				(flow.dulluhan as Node2D).global_position = get_final_dulluhan_position()
			flow.dulluhan.set_story_visible(true)
		else:
			if flow.dulluhan is Node2D:
				(flow.dulluhan as Node2D).global_position = get_final_dulluhan_position()
			flow.dulluhan.visible = true
		return

	if flow.quest_stage == STAGE_RULES.STAGE_DULLUHAN_AVAILABLE and not flow.is_dulluhan_transformation_granted():
		if flow.dulluhan.has_method("set_story_visible"):
			flow.dulluhan.set_story_visible(true)
		else:
			flow.dulluhan.visible = true
	elif flow.is_dulluhan_transformation_granted() and (
		flow.quest_stage == STAGE_RULES.STAGE_WOLF_HUNT_READY
		or flow.quest_stage == STAGE_RULES.STAGE_REPORT_COMPLETE
		or flow.quest_stage == STAGE_RULES.STAGE_WOLF_HUNT_CLEARED
	):
		if flow.dulluhan.has_method("set_waiting_for_story_progress"):
			flow.dulluhan.set_waiting_for_story_progress(true)
		elif flow.dulluhan.has_method("set_story_visible"):
			flow.dulluhan.set_story_visible(true)
	else:
		if flow.dulluhan.has_method("set_story_visible"):
			flow.dulluhan.set_story_visible(false)
		else:
			flow.dulluhan.visible = false


func get_final_dulluhan_position() -> Vector2:
	var marker: Node2D = flow.get_node_or_null(flow.final_dulluhan_marker_path) as Node2D
	if marker != null:
		return marker.global_position

	return flow.final_dulluhan_position
