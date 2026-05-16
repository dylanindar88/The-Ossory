extends RefCounted

const EFFECT_LIST_SCENE := "res://scenes/ui/EffectList.tscn"
const TEST_EFFECT := "weak_to_wolf"
const WORLD_EFFECT_Z_INDEX := 1
const FOREGROUND_Z_INDEX := 2

const CHARACTER_EFFECT_SCENES := {
	"Saorise": "res://scenes/characters/saorise/Saorise.tscn",
	"Banshee": "res://scenes/characters/hostile_npcs/banshees/Banshee.tscn",
	"BasicKnightMelee": "res://scenes/characters/hostile_npcs/knights/BasicKnightMelee.tscn",
	"BasicKnightRanged": "res://scenes/characters/hostile_npcs/knights/BasicKnightRanged.tscn",
	"CampfireBaseTent": "res://scenes/environment/structures/campfire_base/CampfireBaseTent.tscn",
	"CampfireBaseTentFlipped": "res://scenes/environment/structures/campfire_base/CampfireBaseTentFlipped.tscn",
	"Dulluhan": "res://scenes/characters/npcs/dulluhan/Dulluhan.tscn",
	"ElderVillager": "res://scenes/characters/npcs/celtic_villagers/ElderVillager.tscn",
	"Vincent": "res://scenes/characters/npcs/vincent/Vincent.tscn",
}


func run(assertions: TestAssertions, tree: SceneTree, _save_manager: Node):
	await assert_effect_list_defaults(assertions, tree)
	for scene_name in CHARACTER_EFFECT_SCENES.keys():
		await assert_character_effect_list(assertions, tree, scene_name, CHARACTER_EFFECT_SCENES[scene_name])


func assert_effect_list_defaults(assertions: TestAssertions, tree: SceneTree):
	var packed: PackedScene = load(EFFECT_LIST_SCENE)
	assertions.assert_true(packed != null, "EffectList scene should load.")
	if packed == null:
		return

	var effects: EffectList = packed.instantiate() as EffectList
	tree.root.add_child(effects)
	await tree.process_frame
	assert_effect_list_rendering(assertions, effects, "Standalone EffectList")

	effects.set_effects([TEST_EFFECT])
	await tree.process_frame
	var effect_sprite: AnimatedSprite2D = get_effect_sprite(effects, TEST_EFFECT)
	assertions.assert_true(effect_sprite != null, "EffectList should create a weak_to_wolf effect sprite.")
	if effect_sprite != null:
		assertions.assert_true(effect_sprite.z_as_relative, "Effect sprite should use relative z ordering.")
		assertions.assert_eq(effect_sprite.z_index, 0, "Effect sprite should inherit the EffectList world layer.")

	effects.queue_free()
	await tree.process_frame


func assert_character_effect_list(assertions: TestAssertions, tree: SceneTree, scene_name: String, scene_path: String):
	var packed: PackedScene = load(scene_path)
	assertions.assert_true(packed != null, "%s scene should load for effect rendering test." % scene_name)
	if packed == null:
		return

	var instance: Node = packed.instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame

	var effects := get_character_effect_list(instance)
	assertions.assert_true(effects != null, "%s should have a world-attached EffectList." % scene_name)
	if effects != null:
		assert_effect_list_rendering(assertions, effects, "%s EffectList" % scene_name)

	instance.queue_free()
	await tree.process_frame


func assert_effect_list_rendering(assertions: TestAssertions, effects: EffectList, label: String):
	assertions.assert_true(effects.z_as_relative, "%s should use relative z ordering." % label)
	assertions.assert_false(effects.y_sort_enabled, "%s should not y-sort above foreground." % label)
	assertions.assert_eq(effects.z_index, WORLD_EFFECT_Z_INDEX, "%s should sit one local z layer above its owner." % label)
	assertions.assert_true(effects.z_index < FOREGROUND_Z_INDEX, "%s should remain below roof/leaf foreground z layers." % label)


func get_character_effect_list(instance: Node) -> EffectList:
	var effects := instance.get_node_or_null("Effects") as EffectList
	if effects != null:
		return effects

	return instance.get_node_or_null("EffectList") as EffectList


func get_effect_sprite(effects: EffectList, anim_name: String) -> AnimatedSprite2D:
	var effect_sprite := effects.get_node_or_null(anim_name) as AnimatedSprite2D
	if effect_sprite != null:
		return effect_sprite
	if effects.get("effect_sprites") is Dictionary:
		return (effects.get("effect_sprites") as Dictionary).get(anim_name) as AnimatedSprite2D

	return null
