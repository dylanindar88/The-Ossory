class_name PlayerGaugePreviewSettings
extends Resource

@export_range(0.0, 999.0, 1.0) var preview_min_value: float = 0.0
@export_range(1.0, 999.0, 1.0) var preview_max_value: float = 100.0
@export_range(0.01, 100.0, 0.01) var preview_step: float = 1.0
@export_range(0.0, 999.0, 1.0) var stamina_preview_value: float = 65.0
@export_range(0.0, 999.0, 1.0) var transformation_preview_value: float = 80.0
@export_range(0.0, 999.0, 1.0) var cooldown_preview_value: float = 45.0
@export_range(0.0, 128.0, 0.5) var row_spacing: float = 28.0
@export var show_stamina_preview: bool = true
@export var show_transformation_preview: bool = true
@export_enum("cooldown", "transformation", "full") var wolf_preview_mode: String = "cooldown"
