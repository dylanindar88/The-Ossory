class_name DialogueBubble
extends Node2D

signal closed(completed: bool)

@export var bubble_width: float = 190.0
@export var bubble_height: float = 52.0
@export var bubble_padding: Vector2 = Vector2(8.0, 6.0)
@export var max_lines: int = 3
@export var estimated_chars_per_line: int = 29
@export var characters_per_second: float = 80.0
@export var bubble_offset: Vector2 = Vector2(0.0, -84.0)
@export var font_size: int = 9

var pages: Array[String] = []
var page_index: int = 0
var typing_progress: float = 0.0
var is_typing: bool = false
var label: Label
var background: ColorRect


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = bubble_offset
	create_ui()
	set_process(false)
	set_process_input(false)


func create_ui():
	background = ColorRect.new()
	background.color = Color(0.05, 0.045, 0.055, 0.88)
	background.position = Vector2(-bubble_width * 0.5, 0.0)
	background.size = Vector2(bubble_width, bubble_height)
	background.z_index = 200
	add_child(background)

	label = Label.new()
	label.position = background.position + bubble_padding
	label.size = background.size - bubble_padding * 2.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86, 1.0))
	label.z_index = 201
	add_child(label)


func open(sequence: DialogueSequence):
	if sequence == null:
		close(false)
		return

	pages = paginate_pages(sequence.get_pages())
	if pages.is_empty():
		close(false)
		return

	visible = true
	page_index = 0
	show_page(0)
	set_process(true)
	set_process_input(true)


func paginate_pages(raw_pages: Array[String]) -> Array[String]:
	var paginated: Array[String] = []
	var line_count: int = maxi(max_lines, 1)
	var max_chars: int = maxi(estimated_chars_per_line * line_count, 1)

	for raw_page in raw_pages:
		var remaining: String = raw_page.strip_edges()
		while remaining.length() > max_chars:
			var split_index: int = remaining.rfind(" ", max_chars)
			if split_index <= 0:
				split_index = max_chars

			paginated.append(remaining.substr(0, split_index).strip_edges())
			remaining = remaining.substr(split_index).strip_edges()

		if remaining != "":
			paginated.append(remaining)

	return paginated


func show_page(index: int):
	label.text = pages[index]
	label.visible_characters = 0
	typing_progress = 0.0
	is_typing = true


func _process(delta: float):
	if not is_typing:
		return

	typing_progress += characters_per_second * delta
	label.visible_characters = mini(int(typing_progress), label.text.length())
	if label.visible_characters >= label.text.length():
		finish_current_page()


func _input(event: InputEvent):
	if should_advance_from_event(event):
		advance()
		get_viewport().set_input_as_handled()


func should_advance_from_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("left_click"):
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed

	return false


func advance():
	if is_typing:
		finish_current_page()
		return

	if page_index < pages.size() - 1:
		page_index += 1
		show_page(page_index)
		return

	close(true)


func finish_current_page():
	is_typing = false
	label.visible_characters = -1


func close(completed: bool = false):
	set_process(false)
	set_process_input(false)
	visible = false
	closed.emit(completed)
	queue_free()
