# ============================================================================
# BLOCK STATE
# Handles blocking mechanic and damage reduction
# ============================================================================

class_name BlockState

var char_data: Object  # CharacterData reference

var is_blocking: bool = false
var damage_reduction: float = 0.5  # Blocks 50% of damage


func _init(data: Object):
	char_data = data


func enter():
	is_blocking = true
	# TODO: Play block animation
	# char_data.sprite.play("block")


func update(delta: float):
	# Allow slow movement while blocking (optional)
	# Currently set to no movement while blocking
	char_data.velocity = Vector2.ZERO


func exit():
	is_blocking = false
