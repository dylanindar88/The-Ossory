class_name DialogueChoiceBubble
extends Node2D

signal choice_selected(accepted: bool)
signal closed(accepted: bool)

@export var bubble_width: float = 150.0
@export var bubble_height: float = 44.0
@export var bubble_padding: Vector2 = Vector2(8.0, 6.0)
@export var bubble_offset: Vector2 = Vector2(0.0, -84.0)
@export var font_size: int = 9
@export var prompt_text: String = "Accept request?"

var selected_index: int = 0
var is_closing: bool = false
var background: ColorRect
var prompt_label: Label
var accept_label: Label
var decline_label: Label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = bubble_offset
	create_ui()
	set_process_input(false)


func create_ui():
	background = ColorRect.new()
	background.color = Color(0.05, 0.045, 0.055, 0.9)
	background.position = Vector2(-bubble_width * 0.5, 0.0)
	background.size = Vector2(bubble_width, bubble_height)
	background.z_index = 220
	add_child(background)

	prompt_label = Label.new()
	prompt_label.position = background.position + bubble_padding
	prompt_label.size = Vector2(bubble_width - bubble_padding.x * 2.0, 14.0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.text = prompt_text
	prompt_label.add_theme_font_size_override("font_size", font_size)
	prompt_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86, 1.0))
	prompt_label.z_index = 221
	add_child(prompt_label)

	accept_label = create_option_label("Accept", Vector2(background.position.x + 10.0, 24.0))
	decline_label = create_option_label("Decline", Vector2(background.position.x + bubble_width * 0.5 + 4.0, 24.0))
	add_child(accept_label)
	add_child(decline_label)
	refresh_selection()


func create_option_label(text: String, label_position: Vector2) -> Label:
	var option_label: Label = Label.new()
	option_label.position = label_position
	option_label.size = Vector2(bubble_width * 0.5 - 14.0, 14.0)
	option_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	option_label.text = text
	option_label.add_theme_font_size_override("font_size", font_size)
	option_label.z_index = 221
	return option_label


func open():
	visible = true
	selected_index = 0
	is_closing = false
	refresh_selection()
	set_process_input(true)


func _input(event: InputEvent):
	if event.is_action_pressed("move_left"):
		selected_index = 0
		refresh_selection()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right"):
		selected_index = 1
		refresh_selection()
		get_viewport().set_input_as_handled()
		return

	if should_confirm_from_event(event):
		confirm_selection()
		get_viewport().set_input_as_handled()


func should_confirm_from_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("left_click"):
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed

	return false


func confirm_selection():
	if is_closing:
		return

	var accepted: bool = selected_index == 0
	choice_selected.emit(accepted)
	close(accepted)


func close(accepted: bool = false):
	if is_closing:
		return

	is_closing = true
	set_process_input(false)
	visible = false
	closed.emit(accepted)
	queue_free()


func refresh_selection():
	apply_option_style(accept_label, "Accept", selected_index == 0)
	apply_option_style(decline_label, "Decline", selected_index == 1)


func apply_option_style(option_label: Label, option_text: String, selected: bool):
	if option_label == null:
		return

	if selected:
		option_label.text = "> " + option_text
		option_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.62, 1.0))
	else:
		option_label.text = "  " + option_text
		option_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86, 1.0))
