extends SceneTree

const TestAssertionsScript := preload("res://tests/test_assertions.gd")
const TEST_SAVE_RUN_ID := "automated_headless"
const TEST_SAVE_DIR := "user://test_saves/%s" % TEST_SAVE_RUN_ID
const TEST_SAVE_PATH_FORMAT := TEST_SAVE_DIR + "/save_slot_%d.json"
const SUITES := [
	"res://tests/test_scene_loads.gd",
	"res://tests/test_level_contracts.gd",
	"res://tests/test_save_schema_v2.gd",
	"res://tests/test_ui_labels.gd",
]

var assertions: TestAssertions
var save_manager: Node


func _initialize():
	call_deferred("run")


func run():
	assertions = TestAssertionsScript.new()
	save_manager = root.get_node_or_null("/root/SaveManager")
	if save_manager == null:
		assertions.fail("SaveManager autoload was not available to the test runner.")
		report_and_quit()
		return
	setup_test_saves()

	for suite_path in SUITES:
		await run_suite(suite_path)

	cleanup_test_saves()
	report_and_quit()


func report_and_quit():
	if assertions.has_failures():
		print("")
		print("Automated tests failed:")
		for failure in assertions.failures:
			print("  - %s" % failure)
		quit(1)
		return

	print("")
	print("Automated tests passed.")
	quit(0)


func run_suite(suite_path: String):
	var suite_script: Script = load(suite_path)
	if suite_script == null:
		assertions.fail("Could not load test suite: %s" % suite_path)
		return

	var suite = suite_script.new()
	if not suite.has_method("run"):
		assertions.fail("Test suite has no run() method: %s" % suite_path)
		return

	print("Running %s" % suite_path)
	await suite.run(assertions, self, save_manager)


func setup_test_saves():
	remove_dir_recursive(TEST_SAVE_DIR)
	var root_dir := DirAccess.open("user://")
	if root_dir == null:
		assertions.fail("Could not open user:// for test save setup.")
		return

	var error: Error = root_dir.make_dir_recursive("test_saves/%s" % TEST_SAVE_RUN_ID)
	if error != OK:
		assertions.fail("Could not create isolated test save directory. Error: %s" % error_string(error))
		return

	if save_manager != null and save_manager.has_method("_set_test_save_path_format"):
		save_manager.call("_set_test_save_path_format", TEST_SAVE_PATH_FORMAT)


func cleanup_test_saves():
	if save_manager != null and save_manager.has_method("_clear_test_save_path_format"):
		save_manager.call("_clear_test_save_path_format")
	remove_dir_recursive(TEST_SAVE_DIR)


func remove_dir_recursive(path: String):
	if not path.begins_with("user://test_saves/"):
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var child_path := path.path_join(file_name)
			if dir.current_is_dir():
				remove_dir_recursive(child_path)
			else:
				dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	var parent := DirAccess.open(path.get_base_dir())
	if parent != null:
		parent.remove(path.get_file())
