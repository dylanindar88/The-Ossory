class_name CampfireBase
extends StaticBody2D

signal destroyed(campfire: Node)
signal player_detected(campfire: Node, player: Node)
signal player_tracking_exited(campfire: Node, player: Node)
signal active_layout_changed(campfire: Node)

const CHARACTER_NAVIGATION_SETTINGS = preload("res://scripts/levels/shared/CharacterNavigationSettings.gd")

const DEFAULT_VARIANTS: Array[Resource] = [
	preload("res://resources/environment/structures/campfire_base/campfire_base_variant_a.tres"),
	preload("res://resources/environment/structures/campfire_base/campfire_base_variant_b.tres"),
	preload("res://resources/environment/structures/campfire_base/campfire_base_variant_c.tres"),
]

@export var campfire_base_id: StringName = &"campfire_base"
@export var available_variants: Array[Resource] = []
@export var default_variant_id: StringName = &"campfire_base_a"

@onready var layout_root: Node2D = get_node_or_null("LayoutRoot") as Node2D
@onready var camp_aggro_area: Area2D = get_node_or_null("CampAggroArea") as Area2D
@onready var camp_tracking_area: Area2D = get_node_or_null("CampTrackingArea") as Area2D

var dead: bool = false
var current_variant_id: StringName = &""
var current_variant: Resource
var current_layout: Node
var tents: Array[Node] = []
var campfire_sprite: AnimatedSprite2D
var melee_banner_sprite: AnimatedSprite2D
var camp_navigation_region: NavigationRegion2D
var campfire_base_index: int = -1


func _ready():
	add_to_group("campfire_bases")
	connect_camp_aggro_area()
	connect_camp_tracking_area()
	ensure_variant_selected()
	apply_current_variant()


func connect_camp_aggro_area():
	if camp_aggro_area == null:
		return

	camp_aggro_area.monitoring = true
	camp_aggro_area.monitorable = true
	camp_aggro_area.collision_layer = 0
	camp_aggro_area.collision_mask = 2
	var callback := Callable(self, "_on_camp_aggro_body_entered")
	if not camp_aggro_area.body_entered.is_connected(callback):
		camp_aggro_area.body_entered.connect(callback)


func _on_camp_aggro_body_entered(body: Node2D):
	if body != null and body.is_in_group("player"):
		player_detected.emit(self, body)


func connect_camp_tracking_area():
	if camp_tracking_area == null:
		return

	camp_tracking_area.monitoring = true
	camp_tracking_area.monitorable = true
	camp_tracking_area.collision_layer = 0
	camp_tracking_area.collision_mask = 2
	var callback := Callable(self, "_on_camp_tracking_body_exited")
	if not camp_tracking_area.body_exited.is_connected(callback):
		camp_tracking_area.body_exited.connect(callback)


func _on_camp_tracking_body_exited(body: Node2D):
	if body != null and body.is_in_group("player"):
		if should_defer_player_tracking_exit(body):
			call_deferred("refresh_player_tracking_after_deferred_exit", body)
			return
		player_tracking_exited.emit(self, body)


func should_defer_player_tracking_exit(body: Node) -> bool:
	if body == null:
		return false
	if body.has_method("is_transforming_forms") and bool(body.call("is_transforming_forms")):
		return true
	return body.has_method("is_life_respawn_pending") and bool(body.call("is_life_respawn_pending"))


func refresh_player_tracking_after_deferred_exit(body: Node):
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.physics_frame
	await tree.physics_frame
	if not is_inside_tree() or dead:
		return
	if body != null and is_instance_valid(body) and body is Node2D and is_player_in_tracking_area(body as Node2D):
		return
	player_tracking_exited.emit(self, body)


func is_player_in_tracking_area(player_node: Node2D) -> bool:
	if player_node == null or camp_tracking_area == null or not camp_tracking_area.monitoring:
		return false
	for body in camp_tracking_area.get_overlapping_bodies():
		if body == player_node:
			return true
	return is_position_inside_camp_tracking_area(player_node.global_position)


func refresh_player_detection():
	if not is_inside_tree() or dead or camp_aggro_area == null:
		return

	var tree := get_tree()
	if tree == null:
		return

	await tree.physics_frame
	if not is_inside_tree() or dead or camp_aggro_area == null or not camp_aggro_area.monitoring:
		return

	for body in camp_aggro_area.get_overlapping_bodies():
		if body is Node2D and is_instance_valid(body) and body.is_in_group("player"):
			player_detected.emit(self, body)
			return


func get_respawn_position() -> Vector2:
	var respawn_point := get_layout_respawn_point()
	if respawn_point != null:
		return respawn_point.global_position
	return global_position


func collect_story_save_state() -> Dictionary:
	return {
		"campfire_base_id": str(campfire_base_id),
		"variant_id": str(current_variant_id),
		"dead": dead,
		"tents": collect_tent_states(),
	}


func apply_story_save_state(state: Dictionary):
	var saved_variant_id := StringName(str(state.get("variant_id", current_variant_id)))
	if str(saved_variant_id) != "":
		select_variant_by_id(saved_variant_id)
	apply_current_variant()

	apply_tent_states(state.get("tents", []))
	if bool(state.get("dead", false)) and state.get("tents", []) == []:
		destroy_all_tents()
	refresh_destroyed_state(false)
	update_layout_visual_state()


func set_campfire_base_index(index: int):
	campfire_base_index = index


func reset_for_level_entry():
	restore_alive(dead)


func restore_alive(reroll_variant: bool = false):
	if reroll_variant:
		select_random_variant(true)
	apply_current_variant()
	dead = false
	for tent in tents:
		if tent != null and tent.has_method("restore_alive"):
			tent.restore_alive()
	update_layout_visual_state()


func ensure_variant_selected():
	if str(current_variant_id) != "" and current_variant != null:
		return

	if str(default_variant_id) != "":
		select_variant_by_id(default_variant_id)
	if current_variant == null:
		var variants := get_available_variants()
		if not variants.is_empty():
			set_current_variant(variants[0])


func get_available_variants() -> Array[Resource]:
	var variants: Array[Resource] = []
	for variant in available_variants:
		if is_valid_variant(variant):
			variants.append(variant)
	if variants.is_empty():
		for variant in DEFAULT_VARIANTS:
			if is_valid_variant(variant):
				variants.append(variant)
	return variants


func is_valid_variant(variant: Resource) -> bool:
	return variant != null and variant.get("variant_id") != null and variant.get("layout_scene") != null


func select_variant_by_id(variant_id: StringName) -> bool:
	for variant in get_available_variants():
		if StringName(str(variant.get("variant_id"))) == variant_id:
			set_current_variant(variant)
			return true
	return false


func select_random_variant(exclude_current: bool = false):
	var variants := get_available_variants()
	if variants.is_empty():
		return

	var candidates: Array[Resource] = []
	for variant in variants:
		var variant_id := StringName(str(variant.get("variant_id")))
		if not exclude_current or variant_id != current_variant_id:
			candidates.append(variant)
	if candidates.is_empty():
		candidates = variants

	set_current_variant(candidates[randi() % candidates.size()])


func set_current_variant(variant: Resource):
	if not is_valid_variant(variant):
		return

	current_variant = variant
	current_variant_id = StringName(str(variant.get("variant_id")))


func apply_current_variant():
	ensure_variant_selected()
	if current_variant == null or layout_root == null:
		return

	clear_layout()
	var layout_scene: PackedScene = current_variant.get("layout_scene")
	current_layout = layout_scene.instantiate()
	layout_root.add_child(current_layout)
	promote_knight_roster_children()
	discover_layout_members()
	connect_tents()
	update_layout_visual_state()
	active_layout_changed.emit(self)


func clear_layout():
	tents.clear()
	campfire_sprite = null
	melee_banner_sprite = null
	camp_navigation_region = null
	current_layout = null
	if layout_root == null:
		return

	for child in layout_root.get_children():
		layout_root.remove_child(child)
		child.free()


func discover_layout_members():
	tents.clear()
	campfire_sprite = null
	melee_banner_sprite = null
	camp_navigation_region = null
	if current_layout == null:
		return

	collect_tents_from(current_layout)
	campfire_sprite = find_component_sprite(current_layout, "Campfire")
	melee_banner_sprite = find_component_sprite(current_layout, "MeleeBanner")
	camp_navigation_region = current_layout.find_child("CampNavigationRegion", true, false) as NavigationRegion2D
	if camp_navigation_region != null:
		camp_navigation_region.enabled = true
		camp_navigation_region.navigation_layers = CHARACTER_NAVIGATION_SETTINGS.CAMPFIRE_BASE_KNIGHT_NAVIGATION_LAYER


func promote_knight_roster_children():
	if current_layout == null:
		return

	var knight_roster := current_layout.find_child("KnightRoster", false, false) as Node2D
	if knight_roster == null:
		return
	var promotion_parent := current_layout.find_child("CampNavigationRegion", false, false) as Node2D
	if promotion_parent == null:
		promotion_parent = current_layout

	for child in knight_roster.get_children():
		if not (child is Node2D):
			continue

		var child_2d := child as Node2D
		var preserved_global_transform := child_2d.global_transform
		knight_roster.remove_child(child_2d)
		promotion_parent.add_child(child_2d)
		child_2d.global_transform = preserved_global_transform
		if child_2d.has_method("set_campfire_base_path_if_empty"):
			child_2d.set_campfire_base_path_if_empty(child_2d.get_path_to(self))


func collect_tents_from(root: Node):
	if root == null:
		return

	for child in root.get_children():
		if child.has_method("get_tent_id") and child.has_method("apply_story_save_state"):
			tents.append(child)
		collect_tents_from(child)


func connect_tents():
	for tent in tents:
		if tent == null or not tent.has_signal("destroyed"):
			continue
		var callback := Callable(self, "_on_tent_destroyed")
		if not tent.is_connected("destroyed", callback):
			tent.connect("destroyed", callback)


func _on_tent_destroyed(_tent: Node):
	refresh_destroyed_state(true)


func refresh_destroyed_state(should_emit_destroyed: bool):
	var all_destroyed := not tents.is_empty()
	for tent in tents:
		if tent != null and not bool(tent.get("dead")):
			all_destroyed = false
			break

	if all_destroyed and not dead:
		dead = true
		update_layout_visual_state()
		if should_emit_destroyed:
			destroyed.emit(self)
	elif not all_destroyed:
		dead = false
		update_layout_visual_state()


func update_layout_visual_state():
	play_sprite_state(campfire_sprite, "unlit" if dead else "lit")
	play_sprite_state(melee_banner_sprite, "ruined" if dead else "intact")


func play_sprite_state(sprite: AnimatedSprite2D, animation_name: String):
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)


func find_component_sprite(root: Node, component_name: String) -> AnimatedSprite2D:
	if root == null:
		return null

	var component := root.find_child(component_name, true, false)
	if component is AnimatedSprite2D:
		return component as AnimatedSprite2D
	if component == null:
		return null

	return component.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D


func get_layout_respawn_point() -> Marker2D:
	if current_layout == null:
		return null
	return current_layout.find_child("RespawnPoint", true, false) as Marker2D


func get_active_camp_navigation_region() -> NavigationRegion2D:
	return camp_navigation_region


func get_active_layout() -> Node:
	return current_layout


func is_position_inside_camp_navigation(world_position: Vector2) -> bool:
	if camp_navigation_region == null or camp_navigation_region.navigation_polygon == null:
		return false

	var navigation_polygon := camp_navigation_region.navigation_polygon
	if navigation_polygon.get_polygon_count() <= 0:
		return false

	var local_position := camp_navigation_region.to_local(world_position)
	var vertices := navigation_polygon.get_vertices()
	for polygon_index in range(navigation_polygon.get_polygon_count()):
		var polygon_indices := navigation_polygon.get_polygon(polygon_index)
		var polygon_points: PackedVector2Array = []
		for vertex_index in polygon_indices:
			if vertex_index >= 0 and vertex_index < vertices.size():
				polygon_points.append(vertices[vertex_index])
		if polygon_points.size() >= 3 and Geometry2D.is_point_in_polygon(local_position, polygon_points):
			return true

	return false


func is_position_inside_camp_aggro_area(world_position: Vector2) -> bool:
	return is_position_inside_area_shape(camp_aggro_area, world_position)


func is_position_inside_camp_tracking_area(world_position: Vector2) -> bool:
	return is_position_inside_area_shape(camp_tracking_area, world_position)


func is_position_inside_area_shape(area: Area2D, world_position: Vector2) -> bool:
	if area == null:
		return false

	var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null or shape_node.disabled:
		return false

	var local_position := shape_node.to_local(world_position)
	var shape := shape_node.shape
	if shape is CircleShape2D:
		return local_position.length() <= (shape as CircleShape2D).radius
	if shape is RectangleShape2D:
		var half_size := (shape as RectangleShape2D).size * 0.5
		return absf(local_position.x) <= half_size.x and absf(local_position.y) <= half_size.y
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half_segment := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		var closest_point := Vector2(0.0, clampf(local_position.y, -half_segment, half_segment))
		return local_position.distance_to(closest_point) <= capsule.radius

	return false


func is_position_inside_camp_bounds(world_position: Vector2) -> bool:
	return is_position_inside_camp_navigation(world_position) or is_position_inside_camp_aggro_area(world_position)


func get_tent_count() -> int:
	return tents.size()


func get_max_knight_count() -> int:
	if current_variant != null:
		var configured_count := int(current_variant.get("max_knight_count"))
		if configured_count > 0:
			return configured_count
	return get_tent_count()


func collect_tent_states() -> Array:
	var states: Array = []
	for tent in tents:
		if tent == null:
			continue
		var state: Dictionary = {}
		if tent.has_method("collect_story_save_state"):
			var raw_state: Variant = tent.collect_story_save_state()
			if raw_state is Dictionary:
				state = raw_state
		state["node_name"] = tent.name
		states.append(state)
	return states


func apply_tent_states(raw_states: Variant):
	if not (raw_states is Array):
		return

	var lookup: Dictionary = {}
	for raw_state in raw_states:
		if not (raw_state is Dictionary):
			continue
		var state: Dictionary = raw_state
		var tent_id := str(state.get("tent_id", ""))
		if tent_id != "":
			lookup[tent_id] = state
		var node_name := str(state.get("node_name", ""))
		if node_name != "":
			lookup[node_name] = state

	for tent in tents:
		var key := get_tent_key(tent)
		if lookup.has(key) and tent.has_method("apply_story_save_state"):
			tent.apply_story_save_state(lookup[key])


func get_tent_key(tent: Node) -> String:
	if tent != null and tent.has_method("get_tent_id"):
		return str(tent.get_tent_id())
	if tent == null:
		return ""
	return str(tent.name)


func destroy_all_tents():
	for tent in tents:
		if tent != null and tent.has_method("destroy"):
			tent.destroy()
