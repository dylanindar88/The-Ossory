class_name DialogueSessionController
extends RefCounted

const DIALOGUE_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/DialogueBubble.tscn")

var owner: Node
var active_dialogue_bubble: DialogueBubble
var current_dialogue_player: Node2D
var dialogue_active: bool = false


func setup(owner_node: Node):
	owner = owner_node


func can_start_dialogue() -> bool:
	return CombatStateManager == null or CombatStateManager.can_start_dialogue()


func start_dialogue(player: Node2D, sequence: DialogueSequence, closed_callback: Callable) -> bool:
	if owner == null or sequence == null or sequence.is_empty() or not can_start_dialogue():
		return false

	current_dialogue_player = player
	dialogue_active = true
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(true)
	if current_dialogue_player != null and current_dialogue_player.has_method("set_dialogue_input_locked"):
		current_dialogue_player.set_dialogue_input_locked(true)

	active_dialogue_bubble = DIALOGUE_BUBBLE_SCENE.instantiate() as DialogueBubble
	owner.add_child(active_dialogue_bubble)
	if not active_dialogue_bubble.closed.is_connected(closed_callback):
		active_dialogue_bubble.closed.connect(closed_callback)
	active_dialogue_bubble.open(sequence)
	return true


func advance() -> bool:
	if not dialogue_active:
		return false

	if active_dialogue_bubble != null:
		active_dialogue_bubble.advance()
	return true


func finish_dialogue() -> Node2D:
	active_dialogue_bubble = null
	var dialogue_player: Node2D = current_dialogue_player
	dialogue_active = false
	current_dialogue_player = null

	if dialogue_player != null and is_instance_valid(dialogue_player) and dialogue_player.has_method("set_dialogue_input_locked"):
		dialogue_player.set_dialogue_input_locked(false)
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(false)

	return dialogue_player
