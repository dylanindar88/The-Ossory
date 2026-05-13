class_name VillagerAmbientPatrolBehavior
extends RefCounted

const AMBIENT_STOPS_NODE_NAME: String = "AmbientStops"
const HOUSE_STOPS_NODE_NAME: String = "HouseStops"

var owner: Node2D
var route_root: Node
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ambient_points: Array[Vector2] = []
var house_points: Array[Vector2] = []
var idle_remaining_seconds: float = 0.0
var social_remaining_seconds: float = 0.0
var general_cooldown_seconds: float = 0.0
var social_cooldown_seconds: float = 0.0
var check_timer_seconds: float = 0.0
var social_partner: Node2D
var reverse_after_idle: bool = false


func setup(new_owner: Node2D, patrol_path: NodePath):
	owner = new_owner
	rng.randomize()
	reset()
	refresh_markers(patrol_path)
	check_timer_seconds = get_check_interval()


func refresh_markers(patrol_path: NodePath):
	ambient_points.clear()
	house_points.clear()
	route_root = null

	if owner == null or str(patrol_path) == "":
		return

	route_root = owner.get_node_or_null(patrol_path)
	if route_root == null:
		return

	add_marker_points(route_root.get_node_or_null(AMBIENT_STOPS_NODE_NAME), ambient_points)
	add_marker_points(route_root.get_node_or_null(HOUSE_STOPS_NODE_NAME), house_points)


func reset():
	idle_remaining_seconds = 0.0
	social_remaining_seconds = 0.0
	general_cooldown_seconds = 0.0
	social_cooldown_seconds = 0.0
	check_timer_seconds = 0.0
	social_partner = null
	reverse_after_idle = false


func get_social_partner() -> Node2D:
	if social_partner == null or not is_instance_valid(social_partner):
		return null

	return social_partner


func cancel_social_with(partner: Node2D):
	if social_partner != partner:
		return

	social_partner = null
	social_remaining_seconds = 0.0


func update(delta: float, can_start_new_behavior: bool):
	general_cooldown_seconds = max(general_cooldown_seconds - delta, 0.0)
	social_cooldown_seconds = max(social_cooldown_seconds - delta, 0.0)

	if is_social_active():
		update_social(delta)
		return

	if is_idle_active():
		update_idle(delta)
		return

	if not can_start_new_behavior:
		return

	check_timer_seconds -= delta
	if check_timer_seconds > 0.0:
		return

	check_timer_seconds = get_check_interval()
	if try_start_social_behavior():
		return

	try_start_idle_behavior()


func is_busy() -> bool:
	return is_idle_active() or is_social_active()


func is_idle_active() -> bool:
	return idle_remaining_seconds > 0.0


func is_social_active() -> bool:
	return social_remaining_seconds > 0.0 and social_partner != null and is_instance_valid(social_partner)


func consume_reverse_after_idle() -> bool:
	if not reverse_after_idle:
		return false

	reverse_after_idle = false
	return true


func start_social_with(partner: Node2D, duration: float):
	if owner == null or partner == null:
		return

	social_partner = partner
	social_remaining_seconds = max(duration, 0.0)
	idle_remaining_seconds = 0.0
	reverse_after_idle = false
	general_cooldown_seconds = get_general_cooldown()
	social_cooldown_seconds = get_social_cooldown()


func update_social(delta: float):
	social_remaining_seconds = max(social_remaining_seconds - delta, 0.0)
	face_partner()
	if social_remaining_seconds <= 0.0:
		social_partner = null


func update_idle(delta: float):
	idle_remaining_seconds = max(idle_remaining_seconds - delta, 0.0)
	if idle_remaining_seconds > 0.0:
		return

	general_cooldown_seconds = get_general_cooldown()
	if rng.randf() <= get_reverse_chance():
		reverse_after_idle = true


func try_start_idle_behavior():
	if owner == null or general_cooldown_seconds > 0.0:
		return

	var chance: float = get_base_stop_chance()
	var duration_min: float = get_idle_min_seconds()
	var duration_max: float = get_idle_max_seconds()

	if is_near_house_stop():
		chance = min(chance * get_house_stop_multiplier(), 1.0)
		duration_min = max(duration_min, get_house_idle_min_seconds())
		duration_max = max(duration_max, get_house_idle_max_seconds())
	elif is_near_ambient_stop():
		chance = min(chance * get_ambient_stop_multiplier(), 1.0)

	if rng.randf() > chance:
		return

	idle_remaining_seconds = rng.randf_range(duration_min, max(duration_min, duration_max))


func try_start_social_behavior() -> bool:
	if owner == null or social_cooldown_seconds > 0.0:
		return false

	if rng.randf() > get_social_chance():
		return false

	var partner: Node2D = find_social_partner()
	if partner == null:
		return false

	var duration: float = rng.randf_range(get_social_min_seconds(), max(get_social_min_seconds(), get_social_max_seconds()))
	start_social_with(partner, duration)
	if partner.has_method("begin_ambient_social"):
		partner.begin_ambient_social(owner, duration)
	return true


func find_social_partner() -> Node2D:
	if owner == null or not owner.is_inside_tree():
		return null

	var radius_squared: float = get_social_radius() * get_social_radius()
	var villagers: Array[Node] = owner.get_tree().get_nodes_in_group("celtic_villagers")
	var best_partner: Node2D = null
	var best_distance: float = radius_squared

	for villager_node in villagers:
		if villager_node == owner:
			continue
		if not (villager_node is Node2D):
			continue
		if owner.get_instance_id() > villager_node.get_instance_id():
			continue
		if not villager_node.has_method("is_available_for_ambient_social"):
			continue
		if not villager_node.is_available_for_ambient_social():
			continue

		var candidate: Node2D = villager_node as Node2D
		var distance: float = owner.global_position.distance_squared_to(candidate.global_position)
		if distance <= best_distance:
			best_distance = distance
			best_partner = candidate

	return best_partner


func face_partner():
	if owner == null or social_partner == null or not is_instance_valid(social_partner):
		return

	if owner.has_method("face_node"):
		owner.face_node(social_partner)


func add_marker_points(marker_parent: Node, target: Array[Vector2]):
	if marker_parent == null:
		return

	for child in marker_parent.get_children():
		if child is Marker2D:
			var marker: Marker2D = child as Marker2D
			target.append(marker.global_position)


func is_near_house_stop() -> bool:
	return is_near_point_in(house_points, get_house_stop_radius())


func is_near_ambient_stop() -> bool:
	return is_near_point_in(ambient_points, get_ambient_stop_radius())


func is_near_point_in(points: Array[Vector2], radius: float) -> bool:
	if owner == null or points.is_empty():
		return false

	var radius_squared: float = radius * radius
	for point in points:
		if owner.global_position.distance_squared_to(point) <= radius_squared:
			return true

	return false


func get_check_interval() -> float:
	return get_owner_float("ambient_check_interval_seconds", 1.25)


func get_general_cooldown() -> float:
	return get_owner_float("ambient_stop_cooldown_seconds", 7.0)


func get_social_cooldown() -> float:
	return get_owner_float("ambient_social_cooldown_seconds", 12.0)


func get_base_stop_chance() -> float:
	return get_owner_float("ambient_stop_chance", 0.1)


func get_ambient_stop_multiplier() -> float:
	return get_owner_float("ambient_marker_stop_multiplier", 2.0)


func get_house_stop_multiplier() -> float:
	return get_owner_float("ambient_house_stop_multiplier", 4.0)


func get_idle_min_seconds() -> float:
	return get_owner_float("ambient_idle_min_seconds", 1.5)


func get_idle_max_seconds() -> float:
	return get_owner_float("ambient_idle_max_seconds", 2.25)


func get_house_idle_min_seconds() -> float:
	return get_owner_float("ambient_house_idle_min_seconds", 1.5)


func get_house_idle_max_seconds() -> float:
	return get_owner_float("ambient_house_idle_max_seconds", 3.5)


func get_reverse_chance() -> float:
	return get_owner_float("ambient_reverse_chance", 0.18)


func get_social_chance() -> float:
	return get_owner_float("ambient_social_chance", 0.5)


func get_social_min_seconds() -> float:
	return get_owner_float("ambient_social_min_seconds", 1.5)


func get_social_max_seconds() -> float:
	return get_owner_float("ambient_social_max_seconds", 3.25)


func get_social_radius() -> float:
	return get_owner_float("ambient_social_radius", 54.0)


func get_house_stop_radius() -> float:
	return get_owner_float("ambient_house_stop_radius", 38.0)


func get_ambient_stop_radius() -> float:
	return get_owner_float("ambient_marker_stop_radius", 32.0)


func get_owner_float(property_name: String, fallback: float) -> float:
	if owner == null:
		return fallback

	var value: Variant = owner.get(property_name)
	if value == null:
		return fallback

	return float(value)
