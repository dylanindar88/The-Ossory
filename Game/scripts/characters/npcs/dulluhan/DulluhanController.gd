extends CharacterBody2D

const DIALOGUE_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/DialogueBubble.tscn")
const UNLOCK_DIALOGUE := [
	"The old shape in your blood is awake now.",
	"When the time comes, wear the wolf and the dead will stay dead.",
]
const REPEAT_DIALOGUE := [
	"The wolf is yours now. Learn its hunger before you trust it.",
]

@export var hidden_alpha: float = 0.35

@onready var sprite: AnimatedSprite2D = $Body
@onready var proximity_area: Area2D = get_node_or_null("PlayerProximityArea") as Area2D
@onready var player_detection_area: Area2D = get_node_or_null("PlayerDetectionArea") as Area2D

var story_visible: bool = true
var revealed: bool = false
var transformation_granted: bool = false
var dialogue_active: bool = false
var active_dialogue_bubble: DialogueBubble
var current_dialogue_player: Node2D


func _ready():
	transformation_granted = has_transformation_upgrade()
	configure_detection_area()
	play_idle()
	apply_story_alpha()


func set_story_visible(should_show: bool):
	story_visible = should_show
	visible = should_show
	set_collision_enabled(should_show)
	if should_show:
		revealed = false
		apply_story_alpha()
		play_idle()
		call_deferred("refresh_player_detection")


func show_for_story():
	set_story_visible(true)


func hide_for_story():
	set_story_visible(false)


func interact(player: Node2D):
	if dialogue_active:
		if active_dialogue_bubble != null:
			active_dialogue_bubble.advance()
		return

	var sequence := create_dialogue_sequence(REPEAT_DIALOGUE if transformation_granted else UNLOCK_DIALOGUE)
	start_dialogue(player, sequence)


func create_dialogue_sequence(raw_pages: Array) -> DialogueSequence:
	var sequence := DialogueSequence.new()
	for page in raw_pages:
		sequence.pages.append(str(page))

	return sequence


func start_dialogue(player: Node2D, sequence: DialogueSequence):
	if CombatStateManager != null and not CombatStateManager.can_start_dialogue():
		return

	current_dialogue_player = player
	dialogue_active = true
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(true)
	if current_dialogue_player != null and current_dialogue_player.has_method("set_dialogue_input_locked"):
		current_dialogue_player.set_dialogue_input_locked(true)

	active_dialogue_bubble = DIALOGUE_BUBBLE_SCENE.instantiate() as DialogueBubble
	add_child(active_dialogue_bubble)
	if not active_dialogue_bubble.closed.is_connected(_on_dialogue_bubble_closed):
		active_dialogue_bubble.closed.connect(_on_dialogue_bubble_closed)
	active_dialogue_bubble.open(sequence)


func _on_dialogue_bubble_closed(completed: bool = false):
	active_dialogue_bubble = null
	var should_grant_transformation := completed and not transformation_granted
	var dialogue_player := current_dialogue_player
	dialogue_active = false
	current_dialogue_player = null

	if dialogue_player != null and is_instance_valid(dialogue_player) and dialogue_player.has_method("set_dialogue_input_locked"):
		dialogue_player.set_dialogue_input_locked(false)
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(false)

	if should_grant_transformation:
		grant_transformation_upgrade()


func grant_transformation_upgrade():
	transformation_granted = true
	if SaveManager == null:
		return

	SaveManager.unlock_upgrade(&"wolf_transformation")
	SaveManager.set_stat_level(&"wolf_transformation", 0)
	SaveManager.save_game("wolf_transformation_unlock", get_tree().current_scene)


func has_transformation_upgrade() -> bool:
	if SaveManager == null:
		return false

	var state := SaveManager.get_upgrade_state()
	var unlocked: Variant = state.get("unlocked", {})
	return unlocked is Dictionary and bool(unlocked.get("wolf_transformation", false))


func play_idle():
	if sprite == null:
		return

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func configure_detection_area():
	if player_detection_area == null:
		return

	player_detection_area.set_deferred("monitoring", true)
	player_detection_area.set_deferred("monitorable", true)
	player_detection_area.collision_layer = 0
	player_detection_area.collision_mask = 2

	if not player_detection_area.body_entered.is_connected(_on_player_detection_body_entered):
		player_detection_area.body_entered.connect(_on_player_detection_body_entered)


func refresh_player_detection():
	if not story_visible or player_detection_area == null:
		return

	for raw_body in player_detection_area.get_overlapping_bodies():
		if not (raw_body is Node2D):
			continue

		var body: Node2D = raw_body as Node2D
		if body.is_in_group("player"):
			reveal_for_player_approach()
			return


func reveal_for_player_approach():
	if not story_visible or revealed:
		return

	revealed = true
	apply_story_alpha()


func apply_story_alpha():
	if not story_visible:
		return

	modulate.a = 1.0 if revealed else hidden_alpha


func set_collision_enabled(enabled: bool):
	if proximity_area != null:
		proximity_area.set_deferred("monitoring", enabled)
		proximity_area.set_deferred("monitorable", enabled)
	if player_detection_area != null:
		player_detection_area.set_deferred("monitoring", enabled)
		player_detection_area.set_deferred("monitorable", enabled)

	for child in get_children():
		if child is CollisionShape2D:
			var collision_shape: CollisionShape2D = child as CollisionShape2D
			collision_shape.set_deferred("disabled", not enabled)
		elif child is Area2D:
			set_area_collision_enabled(child as Area2D, enabled)


func set_area_collision_enabled(area: Area2D, enabled: bool):
	area.set_deferred("monitoring", enabled)
	area.set_deferred("monitorable", enabled)
	for child in area.get_children():
		if child is CollisionShape2D:
			var collision_shape: CollisionShape2D = child as CollisionShape2D
			collision_shape.set_deferred("disabled", not enabled)


func _on_player_detection_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return

	reveal_for_player_approach()
