extends CharacterBody2D

signal dialogue_finished(vincent: Node)

const DIALOGUE_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/DialogueBubble.tscn")
const VINCENT_HOUSE_DIALOGUE_FLAG = "vincent_house_dialogue_completed"
const FLAG_EFFECTS: Array[String] = ["flag"]
const VINCENT_HOUSE_DIALOGUE := [
	"Thanks for helping take care of those banshees, I was just taking a break in here, but im afraid the problem isn't solved. NO I'm not a vampire and this is not my fault, can't you see the mirror? Those banshees were corrupted by a bishop who lives nearby. We need to stop him to fully free the village, otherwise more banshees will keep coming and we'll have to keep purifying them.",
]

@onready var sprite: AnimatedSprite2D = get_node_or_null("Body") as AnimatedSprite2D
@onready var effects: EffectList = get_node_or_null("EffectList") as EffectList
@onready var proximity_area: Area2D = get_node_or_null("PlayerProximityArea") as Area2D

@export var house_dialogue_enabled: bool = true

var dialogue_active: bool = false
var active_dialogue_bubble: DialogueBubble
var current_dialogue_player: Node2D
var level_dialogue_sequence: DialogueSequence
var level_progress_flag_visible: bool = false
var active_dialogue_marks_house_completion: bool = false
var house_dialogue_completed_override_enabled: bool = false
var house_dialogue_completed_override_value: bool = false


func _ready():
	add_to_group("villagers")
	play_idle()
	refresh_progress_flag()


func interact(player: Node2D):
	if player != null and player.has_method("can_current_form_talk") and not player.can_current_form_talk():
		return

	if dialogue_active:
		if active_dialogue_bubble != null:
			active_dialogue_bubble.advance()
		return

	if level_dialogue_sequence != null:
		start_dialogue(player, level_dialogue_sequence, false)
		return

	if not house_dialogue_enabled or is_vincent_house_dialogue_completed():
		return

	start_dialogue(player, create_dialogue_sequence(), true)


func start_dialogue(player: Node2D, sequence: DialogueSequence, marks_house_completion: bool = true):
	if CombatStateManager != null and not CombatStateManager.can_start_dialogue():
		return

	current_dialogue_player = player
	dialogue_active = true
	active_dialogue_marks_house_completion = marks_house_completion
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(true)
	if current_dialogue_player != null and current_dialogue_player.has_method("set_dialogue_input_locked"):
		current_dialogue_player.set_dialogue_input_locked(true)

	active_dialogue_bubble = DIALOGUE_BUBBLE_SCENE.instantiate() as DialogueBubble
	add_child(active_dialogue_bubble)
	if not active_dialogue_bubble.closed.is_connected(_on_dialogue_bubble_closed):
		active_dialogue_bubble.closed.connect(_on_dialogue_bubble_closed)
	active_dialogue_bubble.open(sequence)


func create_dialogue_sequence() -> DialogueSequence:
	var sequence := DialogueSequence.new()
	for page in VINCENT_HOUSE_DIALOGUE:
		sequence.pages.append(page)

	return sequence


func _on_dialogue_bubble_closed(completed: bool = false):
	active_dialogue_bubble = null
	var dialogue_player := current_dialogue_player
	dialogue_active = false
	current_dialogue_player = null

	if dialogue_player != null and is_instance_valid(dialogue_player) and dialogue_player.has_method("set_dialogue_input_locked"):
		dialogue_player.set_dialogue_input_locked(false)
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(false)

	if completed:
		if active_dialogue_marks_house_completion and SaveManager != null and SaveManager.has_method("set_story_flag"):
			SaveManager.set_story_flag(VINCENT_HOUSE_DIALOGUE_FLAG, true)
		refresh_progress_flag()
		dialogue_finished.emit(self)
	active_dialogue_marks_house_completion = false


func refresh_progress_flag():
	if effects == null:
		return

	if level_progress_flag_visible:
		effects.set_effects(FLAG_EFFECTS)
	elif not house_dialogue_enabled or is_vincent_house_dialogue_completed():
		effects.clear_effects()
	else:
		effects.set_effects(FLAG_EFFECTS)


func set_level_dialogue_override(sequence: DialogueSequence, show_progress_flag: bool):
	level_dialogue_sequence = sequence
	level_progress_flag_visible = show_progress_flag
	refresh_progress_flag()


func clear_level_dialogue_override():
	set_level_dialogue_override(null, false)


func set_house_dialogue_enabled(enabled: bool):
	house_dialogue_enabled = enabled
	refresh_progress_flag()


func set_house_dialogue_completed_override(enabled: bool, completed: bool):
	house_dialogue_completed_override_enabled = enabled
	house_dialogue_completed_override_value = completed
	refresh_progress_flag()


func set_interaction_enabled(enabled: bool):
	if proximity_area == null:
		return

	proximity_area.set_deferred("monitoring", enabled)
	proximity_area.set_deferred("monitorable", enabled)


func is_vincent_house_dialogue_completed() -> bool:
	if house_dialogue_completed_override_enabled:
		return house_dialogue_completed_override_value

	return SaveManager != null and SaveManager.has_method("get_story_flag") and bool(SaveManager.get_story_flag(VINCENT_HOUSE_DIALOGUE_FLAG))


func play_idle():
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
