extends RefCounted

const LEVEL_PATH := "res://scenes/levels/StartingWilderness.tscn"
const HOSTILE_ROOT := "PlayableWorld/Environment/Characters/HostileNPCs/Banshees"
const PATROL_ROOT := "PlayableWorld/Markers/PatrolPaths"

const EXPECTED_PATROLS := {
	"Banshee2": "../../../../../Markers/PatrolPaths/Banshee2And4CirclePath",
	"Banshee4": "../../../../../Markers/PatrolPaths/Banshee2And4CirclePath",
	"Banshee9": "../../../../../Markers/PatrolPaths/Banshee3_9_10TrianglePath",
	"Banshee3": "../../../../../Markers/PatrolPaths/Banshee3_9_10TrianglePath",
	"Banshee10": "../../../../../Markers/PatrolPaths/Banshee3_9_10TrianglePath",
	"Banshee5": "../../../../../Markers/PatrolPaths/Banshee5SmallCirclePath",
	"Banshee6": "../../../../../Markers/PatrolPaths/Banshee6LinePath",
	"Banshee7": "../../../../../Markers/PatrolPaths/Banshee7LinePath",
	"Banshee8": "../../../../../Markers/PatrolPaths/Banshee8LinePath",
}

const EXPECTED_PING_PONG := {
	"Banshee2": false,
	"Banshee4": false,
	"Banshee9": false,
	"Banshee3": false,
	"Banshee10": false,
	"Banshee5": false,
	"Banshee6": true,
	"Banshee7": true,
	"Banshee8": true,
}

const SMOOTH_ROUTES := [
	"Banshee2And4CirclePath",
	"Banshee3_9_10TrianglePath",
	"Banshee5SmallCirclePath",
]

const LINE_ROUTE_STOP_COUNTS := {
	"Banshee6LinePath": 2,
	"Banshee7LinePath": 2,
	"Banshee8LinePath": 2,
}


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var packed: PackedScene = load(LEVEL_PATH)
	assertions.assert_true(packed != null, "Starting Wilderness should load for patrol tests.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	assert_banshee_patrol_assignments(assertions, level)
	assert_starting_banshee_villager_stalk(assertions, level)
	assert_route_shapes(assertions, level)

	level.queue_free()
	save_manager.call("set_current_level", null)
	await tree.process_frame


func assert_banshee_patrol_assignments(assertions: TestAssertions, level: Node):
	for banshee_name in EXPECTED_PATROLS.keys():
		var banshee: Node = level.get_node_or_null("%s/%s" % [HOSTILE_ROOT, banshee_name])
		assertions.assert_true(banshee != null, "%s should exist in Starting Wilderness." % banshee_name)
		if banshee == null:
			continue

		var expected_path: String = str(EXPECTED_PATROLS[banshee_name])
		assertions.assert_eq(str(banshee.get("patrol_path")), expected_path, "%s should use the expected patrol path." % banshee_name)
		assertions.assert_eq(bool(banshee.get("patrol_ping_pong")), bool(EXPECTED_PING_PONG[banshee_name]), "%s should use the expected ping-pong setting." % banshee_name)
		assertions.assert_eq(str(banshee.get("assigned_villager_path")), "", "%s should not be assigned to a villager." % banshee_name)

		var route: Node = banshee.get_node_or_null(banshee.get("patrol_path"))
		assertions.assert_true(route != null, "%s patrol path should resolve." % banshee_name)


func assert_starting_banshee_villager_stalk(assertions: TestAssertions, level: Node):
	var banshee: Node = level.get_node_or_null("%s/Banshee" % HOSTILE_ROOT)
	var villager: Node = level.get_node_or_null("PlayableWorld/Environment/Characters/NPCs/MaleVillager")
	assertions.assert_true(banshee != null, "Starting Wilderness Banshee should exist.")
	assertions.assert_true(villager != null, "Starting Wilderness MaleVillager should exist.")
	if banshee == null or villager == null:
		return

	assertions.assert_eq(str(banshee.get("patrol_path")), "../../../../../Markers/PatrolPaths/VillagerPath", "Starting Banshee should use the shared villager patrol path.")
	assertions.assert_eq(str(banshee.get("assigned_villager_path")), "../../../NPCs/MaleVillager", "Starting Banshee should resolve its assigned villager from the Banshees folder.")
	assertions.assert_true(banshee.get_node_or_null(banshee.get("assigned_villager_path")) == villager, "Starting Banshee assigned villager path should resolve to MaleVillager.")
	assertions.assert_true(bool(banshee.call("has_assigned_villager")), "Starting Banshee should have active villager-stalk behavior.")


func assert_route_shapes(assertions: TestAssertions, level: Node):
	for route_name in SMOOTH_ROUTES:
		var route: Node = level.get_node_or_null("%s/%s" % [PATROL_ROOT, route_name])
		assertions.assert_true(route != null, "%s should exist." % route_name)
		if route == null:
			continue

		var path: Path2D = route.get_node_or_null("Path") as Path2D
		assertions.assert_true(path != null, "%s should have a Path2D child." % route_name)
		assertions.assert_true(path.curve != null, "%s Path2D should have a curve." % route_name)
		if path != null and path.curve != null:
			assertions.assert_true(path.curve.get_baked_length() > 0.0, "%s curve should have length." % route_name)

		var stops: Node = route.get_node_or_null("Stops")
		assertions.assert_true(stops != null, "%s should have editable Stops." % route_name)
		if stops != null:
			assertions.assert_true(count_marker_children(stops) >= 3, "%s should expose editable perimeter markers." % route_name)

	for route_name in LINE_ROUTE_STOP_COUNTS.keys():
		var route: Node = level.get_node_or_null("%s/%s" % [PATROL_ROOT, route_name])
		assertions.assert_true(route != null, "%s should exist." % route_name)
		if route == null:
			continue

		var stops: Node = route.get_node_or_null("Stops")
		assertions.assert_true(stops != null, "%s should have editable Stops." % route_name)
		if stops != null:
			assertions.assert_eq(count_marker_children(stops), int(LINE_ROUTE_STOP_COUNTS[route_name]), "%s should have exactly two ping-pong points." % route_name)


func count_marker_children(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child is Marker2D:
			count += 1
	return count
