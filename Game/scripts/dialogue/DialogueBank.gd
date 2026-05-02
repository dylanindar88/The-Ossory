class_name DialogueBank
extends Resource

enum SelectionMode { FIXED, RANDOM, LEVEL_OVERRIDE }

@export_enum("Fixed", "Random", "Level Override") var selection_mode: int = SelectionMode.FIXED
@export var fixed_sequence: DialogueSequence
@export var random_sequences: Array[DialogueSequence] = []
@export var level_override_key: StringName = &""


func get_sequence(context: Dictionary = {}) -> DialogueSequence:
	if selection_mode == SelectionMode.LEVEL_OVERRIDE and context.has(level_override_key):
		var override_sequence: Variant = context[level_override_key]
		if override_sequence is DialogueSequence:
			return override_sequence

	if selection_mode == SelectionMode.RANDOM:
		var available_sequences: Array[DialogueSequence] = get_available_random_sequences()
		if not available_sequences.is_empty():
			var sequence: DialogueSequence = available_sequences.pick_random()
			return sequence

	return fixed_sequence


func get_available_random_sequences() -> Array[DialogueSequence]:
	var available_sequences: Array[DialogueSequence] = []
	for sequence in random_sequences:
		if sequence != null and not sequence.is_empty():
			available_sequences.append(sequence)

	return available_sequences
