class_name CampfireBaseVariant
extends Resource

@export var variant_id: StringName = &"campfire_base_a"
@export var display_name: String = "Campfire Base A"

@export_group("Layout")
@export var layout_scene: PackedScene
@export var max_knight_count: int = 0

@export_group("Future Spawn Tuning")
@export var allowed_knight_type_ids: Array[StringName] = []
@export var spawn_interval_seconds: float = 10.0
@export var spawn_count: int = 1
@export var spawn_point_hints: Array[Vector2] = []
