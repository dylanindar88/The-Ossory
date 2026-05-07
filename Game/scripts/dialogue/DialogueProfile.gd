class_name DialogueProfile
extends Resource

@export var entries: Array[DialogueEntry] = []


func get_sequence(key: StringName) -> DialogueSequence:
	for entry in entries:
		if entry != null and entry.key == key:
			return entry.sequence

	return null


func has_sequence(key: StringName) -> bool:
	var sequence: DialogueSequence = get_sequence(key)
	return sequence != null and not sequence.is_empty()


func get_missing_keys(required_keys: Array[StringName]) -> Array[StringName]:
	var missing_keys: Array[StringName] = []
	for key in required_keys:
		if not has_sequence(key):
			missing_keys.append(key)

	return missing_keys
