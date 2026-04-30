extends Node

@export var autosave_on_enter: bool = true
@export var autosave_on_exit: bool = true

var level: Node


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = get_parent()
	if SaveManager != null:
		SaveManager.current_level = level

	if autosave_on_enter:
		call_deferred("autosave_level_entered")


func _exit_tree():
	if autosave_on_exit and SaveManager != null:
		SaveManager.autosave_level_exiting(level)


func autosave_level_entered():
	if SaveManager != null:
		SaveManager.autosave_level_entered(level)


func _unhandled_input(event: InputEvent):
	if is_dev_reset_event(event):
		SaveManager.reset_current_level_for_dev()
		get_viewport().set_input_as_handled()


func is_dev_reset_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_R
		and event.ctrl_pressed
		and event.shift_pressed
	)
