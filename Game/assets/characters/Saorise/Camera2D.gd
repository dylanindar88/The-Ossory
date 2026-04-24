extends Camera2D

@export var zoom_step := 0.005
@export var min_zoom := 1.25
@export var max_zoom := 2.5
@export var default_zoom := 1.5

func _ready():
	zoom = Vector2(default_zoom, default_zoom)

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
