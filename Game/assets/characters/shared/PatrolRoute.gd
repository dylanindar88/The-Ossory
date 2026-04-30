class_name PatrolRoute
extends RefCounted

var path_node: Path2D
var curve: Curve2D
var route_loaded: bool = false
var path_offset: float = 0.0
var path_length: float = 0.0
var ping_pong_direction: float = 1.0
var points: Array[Vector2] = []
var point_index: int = 0
var point_direction: int = 1


func refresh(owner: Node2D, patrol_path: NodePath):
	points.clear()
	path_node = null
	curve = null
	route_loaded = false
	path_offset = 0.0
	path_length = 0.0

	if str(patrol_path) == "":
		point_index = 0
		return

	var route_root: Node = owner.get_node_or_null(patrol_path)
	if route_root == null:
		point_index = 0
		return

	var route_path: Path2D = get_route_path(route_root)
	if route_path != null and route_path.curve != null:
		set_curve(owner, route_path)

	if curve == null:
		add_marker_points(route_root)

	if point_index >= points.size():
		point_index = 0

	route_loaded = has_route()


func get_route_path(route_root: Node) -> Path2D:
	if route_root is Path2D:
		return route_root as Path2D

	return route_root.get_node_or_null("Path") as Path2D


func set_curve(owner: Node2D, route_path: Path2D):
	path_node = route_path
	curve = route_path.curve
	path_length = curve.get_baked_length()

	if path_length <= 0.0:
		path_node = null
		curve = null
		path_length = 0.0
		return

	path_offset = get_nearest_path_offset(owner.global_position)


func add_marker_points(route_root: Node):
	var stops_node := route_root.get_node_or_null("Stops")
	if stops_node != null:
		add_marker_points_from(stops_node)
		if not points.is_empty():
			return

	add_marker_points_from(route_root)


func add_marker_points_from(marker_parent: Node):
	var marker_points: Array[Marker2D] = []
	for child in marker_parent.get_children():
		if child is Marker2D:
			marker_points.append(child as Marker2D)

	marker_points.sort_custom(
		func(a: Marker2D, b: Marker2D):
			return String(a.name).naturalnocasecmp_to(String(b.name)) < 0
	)

	for marker in marker_points:
		points.append(marker.global_position)


func has_route() -> bool:
	return curve != null or points.size() > 0


func has_smooth_route() -> bool:
	return path_node != null and curve != null and path_length > 0.0


func get_current_point(fallback_position: Vector2) -> Vector2:
	if not has_route() or points.is_empty():
		return fallback_position

	return points[point_index]


func advance_path_offset(speed: float, delta: float, ping_pong: bool):
	if not has_smooth_route():
		return

	if ping_pong:
		path_offset += speed * delta * ping_pong_direction

		if path_offset >= path_length:
			path_offset = path_length
			ping_pong_direction = -1.0
		elif path_offset <= 0.0:
			path_offset = 0.0
			ping_pong_direction = 1.0

		return

	path_offset = wrapf(path_offset + speed * delta, 0.0, path_length)


func advance_point(ping_pong: bool):
	if not has_route() or points.is_empty():
		return

	if ping_pong and points.size() > 1:
		point_index += point_direction

		if point_index >= points.size():
			point_direction = -1
			point_index = points.size() - 2
		elif point_index < 0:
			point_direction = 1
			point_index = 1

		return

	point_index = (point_index + 1) % points.size()


func select_nearest(world_position: Vector2):
	if not has_route():
		return

	if has_smooth_route():
		path_offset = get_nearest_path_offset(world_position)
		return

	if points.is_empty():
		return

	var nearest_index: int = 0
	var nearest_distance: float = world_position.distance_squared_to(points[0])

	for index in range(1, points.size()):
		var distance: float = world_position.distance_squared_to(points[index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	point_index = nearest_index


func get_position_at_offset(offset: float, fallback_position: Vector2) -> Vector2:
	if not has_smooth_route():
		return fallback_position

	return path_node.to_global(curve.sample_baked(offset, true))


func get_nearest_path_offset(world_position: Vector2) -> float:
	if path_node == null or curve == null:
		return 0.0

	return curve.get_closest_offset(path_node.to_local(world_position))


func get_anchor_position(fallback_position: Vector2, distance: float, ping_pong: bool, last_direction: Vector2) -> Vector2:
	if has_smooth_route():
		return get_position_at_offset(get_anchor_path_offset(distance, ping_pong), fallback_position)

	if last_direction == Vector2.ZERO:
		return fallback_position

	return fallback_position - last_direction * max(distance, 0.0)


func get_anchor_path_offset(distance: float, ping_pong: bool) -> float:
	var safe_distance: float = max(distance, 0.0)

	if ping_pong:
		return clamp(path_offset - ping_pong_direction * safe_distance, 0.0, path_length)

	return wrapf(path_offset - safe_distance, 0.0, path_length)


func to_save_data() -> Dictionary:
	return {
		"path_offset": path_offset,
		"ping_pong_direction": ping_pong_direction,
		"point_index": point_index,
		"point_direction": point_direction,
	}


func apply_save_data(data: Variant):
	if not (data is Dictionary):
		return

	var saved_data: Dictionary = data
	if has_smooth_route():
		path_offset = clamp(float(saved_data.get("path_offset", path_offset)), 0.0, path_length)
		ping_pong_direction = get_saved_direction(float(saved_data.get("ping_pong_direction", ping_pong_direction)))

	if not points.is_empty():
		point_index = clamp(int(saved_data.get("point_index", point_index)), 0, points.size() - 1)
		point_direction = int(get_saved_direction(float(saved_data.get("point_direction", point_direction))))


func get_saved_direction(value: float) -> float:
	if value < 0.0:
		return -1.0

	return 1.0
