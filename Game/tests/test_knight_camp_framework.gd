extends RefCounted

const MELEE_SCENE := "res://scenes/characters/hostile_npcs/knights/BasicKnightMelee.tscn"
const RANGED_SCENE := "res://scenes/characters/hostile_npcs/knights/BasicKnightRanged.tscn"
const PROJECTILE_SCENE := "res://scenes/characters/hostile_npcs/knights/KnightArrowProjectile.tscn"
const BANSHEE_SCENE := "res://scenes/characters/hostile_npcs/banshees/Banshee.tscn"
const SAORISE_SCENE := "res://scenes/characters/saorise/Saorise.tscn"
const SAORISE_HUMAN_FORM := "res://resources/characters/saorise/forms/human_form.tres"
const SAORISE_WOLF_FORM := "res://resources/characters/saorise/forms/wolf_form.tres"
const CAMPFIRE_SCENE := "res://scenes/environment/structures/campfire_base/CampfireBase.tscn"
const STARTING_WILDERNESS_SCENE := "res://scenes/levels/StartingWilderness.tscn"
const WEEPING_WOODS_SCENE := "res://scenes/levels/WeepingWoods.tscn"
const BANSHEE_VILLAGE_SCENE := "res://scenes/levels/BansheeVillage.tscn"
const CAMPFIRE_TENT_SCENE := "res://scenes/environment/structures/campfire_base/CampfireBaseTent.tscn"
const CAMPFIRE_TENT_FLIPPED_SCENE := "res://scenes/environment/structures/campfire_base/CampfireBaseTentFlipped.tscn"
const CAMPFIRE_COMPONENT_SCENE := "res://scenes/environment/structures/campfire_base/Campfire.tscn"
const MELEE_BANNER_COMPONENT_SCENE := "res://scenes/environment/structures/campfire_base/MeleeBanner.tscn"
const WEAK_TO_WOLF_EFFECT := "weak_to_wolf"
const CAMPFIRE_LAYOUT_SCENES := {
	"A": "res://scenes/environment/structures/campfire_base/layouts/CampfireBaseLayoutA.tscn",
	"B": "res://scenes/environment/structures/campfire_base/layouts/CampfireBaseLayoutB.tscn",
	"C": "res://scenes/environment/structures/campfire_base/layouts/CampfireBaseLayoutC.tscn",
}
const CAMPFIRE_VARIANT_RESOURCES := {
	"A": "res://resources/environment/structures/campfire_base/campfire_base_variant_a.tres",
	"B": "res://resources/environment/structures/campfire_base/campfire_base_variant_b.tres",
	"C": "res://resources/environment/structures/campfire_base/campfire_base_variant_c.tres",
}
const ENCOUNTER_CONTROLLER_SCRIPT := preload("res://scripts/levels/shared/KnightCampEncounterController.gd")
const LEVEL_SUPPORT_SCRIPT := preload("res://scripts/levels/shared/KnightCampLevelSupport.gd")
const CHARACTER_NAVIGATION_SETTINGS := preload("res://scripts/levels/shared/CharacterNavigationSettings.gd")
const SAORISE_ATTACK_BOX_MANAGER_SCRIPT := preload("res://scripts/characters/saorise/combat/attackBoxManager.gd")
const SAORISE_ATTACK_STATE_SCRIPT := preload("res://scripts/characters/saorise/state_machine/attackState.gd")
const BANSHEE_ATTACK_BOX_MANAGER_SCRIPT := preload("res://scripts/characters/hostile_npcs/banshees/combat/bansheeAttackBoxManager.gd")
const TOP_DOWN_MOVEMENT_SCRIPT := preload("res://scripts/characters/shared/movement/TopDownMovement.gd")
const DEFAULT_CHARACTER_NAVIGATION_LAYER := CHARACTER_NAVIGATION_SETTINGS.DEFAULT_CHARACTER_NAVIGATION_LAYER
const CAMPFIRE_BASE_KNIGHT_NAVIGATION_LAYER := CHARACTER_NAVIGATION_SETTINGS.CAMPFIRE_BASE_KNIGHT_NAVIGATION_LAYER


class MockPlayer:
	extends CharacterBody2D

	signal transformation_state_changed(active: bool)

	var form_id: StringName = &"human"
	var transforming_forms: bool = false

	func _ready():
		add_to_group("player")
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)

	func get_current_form_id() -> StringName:
		return form_id

	func is_transforming_forms() -> bool:
		return transforming_forms

	func is_life_respawn_pending() -> bool:
		return false


func run(assertions: TestAssertions, tree: SceneTree, _save_manager: Node):
	await assert_knight_scene_contracts(assertions, tree)
	await assert_top_down_movement_helper_contract(assertions, tree)
	assert_tree_trunk_tile_collision_contract(assertions)
	await assert_projectile_spawn_marker_contracts(assertions, tree)
	await assert_melee_knight_animation_contract(assertions, tree)
	await assert_saorise_frame_sliced_attack_contract(assertions, tree)
	await assert_saorise_incoming_damage_parity(assertions, tree)
	await assert_shared_attack_box_shape_convention(assertions, tree)
	await assert_knight_player_combat_contract(assertions, tree)
	await assert_campfire_component_scene_contracts(assertions, tree)
	await assert_campfire_layout_contracts(assertions, tree)
	await assert_campfire_variant_roster_contracts(assertions, tree)
	await assert_campfire_layout_reload_contract(assertions, tree)
	await assert_campfire_roster_y_sort_promotion(assertions, tree)
	await assert_campfire_wolf_damage_contract(assertions, tree)
	await assert_knight_home_default_and_aggro_contract(assertions, tree)
	await assert_knight_transform_aggro_contract(assertions, tree)
	await assert_knight_runtime_stabilization_contract(assertions, tree)
	await assert_knight_damage_knockback_facing_lock(assertions, tree)
	await assert_knight_camp_encounter_helper(assertions, tree)
	await assert_knight_camp_level_support(assertions, tree)
	await assert_split_knight_navigation_support(assertions, tree)
	await assert_multi_camp_identity_isolation(assertions, tree)
	await assert_starting_wilderness_campfire_identity_and_indexes(assertions, tree)
	await assert_knight_camp_navigation_switching(assertions, tree)
	await assert_starting_wilderness_knight_camp_wiring(assertions, tree)
	await assert_weeping_woods_knight_camp_wiring(assertions, tree)
	await assert_banshee_village_knight_camp_support_is_available(assertions, tree)
	await assert_level_navigation_authoring_contracts(assertions, tree)


func assert_knight_scene_contracts(assertions: TestAssertions, tree: SceneTree):
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	var ranged := await instantiate_scene(assertions, tree, RANGED_SCENE)
	var projectile := await instantiate_scene(assertions, tree, PROJECTILE_SCENE)
	var tent := await instantiate_scene(assertions, tree, CAMPFIRE_TENT_SCENE)
	var flipped_tent := await instantiate_scene(assertions, tree, CAMPFIRE_TENT_FLIPPED_SCENE)

	assert_knight_contract(assertions, melee, "Melee knight")
	assert_knight_contract(assertions, ranged, "Ranged knight")
	assertions.assert_true(projectile != null, "Knight arrow projectile should instantiate.")
	assertions.assert_true(tent != null, "Campfire base tent should instantiate.")
	assertions.assert_true(flipped_tent != null, "Flipped campfire base tent should instantiate.")
	assertions.assert_true(tent != null and tent.get_node_or_null("Effects") is EffectList, "Campfire base tent should have an Effects node.")
	assertions.assert_true(flipped_tent != null and flipped_tent.get_node_or_null("Effects") is EffectList, "Flipped campfire base tent should have an Effects node.")
	if flipped_tent != null:
		var flipped_sprite := flipped_tent.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		assertions.assert_true(flipped_sprite != null and str(flipped_sprite.animation) == "alive_flipped", "Flipped campfire base tent should prefer alive_flipped on ready.")

	if melee != null and ranged != null:
		var melee_tuning: Resource = melee.get("tuning") as Resource
		var ranged_tuning: Resource = ranged.get("tuning") as Resource
		assertions.assert_true(melee_tuning != null, "Melee knight should have tuning.")
		assertions.assert_true(ranged_tuning != null, "Ranged knight should have tuning.")
		if melee_tuning != null and ranged_tuning != null:
			assertions.assert_ne(melee_tuning.resource_path, ranged_tuning.resource_path, "Melee and ranged knights should use separate tuning resources.")
			assertions.assert_ne(melee_tuning.max_health, ranged_tuning.max_health, "Melee and ranged health should be independently tunable.")
			assertions.assert_ne(melee_tuning.attack_range, ranged_tuning.attack_range, "Melee and ranged attack range should be independently tunable.")
			assertions.assert_eq(float(melee_tuning.block_stun_duration), 1.0, "Melee knight block stun duration should default to banshee timing.")
			assertions.assert_eq(float(ranged_tuning.block_stun_duration), 1.0, "Ranged knight block stun duration should default to banshee timing.")
			assertions.assert_eq(float(melee_tuning.block_stun_move_speed_modifier), 0.15, "Melee knight block stun movement modifier should default to banshee timing.")
			assertions.assert_eq(float(ranged_tuning.block_stun_move_speed_modifier), 0.15, "Ranged knight block stun movement modifier should default to banshee timing.")
			assertions.assert_true(bool(melee_tuning.damage_knockback_enabled), "Melee knight damage knockback should be tunable and enabled by default.")
			assertions.assert_true(bool(ranged_tuning.damage_knockback_enabled), "Ranged knight damage knockback should be tunable and enabled by default.")
			assertions.assert_ne(float(melee_tuning.damage_knockback_distance), float(ranged_tuning.damage_knockback_distance), "Melee and ranged knights should be able to use different knockback distances.")
			assertions.assert_ne(float(melee_tuning.damage_knockback_duration), float(ranged_tuning.damage_knockback_duration), "Melee and ranged knights should be able to use different knockback durations.")
			assertions.assert_true(ranged_tuning.projectile_scene != null, "Ranged tuning should point to the arrow projectile scene.")

	if melee != null:
		assertions.assert_eq((melee as CharacterBody2D).motion_mode, CharacterBody2D.MOTION_MODE_FLOATING, "Basic Melee Knight should use floating/top-down CharacterBody2D motion.")
		assertions.assert_eq((melee as CharacterBody2D).max_slides, 8, "Basic Melee Knight should allow extra slide resolution around camp corners.")
		assertions.assert_eq((melee as CharacterBody2D).wall_min_slide_angle, 0.0, "Basic Melee Knight should allow top-down wall sliding on shallow contacts.")
		assertions.assert_true(absf((melee as CharacterBody2D).safe_margin - 0.04) <= 0.0001, "Basic Melee Knight should use a small safe margin for top-down static collision seams.")
		var movement_box := melee.get_node_or_null("MovementBox") as CollisionShape2D
		var navigation_agent := melee.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
		assertions.assert_true(movement_box != null, "Basic Melee Knight should have an authored MovementBox for collision footprint tuning.")
		if movement_box != null:
			assertions.assert_eq(movement_box.position, Vector2(0, -2), "Basic Melee Knight MovementBox should use the compact anti-corner position.")
			assertions.assert_eq(movement_box.rotation, 0.0, "Basic Melee Knight MovementBox should not rotate a circular top-down footprint.")
			assertions.assert_eq(movement_box.scale, Vector2.ONE, "Basic Melee Knight MovementBox should keep its circular footprint unscaled.")
			assertions.assert_true(movement_box.shape is CircleShape2D, "Basic Melee Knight MovementBox should use a circular top-down footprint.")
			if movement_box.shape is CircleShape2D:
				assertions.assert_eq((movement_box.shape as CircleShape2D).radius, 7.0, "Basic Melee Knight circular movement footprint should use the chosen radius.")
		assertions.assert_true(navigation_agent != null, "Basic Melee Knight should have NavigationAgent2D for path tolerance tuning.")
		if navigation_agent != null:
			assertions.assert_eq(navigation_agent.path_desired_distance, 8.0, "Basic Melee Knight should use circular-footprint path tolerance.")
			assertions.assert_eq(navigation_agent.target_desired_distance, 10.0, "Basic Melee Knight should use circular-footprint target tolerance.")
			assertions.assert_eq(navigation_agent.path_max_distance, 32.0, "Basic Melee Knight should repath after being pushed too far from its current navigation path.")
		var patrol_root := Node2D.new()
		patrol_root.name = "TestPatrolRoute"
		var patrol_stop_a := Marker2D.new()
		patrol_stop_a.name = "StopA"
		patrol_stop_a.position = Vector2.ZERO
		var patrol_stop_b := Marker2D.new()
		patrol_stop_b.name = "StopB"
		patrol_stop_b.position = Vector2(96, 0)
		patrol_root.add_child(patrol_stop_a)
		patrol_root.add_child(patrol_stop_b)
		melee.add_child(patrol_root)
		melee.set("patrol_path", NodePath("TestPatrolRoute"))
		melee.call("refresh_patrol_points")
		assertions.assert_true(bool(melee.call("has_patrol_route")), "Non-camp patrol knights should be able to load a scene-authored patrol path.")
		assertions.assert_eq(melee.call("get_default_state"), "patrol", "A non-camp knight with a patrol route should default to patrol, not camp behavior.")
		assertions.assert_false(bool(melee.call("is_camp_linked")), "A patrol knight should not need a campfire_base_path.")

	if ranged != null:
		assertions.assert_eq((ranged as CharacterBody2D).motion_mode, CharacterBody2D.MOTION_MODE_FLOATING, "Basic Ranged Knight should use floating/top-down CharacterBody2D motion.")
		assertions.assert_eq((ranged as CharacterBody2D).max_slides, 8, "Basic Ranged Knight should allow extra slide resolution around camp corners.")
		assertions.assert_eq((ranged as CharacterBody2D).wall_min_slide_angle, 0.0, "Basic Ranged Knight should allow top-down wall sliding on shallow contacts.")
		assertions.assert_true(absf((ranged as CharacterBody2D).safe_margin - 0.04) <= 0.0001, "Basic Ranged Knight should use a small safe margin for top-down static collision seams.")
		var ranged_movement_box := ranged.get_node_or_null("MovementBox") as CollisionShape2D
		assertions.assert_true(ranged_movement_box != null and ranged_movement_box.shape is CircleShape2D, "Basic Ranged Knight MovementBox should use a circular top-down footprint.")
		if ranged_movement_box != null and ranged_movement_box.shape is CircleShape2D:
			assertions.assert_eq((ranged_movement_box.shape as CircleShape2D).radius, 7.0, "Basic Ranged Knight circular movement footprint should use the chosen radius.")

	var saorise := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	if saorise != null:
		assertions.assert_eq((saorise as CharacterBody2D).motion_mode, CharacterBody2D.MOTION_MODE_FLOATING, "Saorise should use floating/top-down CharacterBody2D motion for consistent wall sliding.")
		assertions.assert_eq((saorise as CharacterBody2D).max_slides, 8, "Saorise should allow extra slide resolution along angled world collisions.")
		assertions.assert_eq((saorise as CharacterBody2D).wall_min_slide_angle, 0.0, "Saorise should allow top-down wall sliding on shallow contacts.")
		assertions.assert_true(absf((saorise as CharacterBody2D).safe_margin - 0.04) <= 0.0001, "Saorise should use a small safe margin for top-down static collision seams.")
		var saorise_movement_box := saorise.get_node_or_null("MovementBox") as CollisionShape2D
		assertions.assert_true(saorise_movement_box != null and saorise_movement_box.shape is CircleShape2D, "Saorise should use a circular movement footprint after form activation.")
		if saorise_movement_box != null and saorise_movement_box.shape is CircleShape2D:
			assertions.assert_eq((saorise_movement_box.shape as CircleShape2D).radius, 6.0, "Human Saorise circular movement footprint should use the chosen radius.")
		saorise.queue_free()

	var human_form: Resource = load(SAORISE_HUMAN_FORM)
	var wolf_form: Resource = load(SAORISE_WOLF_FORM)
	assertions.assert_true(human_form != null and human_form.get("movement_shape") is CircleShape2D, "Human form movement shape should be a circular top-down footprint.")
	if human_form != null and human_form.get("movement_shape") is CircleShape2D:
		assertions.assert_eq((human_form.get("movement_shape") as CircleShape2D).radius, 6.0, "Human form movement footprint should use the chosen radius.")
		assertions.assert_eq(float(human_form.get("movement_shape_rotation")), 0.0, "Human form circular movement footprint should not be rotated.")
	assertions.assert_true(wolf_form != null and wolf_form.get("movement_shape") is CircleShape2D, "Wolf form movement shape should be a circular top-down footprint.")
	if wolf_form != null and wolf_form.get("movement_shape") is CircleShape2D:
		assertions.assert_eq((wolf_form.get("movement_shape") as CircleShape2D).radius, 7.0, "Wolf form movement footprint should use the chosen radius.")
		assertions.assert_eq(float(wolf_form.get("movement_shape_rotation")), 0.0, "Wolf form circular movement footprint should not be rotated.")

	for node in [melee, ranged, projectile, tent, flipped_tent]:
		if node != null:
			node.queue_free()
	await tree.process_frame


func assert_top_down_movement_helper_contract(assertions: TestAssertions, tree: SceneTree):
	var helper := TOP_DOWN_MOVEMENT_SCRIPT
	assertions.assert_eq(helper.get_tangent_velocity_for_normal(Vector2(80, 0), Vector2(0, -1)), Vector2(80, 0), "Top-down helper should preserve motion along a flat horizontal blocker.")
	assertions.assert_eq(helper.get_tangent_velocity_for_normal(Vector2(80, 0), Vector2(-1, 0)), Vector2.ZERO, "Top-down helper should stop motion directly into a wall normal.")

	var static_body := StaticBody2D.new()
	var actor_body := CharacterBody2D.new()
	tree.root.add_child(static_body)
	tree.root.add_child(actor_body)
	assertions.assert_true(helper.is_static_world_collider(static_body), "Top-down helper should treat StaticBody2D blockers as static world colliders.")
	assertions.assert_false(helper.is_static_world_collider(actor_body), "Top-down helper should not treat actor bodies as static world colliders for seam recovery.")
	assertions.assert_eq(helper.get_preferred_static_edge_velocity(null, Vector2(80, 0), 0.016), Vector2(80, 0), "Top-down helper should fall back to requested velocity when no body is supplied.")
	static_body.queue_free()
	actor_body.queue_free()
	await tree.process_frame


func assert_tree_trunk_tile_collision_contract(assertions: TestAssertions):
	var file := FileAccess.open("res://resources/terrain/GroundTileSet.tres", FileAccess.READ)
	assertions.assert_true(file != null, "GroundTileSet should be readable for tree-trunk collision contract checks.")
	if file == null:
		return

	var contents := file.get_as_text()
	file.close()
	assertions.assert_true(contents.contains("2:28/0/physics_layer_0/polygon_0/points = PackedVector2Array(8, -16, 16, -16, 16, 16, 8, 16)"), "Right tree-trunk collision edge should be flat and aligned.")
	assertions.assert_true(contents.contains("0:28/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -16, -8, 16, -16, 16, -16, -16)"), "Left tree-trunk collision edge should be flat and aligned.")
	assertions.assert_false(contents.contains("8.66206, -16"), "Tree-trunk collision should not keep seam-prone sub-pixel top edge points.")
	assertions.assert_false(contents.contains("9.01561"), "Tree-trunk collision should not keep seam-prone sub-pixel horizontal edge points.")


func assert_projectile_spawn_marker_contracts(assertions: TestAssertions, tree: SceneTree):
	var banshee := await instantiate_scene(assertions, tree, BANSHEE_SCENE)
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	var ranged := await instantiate_scene(assertions, tree, RANGED_SCENE)

	if banshee != null:
		assertions.assert_true(banshee.get_node_or_null("ProjectileSpawn") is Marker2D, "Banshee should expose an editable ProjectileSpawn marker.")
		banshee.global_position = Vector2(100, 200)
		banshee.set("facing_left", false)
		assertions.assert_eq(banshee.call("get_ranged_projectile_spawn_position", Vector2.RIGHT), Vector2(124, 180), "Banshee right-facing projectile spawn should use the marker offset.")
		banshee.set("facing_left", true)
		assertions.assert_eq(banshee.call("get_ranged_projectile_spawn_position", Vector2.LEFT), Vector2(76, 180), "Banshee left-facing projectile spawn should mirror the marker offset.")

	if melee != null:
		var melee_tuning: Resource = melee.get("tuning") as Resource
		assertions.assert_false(melee.has_node("ProjectileSpawn"), "Melee knight should not carry a projectile-only spawn marker.")
		if melee_tuning != null:
			assertions.assert_true(melee_tuning.projectile_scene == null, "Melee knight tuning should not define a projectile scene.")
		assertions.assert_false(bool(melee.call("should_launch_projectile")), "Melee knight should not launch projectiles.")

	if ranged != null:
		var ranged_tuning: Resource = ranged.get("tuning") as Resource
		assertions.assert_true(ranged.get_node_or_null("ProjectileSpawn") is Marker2D, "Ranged knight should expose an editable ProjectileSpawn marker.")
		if ranged_tuning != null:
			assertions.assert_true(ranged_tuning.projectile_scene != null, "Ranged knight tuning should define a projectile scene.")
		assertions.assert_true(bool(ranged.call("should_launch_projectile")), "Ranged knight should launch projectiles when its marker and projectile scene are present.")

	for node in [banshee, melee, ranged]:
		if node != null:
			node.queue_free()
	await tree.process_frame


func assert_melee_knight_animation_contract(assertions: TestAssertions, tree: SceneTree):
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	assertions.assert_true(melee != null, "Melee knight should instantiate for animation contract.")
	if melee == null:
		return

	var sprite := melee.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assertions.assert_true(sprite != null, "Melee knight should have an AnimatedSprite2D.")
	if sprite == null or sprite.sprite_frames == null:
		melee.queue_free()
		await tree.process_frame
		return

	var frames := sprite.sprite_frames
	var looping_animations := ["idle", "idle_up", "walk", "walk_down", "walk_up", "run", "run_down", "run_up"]
	var non_looping_animations := ["attack", "attack_down", "attack_up", "hurt", "death"]

	for animation_name in looping_animations:
		assertions.assert_true(frames.has_animation(animation_name), "Melee knight should have %s animation." % animation_name)
		if frames.has_animation(animation_name):
			assertions.assert_true(frames.get_animation_loop(animation_name) == true, "%s should loop." % animation_name)

	for animation_name in non_looping_animations:
		assertions.assert_true(frames.has_animation(animation_name), "Melee knight should have %s animation." % animation_name)
		if frames.has_animation(animation_name):
			assertions.assert_false(frames.get_animation_loop(animation_name) == true, "%s should not loop." % animation_name)

	assert_directional_animation(assertions, melee, "right", "attack", false, "Right attack")
	assert_directional_animation(assertions, melee, "left", "attack", true, "Left attack")
	assert_directional_animation(assertions, melee, "up", "attack_up", false, "Up attack")
	assert_directional_animation(assertions, melee, "down", "attack_down", false, "Down attack")
	assert_directional_animation(assertions, melee, "up", "idle_up", false, "Up idle", "idle")
	assert_directional_animation(assertions, melee, "down", "idle", false, "Down idle", "idle")

	assert_attack_timing(assertions, melee, "right", "attack")
	assert_attack_timing(assertions, melee, "up", "attack_up")
	assert_attack_timing(assertions, melee, "down", "attack_down")

	melee.queue_free()
	await tree.process_frame


func assert_saorise_frame_sliced_attack_contract(assertions: TestAssertions, tree: SceneTree):
	var saorise := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	assertions.assert_true(saorise != null, "Saorise should instantiate for frame-sliced attack contract.")
	if saorise == null:
		return

	var sprite := saorise.get("sprite") as AnimatedSprite2D
	assertions.assert_true(sprite != null and sprite.sprite_frames != null, "Saorise should expose human SpriteFrames for frame-sliced attack checks.")
	if sprite == null or sprite.sprite_frames == null:
		saorise.queue_free()
		await tree.process_frame
		return

	var frames := sprite.sprite_frames
	for animation_name in ["unarmed_attack", "unarmed_attack_up", "unarmed_attack_down"]:
		assertions.assert_true(frames.has_animation(animation_name), "Saorise should have %s animation." % animation_name)
		if frames.has_animation(animation_name):
			assertions.assert_true(frames.get_frame_count(animation_name) >= 16, "%s should include all three combo slices." % animation_name)
			assertions.assert_false(frames.get_animation_loop(animation_name), "%s should not loop." % animation_name)

	for old_animation_name in ["unarmed_attack_1", "unarmed_attack_2", "unarmed_attack_3", "unarmed_attack_up1", "unarmed_attack_up2", "unarmed_attack_up3", "unarmed_attack_down1", "unarmed_attack_down2", "unarmed_attack_down3"]:
		assertions.assert_false(frames.has_animation(old_animation_name), "Saorise should not require old split combo animation %s." % old_animation_name)

	var attack_state = SAORISE_ATTACK_STATE_SCRIPT.new()
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 1, "right", "unarmed_attack", 0, false)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 2, "right", "unarmed_attack", 6, false)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 3, "right", "unarmed_attack", 11, false)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 1, "left", "unarmed_attack", 0, true)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 2, "up", "unarmed_attack_up", 6, false)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 3, "down", "unarmed_attack_down", 11, false)
	assert_frame_sliced_attack_duration(assertions, attack_state, saorise, 1, "unarmed_attack", 6)
	assert_frame_sliced_attack_duration(assertions, attack_state, saorise, 2, "unarmed_attack", 5)
	assert_frame_sliced_attack_duration(assertions, attack_state, saorise, 3, "unarmed_attack", 5)

	attack_state.combo_part = 2
	attack_state.attack_direction = "right"
	attack_state.play_attack_animation(saorise)
	sprite.set_frame_and_progress(7, 0.25)
	attack_state.animation_duration = attack_state.get_attack_slice_duration(saorise, "unarmed_attack", 2)
	attack_state.attack_timer = attack_state.animation_duration * 0.5
	attack_state.attack_direction = "up"
	attack_state.transition_attack_animation(saorise)
	assertions.assert_eq(str(sprite.animation), "unarmed_attack_up", "Direction switching should use the target directional sliced animation.")
	assertions.assert_eq(sprite.frame, 7, "Direction switching should preserve progress inside the current combo slice.")
	assertions.assert_true(absf(sprite.frame_progress - 0.0) <= 0.0001, "Direction switching should seek to a stable sliced attack frame.")

	attack_state.combo_part = 2
	attack_state.attack_direction = "right"
	attack_state.play_attack_animation(saorise)
	sprite.set_frame_and_progress(11, 0.0)
	attack_state.maintain_attack_slice_frame(saorise)
	assertions.assert_eq(sprite.frame, 10, "Sliced attack playback should clamp at the active combo part end frame.")

	var wolf_form_changed: bool = bool(saorise.call("set_form", &"wolf"))
	assertions.assert_true(wolf_form_changed, "Saorise should switch to wolf form for frame-sliced wolf attack checks.")
	await tree.process_frame
	frames = sprite.sprite_frames
	for animation_name in ["attack", "attack_up", "attack_down"]:
		assertions.assert_true(frames.has_animation(animation_name), "Wolf Saorise should have %s animation." % animation_name)
		if frames.has_animation(animation_name):
			assertions.assert_true(frames.get_frame_count(animation_name) >= 16, "%s should include all three wolf combo slices." % animation_name)
			assertions.assert_false(frames.get_animation_loop(animation_name), "%s should not loop." % animation_name)

	for old_wolf_animation_name in ["attack_1", "attack_2", "attack_3", "attack_up1", "attack_up2", "attack_up3", "attack_down1", "attack_down2", "attack_down3"]:
		assertions.assert_false(frames.has_animation(old_wolf_animation_name), "Wolf Saorise should not require old split combo animation %s." % old_wolf_animation_name)

	attack_state.combo_part = 0
	attack_state.attack_direction = "right"
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 1, "right", "attack", 0, false)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 2, "right", "attack", 6, false)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 3, "right", "attack", 11, false)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 1, "left", "attack", 0, true)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 2, "up", "attack_up", 6, false)
	assert_frame_sliced_attack_part(assertions, attack_state, saorise, 3, "down", "attack_down", 11, false)
	assert_frame_sliced_attack_duration(assertions, attack_state, saorise, 1, "attack", 6)
	assert_frame_sliced_attack_duration(assertions, attack_state, saorise, 2, "attack", 5)
	assert_frame_sliced_attack_duration(assertions, attack_state, saorise, 3, "attack", 5)

	saorise.queue_free()
	await tree.process_frame


func assert_saorise_incoming_damage_parity(assertions: TestAssertions, tree: SceneTree):
	var saorise := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	assertions.assert_true(saorise != null, "Saorise should instantiate for incoming damage parity checks.")
	if saorise == null:
		return

	var health: Node = saorise.get_node_or_null("Health")
	assertions.assert_true(health != null, "Saorise should expose Health for incoming damage parity checks.")
	if health == null:
		saorise.queue_free()
		await tree.process_frame
		return

	var max_health: int = int(health.get("max_health"))
	var expected_damage: int = int(ceil(float(max_health) / float(max(int(health.get("hits_to_die")), 1))))

	saorise.call("set_form", &"human")
	health.set("health", max_health)
	health.set("dead", false)
	health.set("invulnerable", false)
	saorise.call("take_damage", 1, false, null)
	var human_health_after_hit: int = int(health.get("health"))

	saorise.call("set_form", &"wolf")
	health.set("health", max_health)
	health.set("dead", false)
	health.set("invulnerable", false)
	saorise.call("take_damage", 1, false, null)
	var wolf_health_after_hit: int = int(health.get("health"))

	assertions.assert_eq(human_health_after_hit, max_health - expected_damage, "Human form should take the standard incoming hit damage.")
	assertions.assert_eq(wolf_health_after_hit, human_health_after_hit, "Wolf form should take the same incoming hit damage as human form.")

	saorise.queue_free()
	await tree.process_frame


func assert_frame_sliced_attack_part(assertions: TestAssertions, attack_state: Object, saorise: Node, combo_part: int, direction: String, expected_animation: String, expected_frame: int, expected_flip_h: bool):
	attack_state.combo_part = combo_part
	attack_state.attack_direction = direction
	var duration: float = attack_state.play_attack_animation(saorise)
	var sprite := saorise.get("sprite") as AnimatedSprite2D
	assertions.assert_eq(str(sprite.animation), expected_animation, "Combo part %d %s attack should use %s." % [combo_part, direction, expected_animation])
	assertions.assert_eq(sprite.frame, expected_frame, "Combo part %d %s attack should start at the authored slice frame." % [combo_part, direction])
	assertions.assert_eq(sprite.flip_h, expected_flip_h, "Combo part %d %s attack should use the expected horizontal flip." % [combo_part, direction])
	assertions.assert_true(duration > 0.0, "Combo part %d %s attack should have a positive sliced duration." % [combo_part, direction])


func assert_frame_sliced_attack_duration(assertions: TestAssertions, attack_state: Object, saorise: Node, combo_part: int, animation_name: String, expected_frame_count: int):
	var sprite := saorise.get("sprite") as AnimatedSprite2D
	var sprite_frames := sprite.sprite_frames if sprite != null else null
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		assertions.assert_true(false, "Saorise should have %s for sliced duration checks." % animation_name)
		return

	var animation_speed: float = sprite_frames.get_animation_speed(animation_name)
	var expected_duration: float = float(expected_frame_count) / animation_speed
	var actual_duration: float = attack_state.get_attack_slice_duration(saorise, animation_name, combo_part)
	assertions.assert_true(absf(actual_duration - expected_duration) <= 0.0001, "Combo part %d should use %d sliced frames." % [combo_part, expected_frame_count])


func assert_shared_attack_box_shape_convention(assertions: TestAssertions, tree: SceneTree):
	await assert_scene_authored_attackbox_profile_contract(assertions, tree)
	assert_saorise_attack_box_shape_convention(assertions)
	assert_banshee_attack_box_shape_convention(assertions)
	await assert_knight_attack_box_shape_convention(assertions, tree)


func assert_scene_authored_attackbox_profile_contract(assertions: TestAssertions, tree: SceneTree):
	var saorise := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	var ranged := await instantiate_scene(assertions, tree, RANGED_SCENE)
	var banshee := await instantiate_scene(assertions, tree, BANSHEE_SCENE)
	var banshee_projectile := await instantiate_scene(assertions, tree, "res://scenes/characters/hostile_npcs/banshees/banshee_projectile.tscn")
	var knight_projectile := await instantiate_scene(assertions, tree, PROJECTILE_SCENE)

	assert_attackbox_profile_node(assertions, saorise, "Saorise", [&"human", &"wolf"], [&"right", &"up", &"down"], 3)
	assert_attackbox_profile_node(assertions, melee, "Melee knight", [&"default"], [&"right", &"up", &"down"], 1)
	assert_attackbox_profile_node(assertions, ranged, "Ranged knight", [&"default"], [&"right", &"up", &"down"], 1)
	assert_attackbox_profile_node(assertions, banshee, "Banshee", [&"default"], [&"right", &"up", &"down"], 2)
	assert_attackbox_profile_node(assertions, banshee_projectile, "Banshee projectile", [&"default"], [&"default"], 1)
	assert_attackbox_profile_node(assertions, knight_projectile, "Knight arrow projectile", [&"default"], [&"default"], 1)

	var profile_node := get_attackbox_profile_node(saorise)
	if profile_node != null:
		var right_profile: Dictionary = profile_node.get_profile(&"human", &"right", 2)
		var left_profile: Dictionary = profile_node.get_profile(&"human", &"left", 2)
		assertions.assert_eq(left_profile.get("position"), Vector2(-20, -32), "Saorise left attack profile should mirror the authored right profile.")
		assertions.assert_eq(right_profile.get("size"), left_profile.get("size"), "Mirrored left/right attack profiles should preserve size.")
		assert_saorise_attackbox_profile_data_is_clean(assertions, profile_node)
		assert_saorise_runtime_attackbox_profiles_match_authored(assertions, saorise, profile_node)
		assert_attackbox_profile_edit_persistence(assertions, profile_node)

	free_nodes([saorise, melee, ranged, banshee, banshee_projectile, knight_projectile])
	await tree.process_frame


func assert_attackbox_profile_edit_persistence(assertions: TestAssertions, profile_node: AttackHitboxProfileAuthoring):
	assert_attackbox_profile_selection_persists(
		assertions,
		profile_node,
		&"wolf",
		&"right",
		2,
		Vector2(83, 29),
		Vector2(41, -18),
		"Wolf right combo part 2"
	)
	assert_attackbox_profile_selection_persists(
		assertions,
		profile_node,
		&"wolf",
		&"up",
		2,
		Vector2(47, 31),
		Vector2(2, -61),
		"Wolf up combo part 2"
	)
	assert_attackbox_profile_selection_persists(
		assertions,
		profile_node,
		&"wolf",
		&"down",
		3,
		Vector2(51, 35),
		Vector2(-3, -6),
		"Wolf down combo part 3"
	)
	assert_attackbox_profile_selection_persists(
		assertions,
		profile_node,
		&"human",
		&"right",
		2,
		Vector2(61, 27),
		Vector2(24, -35),
		"Human right combo part 2"
	)
	assert_attackbox_profile_selection_persists(
		assertions,
		profile_node,
		&"wolf",
		&"",
		2,
		Vector2(73, 24),
		Vector2(36, -24),
		"Blank direction wolf combo part 2"
	)

	var wolf_profiles: Dictionary = profile_node.get_context_profiles(&"wolf")
	assertions.assert_false(wolf_profiles.has(""), "Blank selected direction should normalize to right instead of creating wolf/blank direction profile data.")
	assertions.assert_eq(profile_node.get_exact_profile(&"wolf", &"right", 2).get("size"), Vector2(73, 24), "Blank direction edits should persist into wolf/right combo part 2.")
	assert_saorise_attackbox_rejects_profile_scale(assertions, profile_node)
	assert_invalid_attackbox_profile_selection_does_not_create_partial_keys(assertions, profile_node)


func assert_attackbox_profile_selection_persists(assertions: TestAssertions, profile_node: AttackHitboxProfileAuthoring, context: StringName, direction: StringName, combo_part: int, edited_size: Vector2, edited_position: Vector2, label: String):
	profile_node.selected_context = context
	profile_node.selected_direction = direction
	profile_node.selected_combo_part = combo_part
	profile_node.apply_selected_profile_to_shape()

	var collision_shape: CollisionShape2D = profile_node.get_collision_shape()
	assertions.assert_true(collision_shape != null and collision_shape.shape is RectangleShape2D, "Saorise profile authoring should expose an editable rectangle for %s persistence checks." % label)
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return

	(collision_shape.shape as RectangleShape2D).size = edited_size
	collision_shape.position = edited_position
	profile_node.commit_visible_shape_to_last_profile()

	profile_node.selected_combo_part = 1 if combo_part != 1 else 3
	profile_node.apply_selected_profile_to_shape()
	profile_node.selected_combo_part = combo_part
	profile_node.apply_selected_profile_to_shape()

	var stored_profile: Dictionary = profile_node.get_exact_profile(context, direction, combo_part)
	assertions.assert_eq(stored_profile.get("size"), edited_size, "%s attackbox edits should persist when changing preview selections." % label)
	assertions.assert_eq(stored_profile.get("position"), edited_position, "%s attackbox position edits should persist when changing preview selections." % label)
	assertions.assert_eq(stored_profile.get("scale"), Vector2.ONE, "%s attackbox edits should keep Saorise profile scale unit-sized." % label)


func assert_saorise_attackbox_rejects_profile_scale(assertions: TestAssertions, profile_node: AttackHitboxProfileAuthoring):
	profile_node.selected_context = &"wolf"
	profile_node.selected_direction = &"right"
	profile_node.selected_combo_part = 2
	profile_node.apply_selected_profile_to_shape()

	var collision_shape: CollisionShape2D = profile_node.get_collision_shape()
	assertions.assert_true(collision_shape != null and collision_shape.shape is RectangleShape2D, "Saorise scale normalization should have an editable rectangle.")
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return

	(collision_shape.shape as RectangleShape2D).size = Vector2(24, 13)
	collision_shape.position = Vector2(18, -23)
	collision_shape.scale = Vector2(2, 3)
	profile_node.write_selected_profile(profile_node.read_profile_from_shape())

	var stored_profile: Dictionary = profile_node.get_exact_profile(&"wolf", &"right", 2)
	assertions.assert_eq(stored_profile.get("size"), Vector2(24, 13), "Saorise should store the visible rectangle size without baking collision shape scale.")
	assertions.assert_eq(stored_profile.get("position"), Vector2(18, -23), "Saorise should still store the edited profile position.")
	assertions.assert_eq(stored_profile.get("scale"), Vector2.ONE, "Saorise should reject non-unit attackbox profile scale.")
	assertions.assert_eq(collision_shape.scale, Vector2.ONE, "Saorise editor attackbox scale should snap back to unit scale.")


func assert_saorise_attackbox_profile_data_is_clean(assertions: TestAssertions, profile_node: AttackHitboxProfileAuthoring):
	var profile_data: Dictionary = profile_node.profiles
	assertions.assert_true(bool(profile_node.get("force_unit_collision_shape_scale")), "Saorise attackbox profiles should force unit scale so editor rectangle size is the runtime hitbox size.")
	assertions.assert_false(bool(profile_node.get("normalize_rectangle_scale_into_size")), "Saorise attackbox profiles should not bake collision shape scale into rectangle size.")
	for invalid_context in ["", "h", "hu", "hum", "huma", "w", "wo", "wol"]:
		assertions.assert_false(profile_data.has(invalid_context), "Saorise attackbox profiles should not keep accidental %s context data." % invalid_context)

	for context in [&"human", &"wolf"]:
		var context_profiles: Dictionary = profile_node.get_context_profiles(context)
		assertions.assert_false(context_profiles.has(""), "Saorise %s attackbox profiles should not keep blank direction data." % context)
		for invalid_direction in ["d", "do", "dow", "l", "le", "lef", "r", "ri", "rig", "righ", "u"]:
			assertions.assert_false(context_profiles.has(invalid_direction), "Saorise %s attackbox profiles should not keep accidental %s direction data." % [context, invalid_direction])
		for direction in [&"right", &"up", &"down"]:
			for combo_part in range(1, 4):
				var profile: Dictionary = profile_node.get_exact_profile(context, direction, combo_part)
				assertions.assert_false(profile.is_empty(), "Saorise should define exact profile %s/%s/%d." % [context, direction, combo_part])
				assertions.assert_eq(profile.get("scale"), Vector2.ONE, "Saorise %s/%s/%d profile scale should stay unit-sized." % [context, direction, combo_part])


func assert_invalid_attackbox_profile_selection_does_not_create_partial_keys(assertions: TestAssertions, profile_node: AttackHitboxProfileAuthoring):
	profile_node.selected_context = &"wolf"
	profile_node.selected_direction = &"rig"
	profile_node.selected_combo_part = 3
	profile_node.apply_selected_profile_to_shape()

	var collision_shape: CollisionShape2D = profile_node.get_collision_shape()
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		(collision_shape.shape as RectangleShape2D).size = Vector2(91, 37)
		collision_shape.position = Vector2(31, -33)
		profile_node.write_selected_profile(profile_node.read_profile_from_shape())

	var wolf_profiles: Dictionary = profile_node.get_context_profiles(&"wolf")
	assertions.assert_false(wolf_profiles.has("rig"), "Invalid partial direction should not create a wolf/rig profile.")

	profile_node.selected_context = &"wol"
	profile_node.selected_direction = &"right"
	profile_node.selected_combo_part = 3
	profile_node.apply_selected_profile_to_shape()
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		(collision_shape.shape as RectangleShape2D).size = Vector2(92, 38)
		profile_node.write_selected_profile(profile_node.read_profile_from_shape())
	assertions.assert_false(profile_node.profiles.has("wol"), "Invalid partial context should not create a wol profile.")


func assert_saorise_runtime_attackbox_profiles_match_authored(assertions: TestAssertions, saorise: Node, profile_node: AttackHitboxProfileAuthoring):
	var hitbox_manager: Object = saorise.get("hitbox_manager")
	var collision_shape: CollisionShape2D = profile_node.get_collision_shape()
	var attack_box: Area2D = saorise.get_node_or_null("AttackBox") as Area2D
	assertions.assert_true(attack_box != null, "Saorise should expose its AttackBox for runtime scale checks.")
	assertions.assert_true(hitbox_manager != null, "Saorise should expose its hitbox manager for runtime attackbox parity checks.")
	assertions.assert_true(collision_shape != null and collision_shape.shape is RectangleShape2D, "Saorise should expose a rectangle attack shape for runtime attackbox parity checks.")
	if hitbox_manager == null or collision_shape == null or not (collision_shape.shape is RectangleShape2D) or attack_box == null:
		return
	assertions.assert_eq(attack_box.scale, Vector2.ONE, "Saorise AttackBox should not be scaled by either form.")
	assertions.assert_eq(collision_shape.scale, Vector2.ONE, "Saorise AttackBox CollisionShape2D should start with unit scale.")

	for context in [&"human", &"wolf"]:
		saorise.call("set_form", context)
		assertions.assert_eq(attack_box.scale, Vector2.ONE, "Switching to %s should not scale Saorise AttackBox." % context)
		assertions.assert_eq(collision_shape.scale, Vector2.ONE, "Switching to %s should not scale Saorise AttackBox CollisionShape2D." % context)
		for direction in [&"right", &"up", &"down"]:
			for combo_part in range(1, 4):
				var expected_profile: Dictionary = profile_node.get_exact_profile(context, direction, combo_part)
				hitbox_manager.activate_attack_hitbox(combo_part, str(direction))
				var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
				var expected_size: Vector2 = expected_profile.get("size")
				var expected_scale: Vector2 = expected_profile.get("scale")
				assertions.assert_eq((collision_shape.shape as RectangleShape2D).size, expected_profile.get("size"), "Runtime %s/%s/%d attackbox size should match authored profile." % [context, direction, combo_part])
				assertions.assert_eq(collision_shape.position, expected_profile.get("position"), "Runtime %s/%s/%d attackbox position should match authored profile." % [context, direction, combo_part])
				assertions.assert_eq(collision_shape.rotation, expected_profile.get("rotation"), "Runtime %s/%s/%d attackbox rotation should match authored profile." % [context, direction, combo_part])
				assertions.assert_eq(collision_shape.scale, expected_profile.get("scale"), "Runtime %s/%s/%d attackbox scale should match authored profile." % [context, direction, combo_part])
				assertions.assert_eq(get_attackbox_effective_size(rectangle.size, collision_shape.scale), get_attackbox_effective_size(expected_size, expected_scale), "Runtime %s/%s/%d effective attackbox size should match authored profile exactly." % [context, direction, combo_part])
				assertions.assert_eq(get_attackbox_effective_size(rectangle.size, collision_shape.scale), expected_size, "Runtime %s/%s/%d effective attackbox size should equal the authored rectangle size." % [context, direction, combo_part])
				hitbox_manager.deactivate_attack_hitbox()

	saorise.call("set_form", &"wolf")
	var right_profile: Dictionary = profile_node.get_exact_profile(&"wolf", &"right", 2)
	var left_profile: Dictionary = profile_node.get_profile(&"wolf", &"left", 2)
	var right_position: Vector2 = right_profile.get("position")
	assertions.assert_eq(left_profile.get("size"), right_profile.get("size"), "Wolf left attackbox should mirror right size without separate left data.")
	assertions.assert_eq(left_profile.get("position"), Vector2(-right_position.x, right_position.y), "Wolf left attackbox should mirror right position without separate left data.")


func get_attackbox_effective_size(size: Vector2, scale: Vector2) -> Vector2:
	return Vector2(size.x * absf(scale.x), size.y * absf(scale.y))


func assert_attackbox_profile_node(assertions: TestAssertions, actor: Node, label: String, contexts: Array, directions: Array, combo_count: int):
	assertions.assert_true(actor != null, "%s should instantiate for attackbox profile checks." % label)
	if actor == null:
		return

	var profile_node := get_attackbox_profile_node(actor)
	assertions.assert_true(profile_node != null, "%s should have scene-authored AttackHitboxProfiles." % label)
	if profile_node == null:
		return

	var collision_shape: CollisionShape2D = profile_node.get_collision_shape()
	assertions.assert_true(collision_shape != null and collision_shape.shape is RectangleShape2D, "%s attackbox profile node should bind to an authored RectangleShape2D." % label)
	for context in contexts:
		for direction in directions:
			for combo_part in range(1, combo_count + 1):
				var profile: Dictionary = profile_node.get_profile(context, direction, combo_part)
				assertions.assert_false(profile.is_empty(), "%s should define profile %s/%s/%d." % [label, context, direction, combo_part])


func get_attackbox_profile_node(actor: Node) -> AttackHitboxProfileAuthoring:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is AttackHitboxProfileAuthoring:
			return child as AttackHitboxProfileAuthoring
	return null


func assert_saorise_attack_box_shape_convention(assertions: TestAssertions):
	var attack_box := Area2D.new()
	var collision_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 10)
	collision_shape.shape = shape
	collision_shape.position = Vector2(3, -4)
	attack_box.add_child(collision_shape)
	attack_box.position = Vector2(11, 12)

	var manager = SAORISE_ATTACK_BOX_MANAGER_SCRIPT.new()
	manager.attack_box = attack_box
	manager.setup()
	var base_area_position: Vector2 = attack_box.position
	var base_shape_position: Vector2 = collision_shape.position
	manager.activate_attack_hitbox(1, "right")

	assertions.assert_eq(attack_box.position, base_area_position, "Saorise AttackBox area should stay stable when applying attack profiles.")
	assertions.assert_ne(collision_shape.position, base_shape_position, "Saorise should move the child attack collision shape through profiles.")
	manager.deactivate_attack_hitbox()
	assertions.assert_eq(collision_shape.position, base_shape_position, "Saorise attack shape should restore to editor-authored position on deactivate.")

	attack_box.queue_free()


func assert_banshee_attack_box_shape_convention(assertions: TestAssertions):
	var attack_box := Area2D.new()
	var collision_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 10)
	collision_shape.shape = shape
	collision_shape.position = Vector2(18, -7)
	attack_box.add_child(collision_shape)
	attack_box.position = Vector2(5, 6)

	var manager = BANSHEE_ATTACK_BOX_MANAGER_SCRIPT.new()
	manager.attack_box = attack_box
	manager.setup()
	var base_area_position: Vector2 = attack_box.position
	var base_shape_position: Vector2 = collision_shape.position
	manager.activate_attack_hitbox(1, true)

	assertions.assert_eq(attack_box.position, base_area_position, "Banshee AttackBox area should stay stable when facing changes.")
	assertions.assert_eq(collision_shape.position, Vector2(-abs(base_shape_position.x), base_shape_position.y), "Banshee should flip the child attack collision shape left.")
	manager.deactivate_attack_hitbox()
	assertions.assert_eq(collision_shape.position, base_shape_position, "Banshee attack shape should restore to editor-authored position on deactivate.")

	attack_box.queue_free()


func assert_knight_attack_box_shape_convention(assertions: TestAssertions, tree: SceneTree):
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	assertions.assert_true(melee != null, "Melee knight should instantiate for attack-box convention.")
	if melee == null:
		return

	var attack_box := melee.get_node_or_null("AttackBox") as Area2D
	var collision_shape := melee.get_node_or_null("AttackBox/CollisionShape2D") as CollisionShape2D
	assertions.assert_true(attack_box != null, "Melee knight should have an AttackBox.")
	assertions.assert_true(collision_shape != null, "Melee knight should have an AttackBox CollisionShape2D.")
	if attack_box == null or collision_shape == null:
		melee.queue_free()
		await tree.process_frame
		return

	var base_area_position: Vector2 = attack_box.position
	var profile_node := get_attackbox_profile_node(melee)
	assertions.assert_true(profile_node != null, "Melee knight attack shape should be driven by scene-authored attackbox profiles.")
	if profile_node == null:
		melee.queue_free()
		await tree.process_frame
		return
	var right_profile: Dictionary = profile_node.get_profile(&"default", &"right", 1)
	var left_profile: Dictionary = profile_node.get_profile(&"default", &"left", 1)
	var up_profile: Dictionary = profile_node.get_profile(&"default", &"up", 1)
	var down_profile: Dictionary = profile_node.get_profile(&"default", &"down", 1)

	melee.set("last_facing_direction", "right")
	melee.set("last_horizontal_facing_direction", "right")
	melee.call("apply_directional_attack_shape_offset")
	assertions.assert_eq(attack_box.position, base_area_position, "Knight horizontal attacks should keep the AttackBox area stable.")
	assertions.assert_eq(collision_shape.position, right_profile.get("position"), "Knight right attacks should use the scene-authored right profile.")

	melee.set("last_facing_direction", "left")
	melee.set("last_horizontal_facing_direction", "left")
	melee.call("apply_directional_attack_shape_offset")
	assertions.assert_eq(attack_box.position, base_area_position, "Knight left attacks should keep the AttackBox area stable.")
	assertions.assert_eq(collision_shape.position, left_profile.get("position"), "Knight left attacks should mirror the scene-authored right profile.")

	melee.set("last_facing_direction", "up")
	melee.call("apply_directional_attack_shape_offset")
	assertions.assert_eq(attack_box.position, base_area_position, "Knight up attacks should keep the AttackBox area stable.")
	assertions.assert_eq(collision_shape.position, up_profile.get("position"), "Knight up attacks should use the scene-authored up profile.")

	melee.call("set_attack_shape_enabled", false)
	assertions.assert_eq(collision_shape.position, right_profile.get("position"), "Knight attack shape should restore to the editor preview profile after disable.")

	melee.set("last_facing_direction", "down")
	melee.call("apply_directional_attack_shape_offset")
	assertions.assert_eq(attack_box.position, base_area_position, "Knight down attacks should keep the AttackBox area stable.")
	assertions.assert_eq(collision_shape.position, down_profile.get("position"), "Knight down attacks should use the scene-authored down profile.")

	await melee.call("activate_melee_hitbox")
	assertions.assert_eq(collision_shape.position, right_profile.get("position"), "Knight attack shape should restore after the melee hit window closes.")

	melee.queue_free()
	await tree.process_frame


func assert_knight_player_combat_contract(assertions: TestAssertions, tree: SceneTree):
	await assert_melee_knight_damages_player(assertions, tree)
	await assert_melee_knight_block_stun_contract(assertions, tree)
	await assert_melee_knight_parry_bonus_contract(assertions, tree)
	await assert_melee_knight_blocked_attack_deferred_cleanup(assertions, tree)
	await assert_ranged_knight_projectile_damage_contract(assertions, tree)
	await assert_ranged_knight_projectile_block_contract(assertions, tree)


func assert_melee_knight_damages_player(assertions: TestAssertions, tree: SceneTree):
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	var player := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	if melee == null or player == null:
		free_nodes([melee, player])
		await tree.process_frame
		return

	var health := player.get_node_or_null("Health")
	var hurt_box := player.get_node_or_null("HurtBox") as Area2D
	assertions.assert_true(health != null and hurt_box != null, "Saorise should expose health and a player hurtbox for knight damage.")
	if health != null and hurt_box != null:
		var starting_health := int(health.get("health"))
		await trigger_melee_overlap_hit(tree, melee, player)
		assertions.assert_true(int(health.get("health")) < starting_health, "Melee knight hit should damage an unblocking player.")
		assertions.assert_eq(str(melee.get("state")), "idle", "Melee knight should not stun itself on a normal damaging hit.")

	free_nodes([melee, player])
	await tree.process_frame


func assert_melee_knight_block_stun_contract(assertions: TestAssertions, tree: SceneTree):
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	var player := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	if melee == null or player == null:
		free_nodes([melee, player])
		await tree.process_frame
		return

	var health := player.get_node_or_null("Health")
	var hurt_box := player.get_node_or_null("HurtBox") as Area2D
	var tuning: Resource = melee.get("tuning") as Resource
	var sprite := melee.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if health != null and hurt_box != null and tuning != null:
		var starting_health := int(health.get("health"))
		health.call("set_blocking", true)
		melee.set("state", "attack")
		await trigger_melee_overlap_hit(tree, melee, player)
		assertions.assert_eq(int(health.get("health")), starting_health, "Blocking should prevent melee knight damage.")
		assertions.assert_eq(str(melee.get("state")), "hurt", "Blocking a melee knight should put the knight in hurt stun.")
		assertions.assert_eq(float(melee.get("damage_knockback_timer")), 0.0, "Blocked melee knight self-stun should not start player-damage knockback.")
		assertions.assert_true(absf(float(melee.get("hurt_timer")) - float(tuning.block_stun_duration)) <= 0.001, "Melee knight block stun should use knight tuning.")
		assertions.assert_true(absf(float(melee.get("attack_cooldown_timer")) - float(tuning.attack_cooldown)) <= 0.001, "Blocked melee knight should reset attack cooldown from tuning.")
		if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("hurt"):
			assertions.assert_eq(str(sprite.animation), "hurt", "Blocked melee knight should hold the hurt animation.")
			assertions.assert_eq(sprite.frame, 1, "Blocked melee knight should freeze on the second hurt frame during stun.")
			assertions.assert_eq(float(sprite.speed_scale), 0.0, "Blocked melee knight hurt animation should pause during stun.")
			melee.call("update_hurt", float(tuning.block_stun_duration) * 0.5)
			assertions.assert_eq(str(melee.get("state")), "hurt", "Blocked melee knight should stay hurt during block stun.")
			assertions.assert_eq(sprite.frame, 1, "Blocked melee knight should keep holding the second hurt frame during stun.")
			assertions.assert_eq(float(sprite.speed_scale), 0.0, "Blocked melee knight hurt animation should remain paused during stun.")
			melee.call("update_hurt", float(tuning.block_stun_duration))
			assertions.assert_eq(str(melee.get("state")), "hurt", "Blocked melee knight should finish hurt animation before leaving stun.")
			assertions.assert_eq(float(sprite.speed_scale), 1.0, "Blocked melee knight hurt animation should resume after stun timer ends.")
			assertions.assert_true(float(melee.get("hurt_animation_finish_timer")) > 0.0, "Blocked melee knight should track remaining hurt animation time after stun.")
			melee.call("update_hurt", float(melee.get("hurt_animation_finish_timer")) + 0.01)
			assertions.assert_ne(str(melee.get("state")), "hurt", "Blocked melee knight should leave hurt after the finishing animation completes.")

	free_nodes([melee, player])
	await tree.process_frame


func assert_melee_knight_parry_bonus_contract(assertions: TestAssertions, tree: SceneTree):
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	var player := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	if melee == null or player == null:
		free_nodes([melee, player])
		await tree.process_frame
		return

	var health := player.get_node_or_null("Health")
	var hurt_box := player.get_node_or_null("HurtBox") as Area2D
	if health != null and hurt_box != null:
		health.call("set_parry_window", true)
		melee.set("state", "attack")
		await trigger_melee_overlap_hit(tree, melee, player)
		assertions.assert_eq(str(melee.get("state")), "hurt", "Parrying a melee knight should stun the knight.")
		assertions.assert_true(bool(health.call("has_parry_bonus")), "Parrying a melee knight should grant Saorise's parry bonus.")

	free_nodes([melee, player])
	await tree.process_frame


func assert_melee_knight_blocked_attack_deferred_cleanup(assertions: TestAssertions, tree: SceneTree):
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	if melee == null:
		await tree.process_frame
		return

	var attack_box := melee.get_node_or_null("AttackBox") as Area2D
	assertions.assert_true(attack_box != null, "Melee knight should have an AttackBox for blocked cleanup.")
	if attack_box != null:
		melee.set("state", "attack")
		melee.set("attack_has_dealt_damage", true)
		attack_box.set_deferred("monitoring", true)
		melee.call("set_attack_shape_enabled", true)
		await tree.physics_frame
		assertions.assert_true(attack_box.monitoring, "Melee knight AttackBox should become active before blocked cleanup.")
		melee.call("on_attack_blocked")
		assertions.assert_eq(str(melee.get("state")), "hurt", "Blocked active attack cleanup should enter hurt.")
		await tree.physics_frame
		assertions.assert_false(attack_box.monitoring, "Blocked active attack cleanup should defer AttackBox monitoring off safely.")

	free_nodes([melee])
	await tree.process_frame


func assert_ranged_knight_projectile_damage_contract(assertions: TestAssertions, tree: SceneTree):
	var ranged := await instantiate_scene(assertions, tree, RANGED_SCENE)
	var projectile := await instantiate_scene(assertions, tree, PROJECTILE_SCENE)
	var player := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	if ranged == null or projectile == null or player == null:
		free_nodes([ranged, projectile, player])
		await tree.process_frame
		return

	var health := player.get_node_or_null("Health")
	var hurt_box := player.get_node_or_null("HurtBox") as Area2D
	if health != null and hurt_box != null:
		var starting_health := int(health.get("health"))
		await trigger_projectile_overlap_hit(tree, projectile, ranged, player)
		assertions.assert_true(int(health.get("health")) < starting_health, "Ranged knight projectile should damage an unblocking player.")
		assertions.assert_ne(str(ranged.get("state")), "hurt", "Ranged knight should not stun itself when an arrow damages the player.")

	free_nodes([ranged, projectile, player])
	await tree.process_frame


func assert_ranged_knight_projectile_block_contract(assertions: TestAssertions, tree: SceneTree):
	var ranged := await instantiate_scene(assertions, tree, RANGED_SCENE)
	var projectile := await instantiate_scene(assertions, tree, PROJECTILE_SCENE)
	var player := await instantiate_scene(assertions, tree, SAORISE_SCENE)
	if ranged == null or projectile == null or player == null:
		free_nodes([ranged, projectile, player])
		await tree.process_frame
		return

	var health := player.get_node_or_null("Health")
	var hurt_box := player.get_node_or_null("HurtBox") as Area2D
	var tuning: Resource = ranged.get("tuning") as Resource
	if health != null and hurt_box != null and tuning != null:
		var starting_health := int(health.get("health"))
		health.call("set_parry_window", true)
		ranged.set("state", "attack")
		await trigger_projectile_overlap_hit(tree, projectile, ranged, player)
		assertions.assert_eq(int(health.get("health")), starting_health, "Blocking a ranged knight projectile should prevent player damage.")
		assertions.assert_eq(str(ranged.get("state")), "hurt", "Blocking a ranged knight projectile should stun the ranged knight.")
		assertions.assert_true(bool(health.call("has_parry_bonus")), "Parrying a ranged knight projectile should grant Saorise's parry bonus.")
		assertions.assert_true(absf(float(ranged.get("hurt_timer")) - float(tuning.block_stun_duration)) <= 0.001, "Ranged knight projectile block stun should use ranged knight tuning.")

	free_nodes([ranged, projectile, player])
	await tree.process_frame


func trigger_melee_overlap_hit(tree: SceneTree, melee: Node, player: Node):
	melee.global_position = Vector2.ZERO
	player.global_position = Vector2(40, 0)
	melee.set("last_facing_direction", "right")
	melee.set("last_horizontal_facing_direction", "right")
	melee.set("facing_left", false)
	melee.set("attack_has_dealt_damage", true)
	await tree.physics_frame
	await melee.call("activate_melee_hitbox")


func trigger_projectile_overlap_hit(tree: SceneTree, projectile: Node, source_knight: Node, player: Node):
	source_knight.global_position = Vector2.ZERO
	player.global_position = Vector2(40, 0)
	projectile.global_position = player.global_position
	projectile.call("launch", source_knight, Vector2.RIGHT, 0.0, 1.0, 7)
	await tree.physics_frame
	projectile.call("hit_current_overlaps")
	await tree.process_frame


func free_nodes(nodes: Array):
	for node in nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()


func assert_directional_animation(assertions: TestAssertions, knight: Node, facing: String, expected_animation: String, expected_flip: bool, label: String, base_animation: String = "attack"):
	knight.set("last_facing_direction", facing)
	if facing == "left" or facing == "right":
		knight.set("last_horizontal_facing_direction", facing)
		knight.set("facing_left", facing == "left")
	knight.call("play_directional_animation", base_animation)

	var sprite := knight.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assertions.assert_true(sprite != null, "%s should have a sprite." % label)
	if sprite == null:
		return

	assertions.assert_eq(str(sprite.animation), expected_animation, "%s should play the expected directional animation." % label)
	assertions.assert_eq(sprite.flip_h, expected_flip, "%s should use the expected horizontal flip." % label)


func assert_attack_timing(assertions: TestAssertions, knight: Node, facing: String, expected_animation: String):
	knight.set("last_facing_direction", facing)
	if facing == "left" or facing == "right":
		knight.set("last_horizontal_facing_direction", facing)
	knight.call("start_attack")

	var sprite := knight.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(expected_animation):
		assertions.fail("Could not inspect timing for %s." % expected_animation)
		return

	var expected_duration := get_animation_duration(sprite.sprite_frames, expected_animation)
	assertions.assert_eq(str(knight.get("active_attack_animation")), expected_animation, "%s should be the active attack animation." % expected_animation)
	assertions.assert_true(abs(float(knight.get("active_attack_duration")) - expected_duration) <= 0.001, "%s attack duration should come from SpriteFrames." % expected_animation)
	assertions.assert_true(abs(float(knight.get("active_attack_hit_time")) - expected_duration * 0.5) <= 0.001, "%s hit time should be at the animation midpoint." % expected_animation)
	assertions.assert_eq(float(sprite.speed_scale), 1.0, "%s attack should restore sprite playback speed when it starts." % expected_animation)

	knight.set("attack_has_dealt_damage", false)
	knight.set("attack_windup_timer", 0.01)
	knight.call("update_attack", 0.02)
	assertions.assert_true(knight.get("attack_has_dealt_damage") == true, "%s should trigger exactly one damage window when the midpoint passes." % expected_animation)
	knight.call("update_attack", 0.02)
	assertions.assert_true(knight.get("attack_has_dealt_damage") == true, "%s should not reset the damage window during the same attack." % expected_animation)
	if sprite != null:
		sprite.speed_scale = 0.0
	knight.set("attack_recover_timer", 0.01)
	knight.call("update_attack", 0.02)
	assertions.assert_ne(str(knight.get("state")), "attack", "%s should leave attack when recovery finishes." % expected_animation)
	if sprite != null:
		assertions.assert_eq(float(sprite.speed_scale), 1.0, "%s should restore sprite playback speed after attack recovery." % expected_animation)


func get_animation_duration(frames: SpriteFrames, animation_name: String) -> float:
	var speed := frames.get_animation_speed(animation_name)
	if speed <= 0.0:
		return 0.0

	var duration := 0.0
	for frame_index in range(frames.get_frame_count(animation_name)):
		duration += frames.get_frame_duration(animation_name, frame_index) / speed
	return duration


func is_vector_approx(actual: Vector2, expected: Vector2) -> bool:
	return actual.is_equal_approx(expected)


func get_expected_flipped_tents(layout_key: String) -> Dictionary:
	match layout_key:
		"A":
			return {"Tent4": true, "Tent5": true}
		"B":
			return {"Tent3": true, "Tent4": true}
		"C":
			return {"Tent4": true, "Tent5": true, "Tent6": true}
		_:
			return {}


func is_flipped_tent_instance(tent: Node) -> bool:
	if tent == null:
		return false
	return str(tent.scene_file_path).ends_with("CampfireBaseTentFlipped.tscn")


func get_layout_tent_count(layout: Node) -> int:
	var count := 0
	count = count_layout_tents_recursive(layout, count)
	return count


func count_layout_tents_recursive(root: Node, count: int) -> int:
	for child in root.get_children():
		if child.has_method("get_tent_id"):
			count += 1
		count = count_layout_tents_recursive(child, count)
	return count


func assert_knight_contract(assertions: TestAssertions, knight: Node, label: String):
	assertions.assert_true(knight != null, "%s should instantiate." % label)
	if knight == null:
		return

	assertions.assert_true(knight.is_in_group("hostile_npcs"), "%s should join hostile_npcs." % label)
	for node_path in ["Health", "HealthBarDisplay/HealthBar", "HurtBox", "AttackBox", "NavigationAgent2D", "DetectionArea", "TrackingArea", "AttackRange", "Effects", "DialogueAnchor"]:
		assertions.assert_true(knight.get_node_or_null(node_path) != null, "%s should have %s." % [label, node_path])

	assertions.assert_eq((knight as CharacterBody2D).collision_layer, 4, "%s should use the HostileNPC body collision layer." % label)
	assertions.assert_eq((knight as CharacterBody2D).collision_mask, 11, "%s should collide with World, Player, and NPC bodies, but not other HostileNPC bodies." % label)
	assertions.assert_false(((knight as CharacterBody2D).collision_mask & 4) != 0, "%s should not hard-collide with other HostileNPC bodies." % label)
	var navigation_agent := knight.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	assertions.assert_true(navigation_agent != null and not navigation_agent.avoidance_enabled, "%s should use navigation path points without actor avoidance steering." % label)
	if navigation_agent != null:
		assertions.assert_eq(navigation_agent.navigation_layers, DEFAULT_CHARACTER_NAVIGATION_LAYER, "%s NavigationAgent2D should use the shared character navigation layer." % label)
	assertions.assert_true(knight.has_method("collect_story_save_state"), "%s should expose story save collection." % label)
	assertions.assert_true(knight.has_method("apply_story_save_state"), "%s should expose story save restore." % label)
	assertions.assert_true(knight.has_method("set_respawn_enabled"), "%s should expose respawn policy control." % label)


func assert_knight_transform_aggro_contract(assertions: TestAssertions, tree: SceneTree):
	var knight := await instantiate_scene(assertions, tree, MELEE_SCENE)
	var player := MockPlayer.new()
	tree.root.add_child(player)
	player.global_position = knight.global_position
	await tree.physics_frame

	knight.call("_on_tracking_body_entered", player)
	await tree.physics_frame
	assertions.assert_true(bool(knight.get("player_in_tracking")), "Non-camp knight should track the player before transformation.")
	assertions.assert_true(player.is_connected("transformation_state_changed", Callable(knight, "_on_player_transformation_state_changed")), "Knight should track Saorise's transformation signal once engaged.")

	player.transforming_forms = true
	player.transformation_state_changed.emit(true)
	knight.call("_on_tracking_body_exited", player)
	knight.call("_on_attack_range_body_exited", player)
	assertions.assert_true(bool(knight.get("player_in_tracking")), "Transform-caused tracking exit should not clear non-camp knight aggro immediately.")
	assertions.assert_true(bool(knight.get("refreshing_player_ranges_after_transform")), "Knight should schedule a post-transform range refresh.")

	player.transforming_forms = false
	player.transformation_state_changed.emit(false)
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	assertions.assert_true(bool(knight.get("player_in_tracking")), "Non-camp knight should preserve aggro after transformation settles while Saorise still overlaps tracking range.")
	assertions.assert_false(bool(knight.get("refreshing_player_ranges_after_transform")), "Knight transform range refresh should finish after the settle frames.")

	player.global_position = knight.global_position + Vector2(10000, 0)
	await tree.physics_frame
	knight.call("_on_tracking_body_exited", player)
	await tree.physics_frame
	assertions.assert_false(bool(knight.get("player_in_tracking")), "Knight should still lose aggro from a real tracking exit after transformation has settled.")

	free_nodes([knight, player])
	await tree.process_frame


func assert_campfire_layout_contracts(assertions: TestAssertions, tree: SceneTree):
	var expected_positions := {
		"A": {
			"Tent1": Vector2(73, -60), "Tent2": Vector2(173, -31), "Tent3": Vector2(147, 49),
			"Tent4": Vector2(-97, -60), "Tent5": Vector2(-112, 45),
			"Campfire": Vector2(0, 0), "MeleeBanner": Vector2(0, -112),
		},
		"B": {
			"Tent1": Vector2(121, -56), "Tent2": Vector2(156, 67), "Tent3": Vector2(-116, -74),
			"Tent4": Vector2(-215, 16),
			"Campfire": Vector2(0, 0), "MeleeBanner": Vector2(0, -107),
		},
		"C": {
			"Tent1": Vector2(90, -160), "Tent2": Vector2(165, -93), "Tent3": Vector2(126, 9),
			"Tent4": Vector2(-82, -155), "Tent5": Vector2(-143, -85), "Tent6": Vector2(-144, 15),
			"Campfire": Vector2(0, 0), "MeleeBanner": Vector2(0, -86),
		},
	}
	var expected_respawn_positions := {
		"A": Vector2(0, 26),
		"B": Vector2(0, 27),
		"C": Vector2(0, 33),
	}

	for layout_key in CAMPFIRE_LAYOUT_SCENES.keys():
		var layout := await instantiate_scene(assertions, tree, CAMPFIRE_LAYOUT_SCENES[layout_key])
		assertions.assert_true(layout != null, "Campfire layout %s should instantiate." % layout_key)
		if layout == null:
			continue

		var expected: Dictionary = expected_positions[layout_key]
		var expected_flipped := get_expected_flipped_tents(layout_key)
		var tent_count := 0
		var camp_navigation_region := layout.get_node_or_null("CampNavigationRegion") as NavigationRegion2D
		assertions.assert_true(camp_navigation_region != null, "Campfire layout %s should own a variant-specific CampNavigationRegion." % layout_key)
		if camp_navigation_region != null:
			assertions.assert_true(camp_navigation_region.navigation_polygon != null, "Campfire layout %s CampNavigationRegion should have an editable NavigationPolygon." % layout_key)
			assertions.assert_eq(camp_navigation_region.navigation_layers, CAMPFIRE_BASE_KNIGHT_NAVIGATION_LAYER, "Campfire layout %s CampNavigationRegion should use the campfire-base knight navigation layer." % layout_key)
		for node_name in expected.keys():
			var node := camp_navigation_region.get_node_or_null(node_name) if camp_navigation_region != null else null
			assertions.assert_true(node != null, "Campfire layout %s should have %s." % [layout_key, node_name])
			if node == null:
				continue

			assertions.assert_eq(node.position, expected[node_name], "Campfire layout %s should place %s from the Aseprite blueprint." % [layout_key, node_name])
			if node_name.begins_with("Tent"):
				tent_count += 1
				var tent_number: String = node_name.substr("Tent".length())
				assertions.assert_eq(str(node.get("tent_id")), "tent_%s" % tent_number, "Campfire layout %s should use stable tent id for %s." % [layout_key, node_name])
				assertions.assert_eq(is_flipped_tent_instance(node), expected_flipped.has(node_name), "Campfire layout %s should preserve the authored normal/flipped tent instance for %s." % [layout_key, node_name])

		assertions.assert_eq(tent_count, expected.size() - 2, "Campfire layout %s should have the expected Aseprite tent count." % layout_key)
		assertions.assert_true(camp_navigation_region != null and camp_navigation_region.get_node_or_null("Campfire") is StaticBody2D, "Campfire layout %s should keep a collision-ready campfire component under CampNavigationRegion." % layout_key)
		assertions.assert_true(camp_navigation_region != null and camp_navigation_region.get_node_or_null("MeleeBanner") is StaticBody2D, "Campfire layout %s should keep a collision-ready banner component under CampNavigationRegion." % layout_key)
		var return_paths := camp_navigation_region.get_node_or_null("ReturnPaths") if camp_navigation_region != null else null
		assertions.assert_true(return_paths == null, "Campfire layout %s should not keep obsolete ReturnPaths; knight return-home uses navigation only." % layout_key)
		assertions.assert_true(layout.get_node_or_null("NavigationLinks") == null, "Campfire layout %s should not use forced NavigationLink2D exits; camp and level navigation stay separate." % layout_key)
		assertions.assert_true(layout.get_node_or_null("KnightRoster") is Node2D, "Campfire layout %s should have a KnightRoster container for authored linked knights." % layout_key)
		var respawn_point := layout.get_node_or_null("RespawnPoint") as Marker2D
		assertions.assert_true(respawn_point is Marker2D, "Campfire layout %s should keep a respawn marker as a direct layout child." % layout_key)
		if respawn_point != null:
			assertions.assert_eq(respawn_point.position, expected_respawn_positions[layout_key], "Campfire layout %s should preserve its RespawnPoint marker position." % layout_key)
		for region_node_name in expected.keys():
			var region_child := camp_navigation_region.get_node_or_null(region_node_name) if camp_navigation_region != null else null
			assertions.assert_true(region_child != null and region_child.get_parent() == camp_navigation_region, "Campfire layout %s should keep %s under CampNavigationRegion for source geometry and y-sort." % [layout_key, region_node_name])
		if layout_key == "C":
			var has_authored_navigation := false
			if camp_navigation_region != null and camp_navigation_region.navigation_polygon != null:
				has_authored_navigation = camp_navigation_region.navigation_polygon.get_polygon_count() > 0 or camp_navigation_region.navigation_polygon.get_outline_count() > 0
			assertions.assert_true(has_authored_navigation, "Campfire layout C should preserve its authored navigation polygon.")
			var knight_roster := layout.get_node_or_null("KnightRoster")
			assertions.assert_true(knight_roster != null and knight_roster.get_node_or_null("Knight1") != null, "Authored Layout C should keep knights under KnightRoster for editor organization.")
			if knight_roster != null:
				for knight_index in range(1, 7):
					var layout_knight := knight_roster.get_node_or_null("Knight%d" % knight_index)
					assertions.assert_true(layout_knight != null and str(layout_knight.get("default_behavior")) == "idle", "Layout C Knight%d should default to idle." % knight_index)

		layout.queue_free()
	await tree.process_frame


func assert_campfire_variant_roster_contracts(assertions: TestAssertions, tree: SceneTree):
	var expected_max_counts := {"A": 5, "B": 4, "C": 6}
	for layout_key in CAMPFIRE_VARIANT_RESOURCES.keys():
		var variant: Resource = load(CAMPFIRE_VARIANT_RESOURCES[layout_key])
		assertions.assert_true(variant != null, "Campfire variant %s should load." % layout_key)
		if variant == null:
			continue

		assertions.assert_eq(int(variant.get("max_knight_count")), expected_max_counts[layout_key], "Campfire variant %s should use tent count as max knight roster." % layout_key)
		var layout := await instantiate_scene(assertions, tree, CAMPFIRE_LAYOUT_SCENES[layout_key])
		if layout != null:
			assertions.assert_eq(int(variant.get("max_knight_count")), get_layout_tent_count(layout), "Campfire variant %s max knight count should match its tent count." % layout_key)
			layout.queue_free()
	await tree.process_frame


func assert_campfire_layout_reload_contract(assertions: TestAssertions, tree: SceneTree):
	var campfire := await instantiate_scene(assertions, tree, CAMPFIRE_SCENE)
	assertions.assert_true(campfire != null, "Campfire base should instantiate for layout reload contract.")
	if campfire == null:
		return

	var layout_root := campfire.get_node_or_null("LayoutRoot")
	assertions.assert_true(layout_root != null, "Campfire base should have a LayoutRoot for reload contract.")
	if layout_root == null:
		campfire.queue_free()
		await tree.process_frame
		return

	campfire.call("select_variant_by_id", &"campfire_base_a")
	campfire.call("apply_current_variant")
	var layout_a := campfire.get("current_layout") as Node
	var region_a := campfire.call("get_active_camp_navigation_region") as NavigationRegion2D
	assertions.assert_eq(layout_root.get_child_count(), 1, "Applying a campfire variant should leave exactly one layout instance.")
	assertions.assert_eq(campfire.call("get_tent_count"), 5, "Variant A should discover five tents after immediate layout replacement.")
	assertions.assert_true(is_flipped_tent_instance((campfire.get("tents") as Array)[3]), "Variant A should discover flipped tent instances after reload.")
	assertions.assert_true(region_a != null and layout_a != null and region_a == layout_a.get_node_or_null("CampNavigationRegion"), "Variant A should expose its active layout navigation region.")

	campfire.call("select_variant_by_id", &"campfire_base_b")
	campfire.call("apply_current_variant")
	var layout_b := campfire.get("current_layout") as Node
	var region_b := campfire.call("get_active_camp_navigation_region") as NavigationRegion2D
	assertions.assert_eq(layout_root.get_child_count(), 1, "Switching campfire variants should immediately remove the previous layout.")
	assertions.assert_eq(campfire.call("get_tent_count"), 4, "Variant B should discover four tents after variant switch.")
	assertions.assert_true(is_flipped_tent_instance((campfire.get("tents") as Array)[2]), "Variant B should preserve flipped tent instances after variant switch.")
	assertions.assert_eq(campfire.call("get_max_knight_count"), 4, "Variant B should expose its authored max knight count.")
	assertions.assert_true(region_b != null and layout_b != null and region_b == layout_b.get_node_or_null("CampNavigationRegion"), "Variant B should expose its active layout navigation region after switch.")

	campfire.queue_free()
	await tree.process_frame


func assert_campfire_roster_y_sort_promotion(assertions: TestAssertions, tree: SceneTree):
	var campfire := await instantiate_scene(assertions, tree, CAMPFIRE_SCENE)
	assertions.assert_true(campfire != null, "Campfire base should instantiate for roster y-sort promotion.")
	if campfire == null:
		return

	campfire.call("select_variant_by_id", &"campfire_base_c")
	campfire.call("apply_current_variant")

	var active_layout: Node = campfire.get("current_layout") as Node
	assertions.assert_true(active_layout != null, "Campfire base should expose an active layout after applying Layout C.")
	if active_layout == null:
		campfire.queue_free()
		await tree.process_frame
		return

	var knight_roster := active_layout.get_node_or_null("KnightRoster")
	assertions.assert_true(knight_roster is Node2D, "Runtime Layout C should keep an empty KnightRoster authoring container.")
	if knight_roster != null:
		assertions.assert_eq(knight_roster.get_child_count(), 0, "Runtime KnightRoster should be empty after promoting knights for y-sort.")

	var expected_positions := await get_authored_layout_roster_positions(tree, "C")
	var camp_navigation_region := active_layout.get_node_or_null("CampNavigationRegion") as NavigationRegion2D
	assertions.assert_true(camp_navigation_region != null, "Runtime Layout C should expose CampNavigationRegion as the y-sort/source-geometry parent.")
	for knight_name in expected_positions.keys():
		var knight := camp_navigation_region.get_node_or_null(knight_name) if camp_navigation_region != null else null
		assertions.assert_true(knight != null, "Runtime Layout C should promote %s into CampNavigationRegion." % knight_name)
		if knight == null:
			continue
		assertions.assert_eq(knight.get_parent(), camp_navigation_region, "%s should share CampNavigationRegion with tents for individual y-sort." % knight_name)
		assertions.assert_true(is_vector_approx(active_layout.to_local(knight.global_position), expected_positions[knight_name]), "%s should preserve its authored layout position after promotion." % knight_name)
		assertions.assert_true(knight.is_in_group("hostile_npcs"), "%s should remain a hostile NPC after roster promotion." % knight_name)

	campfire.queue_free()
	await tree.process_frame


func get_authored_layout_roster_positions(tree: SceneTree, layout_key: String) -> Dictionary:
	var positions := {}
	var packed: PackedScene = load(CAMPFIRE_LAYOUT_SCENES[layout_key])
	if packed == null:
		return positions

	var layout := packed.instantiate() as Node2D
	if layout == null:
		return positions

	tree.root.add_child(layout)
	await tree.process_frame
	var roster := layout.get_node_or_null("KnightRoster")
	if roster != null:
		for child in roster.get_children():
			if child is Node2D:
				positions[str(child.name)] = layout.to_local((child as Node2D).global_position)
	layout.queue_free()
	await tree.process_frame
	return positions


func assert_campfire_component_scene_contracts(assertions: TestAssertions, tree: SceneTree):
	var campfire := await instantiate_scene(assertions, tree, CAMPFIRE_COMPONENT_SCENE)
	var banner := await instantiate_scene(assertions, tree, MELEE_BANNER_COMPONENT_SCENE)

	assertions.assert_true(campfire is StaticBody2D, "Campfire component scene root should be a StaticBody2D.")
	assertions.assert_true(banner is StaticBody2D, "Melee banner component scene root should be a StaticBody2D.")

	if campfire is StaticBody2D:
		assertions.assert_eq((campfire as StaticBody2D).collision_layer, 1, "Campfire component should be on the World physics layer.")
		assertions.assert_eq((campfire as StaticBody2D).collision_mask, 14, "Campfire component should use the world blocker mask.")
		assertions.assert_true(campfire.get_node_or_null("BodyCollision") is CollisionShape2D, "Campfire component should have an editable body collision shape.")
		var campfire_body := campfire.get_node_or_null("BodyCollision") as CollisionShape2D
		if campfire_body != null:
			assertions.assert_true(campfire_body.shape is CircleShape2D, "Campfire movement blocker should be a simple rounded footprint.")
			assertions.assert_eq(campfire_body.scale, Vector2(2.2, 1.25), "Campfire movement blocker should stay compact so actors can slide around it.")
		var campfire_sprite := campfire.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		assertions.assert_true(campfire_sprite != null, "Campfire component should have an AnimatedSprite2D child.")
		assertions.assert_true(campfire_sprite.sprite_frames != null, "Campfire component should have SpriteFrames.")
		if campfire_sprite.sprite_frames != null:
			assertions.assert_true(campfire_sprite.sprite_frames.has_animation("lit"), "Campfire component should have lit animation.")
			assertions.assert_true(campfire_sprite.sprite_frames.has_animation("unlit"), "Campfire component should have unlit animation.")

	if banner is StaticBody2D:
		assertions.assert_eq((banner as StaticBody2D).collision_layer, 1, "Melee banner component should be on the World physics layer.")
		assertions.assert_eq((banner as StaticBody2D).collision_mask, 14, "Melee banner component should use the world blocker mask.")
		assertions.assert_true(banner.get_node_or_null("BodyCollision") is CollisionShape2D, "Melee banner component should have an editable body collision shape.")
		var banner_sprite := banner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		assertions.assert_true(banner_sprite != null, "Melee banner component should have an AnimatedSprite2D child.")
		assertions.assert_true(banner_sprite.sprite_frames != null, "Melee banner component should have SpriteFrames.")
		if banner_sprite.sprite_frames != null:
			assertions.assert_true(banner_sprite.sprite_frames.has_animation("intact"), "Melee banner component should have intact animation.")
			assertions.assert_true(banner_sprite.sprite_frames.has_animation("ruined"), "Melee banner component should have ruined animation.")

	var tent := await instantiate_scene(assertions, tree, CAMPFIRE_TENT_SCENE)
	var flipped_tent := await instantiate_scene(assertions, tree, CAMPFIRE_TENT_FLIPPED_SCENE)
	for tent_node in [tent, flipped_tent]:
		if tent_node == null:
			continue
		var body_shape := tent_node.get_node_or_null("BodyCollision") as CollisionPolygon2D
		var hurt_shape := tent_node.get_node_or_null("HurtBox/CollisionShape2D") as CollisionPolygon2D
		assertions.assert_true(body_shape != null, "Campfire tent movement blocker should be a local segmented collision polygon.")
		assertions.assert_true(hurt_shape != null, "Campfire tent hurt box should preserve its authored damage polygon separately from movement blocking.")
		if body_shape != null:
			assertions.assert_false(body_shape.top_level, "Campfire tent movement blocker should stay local to the tent, not top-level.")
			assertions.assert_eq(body_shape.skew, 0.0, "Campfire tent movement blocker should not use skewed transforms.")
			assertions.assert_eq(body_shape.scale, Vector2.ONE, "Campfire tent movement blocker should not rely on heavy scaling.")
			assertions.assert_true(body_shape.polygon.size() >= 18, "Campfire tent movement polygon should use a dense rounded footprint for building-style sliding.")
			assertions.assert_ne(body_shape.polygon, hurt_shape.polygon, "Campfire tent movement blocker should remain separate from the larger damage/hurt polygon.")

	for node in [campfire, banner, tent, flipped_tent]:
		if node != null:
			node.queue_free()
	await tree.process_frame


func assert_knight_home_default_and_aggro_contract(assertions: TestAssertions, tree: SceneTree):
	var root := Node2D.new()
	tree.root.add_child(root)

	var player := MockPlayer.new()
	player.global_position = Vector2(220, 0)
	root.add_child(player)

	var knight_packed: PackedScene = load(MELEE_SCENE)
	var knight := knight_packed.instantiate()
	knight.global_position = Vector2(64, -32)
	knight.set("default_behavior", "idle")
	knight.set("home_facing_direction", "left")
	knight.set("campfire_base_path", NodePath("../MissingCampfire"))
	root.add_child(knight)
	await tree.process_frame

	assertions.assert_eq(knight.call("get_home_position"), Vector2(64, -32), "Knight editor placement should become its home position.")
	assertions.assert_eq(knight.get("state"), "idle", "Camp-linked knight should start in its authored default behavior.")
	assertions.assert_eq(knight.get("last_facing_direction"), "left", "Knight should apply its authored home facing direction.")

	var animated_sprite := knight.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var navigation_agent := knight.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	var authored_path_distance := 0.0
	var authored_target_distance := 0.0
	if navigation_agent != null:
		authored_path_distance = navigation_agent.path_desired_distance
		authored_target_distance = navigation_agent.target_desired_distance
	knight.call("_on_detection_body_entered", player)
	assertions.assert_eq(knight.get("state"), "idle", "Camp-linked knight-only detection should not replace camp-base aggro startup.")
	if animated_sprite != null:
		assertions.assert_true(str(animated_sprite.animation).begins_with("idle"), "Camp-linked knight-only detection should keep the idle animation until camp aggro starts.")

	knight.call("force_aggro", player)
	assertions.assert_true(knight.get("camp_aggro_active") == true, "Camp aggro should force a knight into active pursuit.")
	assertions.assert_eq(knight.get("state"), "chase", "Forced camp aggro should switch the knight to chase.")
	assertions.assert_false(knight.has_method("should_force_direct_chase"), "Forced camp aggro should not use a direct fallback movement helper.")

	knight.global_position = Vector2(160, -32)
	knight.call("return_to_camp")
	assertions.assert_false(knight.get("camp_aggro_active") == true, "Returning to camp should clear forced aggro.")
	assertions.assert_false(knight.get("player_in_tracking") == true, "Returning to camp should clear tracking state.")
	assertions.assert_false(knight.get("player_in_attack_range") == true, "Returning to camp should clear attack-range state.")
	assertions.assert_eq(knight.get("state"), "return_home", "Returning to camp should put the knight into return-home state.")
	if navigation_agent != null:
		assertions.assert_eq(navigation_agent.target_desired_distance, 6.0, "Return-home should tighten NavigationAgent target distance to patrol arrival distance.")
		assertions.assert_eq(navigation_agent.path_desired_distance, 6.0, "Return-home should tighten NavigationAgent path distance to patrol arrival distance when authored distance is looser.")
	knight.set("player_in_tracking", true)
	assertions.assert_true(bool(knight.call("should_return_home")), "Return-home should ignore fresh tracking flags after camp aggro has already cleared.")
	knight.set("velocity", Vector2(-24, 0))
	knight.call("register_blocked_movement")
	assertions.assert_eq(knight.get("velocity"), Vector2(-24, 0), "Blocked return-home should not immediately zero velocity on the first tiny movement frame.")
	knight.global_position = Vector2(160, -32)
	knight.call("move_home", 2.5)
	assertions.assert_ne(knight.global_position, Vector2(64, -32), "Return-home should not teleport home after a timer while still outside arrival range.")
	assertions.assert_eq(knight.get("state"), "return_home", "Return-home should keep trying until the knight reaches arrival range.")
	knight.global_position = Vector2(66, -32)
	knight.call("move_home", 0.02)
	assertions.assert_eq(knight.global_position, Vector2(64, -32), "Arrival-range return-home should settle to the exact authored home position.")
	assertions.assert_eq(knight.get("velocity"), Vector2.ZERO, "Arrival-range return-home should clear velocity.")
	assertions.assert_eq(knight.get("state"), "idle", "Arrival-range return-home should resume the authored default behavior.")
	if navigation_agent != null:
		assertions.assert_eq(navigation_agent.path_desired_distance, authored_path_distance, "Finishing return-home should restore the authored/chase NavigationAgent path distance.")
		assertions.assert_eq(navigation_agent.target_desired_distance, authored_target_distance, "Finishing return-home should restore the authored/chase NavigationAgent target distance.")

	knight.call("reset_for_level_entry")
	assertions.assert_eq(knight.global_position, Vector2(64, -32), "Level-entry reset should restore a camp knight to its home position.")
	assertions.assert_true(knight.get("respawn_enabled") == true, "Level-entry reset should keep camp knight respawn enabled.")

	root.queue_free()
	await tree.process_frame


func assert_knight_runtime_stabilization_contract(assertions: TestAssertions, tree: SceneTree):
	var melee := await instantiate_scene(assertions, tree, MELEE_SCENE)
	assertions.assert_true(melee != null, "Melee knight should instantiate for runtime stabilization contract.")
	if melee == null:
		return

	var sprite := melee.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assertions.assert_true(sprite != null, "Melee knight should have a sprite for runtime stabilization contract.")

	melee.call("update_idle_behavior")
	assertions.assert_eq(melee.get("velocity"), Vector2.ZERO, "Idle knight should keep zero velocity.")
	if sprite != null:
		assertions.assert_true(str(sprite.animation).begins_with("idle"), "Idle knight should play idle animation, not walk or run.")
		sprite.frame = 1
		sprite.frame_progress = 0.5
		melee.call("play_directional_animation", "idle")
		assertions.assert_eq(sprite.frame, 1, "Repeating the same knight animation should not reset the current frame.")
		assertions.assert_true(sprite.frame_progress > 0.0, "Repeating the same knight animation should not reset frame progress.")

	melee.set("state", "chase")
	var moved: bool = bool(melee.call("move_toward_position", melee.global_position, 96.0))
	assertions.assert_false(moved, "Knight movement should report no movement when target equals current position.")
	assertions.assert_eq(melee.get("velocity"), Vector2.ZERO, "Knight should clear velocity when movement is blocked or too close.")
	if sprite != null:
		assertions.assert_true(str(sprite.animation).begins_with("idle"), "Knight should play idle instead of running in place when target is too close.")

	var player := MockPlayer.new()
	player.global_position = melee.global_position + Vector2(240, 0)
	tree.root.add_child(player)
	await tree.process_frame
	melee.set("player", player)
	melee.set("player_in_tracking", true)
	melee.set("state", "chase")
	melee.set("player_in_attack_range", false)
	var far_chase_target: Vector2 = melee.call("get_chase_target_position")
	assertions.assert_ne(far_chase_target, player.global_position, "Melee knights outside attack range should use a small stable navigation target offset so several knights do not perfectly overlap.")
	assertions.assert_true(absf(far_chase_target.distance_to(player.global_position) - 18.0) <= 0.01, "Melee chase target offset should stay small enough to preserve close engagement.")
	var melee_tuning: Resource = melee.get("tuning") as Resource
	if melee_tuning != null:
		assertions.assert_true(absf(float(melee.call("get_effective_melee_attack_range")) - (float(melee_tuning.attack_range) + 4.0)) <= 0.001, "Melee effective attack range should be tuning attack range plus a tiny contact tolerance.")
	melee.global_position = player.global_position + Vector2(48, 0)
	melee.set("player_in_attack_range", true)
	assertions.assert_false(bool(melee.call("is_player_within_attack_distance")), "Melee knight should not treat oversized AttackRange overlap as valid attack distance.")
	assertions.assert_false(bool(melee.call("can_start_attack")), "Melee knight should not attack beyond tuned melee range plus contact tolerance.")
	melee.global_position = player.global_position + Vector2(44, 0)
	melee.set("player_in_attack_range", false)
	assertions.assert_eq(melee.call("get_chase_target_position"), player.global_position, "Melee knights inside effective attack range should drop spread offsets and attack the player directly.")
	assertions.assert_true(bool(melee.call("is_player_within_attack_distance")), "Melee knight should detect attack distance even if AttackRange signal has not fired.")
	assertions.assert_true(bool(melee.call("can_start_attack")), "Melee knight should be able to attack from distance fallback even when player_in_attack_range is false.")
	melee.call("chase_player")
	assertions.assert_false(bool(melee.get("current_movement_uses_navigation")), "Melee knight should not direct-fallback when no navigation path point is available.")
	melee.global_position = player.global_position - Vector2(160, 0)
	melee.call("play_directional_animation", "run")
	melee.set("velocity", Vector2(32, 0))
	melee.call("register_blocked_movement")
	assertions.assert_eq(melee.get("state"), "chase", "Blocked chase should stay in chase state.")
	assertions.assert_eq(melee.get("velocity"), Vector2(32, 0), "Blocked chase should not immediately zero velocity on the first tiny movement frame.")
	if sprite != null:
		assertions.assert_true(str(sprite.animation).begins_with("run"), "Blocked chase should keep locomotion intent instead of flickering into idle.")
	melee.call("_on_navigation_velocity_computed", Vector2.ZERO)
	assertions.assert_eq(melee.get("velocity"), Vector2(32, 0), "Stale avoidance callbacks should be ignored because knight avoidance is disabled.")
	if sprite != null:
		assertions.assert_true(str(sprite.animation).begins_with("run"), "A stale zero velocity callback should not force chase animation back to idle.")

	var attack_box := melee.get_node_or_null("AttackBox") as Area2D
	melee.set("player_in_attack_range", true)
	melee.set("state", "attack")
	melee.set("velocity", Vector2(42, 0))
	melee.set("attack_windup_timer", 0.1)
	melee.set("attack_recover_timer", 0.2)
	melee.set("attack_has_dealt_damage", false)
	if attack_box != null:
		attack_box.monitoring = true
	var applied: bool = bool(melee.call("take_damage", 1, true, player))
	if sprite != null:
		assertions.assert_eq(str(sprite.animation), "hurt", "Melee knight should play hurt animation immediately when stunned.")
		assertions.assert_eq(float(sprite.speed_scale), 1.0, "Normal melee knight hurt should not use the block-stun animation hold.")
		assertions.assert_false(bool(melee.get("hurt_animation_hold_active")), "Normal melee knight hurt should not freeze the hurt animation.")
	await tree.process_frame
	assertions.assert_true(applied, "Non-lethal knight damage should be applied.")
	assertions.assert_eq(melee.get("state"), "hurt", "Non-lethal knight damage should enter hurt state.")
	assertions.assert_true(float(melee.get("damage_knockback_timer")) > 0.0, "Non-lethal Saorise damage should start the knight damage knockback timer.")
	assertions.assert_true((melee.get("damage_knockback_velocity") as Vector2).x > 0.0, "Damage knockback should push the knight away from Saorise.")
	var position_before_knockback: Vector2 = melee.global_position
	melee.call("update_hurt", float(tuning.damage_knockback_duration) * 0.5)
	assertions.assert_true(melee.global_position.x > position_before_knockback.x, "Damage knockback should move the knight away from Saorise during hurt.")
	assertions.assert_true(float(melee.get("damage_knockback_timer")) > 0.0, "Damage knockback should remain active during its configured window.")
	melee.call("update_hurt", float(tuning.damage_knockback_duration))
	assertions.assert_eq(float(melee.get("damage_knockback_timer")), 0.0, "Damage knockback should clear after its configured duration.")
	assertions.assert_eq(melee.get("damage_knockback_velocity"), Vector2.ZERO, "Damage knockback velocity should clear after the window.")
	assertions.assert_true(melee.get("attack_has_dealt_damage") == true, "Hurt should cancel any pending one-stage attack damage window.")
	if attack_box != null:
		assertions.assert_false(attack_box.monitoring, "Hurt should disable the melee AttackBox monitoring.")
	assertions.assert_false(bool(melee.call("can_start_attack")), "Hurt knight should not be able to start another attack during stun.")
	var tuning: Resource = melee.get("tuning") as Resource
	var hurt_duration := float(tuning.hurt_duration_seconds) if tuning != null else 0.35
	melee.call("update_hurt", hurt_duration + 0.01)
	assertions.assert_eq(melee.get("state"), "chase", "Hurt knight should resume chase if the player is still tracked.")
	if sprite != null:
		assertions.assert_eq(float(sprite.speed_scale), 1.0, "Normal hurt recovery should leave sprite playback speed restored.")
		melee.call("play_directional_animation", "run")
		assertions.assert_true(sprite.is_playing(), "Knight locomotion animation should be playing after normal hurt recovery.")

	var health := melee.get_node_or_null("Health")
	var max_health := int(health.get("max_health")) if health != null else 999
	var movement_box := melee.get_node_or_null("MovementBox") as CollisionShape2D
	var authored_movement_box_disabled := movement_box != null and movement_box.disabled
	assertions.assert_false(authored_movement_box_disabled, "Basic Melee Knight should preserve its scene-authored enabled MovementBox after setup.")
	melee.call("take_damage", max_health, true, player)
	await tree.process_frame
	assertions.assert_true(bool(melee.get("dead")), "Lethal knight damage should enter death state.")
	assertions.assert_ne(melee.get("state"), "hurt", "Lethal knight damage should not leave the knight in hurt state.")
	assertions.assert_eq(float(melee.get("damage_knockback_timer")), 0.0, "Lethal knight damage should not leave damage knockback active.")

	var navigation_agent := melee.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	assertions.assert_true(movement_box != null and movement_box.disabled, "Dead knight body collision should be disabled so it cannot create invisible walls.")
	assertions.assert_true(navigation_agent != null and not navigation_agent.avoidance_enabled, "Dead knight actor avoidance should stay disabled.")
	var home_position: Vector2 = melee.call("get_home_position")
	melee.call("respawn_at", home_position)
	await tree.process_frame
	assertions.assert_false(bool(melee.get("dead")), "Respawned knight should no longer be dead.")
	assertions.assert_true(movement_box != null and movement_box.disabled == authored_movement_box_disabled, "Respawned knight body collision should restore the scene-authored alive MovementBox state.")
	assertions.assert_true(navigation_agent != null and not navigation_agent.avoidance_enabled, "Respawned knight actor avoidance should stay disabled while path points remain available.")
	melee.call("reset_for_level_entry")
	await tree.process_frame
	assertions.assert_true(movement_box != null and movement_box.disabled == authored_movement_box_disabled, "Level-entry reset should preserve the scene-authored alive MovementBox state.")

	var ranged := await instantiate_scene(assertions, tree, RANGED_SCENE)
	assertions.assert_true(ranged != null, "Ranged knight should instantiate for hurt fallback test.")
	if ranged != null:
		var ranged_sprite := ranged.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		ranged.set("player", player)
		ranged.set("player_in_tracking", true)
		ranged.global_position = player.global_position - Vector2(96, 0)
		assertions.assert_eq(ranged.call("get_chase_target_position"), player.global_position, "Ranged knight aggro should target the player through navigation instead of separated direct spacing.")
		var ranged_applied: bool = bool(ranged.call("take_damage", 1, true, player))
		assertions.assert_true(ranged_applied, "Ranged knight should accept non-lethal damage.")
		assertions.assert_eq(ranged.get("state"), "hurt", "Ranged knight should enter hurt state even before ranged hurt sprites exist.")
		if ranged_sprite != null:
			assertions.assert_eq(str(ranged_sprite.animation), "idle", "Ranged knight should fall back safely when hurt animation is missing.")
		ranged.queue_free()

	melee.queue_free()
	player.queue_free()
	await tree.process_frame


func assert_knight_damage_knockback_facing_lock(assertions: TestAssertions, tree: SceneTree):
	var right_facing_knight := await instantiate_scene(assertions, tree, MELEE_SCENE)
	assertions.assert_true(right_facing_knight != null, "Right-facing knight should instantiate for knockback facing lock.")
	if right_facing_knight == null:
		return

	var right_hit_player := MockPlayer.new()
	tree.root.add_child(right_hit_player)
	await tree.process_frame
	right_facing_knight.global_position = Vector2.ZERO
	right_hit_player.global_position = Vector2(32, 0)
	right_facing_knight.call("update_facing", Vector2.RIGHT)
	right_facing_knight.call("play_directional_animation", "idle")
	var right_sprite := right_facing_knight.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	right_facing_knight.call("take_damage", 1, true, right_hit_player)
	assertions.assert_true((right_facing_knight.get("damage_knockback_velocity") as Vector2).x < 0.0, "Right-facing knight should be pushed left when hit from the right.")
	right_facing_knight.call("update_hurt", get_knight_damage_knockback_half_duration(right_facing_knight))
	assertions.assert_eq(right_facing_knight.get("last_horizontal_facing_direction"), "right", "Knockback should not change right-facing horizontal intent.")
	assertions.assert_false(bool(right_facing_knight.get("facing_left")), "Knockback should not flip a right-facing knight to left.")
	if right_sprite != null:
		assertions.assert_false(right_sprite.flip_h, "Right-facing hurt animation should stay unflipped while knockback moves left.")
	right_facing_knight.queue_free()
	right_hit_player.queue_free()
	await tree.process_frame

	var left_facing_knight := await instantiate_scene(assertions, tree, MELEE_SCENE)
	assertions.assert_true(left_facing_knight != null, "Left-facing knight should instantiate for knockback facing lock.")
	if left_facing_knight == null:
		return

	var left_hit_player := MockPlayer.new()
	tree.root.add_child(left_hit_player)
	await tree.process_frame
	left_facing_knight.global_position = Vector2.ZERO
	left_hit_player.global_position = Vector2(-32, 0)
	left_facing_knight.call("update_facing", Vector2.LEFT)
	left_facing_knight.call("play_directional_animation", "idle")
	var left_sprite := left_facing_knight.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	left_facing_knight.call("take_damage", 1, true, left_hit_player)
	assertions.assert_true((left_facing_knight.get("damage_knockback_velocity") as Vector2).x > 0.0, "Left-facing knight should be pushed right when hit from the left.")
	left_facing_knight.call("update_hurt", get_knight_damage_knockback_half_duration(left_facing_knight))
	assertions.assert_eq(left_facing_knight.get("last_horizontal_facing_direction"), "left", "Knockback should not change left-facing horizontal intent.")
	assertions.assert_true(bool(left_facing_knight.get("facing_left")), "Knockback should not flip a left-facing knight to right.")
	if left_sprite != null:
		assertions.assert_true(left_sprite.flip_h, "Left-facing hurt animation should stay flipped while knockback moves right.")
	left_facing_knight.call("update_hurt", get_knight_damage_knockback_full_duration(left_facing_knight))
	left_facing_knight.call("update_facing", Vector2.RIGHT)
	assertions.assert_eq(left_facing_knight.get("last_horizontal_facing_direction"), "right", "Knight facing should update normally after knockback clears.")
	left_facing_knight.queue_free()
	left_hit_player.queue_free()
	await tree.process_frame


func get_knight_damage_knockback_half_duration(knight: Node) -> float:
	return maxf(get_knight_damage_knockback_full_duration(knight) * 0.5, 0.01)


func get_knight_damage_knockback_full_duration(knight: Node) -> float:
	var tuning: Resource = knight.get("tuning") as Resource
	return float(tuning.damage_knockback_duration) if tuning != null else 0.12


func assert_campfire_wolf_damage_contract(assertions: TestAssertions, tree: SceneTree):
	var player := MockPlayer.new()
	tree.root.add_child(player)
	await tree.process_frame

	var campfire := await instantiate_scene(assertions, tree, CAMPFIRE_SCENE)
	assertions.assert_true(campfire != null, "Campfire base should instantiate.")
	if campfire == null:
		player.queue_free()
		await tree.process_frame
		return

	assertions.assert_true(campfire.is_in_group("campfire_bases"), "Campfire base should join campfire_bases.")
	assertions.assert_true(campfire.get_node_or_null("LayoutRoot") != null, "Campfire base should have LayoutRoot.")
	assertions.assert_true(campfire.get_node_or_null("CampAggroArea") is Area2D, "Campfire base should expose an editable CampAggroArea.")
	assertions.assert_true(campfire.get_node_or_null("CampAggroArea/CollisionShape2D") is CollisionShape2D, "Campfire base aggro area should have an editable CollisionShape2D.")
	assertions.assert_true(campfire.get_node_or_null("Effects") == null, "Campfire base should not own an aggregate Effects node.")
	assertions.assert_true(str(campfire.get("current_variant_id")) != "", "Campfire base should select a variant on ready.")
	assertions.assert_false(campfire.get_node_or_null("LayoutRoot").get_children().is_empty(), "Campfire base should instance a variant layout.")
	var campfire_sprite := get_camp_component_sprite(campfire, "Campfire")
	var banner_sprite := get_camp_component_sprite(campfire, "MeleeBanner")
	assertions.assert_true(campfire_sprite != null, "Campfire base should discover the campfire component's animated child.")
	assertions.assert_true(banner_sprite != null, "Campfire base should discover the banner component's animated child.")

	var tents: Array = campfire.get("tents")
	assertions.assert_true(not tents.is_empty(), "Campfire base layout should include at least one tent.")
	var first_tent: Node = tents[0]
	assertions.assert_true(first_tent != null and first_tent.get_node_or_null("HurtBox") != null, "Campfire tent should have a HurtBox.")
	assertions.assert_true(first_tent != null and first_tent.get_node_or_null("HealthBarDisplay/HealthBar") != null, "Campfire tent should have a health bar.")
	assertions.assert_true(first_tent != null and first_tent.get_node_or_null("Effects") is EffectList, "Campfire tent should have its own Effects node.")

	player.form_id = &"human"
	await tree.process_frame
	for tent in tents:
		assert_campfire_tent_effect_visible(assertions, tent, false, "Human-form campfire tent should not show weak-to-wolf.")

	first_tent.call("take_damage", int(first_tent.get("max_health")), false, player)
	assertions.assert_false(bool(first_tent.get("dead")), "Campfire tent should reject human-form damage.")
	assertions.assert_false(first_tent.get_node_or_null("HealthBarDisplay").visible, "Campfire tent health bar should stay hidden after rejected damage.")

	player.form_id = &"wolf"
	await tree.process_frame
	for tent in tents:
		assert_campfire_tent_effect_visible(assertions, tent, true, "Wolf-form live campfire tent should show weak-to-wolf.")

	first_tent.call("take_damage", 1, false, player)
	await tree.process_frame
	assertions.assert_true(first_tent.get_node_or_null("HealthBarDisplay").visible, "Campfire tent health bar should show after partial wolf damage.")
	first_tent.call("take_damage", int(first_tent.get("max_health")), false, player)
	await tree.process_frame
	assertions.assert_true(bool(first_tent.get("dead")), "Campfire tent should accept wolf-form damage.")
	assertions.assert_false(first_tent.get_node_or_null("HealthBarDisplay").visible, "Destroyed tent health bar should hide.")
	assert_campfire_tent_effect_visible(assertions, first_tent, false, "Destroyed campfire tent should hide weak-to-wolf.")
	if tents.size() > 1:
		assertions.assert_false(bool(campfire.get("dead")), "Destroying one tent should not destroy the whole base while other tents live.")
		for tent in tents:
			if tent != first_tent:
				assert_campfire_tent_effect_visible(assertions, tent, true, "Remaining live campfire tents should keep weak-to-wolf visible.")

	for tent in tents:
		if tent != null and not bool(tent.get("dead")):
			tent.call("take_damage", int(tent.get("max_health")), false, player)
	await tree.process_frame
	assertions.assert_true(bool(campfire.get("dead")), "Campfire base should be destroyed only after all tents are destroyed.")
	assertions.assert_true(campfire.visible, "Destroyed campfire base should remain visible for ruined camp visuals.")
	if campfire_sprite != null:
		assertions.assert_eq(str(campfire_sprite.animation), "unlit", "Destroyed campfire base should switch campfire component to unlit.")
	if banner_sprite != null:
		assertions.assert_eq(str(banner_sprite.animation), "ruined", "Destroyed campfire base should switch banner component to ruined.")
	for tent in tents:
		assert_campfire_tent_effect_visible(assertions, tent, false, "Fully destroyed campfire base should have no visible tent effects.")

	campfire.call("restore_alive", false)
	await tree.process_frame
	assertions.assert_false(bool(campfire.get("dead")), "Campfire base should restore alive in wolf-form effect test.")
	campfire_sprite = get_camp_component_sprite(campfire, "Campfire")
	banner_sprite = get_camp_component_sprite(campfire, "MeleeBanner")
	if campfire_sprite != null:
		assertions.assert_eq(str(campfire_sprite.animation), "lit", "Restored campfire base should switch campfire component to lit.")
	if banner_sprite != null:
		assertions.assert_eq(str(banner_sprite.animation), "intact", "Restored campfire base should switch banner component to intact.")
	for tent in campfire.get("tents"):
		assert_campfire_tent_effect_visible(assertions, tent, true, "Restored live campfire tent should show weak-to-wolf while player remains wolf.")

	var saved_state: Dictionary = campfire.call("collect_story_save_state")
	assertions.assert_has_key(saved_state, "variant_id", "Campfire save state should include variant_id.")
	assertions.assert_has_key(saved_state, "tents", "Campfire save state should include per-tent state.")

	campfire.queue_free()
	player.queue_free()
	await tree.process_frame


func assert_campfire_tent_effect_visible(assertions: TestAssertions, tent: Node, expected_visible: bool, message: String):
	var effects: EffectList = tent.get_node_or_null("Effects") as EffectList
	assertions.assert_true(effects != null, "%s Effects node should exist." % message)
	if effects == null:
		return

	assertions.assert_eq(effects.visible, expected_visible, message)
	if not expected_visible:
		return

	var effect_sprite := get_effect_sprite(effects, WEAK_TO_WOLF_EFFECT)
	assertions.assert_true(effect_sprite != null, "%s Effect sprite should exist." % message)
	if effect_sprite != null:
		assertions.assert_eq(str(effect_sprite.animation), WEAK_TO_WOLF_EFFECT, "%s Effect sprite should play weak_to_wolf." % message)
		assertions.assert_true(effect_sprite.visible, "%s Effect sprite should be visible." % message)


func get_effect_sprite(effects: EffectList, anim_name: String) -> AnimatedSprite2D:
	var effect_sprite := effects.get_node_or_null(anim_name) as AnimatedSprite2D
	if effect_sprite != null:
		return effect_sprite
	if effects.get("effect_sprites") is Dictionary:
		return (effects.get("effect_sprites") as Dictionary).get(anim_name) as AnimatedSprite2D

	return null


func get_camp_component_sprite(campfire: Node, component_name: String) -> AnimatedSprite2D:
	var layout_root := campfire.get_node_or_null("LayoutRoot")
	if layout_root == null:
		return null

	var component := layout_root.find_child(component_name, true, false)
	if component is AnimatedSprite2D:
		return component as AnimatedSprite2D
	if component == null:
		return null

	return component.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D


func assert_knight_camp_encounter_helper(assertions: TestAssertions, tree: SceneTree):
	var root := Node2D.new()
	tree.root.add_child(root)

	var campfire_packed: PackedScene = load(CAMPFIRE_SCENE)
	var knight_packed: PackedScene = load(MELEE_SCENE)
	var player := MockPlayer.new()
	var campfire := campfire_packed.instantiate()
	var knight := knight_packed.instantiate()
	var second_knight := knight_packed.instantiate()
	var controller := ENCOUNTER_CONTROLLER_SCRIPT.new()

	root.add_child(player)
	root.add_child(campfire)
	knight.global_position = Vector2(96, 0)
	second_knight.global_position = Vector2(128, 0)
	root.add_child(controller)
	root.add_child(knight)
	root.add_child(second_knight)
	knight.set("campfire_base_path", knight.get_path_to(campfire))
	second_knight.set("campfire_base_path", second_knight.get_path_to(campfire))
	await tree.process_frame
	var original_home: Vector2 = knight.call("get_home_position")
	var knight_tuning: Resource = knight.get("tuning") as Resource
	if knight_tuning != null:
		var fast_tuning := knight_tuning.duplicate()
		fast_tuning.respawn_delay_seconds = 0.01
		knight.set("tuning", fast_tuning)

	controller.call("refresh_members")
	controller.call("connect_campfires")
	controller.call("connect_knights")
	controller.call("apply_campfire_rules")
	await tree.process_frame
	var detection_area := knight.get_node_or_null("DetectionArea") as Area2D
	assertions.assert_true(detection_area != null, "Camp-linked knight should expose its personal DetectionArea.")
	if detection_area != null:
		assertions.assert_false(detection_area.monitoring, "Camp-linked personal DetectionArea should stay disabled while the knight is inside camp bounds.")
	assertions.assert_true(knight.get("respawn_enabled") == true, "Knight respawn should start enabled while the linked campfire is alive.")
	assertions.assert_eq(controller.call("get_camp_max_knight_count", campfire), 5, "Linked campfire variant should expose its max knight roster to the encounter helper.")
	knight.call("_on_detection_body_entered", player)
	var campfire_base_id := str(campfire.get("campfire_base_id"))
	assertions.assert_false(controller.get("camp_aggro_by_id").has(campfire_base_id), "Knight-only detection should not start camp aggro for linked camp knights.")
	knight.call("_on_tracking_body_entered", player)
	assertions.assert_eq(knight.get("state"), "idle", "Camp-linked knight tracking should not start chase before camp aggro.")
	assertions.assert_false(bool(knight.call("should_chase_player")), "Camp-linked knight tracking alone should not satisfy chase rules before camp aggro.")
	var animated_sprite := knight.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		assertions.assert_true(str(animated_sprite.animation).begins_with("idle"), "Camp-linked knight tracking should keep the idle animation before camp aggro.")
	assertions.assert_false(controller.get("camp_aggro_by_id").has(campfire_base_id), "Camp-linked knight tracking should not start camp aggro before the campfire detects the player.")
	player.global_position = campfire.global_position
	knight.call("_on_tracking_body_exited", player)
	second_knight.call("_on_tracking_body_exited", player)
	await tree.physics_frame
	knight.call("_on_died")
	await tree.create_timer(0.05).timeout
	assertions.assert_false(knight.get("dead") == true, "Linked knight should respawn while player is already inside the camp aggro area.")
	assertions.assert_true(controller.get("camp_aggro_by_id").has(campfire_base_id), "Respawn should refresh camp aggro when the player is already inside CampAggroArea.")
	assertions.assert_eq(knight.get("state"), "chase", "Respawned linked knight should chase an already-overlapping camp player.")
	controller.get("camp_aggro_by_id").erase(campfire_base_id)
	controller.get("camp_barked_by_id").erase(campfire_base_id)
	knight.call("return_to_camp")
	second_knight.call("return_to_camp")
	second_knight.call("_on_tracking_body_entered", player)
	controller.call("_on_campfire_player_detected", campfire, player)
	controller.call("_on_campfire_player_detected", campfire, player)
	assertions.assert_true(knight.get("encounter_dialogue_played") != second_knight.get("encounter_dialogue_played"), "Camp encounter helper should allow only one first-detection bark per camp aggro event.")
	assertions.assert_eq(knight.get("state"), "chase", "Camp detection bark should immediately force the detecting knight to chase.")
	assertions.assert_eq(second_knight.get("state"), "chase", "Camp detection bark should immediately force linked knights to chase.")
	assertions.assert_false(bool(knight.get("current_movement_uses_navigation")) == false and (knight.get("velocity") as Vector2).length() > 0.0, "Camp detection should not start direct fallback movement for the first linked knight.")
	assertions.assert_false(bool(second_knight.get("current_movement_uses_navigation")) == false and (second_knight.get("velocity") as Vector2).length() > 0.0, "Camp detection should not start direct fallback movement for linked knights.")
	assertions.assert_true(bool(knight.call("should_chase_player")), "Camp-linked knight tracking should maintain chase after camp aggro starts.")
	player.transforming_forms = true
	player.transformation_state_changed.emit(true)
	knight.call("_on_tracking_body_exited", player)
	second_knight.call("_on_tracking_body_exited", player)
	assertions.assert_true(controller.get("camp_aggro_by_id").has(campfire_base_id), "Camp aggro should not clear from transform-caused tracking exits.")
	assertions.assert_true(bool(knight.get("player_in_tracking")), "Camp-linked knight should preserve tracking during Saorise transformation.")
	assertions.assert_true(bool(second_knight.get("player_in_tracking")), "Sibling camp-linked knight should preserve tracking during Saorise transformation.")
	player.transforming_forms = false
	player.transformation_state_changed.emit(false)
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	player.global_position = campfire.global_position
	await tree.physics_frame
	campfire.emit_signal("player_tracking_exited", campfire, player)
	assertions.assert_false(controller.get("camp_aggro_by_id").has(campfire_base_id), "Camp aggro should clear when CampTrackingArea reports the player exited.")
	await tree.physics_frame
	await tree.physics_frame
	assertions.assert_true(controller.get("camp_aggro_by_id").has(campfire_base_id), "Camp aggro should refresh if the player is already inside CampAggroArea when all knights lose tracking.")
	assertions.assert_eq(knight.get("state"), "chase", "Overlap refresh should force the first linked knight back to chase.")
	assertions.assert_eq(second_knight.get("state"), "chase", "Overlap refresh should force sibling linked knights back to chase.")
	player.global_position = campfire.global_position + Vector2(10000, 0)
	await tree.physics_frame
	campfire.emit_signal("player_tracking_exited", campfire, player)
	await tree.physics_frame
	await tree.physics_frame
	assertions.assert_false(controller.get("camp_aggro_by_id").has(campfire_base_id), "Camp aggro should stay cleared when the player is outside CampAggroArea after all knights lose tracking.")

	player.global_position = campfire.global_position + Vector2(720, 0)
	knight.global_position = campfire.global_position + Vector2(680, 0)
	second_knight.global_position = campfire.global_position + Vector2(700, 0)
	knight.call("refresh_personal_detection_enabled")
	second_knight.call("refresh_personal_detection_enabled")
	await tree.process_frame
	if detection_area != null:
		assertions.assert_false(detection_area.monitoring, "Camp-linked personal DetectionArea should stay disabled outside camp bounds; CampfireBase owns detection.")
	var second_detection_area := second_knight.get_node_or_null("DetectionArea") as Area2D
	if second_detection_area != null:
		assertions.assert_false(second_detection_area.monitoring, "Sibling camp-linked DetectionArea should stay disabled outside camp bounds.")
	knight.call("_on_detection_body_entered", player)
	assertions.assert_false(bool(knight.get("personal_aggro_active")), "Camp-linked knight DetectionArea should not start personal aggro outside camp bounds.")
	assertions.assert_false(controller.get("camp_aggro_by_id").has(campfire_base_id), "Camp-linked knight DetectionArea should not write camp-wide aggro state.")
	controller.call("_on_campfire_player_detected", campfire, player)
	assertions.assert_true(controller.get("camp_aggro_by_id").has(campfire_base_id), "Campfire detection should own camp-wide aggro state outside camp bounds.")
	assertions.assert_eq(knight.get("state"), "chase", "Campfire detection should force the first linked knight to chase.")
	assertions.assert_eq(second_knight.get("state"), "chase", "Campfire detection should force sibling linked knights to chase.")
	player.transforming_forms = true
	player.transformation_state_changed.emit(true)
	campfire.emit_signal("player_tracking_exited", campfire, player)
	assertions.assert_true(controller.get("camp_aggro_by_id").has(campfire_base_id), "Transform-caused camp tracking exit should not clear camp-wide aggro.")
	assertions.assert_eq(knight.get("state"), "chase", "Camp-linked knight should keep chasing during Saorise transformation.")
	player.transforming_forms = false
	player.transformation_state_changed.emit(false)
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	player.global_position = campfire.global_position + Vector2(10000, 0)
	campfire.emit_signal("player_tracking_exited", campfire, player)
	assertions.assert_false(controller.get("camp_aggro_by_id").has(campfire_base_id), "Camp-wide aggro should clear when CampTrackingArea loses the player.")
	assertions.assert_eq(knight.get("state"), "return_home", "Camp-linked knight should return when camp tracking ends.")
	assertions.assert_eq(second_knight.get("state"), "return_home", "Sibling camp-linked knight should return when camp tracking ends.")

	knight.global_position = original_home + Vector2(48, 0)
	if knight.has_method("clear_active_dialogue_bubble"):
		knight.clear_active_dialogue_bubble()
	if second_knight.has_method("clear_active_dialogue_bubble"):
		second_knight.clear_active_dialogue_bubble()
	knight.call("_on_died")
	await tree.create_timer(0.05).timeout
	assertions.assert_false(knight.get("dead") == true, "Linked knight should respawn at its authored home while campfire is alive.")
	assertions.assert_true(is_vector_approx(knight.global_position, original_home), "Linked knight respawn should use its editor-authored home position.")
	var starting_variant_id := str(campfire.get("current_variant_id"))

	for tent in campfire.get("tents"):
		if tent != null and tent.has_method("destroy"):
			tent.destroy()
	await tree.process_frame
	assertions.assert_false(knight.get("respawn_enabled") == true, "Destroyed campfire should disable linked knight respawn during the active visit.")
	controller.get("camp_aggro_by_id").erase(campfire_base_id)
	campfire.call("refresh_player_detection")
	await tree.physics_frame
	assertions.assert_false(controller.get("camp_aggro_by_id").has(campfire_base_id), "Destroyed campfire should not refresh aggro from an already-overlapping player.")

	var state: Dictionary = controller.call("collect_level_state")
	assertions.assert_has_key(state, "destroyed_campfire_base_ids", "Knight camp state should track destroyed campfire base ids locally.")
	assertions.assert_has_key(state, "knights", "Knight camp state should include knight snapshots locally.")
	assertions.assert_has_key(state, "campfires", "Knight camp state should include campfire snapshots locally.")
	var campfire_states: Array = state.get("campfires", [])
	assertions.assert_true(not campfire_states.is_empty() and (campfire_states[0] as Dictionary).has("variant_id"), "Knight camp state should preserve campfire variant ids locally.")

	controller.call("prepare_for_route_exit")
	await tree.process_frame
	assertions.assert_true(knight.get("respawn_enabled") == true, "Route exit preparation should restore linked knight respawn for the next visit.")
	assertions.assert_false(campfire.get("dead") == true, "Route exit preparation should restore the campfire for the next visit.")
	assertions.assert_true(str(campfire.get("current_variant_id")) != "", "Route exit preparation should leave the campfire with a live variant.")

	var restored_variant_id := str(campfire.get("current_variant_id"))
	campfire.call("reset_for_level_entry")
	await tree.process_frame
	assertions.assert_eq(str(campfire.get("current_variant_id")), restored_variant_id, "Alive campfire reset should keep the same variant.")
	campfire.call("apply_story_save_state", {"variant_id": starting_variant_id, "dead": false, "tents": []})
	assertions.assert_eq(str(campfire.get("current_variant_id")), starting_variant_id, "Campfire save restore should restore the saved variant id.")

	root.queue_free()
	await tree.process_frame


func assert_knight_camp_level_support(assertions: TestAssertions, tree: SceneTree):
	var level := Node2D.new()
	var hostile_root := Node2D.new()
	var campfire_packed: PackedScene = load(CAMPFIRE_SCENE)
	var knight_packed: PackedScene = load(MELEE_SCENE)
	var player := MockPlayer.new()
	var campfire := campfire_packed.instantiate()
	var knight := knight_packed.instantiate()
	var support := LEVEL_SUPPORT_SCRIPT.new()

	hostile_root.name = "HostileNPCs"
	campfire.set("campfire_base_id", &"campfire_base_1")
	knight.global_position = Vector2(96, 0)
	level.add_child(hostile_root)
	hostile_root.add_child(player)
	hostile_root.add_child(campfire)
	hostile_root.add_child(knight)
	level.add_child(support)
	tree.root.add_child(level)
	knight.set("campfire_base_path", knight.get_path_to(campfire))
	support.configure(level, hostile_root, hostile_root)
	await tree.process_frame
	await tree.process_frame

	var controller: Node = support.call("get_knight_camp_controller")
	assertions.assert_true(controller != null, "Shared knight camp level support should create an encounter controller.")
	if controller != null:
		assertions.assert_eq((controller.get("campfires") as Array).size(), 1, "Shared level support should discover campfire bases from the configured hostile root.")
		assertions.assert_eq((controller.get("knights") as Array).size(), 1, "Shared level support should discover linked knights from the configured hostile root.")
		assert_campfire_signal_wired(assertions, campfire, controller, "Shared level support")
		assert_knight_signals_wired(assertions, knight, controller, "Shared level support")
		campfire.emit_signal("player_detected", campfire, player)
		assertions.assert_eq(knight.get("state"), "chase", "Shared level support should route campfire detection into linked knight aggro.")

		var state: Dictionary = support.call("collect_level_state")
		assertions.assert_has_key(state, "knights", "Shared level support should expose knight camp state.")
		assertions.assert_has_key(state, "campfires", "Shared level support should expose campfire state.")

	level.queue_free()
	await tree.process_frame


func assert_multi_camp_identity_isolation(assertions: TestAssertions, tree: SceneTree):
	var root := Node2D.new()
	tree.root.add_child(root)

	var campfire_packed: PackedScene = load(CAMPFIRE_SCENE)
	var knight_packed: PackedScene = load(MELEE_SCENE)
	var player := MockPlayer.new()
	var campfire_a := campfire_packed.instantiate()
	var campfire_b := campfire_packed.instantiate()
	var knight_a := knight_packed.instantiate()
	var knight_b := knight_packed.instantiate()
	var controller := ENCOUNTER_CONTROLLER_SCRIPT.new()

	campfire_a.set("campfire_base_id", &"campfire_base_a")
	campfire_b.set("campfire_base_id", &"campfire_base_b")
	campfire_b.global_position = Vector2(320, 0)
	knight_a.global_position = Vector2(64, 0)
	knight_b.global_position = Vector2(384, 0)
	root.add_child(player)
	root.add_child(campfire_a)
	root.add_child(campfire_b)
	root.add_child(controller)
	root.add_child(knight_a)
	root.add_child(knight_b)
	knight_a.set("campfire_base_path", knight_a.get_path_to(campfire_a))
	knight_b.set("campfire_base_path", knight_b.get_path_to(campfire_b))
	await tree.process_frame
	var knight_b_tuning: Resource = knight_b.get("tuning") as Resource
	if knight_b_tuning != null:
		var fast_tuning := knight_b_tuning.duplicate()
		fast_tuning.respawn_delay_seconds = 0.01
		knight_b.set("tuning", fast_tuning)

	controller.call("refresh_members")
	controller.call("connect_campfires")
	controller.call("connect_knights")
	controller.call("apply_campfire_rules")
	assertions.assert_eq(int(campfire_a.get("campfire_base_index")), 0, "First discovered campfire base should receive index 0.")
	assertions.assert_eq(int(campfire_b.get("campfire_base_index")), 1, "Second discovered campfire base should receive index 1.")
	assertions.assert_eq(int(knight_a.get("knight_index")), 0, "First camp's linked knight should receive local index 0.")
	assertions.assert_eq(int(knight_b.get("knight_index")), 0, "Second camp's linked knight should receive its own local index 0.")
	assertions.assert_eq(controller.call("get_campfire_base_by_index", 1), campfire_b, "Camp controller should look up campfire bases by friendly index.")
	assertions.assert_eq(controller.call("get_linked_knight_by_index", campfire_b, 0), knight_b, "Camp controller should look up linked knights by local friendly index.")

	for tent in campfire_a.get("tents"):
		if tent != null and tent.has_method("destroy"):
			tent.destroy()
	await tree.process_frame
	assertions.assert_false(knight_a.get("respawn_enabled") == true, "Destroying campfire base A should disable only camp A knight respawn.")
	assertions.assert_true(knight_b.get("respawn_enabled") == true, "Destroying campfire base A should not disable camp B knight respawn.")

	controller.call("_on_campfire_player_detected", campfire_b, player)
	assertions.assert_eq(knight_b.get("state"), "chase", "Active campfire base B should still aggro its linked knight after camp A is destroyed.")
	knight_b.call("_on_died")
	await tree.create_timer(0.05).timeout
	assertions.assert_false(knight_b.get("dead") == true, "Active campfire base B should still respawn linked knights after camp A is destroyed.")

	var state: Dictionary = controller.call("collect_level_state")
	assertions.assert_has_key(state, "destroyed_campfire_base_ids", "Knight camp state should write campfire base destroyed ids.")
	assertions.assert_true((state.get("destroyed_campfire_base_ids", []) as Array).has("campfire_base_a"), "Destroyed campfire base state should use campfire_base_id.")
	assertions.assert_false((state.get("destroyed_campfire_base_ids", []) as Array).has("campfire_base_b"), "Destroyed campfire base state should not include the active campfire base.")

	var duplicate_campfire := campfire_packed.instantiate()
	var duplicate_knight := knight_packed.instantiate()
	duplicate_campfire.set("campfire_base_id", &"campfire_base_b")
	root.add_child(duplicate_campfire)
	root.add_child(duplicate_knight)
	duplicate_knight.set("campfire_base_path", duplicate_knight.get_path_to(duplicate_campfire))
	await tree.process_frame
	controller.call("refresh_members")
	var duplicate_messages: Array = controller.call("validate_unique_campfire_base_ids")
	assertions.assert_true(not duplicate_messages.is_empty(), "Duplicate campfire_base_id values in one level should be detected as authoring errors.")

	root.queue_free()
	await tree.process_frame

	var level_a := Node2D.new()
	var level_b := Node2D.new()
	var scoped_campfire_a := campfire_packed.instantiate()
	var scoped_campfire_b := campfire_packed.instantiate()
	var scoped_controller_a := ENCOUNTER_CONTROLLER_SCRIPT.new()
	var scoped_controller_b := ENCOUNTER_CONTROLLER_SCRIPT.new()
	scoped_campfire_a.set("campfire_base_id", &"campfire_base_1")
	scoped_campfire_b.set("campfire_base_id", &"campfire_base_1")
	tree.root.add_child(level_a)
	tree.root.add_child(level_b)
	level_a.add_child(scoped_campfire_a)
	level_a.add_child(scoped_controller_a)
	level_b.add_child(scoped_campfire_b)
	level_b.add_child(scoped_controller_b)
	await tree.process_frame
	scoped_controller_a.call("refresh_members")
	scoped_controller_b.call("refresh_members")
	assertions.assert_true((scoped_controller_a.call("validate_unique_campfire_base_ids") as Array).is_empty(), "A campfire_base_id should be valid when unique inside its own level scope.")
	assertions.assert_true((scoped_controller_b.call("validate_unique_campfire_base_ids") as Array).is_empty(), "The same campfire_base_id should be valid in a different level scope.")
	level_a.queue_free()
	level_b.queue_free()
	await tree.process_frame


func assert_split_knight_navigation_support(assertions: TestAssertions, tree: SceneTree):
	var level := Node2D.new()
	level.name = "FutureCampLevel"
	var playable_world := Node2D.new()
	playable_world.name = "PlayableWorld"
	var navigation := Node2D.new()
	navigation.name = "Navigation"
	var character_regions := Node2D.new()
	character_regions.name = "CharacterNavigationRegions"
	var level_region := NavigationRegion2D.new()
	level_region.name = "LevelCharacterNavigationRegion"
	level_region.navigation_layers = DEFAULT_CHARACTER_NAVIGATION_LAYER
	assign_square_navigation_polygon(level_region, Vector2(-512, -512), Vector2(512, 512))
	var source_geometry := Node2D.new()
	source_geometry.name = "NavigationSourceGeometry"
	source_geometry.add_to_group("navigation_polygon_source_group")
	var environment := Node2D.new()
	environment.name = "Environment"
	var characters := Node2D.new()
	characters.name = "Characters"
	var hostile_root := Node2D.new()
	hostile_root.name = "HostileNPCs"

	level.add_child(playable_world)
	playable_world.add_child(navigation)
	navigation.add_child(character_regions)
	character_regions.add_child(level_region)
	level_region.add_child(source_geometry)
	playable_world.add_child(environment)
	environment.add_child(characters)
	characters.add_child(hostile_root)
	tree.root.add_child(level)

	var support := LEVEL_SUPPORT_SCRIPT.new()
	support.name = "KnightCampLevelSupport"
	level.add_child(support)
	var campfire_packed: PackedScene = load(CAMPFIRE_SCENE)
	assertions.assert_true(campfire_packed != null, "Campfire scene should load for split navigation support.")
	if campfire_packed == null:
		level.queue_free()
		await tree.process_frame
		return

	var campfire_a := campfire_packed.instantiate()
	var campfire_b := campfire_packed.instantiate()
	campfire_a.set("campfire_base_id", &"campfire_base_1")
	campfire_b.set("campfire_base_id", &"campfire_base_2")
	campfire_a.global_position = Vector2(-128, 0)
	campfire_b.global_position = Vector2(128, 0)
	hostile_root.add_child(campfire_a)
	hostile_root.add_child(campfire_b)
	await tree.process_frame

	support.configure(level, hostile_root, hostile_root)
	await tree.process_frame
	assertions.assert_eq(level_region.navigation_polygon.get_polygon_count(), 1, "Camp support should not mutate the authored level-wide navigation polygon.")

	var active_camp_region := campfire_a.call("get_active_camp_navigation_region") as NavigationRegion2D
	assertions.assert_true(active_camp_region != null, "CampfireBase should keep the active CampNavigationRegion for linked knight pathing and camp bounds.")
	if active_camp_region != null:
		assertions.assert_true(active_camp_region.enabled, "CampNavigationRegion should be active for camp-linked knight pathing.")
		assertions.assert_eq(active_camp_region.navigation_layers, CAMPFIRE_BASE_KNIGHT_NAVIGATION_LAYER, "CampNavigationRegion should use the campfire-base knight navigation layer.")

	var controller: Node = support.call("get_knight_camp_controller")
	var linked_knight: Node = controller.call("get_linked_knight_by_index", campfire_a, 0) if controller != null else null
	assertions.assert_true(linked_knight != null, "Camp support should discover a linked camp knight.")
	if linked_knight != null:
		var linked_agent := linked_knight.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
		assertions.assert_true(linked_agent != null, "Linked camp knight should have a NavigationAgent2D.")
		if linked_agent != null:
			assertions.assert_eq(linked_agent.navigation_layers, CAMPFIRE_BASE_KNIGHT_NAVIGATION_LAYER, "Linked camp knights should use the camp navigation layer.")
		var linked_detection := linked_knight.get_node_or_null("DetectionArea") as Area2D
		var linked_tracking := linked_knight.get_node_or_null("TrackingArea") as Area2D
		await tree.physics_frame
		if linked_detection != null:
			assertions.assert_false(linked_detection.monitoring, "Camp-linked knight DetectionArea should be disabled; campfire base owns detection.")
		if linked_tracking != null:
			assertions.assert_false(linked_tracking.monitoring, "Camp-linked knight TrackingArea should be disabled; campfire base owns tracking.")

	level.queue_free()
	await tree.process_frame


func assert_starting_wilderness_campfire_identity_and_indexes(assertions: TestAssertions, tree: SceneTree):
	var packed: PackedScene = load(STARTING_WILDERNESS_SCENE)
	assertions.assert_true(packed != null, "Starting Wilderness should load for campfire identity/index coverage.")
	if packed == null:
		return

	var level := packed.instantiate()
	assertions.assert_true(level != null, "Starting Wilderness should instantiate for campfire identity/index coverage.")
	if level == null:
		return

	tree.root.add_child(level)
	await tree.process_frame
	await tree.process_frame
	var flow := level.get_node_or_null("StartingWildernessFlowController")
	var controller: Node = flow.get("knight_camp_controller") if flow != null else null
	assertions.assert_true(controller != null, "Starting Wilderness should expose a knight camp controller for identity/index coverage.")
	if controller != null:
		controller.call("refresh_members")
		var campfire_0: Node = controller.call("get_campfire_base_by_index", 0)
		var campfire_1: Node = controller.call("get_campfire_base_by_index", 1)
		assertions.assert_true(campfire_0 != null and campfire_1 != null, "Starting Wilderness should expose two indexed campfire bases.")
		if campfire_0 != null and campfire_1 != null:
			assertions.assert_ne(str(campfire_0.get("campfire_base_id")), str(campfire_1.get("campfire_base_id")), "Starting Wilderness campfire bases should have unique campfire_base_id values.")
			assertions.assert_eq(str(campfire_0.get("campfire_base_id")), "campfire_base_1", "Starting Wilderness first campfire base should use the authored readable id.")
			assertions.assert_eq(str(campfire_1.get("campfire_base_id")), "campfire_base_2", "Starting Wilderness second campfire base should use the authored readable id.")
		assertions.assert_true((controller.call("validate_unique_campfire_base_ids") as Array).is_empty(), "Starting Wilderness campfire_base_id values should validate as unique within the level.")

	var banshee_root := level.get_node_or_null("PlayableWorld/Environment/Characters/HostileNPCs/Banshees")
	if banshee_root != null:
		var expected_banshee_index := 0
		for child in banshee_root.get_children():
			if child.is_in_group("hostile_npcs") and child.has_method("set_combat_variant"):
				assertions.assert_eq(int(child.get("banshee_index")), expected_banshee_index, "Starting Wilderness banshees should receive deterministic per-level indexes.")
				expected_banshee_index += 1

	var male_villager := level.get_node_or_null("PlayableWorld/Environment/Characters/NPCs/MaleVillager")
	var female_villager := level.get_node_or_null("PlayableWorld/Environment/Characters/NPCs/FemaleVillager")
	if male_villager != null and female_villager != null:
		assertions.assert_eq(int(male_villager.get("villager_index")), 0, "Starting Wilderness male villager should receive deterministic villager index 0.")
		assertions.assert_eq(int(female_villager.get("villager_index")), 1, "Starting Wilderness female villager should receive deterministic villager index 1.")
		assertions.assert_eq(int(male_villager.get("villager_group_index")), 0, "Starting Wilderness male villager should receive male group index 0.")
		assertions.assert_eq(int(female_villager.get("villager_group_index")), 0, "Starting Wilderness female villager should receive female group index 0.")

	level.queue_free()
	await tree.process_frame


func assert_knight_camp_navigation_switching(assertions: TestAssertions, tree: SceneTree):
	var root := Node2D.new()
	tree.root.add_child(root)

	var campfire_packed: PackedScene = load(CAMPFIRE_SCENE)
	var knight_packed: PackedScene = load(MELEE_SCENE)
	var campfire := campfire_packed.instantiate()
	var knight := knight_packed.instantiate()
	var second_knight := knight_packed.instantiate()

	root.add_child(campfire)
	root.add_child(knight)
	root.add_child(second_knight)
	await tree.process_frame
	knight.set("campfire_base_path", knight.get_path_to(campfire))
	second_knight.set("campfire_base_path", second_knight.get_path_to(campfire))

	var region := campfire.call("get_active_camp_navigation_region") as NavigationRegion2D
	assertions.assert_true(region != null, "Active campfire variant should expose a navigation region for linked knights.")
	if region != null:
		assign_square_navigation_polygon(region, Vector2(-256, -256), Vector2(256, 256))
		var inside_player := MockPlayer.new()
		inside_player.global_position = campfire.global_position + Vector2(16, 0)
		root.add_child(inside_player)
		await tree.process_frame
		knight.global_position = campfire.global_position
		assertions.assert_true(bool(knight.call("should_use_navigation_for_chase", campfire.global_position + Vector2(16, 0))), "Linked knight should use NavigationAgent2D for chase.")
		knight.call("force_aggro", inside_player)
		assertions.assert_false(bool(knight.get("current_movement_uses_navigation")) == false and (knight.get("velocity") as Vector2).length() > 0.0, "Camp aggro should not produce non-navigation direct chase velocity.")
		assertions.assert_true(bool(knight.call("should_direct_chase_outside_camp_navigation", campfire.global_position + Vector2(360, 0))), "Linked knight should direct-chase when the chase target is outside the active camp polygon during camp aggro.")
		knight.global_position = campfire.global_position + Vector2(360, 0)
		assertions.assert_true(bool(knight.call("should_direct_return_until_camp_navigation")), "Linked knight should direct-return until it reaches the active camp polygon again.")
		region.navigation_polygon = NavigationPolygon.new()
		knight.global_position = campfire.global_position
		assertions.assert_true(bool(knight.call("should_direct_chase_outside_camp_navigation", campfire.global_position)), "Linked knight should direct-chase if the active camp navigation polygon is empty during camp aggro.")

	var player := MockPlayer.new()
	player.global_position = Vector2(240, 0)
	root.add_child(player)
	await tree.process_frame
	knight.set("player", player)
	second_knight.set("player", player)
	knight.set("player_in_tracking", true)
	second_knight.set("player_in_tracking", true)
	var first_chase_target: Vector2 = knight.call("get_chase_target_position")
	var second_chase_target: Vector2 = second_knight.call("get_chase_target_position")
	assertions.assert_ne(first_chase_target, player.global_position, "Linked melee knights should use small navigation target offsets outside attack range to avoid perfect overlap.")
	assertions.assert_ne(second_chase_target, player.global_position, "Every linked melee knight outside attack range should get a spread navigation target.")
	assertions.assert_ne(first_chase_target, second_chase_target, "Stable linked melee spread targets should differ between rostered knights.")
	knight.global_position = player.global_position + Vector2(44, 0)
	assertions.assert_eq(knight.call("get_chase_target_position"), player.global_position, "Linked melee knights should drop spread targeting once close enough to attack.")

	campfire.call("select_variant_by_id", &"campfire_base_c")
	campfire.call("apply_current_variant")
	await tree.process_frame
	var layout_c := campfire.get("current_layout") as Node2D
	var layout_c_region := layout_c.get_node_or_null("CampNavigationRegion") as NavigationRegion2D
	var outside_player := MockPlayer.new()
	outside_player.global_position = campfire.global_position + Vector2(360, 0)
	root.add_child(outside_player)
	await tree.process_frame
	for knight_name in ["Knight1", "Knight5", "Knight6"]:
		var layout_knight := layout_c_region.get_node_or_null(knight_name) if layout_c_region != null else null
		assertions.assert_true(layout_knight != null, "Layout C should expose %s after roster promotion." % knight_name)
		if layout_knight == null:
			continue
		layout_knight.set("player", outside_player)
		layout_knight.set("player_in_tracking", true)
		assertions.assert_true(bool(layout_knight.call("should_direct_chase_outside_camp_navigation", outside_player.global_position)), "%s should direct-chase when the player is outside Layout C camp navigation." % knight_name)
		layout_knight.call("chase_player")
		assertions.assert_eq(layout_knight.get("state"), "chase", "%s should enter chase when aggroed." % knight_name)
		assertions.assert_true(bool(layout_knight.get("current_movement_uses_navigation")) == false and (layout_knight.get("velocity") as Vector2).length() > 0.0, "%s should direct-chase outside camp navigation during active camp aggro." % knight_name)
		var velocity_before_block: Vector2 = layout_knight.get("velocity") as Vector2
		layout_knight.call("register_blocked_movement")
		assertions.assert_eq(layout_knight.get("velocity"), velocity_before_block, "%s blocked chase should preserve navigation velocity for the active movement grace window." % knight_name)

	root.queue_free()
	await tree.process_frame


func assign_square_navigation_polygon(region: NavigationRegion2D, min_point: Vector2, max_point: Vector2):
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.set_vertices(PackedVector2Array([
		min_point,
		Vector2(max_point.x, min_point.y),
		max_point,
		Vector2(min_point.x, max_point.y),
	]))
	navigation_polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = navigation_polygon


func assert_starting_wilderness_knight_camp_wiring(assertions: TestAssertions, tree: SceneTree):
	var level := await instantiate_scene(assertions, tree, STARTING_WILDERNESS_SCENE)
	assertions.assert_true(level != null, "Starting Wilderness should instantiate for knight camp wiring test.")
	if level == null:
		return

	var flow := level.get_node_or_null("StartingWildernessFlowController")
	assertions.assert_true(flow != null, "Starting Wilderness should have a flow controller.")
	if flow != null:
		assertions.assert_true(flow.get("encounter_controller") != null, "Starting Wilderness should keep its Banshee encounter controller.")
		assertions.assert_true(flow.get("knight_camp_controller") != null, "Starting Wilderness should create a KnightCampEncounterController.")
		assert_real_level_split_navigation_contract(assertions, flow, "Starting Wilderness")
		var controller: Node = flow.get("knight_camp_controller")
		if controller != null:
			var campfire: Node = controller.call("get_campfire_base_by_index", 0)
			var linked_knight: Node = controller.call("get_linked_knight_by_index", campfire, 0) if campfire != null else null
			var player := MockPlayer.new()
			level.add_child(player)
			await tree.process_frame
			if campfire != null and linked_knight != null:
				assert_campfire_signal_wired(assertions, campfire, controller, "Starting Wilderness")
				assert_knight_signals_wired(assertions, linked_knight, controller, "Starting Wilderness")
				campfire.emit_signal("player_detected", campfire, player)
				assertions.assert_eq(linked_knight.get("state"), "chase", "Starting Wilderness campfire signal should force linked knights to chase without manual rewiring.")
		var state: Dictionary = flow.call("collect_level_state")
		assertions.assert_has_key(state, "encounter", "Starting Wilderness state should keep the Banshee encounter key.")
		assertions.assert_has_key(state, "knight_camps", "Starting Wilderness state should include level-local knight camp state.")
		var knight_camp_state: Dictionary = state.get("knight_camps", {})
		assertions.assert_has_key(knight_camp_state, "knights", "Starting Wilderness knight camp state should include knight snapshots.")
		assertions.assert_has_key(knight_camp_state, "campfires", "Starting Wilderness knight camp state should include campfire snapshots.")
		assertions.assert_true(not (knight_camp_state.get("knights", []) as Array).is_empty(), "Starting Wilderness knight camp helper should discover promoted layout knights.")

	level.queue_free()
	await tree.process_frame


func assert_weeping_woods_knight_camp_wiring(assertions: TestAssertions, tree: SceneTree):
	var level := await instantiate_scene(assertions, tree, WEEPING_WOODS_SCENE)
	assertions.assert_true(level != null, "Weeping Woods should instantiate for knight camp wiring test.")
	if level == null:
		return

	var flow := level.get_node_or_null("WeepingWoodsFlowController")
	assertions.assert_true(flow != null, "Weeping Woods should have a flow controller.")
	if flow != null:
		assertions.assert_true(flow.get("knight_camp_controller") != null, "Weeping Woods should create a KnightCampEncounterController for authored campfire bases.")
		assert_real_level_split_navigation_contract(assertions, flow, "Weeping Woods")
		var controller: Node = flow.get("knight_camp_controller")
		if controller != null:
			var campfires: Array = controller.get("campfires") as Array
			var knights: Array = controller.get("knights") as Array
			assertions.assert_eq(campfires.size(), 5, "Weeping Woods should discover all authored campfire bases.")
			assertions.assert_true(not knights.is_empty(), "Weeping Woods camp support should discover promoted layout knights.")
			assertions.assert_true((controller.call("validate_unique_campfire_base_ids") as Array).is_empty(), "Weeping Woods campfire_base_id values should validate as unique within the level.")
			assertions.assert_true((controller.call("validate_campfire_linked_knights") as Array).is_empty(), "Every Weeping Woods campfire base should have linked knights after layout promotion.")

			var campfire: Node = controller.call("get_campfire_base_by_index", 0)
			var linked_knight: Node = controller.call("get_linked_knight_by_index", campfire, 0) if campfire != null else null
			var player := MockPlayer.new()
			level.add_child(player)
			await tree.process_frame
			if campfire != null and linked_knight != null:
				assert_campfire_signal_wired(assertions, campfire, controller, "Weeping Woods")
				assert_knight_signals_wired(assertions, linked_knight, controller, "Weeping Woods")
				campfire.emit_signal("player_detected", campfire, player)
				assertions.assert_eq(linked_knight.get("state"), "chase", "Weeping Woods campfire signal should force linked knights to chase without manual rewiring.")

		var state: Dictionary = flow.call("collect_level_state")
		assertions.assert_has_key(state, "knight_camps", "Weeping Woods state should include level-local knight camp state.")

	level.queue_free()
	await tree.process_frame


func assert_banshee_village_knight_camp_support_is_available(assertions: TestAssertions, tree: SceneTree):
	var level := await instantiate_scene(assertions, tree, BANSHEE_VILLAGE_SCENE)
	assertions.assert_true(level != null, "Banshee Village should instantiate for knight camp support availability test.")
	if level == null:
		return

	var flow := level.get_node_or_null("BansheeVillageFlowController")
	assertions.assert_true(flow != null, "Banshee Village should have a flow controller.")
	if flow != null:
		assertions.assert_true(flow.get("knight_camp_controller") != null, "Banshee Village should create reusable knight camp support so future campfire bases work there.")
		var state: Dictionary = flow.call("collect_level_state")
		assertions.assert_has_key(state, "knight_camps", "Banshee Village state should include reusable knight camp state.")
		var controller: Node = flow.get("knight_camp_controller")
		if controller != null:
			controller.call("refresh_members")
			assertions.assert_true((controller.call("validate_unique_campfire_base_ids") as Array).is_empty(), "Banshee Village empty camp support should validate cleanly when no campfire bases are authored.")

	level.queue_free()
	await tree.process_frame


func assert_real_level_split_navigation_contract(assertions: TestAssertions, flow: Node, label: String):
	var support: Node = flow.get("knight_camp_support") if flow != null else null
	assertions.assert_true(support != null, "%s should expose KnightCampLevelSupport for split camp/level navigation." % label)
	if support == null:
		return
	for variant_id in [&"campfire_base_a", &"campfire_base_b", &"campfire_base_c"]:
		apply_variant_to_all_campfires(flow, variant_id)
		var controller: Node = flow.get("knight_camp_controller") if flow != null else null
		var campfire: Node = controller.call("get_campfire_base_by_index", 0) if controller != null else null
		var camp_region := campfire.call("get_active_camp_navigation_region") as NavigationRegion2D if campfire != null else null
		assertions.assert_true(camp_region != null and camp_region.enabled, "%s active camp region should remain enabled for %s." % [label, variant_id])
		if camp_region != null:
			assertions.assert_eq(camp_region.navigation_layers, CAMPFIRE_BASE_KNIGHT_NAVIGATION_LAYER, "%s active camp region should use camp layer for %s." % [label, variant_id])


func apply_variant_to_all_campfires(flow: Node, variant_id: StringName):
	var controller: Node = flow.get("knight_camp_controller") if flow != null else null
	if controller == null:
		return
	var campfires: Array = controller.get("campfires") as Array
	for campfire in campfires:
		if campfire != null and campfire.has_method("select_variant_by_id") and campfire.has_method("apply_current_variant"):
			campfire.call("select_variant_by_id", variant_id)
			campfire.call("apply_current_variant")
	controller.call("refresh_wiring")


func assert_campfire_signal_wired(assertions: TestAssertions, campfire: Node, controller: Node, label: String):
	assertions.assert_true(campfire != null, "%s should have a campfire to inspect signal wiring." % label)
	assertions.assert_true(controller != null, "%s should have a camp controller to inspect signal wiring." % label)
	if campfire == null or controller == null:
		return

	var callback := Callable(controller, "_on_campfire_player_detected")
	assertions.assert_true(campfire.is_connected("player_detected", callback), "%s CampfireBase player_detected should be connected to the camp controller." % label)
	var tracking_callback := Callable(controller, "_on_campfire_player_tracking_exited")
	assertions.assert_true(campfire.is_connected("player_tracking_exited", tracking_callback), "%s CampfireBase player_tracking_exited should be connected to the camp controller." % label)


func assert_knight_signals_wired(assertions: TestAssertions, knight: Node, controller: Node, label: String):
	assertions.assert_true(knight != null, "%s should have a linked knight to inspect signal wiring." % label)
	assertions.assert_true(controller != null, "%s should have a camp controller to inspect signal wiring." % label)
	if knight == null or controller == null:
		return

	if knight.has_signal("defeated"):
		assertions.assert_true(knight.is_connected("defeated", Callable(controller, "_on_knight_defeated")), "%s linked knight defeated should be connected to the camp controller." % label)
	if knight.has_signal("player_tracking_changed"):
		assertions.assert_false(knight.is_connected("player_tracking_changed", Callable(controller, "_on_knight_tracking_changed")), "%s linked knight tracking should not drive camp aggro; CampfireBase owns tracking." % label)


func assert_level_navigation_authoring_contracts(assertions: TestAssertions, tree: SceneTree):
	await assert_knight_navigation_contract(assertions, tree, STARTING_WILDERNESS_SCENE, "Starting Wilderness", false)
	await assert_knight_navigation_contract(assertions, tree, WEEPING_WOODS_SCENE, "Weeping Woods", true)
	await assert_knight_navigation_contract(assertions, tree, BANSHEE_VILLAGE_SCENE, "Banshee Village", false)


func assert_knight_navigation_contract(assertions: TestAssertions, tree: SceneTree, scene_path: String, label: String, expect_campfire_base_container: bool):
	var level := await instantiate_scene(assertions, tree, scene_path)
	assertions.assert_true(level != null, "%s should instantiate for character navigation authoring test." % label)
	if level == null:
		return

	assertions.assert_true(level.get_node_or_null("PlayableWorld/Navigation") is Node2D, "%s should have PlayableWorld/Navigation." % label)
	assertions.assert_true(level.get_node_or_null("PlayableWorld/Navigation/CharacterNavigationRegions") is Node2D, "%s should have CharacterNavigationRegions." % label)
	assertions.assert_true(level.get_node_or_null("PlayableWorld/Navigation/CharacterNavigationRegions/CampNavigationRegion") == null, "%s should leave camp-specific navigation regions on campfire layout variants." % label)
	var level_navigation_region := level.get_node_or_null("PlayableWorld/Navigation/CharacterNavigationRegions/LevelCharacterNavigationRegion") as NavigationRegion2D
	assertions.assert_true(level_navigation_region != null, "%s should have LevelCharacterNavigationRegion for level-wide character navigation." % label)
	if level_navigation_region != null:
		assertions.assert_true(level_navigation_region.navigation_polygon != null, "%s LevelCharacterNavigationRegion should own a NavigationPolygon resource." % label)
		assertions.assert_eq(level_navigation_region.navigation_layers, DEFAULT_CHARACTER_NAVIGATION_LAYER, "%s LevelCharacterNavigationRegion should use the shared character navigation layer." % label)
		if level_navigation_region.navigation_polygon != null:
			assertions.assert_true(level_navigation_region.navigation_polygon.get_polygon_count() > 0, "%s LevelCharacterNavigationRegion should have an initial walkable polygon for character navigation." % label)
	var source_geometry := level.get_node_or_null("PlayableWorld/Navigation/CharacterNavigationRegions/LevelCharacterNavigationRegion/NavigationSourceGeometry")
	assertions.assert_true(source_geometry is Node2D, "%s should have NavigationSourceGeometry under the level-wide character navigation region." % label)
	assertions.assert_true(level.get_node_or_null("PlayableWorld/Navigation/CharacterNavigationRegions/LevelCharacterNavigationRegion/NavigationSourceGeometry/TerrainProps") is Node2D, "%s TerrainProps should live under NavigationSourceGeometry." % label)
	assertions.assert_true(level.get_node_or_null("PlayableWorld/Navigation/CharacterNavigationRegions/LevelCharacterNavigationRegion/NavigationSourceGeometry/Buildings") is Node2D, "%s Buildings should live under NavigationSourceGeometry." % label)
	assertions.assert_true(level.get_node_or_null("PlayableWorld/Environment/TerrainProps") == null, "%s should not keep TerrainProps under PlayableWorld/Environment after the navigation hierarchy refactor." % label)
	assertions.assert_true(level.get_node_or_null("PlayableWorld/Environment/Buildings") == null, "%s should not keep Buildings under PlayableWorld/Environment after the navigation hierarchy refactor." % label)
	assertions.assert_true(level.get_node_or_null("PlayableWorld/Environment/Characters") is Node2D, "%s should keep Characters outside the navigation source tree." % label)
	assertions.assert_true(level.get_node_or_null("PlayableWorld/Environment/Interactables") is Node2D, "%s should keep Interactables outside the navigation source tree." % label)

	if expect_campfire_base_container:
		assertions.assert_true(level.get_node_or_null("PlayableWorld/Environment/Characters/HostileNPCs/CampfireBases") is Node2D, "%s should have a CampfireBases organization node for future camps." % label)

	level.queue_free()
	await tree.process_frame


func instantiate_scene(assertions: TestAssertions, tree: SceneTree, scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path)
	assertions.assert_true(packed != null, "Scene should load: %s" % scene_path)
	if packed == null:
		return null

	var instance := packed.instantiate()
	assertions.assert_true(instance != null, "Scene should instantiate: %s" % scene_path)
	if instance == null:
		return null

	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	return instance
