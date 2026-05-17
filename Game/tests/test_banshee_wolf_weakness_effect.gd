extends RefCounted

const STARTING_WILDERNESS_PATH := "res://scenes/levels/StartingWilderness.tscn"
const BANSHEE_VILLAGE_PATH := "res://scenes/levels/BansheeVillage.tscn"
const STARTING_WILDERNESS_BANSHEE_PATH := "PlayableWorld/Environment/Characters/HostileNPCs/Banshees/Banshee2"
const BANSHEE_VILLAGE_BANSHEE_PATH := "PlayableWorld/Environment/Characters/HostileNPCs/Banshee2"
const WEAK_TO_WOLF_EFFECT := "weak_to_wolf"
const BANSHEE_TUNING: BansheeTuning = preload("res://resources/characters/hostile_npcs/banshees/banshee_tuning.tres")


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var original_hidden_alpha: float = BANSHEE_TUNING.hidden_banshee_alpha
	var original_passive_alpha: float = BANSHEE_TUNING.passive_banshee_alpha
	await assert_starting_wilderness_wolf_effect(assertions, tree, save_manager)
	await assert_banshee_village_wolf_effect(assertions, tree, save_manager)
	BANSHEE_TUNING.hidden_banshee_alpha = original_hidden_alpha
	BANSHEE_TUNING.passive_banshee_alpha = original_passive_alpha


func assert_starting_wilderness_wolf_effect(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var packed: PackedScene = load(STARTING_WILDERNESS_PATH)
	assertions.assert_true(packed != null, "Starting Wilderness should load for weak-to-wolf effect test.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	var provider: Node = save_manager.call("get_level_state_provider", level)
	var flow: Node = level.get_node_or_null("StartingWildernessFlowController")
	var player: Node = tree.get_first_node_in_group("player")
	var banshee: Node = level.get_node_or_null(STARTING_WILDERNESS_BANSHEE_PATH)
	assertions.assert_true(provider != null, "Starting Wilderness should expose a provider for weak-to-wolf effect test.")
	assertions.assert_true(flow != null, "Starting Wilderness should expose a flow controller for shared Banshee alpha test.")
	assertions.assert_true(player != null, "Starting Wilderness should have a player for weak-to-wolf effect test.")
	assertions.assert_true(banshee != null, "Starting Wilderness should have a Banshee for weak-to-wolf effect test.")
	if provider == null or flow == null or player == null or banshee == null:
		level.queue_free()
		save_manager.call("set_current_level", null)
		await tree.process_frame
		return

	BANSHEE_TUNING.hidden_banshee_alpha = 0.37
	BANSHEE_TUNING.passive_banshee_alpha = 0.11
	set_banshee_world_rules(save_manager, true, true)
	provider.call("apply_level_state", provider.call("collect_level_state"))
	assertions.assert_false(has_exported_property(flow, "banshee_story_visibility_tuning"), "Starting Wilderness should not expose per-level Banshee alpha tuning.")
	assertions.assert_false(has_exported_property(banshee, "undetected_alpha"), "Banshee should not expose per-instance story alpha tuning.")
	assertions.assert_true(absf(float((banshee as CanvasItem).modulate.a) - 0.37) <= 0.001, "Starting Wilderness hostile Banshee should use shared hidden alpha.")
	await set_player_form(player, &"wolf", tree)
	await tree.physics_frame
	assert_effect_visible(assertions, banshee, true, "Starting Wilderness Banshee should show weak-to-wolf while wolf policy is enabled.")

	await set_player_form(player, &"human", tree)
	await tree.physics_frame
	assert_effect_visible(assertions, banshee, false, "Starting Wilderness Banshee should hide weak-to-wolf outside wolf form.")

	set_banshee_world_rules(save_manager, true, false)
	provider.call("apply_level_state", provider.call("collect_level_state"))
	await set_player_form(player, &"wolf", tree)
	await tree.physics_frame
	assert_effect_visible(assertions, banshee, false, "Starting Wilderness Banshee should not show weak-to-wolf when wolf clear policy is disabled.")

	set_banshee_world_rules(save_manager, false, false)
	provider.call("apply_level_state", provider.call("collect_level_state"))
	assertions.assert_true(absf(float((banshee as CanvasItem).modulate.a) - 0.11) <= 0.001, "Starting Wilderness passive Banshee should use shared passive alpha.")

	if banshee.has_method("hide_as_story_defeated"):
		banshee.call("hide_as_story_defeated", BANSHEE_TUNING.hidden_banshee_alpha)
	await tree.physics_frame
	assert_effect_visible(assertions, banshee, false, "Starting Wilderness hidden defeated Banshee should not show weak-to-wolf.")

	level.queue_free()
	save_manager.call("set_current_level", null)
	set_banshee_world_rules(save_manager, false, false)
	await tree.process_frame


func assert_banshee_village_wolf_effect(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var packed: PackedScene = load(BANSHEE_VILLAGE_PATH)
	assertions.assert_true(packed != null, "Banshee Village should load for weak-to-wolf effect test.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	tree.root.add_child(level)
	save_manager.call("set_current_level", level)
	await tree.process_frame
	await tree.process_frame

	var provider: Node = save_manager.call("get_level_state_provider", level)
	var player: Node = tree.get_first_node_in_group("player")
	var banshee: Node = level.get_node_or_null(BANSHEE_VILLAGE_BANSHEE_PATH)
	assertions.assert_true(provider != null, "Banshee Village should expose a provider for weak-to-wolf effect test.")
	assertions.assert_true(player != null, "Banshee Village should have a player for weak-to-wolf effect test.")
	assertions.assert_true(banshee != null, "Banshee Village should have a Banshee for weak-to-wolf effect test.")
	if provider == null or player == null or banshee == null:
		level.queue_free()
		save_manager.call("set_current_level", null)
		await tree.process_frame
		return

	BANSHEE_TUNING.hidden_banshee_alpha = 0.41
	BANSHEE_TUNING.passive_banshee_alpha = 0.13
	provider.set("transformed_banshee_clear_policy", "temporary_wolf_clear")
	provider.call("apply_level_state", build_banshee_village_combat_state(provider))
	assertions.assert_false(has_exported_property(provider, "banshee_story_visibility_tuning"), "Banshee Village should not expose per-level Banshee alpha tuning.")
	assertions.assert_false(has_exported_property(banshee, "undetected_alpha"), "Banshee should not expose per-instance story alpha tuning.")
	assertions.assert_true(absf(float((banshee as CanvasItem).modulate.a) - 0.41) <= 0.001, "Banshee Village active Banshee should use shared hidden alpha.")
	await set_player_form(player, &"wolf", tree)
	await tree.physics_frame
	assert_effect_visible(assertions, banshee, true, "Banshee Village Banshee should show weak-to-wolf when wolf clear policy is active.")

	await set_player_form(player, &"human", tree)
	await tree.physics_frame
	assert_effect_visible(assertions, banshee, false, "Banshee Village Banshee should hide weak-to-wolf outside wolf form.")

	provider.set("transformed_banshee_clear_policy", "respawn")
	provider.call("apply_level_state", build_banshee_village_combat_state(provider))
	await set_player_form(player, &"wolf", tree)
	await tree.physics_frame
	assert_effect_visible(assertions, banshee, false, "Banshee Village Banshee should not show weak-to-wolf when transformed clears only respawn.")

	level.queue_free()
	save_manager.call("set_current_level", null)
	await tree.process_frame


func build_banshee_village_combat_state(provider: Node) -> Dictionary:
	var state: Dictionary = provider.call("collect_level_state")
	state["quest_stage"] = "combat_active"
	state["temporarily_cleared_banshee_paths"] = []
	state["permanently_cleared_banshee_paths"] = []
	state["banshees"] = []
	state["non_hostile_npcs"] = []
	return state


func set_player_form(player: Node, form_id: StringName, tree: SceneTree):
	if player != null and player.has_method("set_form"):
		player.call("set_form", form_id)
	await tree.process_frame


func assert_effect_visible(assertions: TestAssertions, banshee: Node, expected_visible: bool, message: String):
	var effects: EffectList = banshee.get_node_or_null("Effects") as EffectList
	assertions.assert_true(effects != null, "%s Effects node should exist." % message)
	if effects == null:
		return

	assertions.assert_eq(effects.visible, expected_visible, message)
	if not expected_visible:
		return

	var effect_sprite: AnimatedSprite2D = effects.get_node_or_null(WEAK_TO_WOLF_EFFECT) as AnimatedSprite2D
	if effect_sprite == null and effects.get("effect_sprites") is Dictionary:
		effect_sprite = (effects.get("effect_sprites") as Dictionary).get(WEAK_TO_WOLF_EFFECT) as AnimatedSprite2D
	assertions.assert_true(effect_sprite != null, "%s Effect sprite should exist." % message)
	if effect_sprite != null:
		assertions.assert_eq(str(effect_sprite.animation), WEAK_TO_WOLF_EFFECT, "%s Effect sprite should play weak_to_wolf." % message)
		assertions.assert_true(effect_sprite.visible, "%s Effect sprite should be visible." % message)


func has_exported_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false

	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name and (int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0:
			return true

	return false


func set_banshee_world_rules(save_manager: Node, enabled: bool, wolf_clear_enabled: bool):
	if save_manager == null or not save_manager.has_method("set_banshee_world_rule"):
		return

	save_manager.call("set_banshee_world_rule", "banshees_hostile_enabled", enabled)
	save_manager.call("set_banshee_world_rule", "player_can_damage_banshees", enabled)
	save_manager.call("set_banshee_world_rule", "wolf_permanent_clear_enabled", wolf_clear_enabled)
	save_manager.call("set_banshee_world_rule", "bishop_defeated", false)
