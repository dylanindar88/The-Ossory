extends Camera2D

@export var zoom_step := 0.001
@export var min_zoom := 1.75
@export var max_zoom := 3
@export var default_zoom := 2

func _ready():
	var initial_zoom: float = default_zoom
	if SaveManager != null and SaveManager.has_method("get_default_camera_zoom"):
		initial_zoom = SaveManager.get_default_camera_zoom()
	change_zoom(initial_zoom)

func _process(_delta):
	var ctrl_pressed = Input.is_action_pressed("zoom_modifier")

	if ctrl_pressed:
		if Input.is_action_pressed("zoom_in"):
			change_zoom(zoom.x + zoom_step)

		if Input.is_action_pressed("zoom_out"):
			change_zoom(zoom.x - zoom_step)

func change_zoom(new_zoom):
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
