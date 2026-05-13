extends CharacterBody2D

signal dialogue_finished(vincent: Node)

const VINCENT_HOUSE_DIALOGUE_FLAG = "vincent_house_dialogue_completed"
const FLAG_EFFECTS: Array[String] = ["flag"]
const DEFAULT_DIALOGUE_PROFILE: DialogueProfile = preload("res://resources/dialogue/npcs/vincent/vincent_story_profile.tres")
const DIALOGUE_KEY_HOUSE := &"house"

@onready var sprite: AnimatedSprite2D = get_node_or_null("Body") as AnimatedSprite2D
@onready var effects: EffectList = get_node_or_null("EffectList") as EffectList
@onready var proximity_area: Area2D = get_node_or_null("PlayerProximityArea") as Area2D

@export var house_dialogue_enabled: bool = true
@export var dialogue_profile: DialogueProfile = DEFAULT_DIALOGUE_PROFILE

var dialogue_active: bool = false
var dialogue_session: DialogueSessionController = DialogueSessionController.new()
var level_dialogue_sequence: DialogueSequence
var level_progress_flag_visible: bool = false
var active_dialogue_marks_house_completion: bool = false
var house_dialogue_completed_override_enabled: bool = false
var house_dialogue_completed_override_value: bool = false


func _ready():
	add_to_group("non_hostile_npcs")
	dialogue_session.setup(self)
	play_idle()
	refresh_progress_flag()


func interact(player: Node2D):
	if player != null and player.has_method("can_current_form_talk") and not player.can_current_form_talk():
		return

	if dialogue_session.advance():
		return

	if level_dialogue_sequence != null:
		start_dialogue(player, level_dialogue_sequence, false)
		return

	if not house_dialogue_enabled or is_vincent_house_dialogue_completed():
		return

	start_dialogue(player, get_house_dialogue_sequence(), true)


func start_dialogue(player: Node2D, sequence: DialogueSequence, marks_house_completion: bool = true):
	active_dialogue_marks_house_completion = marks_house_completion
	dialogue_active = dialogue_session.start_dialogue(player, sequence, Callable(self, "_on_dialogue_bubble_closed"))


func get_house_dialogue_sequence() -> DialogueSequence:
	if dialogue_profile == null:
		return null

	return dialogue_profile.get_sequence(DIALOGUE_KEY_HOUSE)


func _on_dialogue_bubble_closed(completed: bool = false):
	dialogue_session.finish_dialogue()
	dialogue_active = false

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
