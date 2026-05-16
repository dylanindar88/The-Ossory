extends RefCounted

const SCENE_PATHS := [
	"res://scenes/ui/TitleScreen.tscn",
	"res://scenes/ui/PauseMenu.tscn",
	"res://scenes/characters/saorise/Saorise.tscn",
	"res://scenes/characters/hostile_npcs/banshees/Banshee.tscn",
	"res://scenes/characters/hostile_npcs/knights/BasicKnightMelee.tscn",
	"res://scenes/characters/hostile_npcs/knights/BasicKnightRanged.tscn",
	"res://scenes/characters/hostile_npcs/knights/KnightArrowProjectile.tscn",
	"res://scenes/characters/npcs/celtic_villagers/ElderVillager.tscn",
	"res://scenes/characters/npcs/celtic_villagers/FemaleVillager.tscn",
	"res://scenes/characters/npcs/celtic_villagers/MaleVillager.tscn",
	"res://scenes/characters/npcs/dulluhan/Dulluhan.tscn",
	"res://scenes/characters/npcs/vincent/Vincent.tscn",
	"res://scenes/environment/structures/campfire_base/CampfireBase.tscn",
]


func run(assertions: TestAssertions, tree: SceneTree, save_manager: Node):
	var paths: Array[String] = []
	for level_path in save_manager.LEVEL_DISPLAY_REGISTRY.keys():
		paths.append(str(level_path))
	for scene_path in SCENE_PATHS:
		paths.append(scene_path)

	for scene_path in paths:
		await assert_scene_loads(assertions, tree, save_manager, scene_path)


func assert_scene_loads(assertions: TestAssertions, tree: SceneTree, save_manager: Node, scene_path: String):
	var packed: PackedScene = load(scene_path)
	assertions.assert_true(packed != null, "Scene should load as PackedScene: %s" % scene_path)
	if packed == null:
		return

	var instance: Node = packed.instantiate()
	assertions.assert_true(instance != null, "Scene should instantiate: %s" % scene_path)
	if instance == null:
		return

	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	assertions.assert_true(instance.is_inside_tree(), "Scene should enter tree: %s" % scene_path)
	instance.queue_free()
	if save_manager != null and save_manager.has_method("set_current_level"):
		save_manager.call("set_current_level", null)
	await tree.process_frame
