class_name DialogueEntry
extends Resource

@export var key: StringName = &""
@export var sequence: DialogueSequence


func is_valid_entry() -> bool:
	return key != &"" and sequence != null and not sequence.is_empty()
