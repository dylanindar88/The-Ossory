class_name HealthBarColor
extends RefCounted

const LOW_HEALTH_COLOR: Color = Color(1.0, 0.05, 0.0, 1.0)
const HIGH_HEALTH_COLOR: Color = Color(0.1, 0.95, 0.2, 1.0)


static func apply_to_bar(bar: TextureProgressBar, current_health: float, max_health: float):
	if bar == null:
		return

	var health_ratio: float = 0.0
	if max_health > 0.0:
		health_ratio = clamp(current_health / max_health, 0.0, 1.0)

	var health_color: Color = LOW_HEALTH_COLOR.lerp(HIGH_HEALTH_COLOR, health_ratio)
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([health_color, health_color])

	var gradient_texture: GradientTexture2D = GradientTexture2D.new()
	gradient_texture.width = 64
	gradient_texture.gradient = gradient
	bar.texture_progress = gradient_texture
