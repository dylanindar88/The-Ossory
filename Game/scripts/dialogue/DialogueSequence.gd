class_name DialogueSequence
extends Resource

@export var pages: Array[String] = []


func is_empty() -> bool:
	return pages.is_empty()


func get_pages() -> Array[String]:
	var clean_pages: Array[String] = []
	for page in pages:
		if page.strip_edges() != "":
			clean_pages.append(page)

	return clean_pages
