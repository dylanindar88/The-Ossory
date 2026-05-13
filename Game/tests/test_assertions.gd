class_name TestAssertions
extends RefCounted

var failures: Array[String] = []


func assert_true(value: bool, message: String):
	if not value:
		fail(message)


func assert_false(value: bool, message: String):
	if value:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String):
	if actual != expected:
		fail("%s Expected: %s Actual: %s" % [message, str(expected), str(actual)])


func assert_ne(actual: Variant, expected: Variant, message: String):
	if actual == expected:
		fail("%s Value: %s" % [message, str(actual)])


func assert_has_key(data: Dictionary, key: String, message: String):
	if not data.has(key):
		fail("%s Missing key: %s" % [message, key])


func assert_not_has_key(data: Dictionary, key: String, message: String):
	if data.has(key):
		fail("%s Unexpected key: %s" % [message, key])


func fail(message: String):
	failures.append(message)


func has_failures() -> bool:
	return not failures.is_empty()
