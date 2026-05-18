class_name KnightCampLevelSupport
extends Node

const KNIGHT_CAMP_ENCOUNTER_CONTROLLER_SCRIPT = preload("res://scripts/levels/shared/KnightCampEncounterController.gd")
const CHARACTER_NAVIGATION_SETTINGS = preload("res://scripts/levels/shared/CharacterNavigationSettings.gd")

var level_root: Node
var hostile_root: Node
var campfire_root: Node
var knight_camp_controller: KnightCampEncounterController
var character_navigation_layer: int = CHARACTER_NAVIGATION_SETTINGS.DEFAULT_CHARACTER_NAVIGATION_LAYER


func configure(owner_level: Node, hostile_root_node: Node, campfire_root_node: Node = null):
	level_root = owner_level
	hostile_root = hostile_root_node
	campfire_root = campfire_root_node if campfire_root_node != null else hostile_root_node
	ensure_knight_camp_controller()
	refresh_wiring()


func collect_level_state() -> Dictionary:
	ensure_knight_camp_controller()
	if knight_camp_controller == null:
		return {}
	return knight_camp_controller.collect_level_state()


func apply_level_state(state: Dictionary):
	ensure_knight_camp_controller()
	if knight_camp_controller != null:
		knight_camp_controller.apply_level_state(state)


func validate_level_state(state: Dictionary) -> Array:
	ensure_knight_camp_controller()
	if knight_camp_controller == null:
		return []
	var messages := knight_camp_controller.validate_level_state(state)
	messages.append_array(validate_level_navigation_contract())
	return messages


func uses_level_owned_hostile_state() -> bool:
	return true


func prepare_for_route_exit():
	if knight_camp_controller != null:
		knight_camp_controller.prepare_for_route_exit()


func reset_for_level_entry():
	ensure_knight_camp_controller()
	if knight_camp_controller != null:
		knight_camp_controller.reset_for_level_entry()


func get_knight_camp_controller() -> KnightCampEncounterController:
	ensure_knight_camp_controller()
	return knight_camp_controller


func refresh_members():
	ensure_knight_camp_controller()
	if knight_camp_controller != null:
		knight_camp_controller.refresh_members()


func refresh_wiring():
	if knight_camp_controller != null:
		knight_camp_controller.refresh_wiring()


func ensure_knight_camp_controller():
	if knight_camp_controller == null:
		knight_camp_controller = KNIGHT_CAMP_ENCOUNTER_CONTROLLER_SCRIPT.new()
		knight_camp_controller.name = "KnightCampEncounterController"
		add_child(knight_camp_controller)

	configure_controller_paths()


func configure_controller_paths():
	if knight_camp_controller == null:
		return

	var resolved_level := get_valid_level_root()
	var resolved_hostile := get_valid_hostile_root(resolved_level)
	var resolved_campfire := get_valid_campfire_root(resolved_hostile)

	knight_camp_controller.state_root_path = get_controller_path_to(resolved_level)
	knight_camp_controller.hostile_root_path = get_controller_path_to(resolved_hostile)
	knight_camp_controller.campfire_root_path = get_controller_path_to(resolved_campfire)


func get_valid_level_root() -> Node:
	if is_instance_valid(level_root):
		return level_root
	var parent := get_parent()
	if parent != null:
		return parent.get_parent() if parent.get_parent() != null else parent
	return null


func get_valid_hostile_root(fallback_root: Node) -> Node:
	if is_instance_valid(hostile_root):
		return hostile_root
	return fallback_root


func get_valid_campfire_root(fallback_root: Node) -> Node:
	if is_instance_valid(campfire_root):
		return campfire_root
	return fallback_root


func get_controller_path_to(target: Node) -> NodePath:
	if knight_camp_controller == null or target == null:
		return NodePath("")
	if not knight_camp_controller.is_inside_tree() or not target.is_inside_tree():
		return NodePath("")
	return knight_camp_controller.get_path_to(target)


func validate_level_navigation_contract() -> Array:
	var messages: Array = []
	var resolved_level := get_valid_level_root()
	if resolved_level == null:
		return messages
	if not level_has_navigation_dependent_actors():
		return messages

	var region := get_level_character_navigation_region(resolved_level)
	if region == null:
		messages.append("%s should have PlayableWorld/Navigation/CharacterNavigationRegions/LevelCharacterNavigationRegion for shared character navigation." % resolved_level.name)
		return messages
	if region.navigation_polygon == null:
		messages.append("%s LevelCharacterNavigationRegion should have a NavigationPolygon resource for character pathing." % resolved_level.name)
	if region.navigation_layers != character_navigation_layer:
		messages.append("%s LevelCharacterNavigationRegion should use character navigation layer %d." % [resolved_level.name, character_navigation_layer])
	if region.get_node_or_null(CHARACTER_NAVIGATION_SETTINGS.NAVIGATION_SOURCE_GEOMETRY_NAME) == null:
		messages.append("%s LevelCharacterNavigationRegion should have NavigationSourceGeometry for static world bake sources." % resolved_level.name)
	return messages


func level_has_navigation_dependent_actors() -> bool:
	var root := get_valid_hostile_root(get_valid_level_root())
	if root == null:
		return false
	return has_group_member(root, "hostile_npcs") or has_group_member(root, "campfire_bases")


func has_group_member(root: Node, group_name: StringName) -> bool:
	if root == null:
		return false
	for child in root.get_children():
		if child.is_in_group(group_name):
			return true
		if has_group_member(child, group_name):
			return true
	return false


func get_level_character_navigation_region(root: Node) -> NavigationRegion2D:
	if root == null:
		return null
	return root.get_node_or_null(CHARACTER_NAVIGATION_SETTINGS.LEVEL_CHARACTER_NAVIGATION_REGION_PATH) as NavigationRegion2D


func get_authored_campfires() -> Array[Node]:
	var found: Array[Node] = []
	collect_campfires_from(get_valid_campfire_root(get_valid_hostile_root(get_valid_level_root())), found)
	return found


func collect_campfires_from(root: Node, found: Array[Node]):
	if root == null:
		return
	for child in root.get_children():
		if child.is_in_group("campfire_bases"):
			found.append(child)
		collect_campfires_from(child, found)
