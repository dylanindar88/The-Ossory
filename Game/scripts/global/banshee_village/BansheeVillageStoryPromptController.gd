extends RefCounted
class_name BansheeVillageStoryPromptController

const STAGE_RULES = preload("res://scripts/global/banshee_village/BansheeVillageStageRules.gd")
const STORY_TRANSFORM_PROMPT_TEXT = "Press Q to transform."

var flow


func setup(controller):
	flow = controller


func restore_story_transformation_state():
	if flow.story_wolf_lock_active and flow.is_wolf_hunt_stage():
		flow.story_transform_prompt_consumed = true
		hide_story_prompt()
		if flow.player != null and flow.player.has_method("restore_story_wolf_transformation_lock"):
			flow.player.restore_story_wolf_transformation_lock()
		return

	if (
		flow.player != null
		and flow.player.has_method("is_story_wolf_transformation_locked")
		and bool(flow.player.call("is_story_wolf_transformation_locked"))
	):
		if flow.player.has_method("end_story_wolf_transformation_lock"):
			flow.player.end_story_wolf_transformation_lock(false)

	refresh_story_transform_prompt()


func sync_story_wolf_transformation_lock():
	if flow.player == null:
		return

	if not flow.is_wolf_hunt_stage():
		flow.story_wolf_lock_active = false
		if flow.is_player_story_wolf_transformation_locked() and flow.player.has_method("end_story_wolf_transformation_lock"):
			flow.player.end_story_wolf_transformation_lock(false)
		return

	if not flow.story_wolf_lock_active:
		return

	flow.story_transform_prompt_consumed = true
	hide_story_prompt()
	if flow.is_player_in_wolf_form() and not flow.is_player_story_wolf_transformation_locked() and flow.player.has_method("start_story_wolf_transformation_lock"):
		flow.player.start_story_wolf_transformation_lock()


func refresh_story_transform_prompt():
	if should_show_story_transform_prompt():
		show_story_prompt(STORY_TRANSFORM_PROMPT_TEXT)
	else:
		hide_story_prompt()
	sync_story_wolf_transformation_lock()


func should_show_story_transform_prompt() -> bool:
	return (
		flow.quest_stage == STAGE_RULES.STAGE_WOLF_HUNT_READY
		and flow.has_wolf_transformation_upgrade()
		and not flow.story_transform_prompt_consumed
		and not flow.story_wolf_lock_active
	)


func handle_player_transformation_state_changed(active: bool):
	if not active:
		if flow.story_wolf_lock_active:
			if not flow.is_wolf_hunt_stage():
				flow.story_wolf_lock_active = false
				return
			if flow.is_player_life_respawn_pending():
				return
			flow.call_deferred("restore_story_wolf_transformation_lock_after_unexpected_end")
		return

	if not flow.is_wolf_hunt_stage():
		sync_story_wolf_transformation_lock()
		return

	flow.story_transform_prompt_consumed = true
	flow.story_wolf_lock_active = true
	hide_story_prompt()
	if flow.player != null and flow.player.has_method("start_story_wolf_transformation_lock"):
		flow.player.start_story_wolf_transformation_lock()
	flow.save_wolf_clear_progress()


func restore_story_wolf_transformation_lock_after_unexpected_end():
	if not flow.story_wolf_lock_active or not flow.is_wolf_hunt_stage() or flow.is_player_life_respawn_pending():
		return

	if flow.player != null and flow.player.has_method("restore_story_wolf_transformation_lock"):
		flow.player.restore_story_wolf_transformation_lock()
	flow.save_wolf_clear_progress()


func show_story_prompt(text: String, timeout_seconds: float = 0.0):
	var label := get_story_prompt_label()
	if label == null:
		return

	flow.story_prompt_generation += 1
	label.text = text
	label.visible = true
	if timeout_seconds > 0.0:
		hide_story_prompt_after_delay(flow.story_prompt_generation, timeout_seconds)


func hide_story_prompt():
	flow.story_prompt_generation += 1
	if flow.story_prompt_label != null and is_instance_valid(flow.story_prompt_label):
		flow.story_prompt_label.visible = false


func hide_story_prompt_after_delay(generation: int, timeout_seconds: float):
	await flow.get_tree().create_timer(timeout_seconds).timeout
	if generation == flow.story_prompt_generation:
		hide_story_prompt()


func get_story_prompt_label() -> Label:
	if flow.player == null:
		return null

	if flow.story_prompt_label != null and is_instance_valid(flow.story_prompt_label):
		return flow.story_prompt_label

	flow.story_prompt_label = Label.new()
	flow.story_prompt_label.name = "BansheeVillageStoryPrompt"
	flow.story_prompt_label.z_as_relative = false
	flow.story_prompt_label.z_index = 250
	flow.story_prompt_label.position = Vector2(-120.0, -120.0)
	flow.story_prompt_label.size = Vector2(240.0, 58.0)
	flow.story_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flow.story_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flow.story_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow.story_prompt_label.add_theme_font_size_override("font_size", 9)
	flow.story_prompt_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	flow.story_prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	flow.story_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	flow.story_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	flow.story_prompt_label.visible = false
	flow.player.add_child(flow.story_prompt_label)
	return flow.story_prompt_label
