extends RefCounted
class_name BansheeVillageInteriorTravelController

const STAGE_RULES = preload("res://scripts/levels/banshee_village/BansheeVillageStageRules.gd")
const VINCENT_HOUSE_INTERIOR_ID = "vincent_house"

var flow


func setup(controller):
	flow = controller


func can_enter_vincent_house() -> bool:
	return (
		flow.quest_stage == STAGE_RULES.STAGE_VINCENT_HOUSE_AVAILABLE
		or flow.is_third_wave_stage()
		or flow.quest_stage == STAGE_RULES.STAGE_BISHOP_PATH_READY
	)


func enter_vincent_house():
	if flow.player == null or flow.vincent_house_interior == null:
		return

	flow.active_interior_id = VINCENT_HOUSE_INTERIOR_ID
	set_interior_active(flow.vincent_house_interior, true)
	flow.sync_vincent_house_occupancy()
	reparent_player_to(flow.get_node_or_null(flow.vincent_house_interior_player_parent_path))
	move_player_to_interior(flow.vincent_house_interior)


func move_player_to_interior(interior: Node2D):
	var entry_position: Vector2 = interior.global_position
	if interior.has_method("get_entry_position"):
		var raw_entry_position: Variant = interior.call("get_entry_position")
		if raw_entry_position is Vector2:
			entry_position = raw_entry_position

	move_player_to_position(entry_position)


func exit_vincent_house():
	reparent_player_to(flow.get_node_or_null(flow.exterior_player_parent_path))
	var return_marker := flow.get_node_or_null(flow.vincent_house_return_marker_path) as Node2D
	if return_marker != null:
		move_player_to_position(return_marker.global_position)
	else:
		push_warning("Could not find VincentHouse return marker '%s'." % flow.vincent_house_return_marker_path)

	flow.active_interior_id = ""
	set_interior_active(flow.vincent_house_interior, false)
	if should_start_third_wave_after_house_exit():
		flow.begin_third_wave_elder_ready_stage()


func should_start_third_wave_after_house_exit() -> bool:
	return (
		flow.quest_stage == STAGE_RULES.STAGE_VINCENT_HOUSE_AVAILABLE
		and not flow.third_wave_spawned
		and flow.is_vincent_house_dialogue_completed()
	)


func move_player_to_position(target_position: Vector2):
	if flow.player == null:
		return

	if flow.player.has_method("clear_interaction_targets"):
		flow.player.clear_interaction_targets()

	if flow.player is Node2D:
		(flow.player as Node2D).global_position = target_position
		(flow.player as Node2D).set_deferred("velocity", Vector2.ZERO)

	if flow.player.has_method("hold_dialogue_idle"):
		flow.player.hold_dialogue_idle()


func set_interior_active(interior: Node2D, active: bool):
	if interior == null:
		return

	if interior.has_method("set_active_room"):
		interior.call("set_active_room", active)
	else:
		interior.visible = active
		interior.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func restore_active_interior_state():
	var inside_vincent_house: bool = flow.active_interior_id == VINCENT_HOUSE_INTERIOR_ID
	set_interior_active(flow.vincent_house_interior, inside_vincent_house)
	flow.sync_vincent_house_occupancy()
	if inside_vincent_house:
		reparent_player_to(flow.get_node_or_null(flow.vincent_house_interior_player_parent_path))
	else:
		reparent_player_to(flow.get_node_or_null(flow.exterior_player_parent_path))


func reparent_player_to(new_parent: Node):
	if flow.player == null or new_parent == null or flow.player.get_parent() == new_parent:
		return

	if flow.player is Node2D:
		var player_node := flow.player as Node2D
		var saved_global_position := player_node.global_position
		flow.player.reparent(new_parent, true)
		player_node.global_position = saved_global_position
	else:
		flow.player.reparent(new_parent, true)
