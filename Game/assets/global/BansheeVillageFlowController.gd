extends Node

const STAGE_INTRO = "intro"
const STAGE_COMBAT_ACTIVE = "combat_active"
const STAGE_READY_TO_REPORT = "ready_to_report"
const STAGE_REPORT_COMPLETE = "report_complete"
const LEVEL_STATE_VERSION = 1
const DIALOGUE_CHOICE_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/DialogueChoiceBubble.tscn")

@export var player_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/Saorise")
@export var npc_root_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs")
@export var hostile_root_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/HostileNPCs")
@export var elder_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs/ElderVillager")
@export var dulluhan_path: NodePath = NodePath("../PlayableWorld/Environment/Characters/NPCs/Dulluhan")
@export var kill_counter_path: NodePath = NodePath("../HUD/BansheeKillCounter")
@export var hidden_banshee_alpha: float = 0.2
@export var respawn_delay_seconds: float = 10.0
@export var report_kill_threshold: int = 10
@export var elder_reveal_sequence: DialogueSequence
@export var elder_waiting_sequence: DialogueSequence
@export var elder_respawning_sequence: DialogueSequence
@export var male_stalked_sequence: DialogueSequence
@export var female_stalked_sequence: DialogueSequence
@export var male_clear_sequence: DialogueSequence
@export var female_clear_sequence: DialogueSequence

var quest_stage: String = STAGE_INTRO
var banshee_kill_count: int = 0
var cleared_villager_paths: Dictionary = {}
var revealed_banshee_paths: Dictionary = {}
var defeated_banshees: Dictionary = {}
var saved_banshee_states: Dictionary = {}
var saved_villager_states: Dictionary = {}
var player: Node
var elder: Node
var dulluhan: Node
var elder_flag: EffectList
var kill_counter: Label
var elder_choice_bubble: DialogueChoiceBubble
var banshees: Array[Node] = []
var state_generation: int = 0


func _ready():
	player = get_node_or_null(player_path)
	elder = get_node_or_null(elder_path)
	dulluhan = get_node_or_null(dulluhan_path)
	if elder != null:
		elder_flag = elder.get_node_or_null("Effects") as EffectList
		if elder_flag == null:
			elder_flag = elder.get_node_or_null("Flag") as EffectList
	kill_counter = get_node_or_null(kill_counter_path) as Label
	banshees = get_banshees()

	connect_player_interactions()
	connect_elder_dialogue()
	connect_banshees()
	apply_intro_defaults()


func collect_level_state() -> Dictionary:
	return {
		"state_version": LEVEL_STATE_VERSION,
		"quest_stage": quest_stage,
		"banshee_kill_count": banshee_kill_count,
		"revealed_banshee_paths": revealed_banshee_paths.keys(),
		"banshees": collect_banshee_states(),
		"villagers": collect_villager_states(),
	}


func uses_level_owned_hostile_state() -> bool:
	return true


func uses_level_owned_villager_state() -> bool:
	return true


func validate_level_state(state: Dictionary) -> Array:
	var messages: Array = []
	var state_version: int = int(state.get("state_version", 0))
	if state_version > LEVEL_STATE_VERSION:
		messages.append("BansheeVillage save state version %d is newer than supported version %d." % [state_version, LEVEL_STATE_VERSION])

	var saved_stage: String = str(state.get("quest_stage", STAGE_INTRO))
	if saved_stage != get_valid_stage(saved_stage):
		messages.append("BansheeVillage save has invalid quest_stage '%s'." % saved_stage)

	if not (state.get("banshees", []) is Array):
		messages.append("BansheeVillage save has malformed banshees snapshot data.")
	if not (state.get("villagers", []) is Array):
		messages.append("BansheeVillage save has malformed villagers snapshot data.")

	if elder == null:
		messages.append("BansheeVillageFlowController could not find elder at %s." % elder_path)
	if kill_counter == null:
		messages.append("BansheeVillageFlowController could not find kill counter at %s." % kill_counter_path)
	if dulluhan == null:
		messages.append("BansheeVillageFlowController could not find Dulluhan at %s." % dulluhan_path)

	append_missing_actor_path_warnings(messages, state.get("banshees", []), "banshee")
	append_missing_actor_path_warnings(messages, state.get("villagers", []), "villager")
	append_missing_assigned_villager_warnings(messages)
	return messages


func append_missing_actor_path_warnings(messages: Array, raw_states: Variant, actor_label: String):
	if not (raw_states is Array):
		return

	var level: Node = get_parent()
	if level == null:
		return

	for raw_state in raw_states:
		if not (raw_state is Dictionary):
			messages.append("BansheeVillage save has malformed %s snapshot entry." % actor_label)
			continue

		var state: Dictionary = raw_state
		var actor_path: String = str(state.get("node_path", ""))
		if actor_path == "":
			messages.append("BansheeVillage save has %s snapshot with no node_path." % actor_label)
		elif level.get_node_or_null(NodePath(actor_path)) == null:
			messages.append("BansheeVillage save references missing %s '%s'." % [actor_label, actor_path])


func append_missing_assigned_villager_warnings(messages: Array):
	for banshee in banshees:
		if banshee == null or not banshee.has_method("has_assigned_villager"):
			continue

		if str(banshee.get("assigned_villager_path")) != "" and not bool(banshee.call("has_assigned_villager")):
			messages.append("%s has assigned_villager_path '%s' but no resolved villager." % [banshee.name, banshee.get("assigned_villager_path")])


func apply_level_state(state: Dictionary):
	state_generation += 1
	var normalized_state: Dictionary = normalize_level_state(state)
	quest_stage = get_valid_stage(str(normalized_state.get("quest_stage", STAGE_INTRO)))
	banshee_kill_count = maxi(int(normalized_state.get("banshee_kill_count", 0)), 0)
	cleared_villager_paths = {}
	defeated_banshees.clear()
	saved_banshee_states = parse_saved_banshee_states(normalized_state.get("banshees", []))
	saved_villager_states = SaveManager.parse_actor_snapshot_lookup(normalized_state.get("villagers", []))

	revealed_banshee_paths = {}
	var saved_revealed_paths: Variant = normalized_state.get("revealed_banshee_paths", [])
	if saved_revealed_paths is Array:
		for path in saved_revealed_paths:
			revealed_banshee_paths[str(path)] = true

	if quest_stage == STAGE_COMBAT_ACTIVE and banshee_kill_count >= report_kill_threshold:
		quest_stage = STAGE_READY_TO_REPORT

	restore_saved_villager_states()
	restore_stage_world_state()
	saved_banshee_states.clear()
	saved_villager_states.clear()


func normalize_level_state(state: Dictionary) -> Dictionary:
	var normalized_state: Dictionary = state.duplicate(true)
	var state_version: int = int(normalized_state.get("state_version", 0))
	normalized_state["state_version"] = clamp(state_version, 0, LEVEL_STATE_VERSION)
	return normalized_state


func connect_player_interactions():
	if player == null or not player.has_signal("interaction_requested"):
		return

	var callback: Callable = Callable(self, "_on_player_interaction_requested")
	if not player.is_connected("interaction_requested", callback):
		player.connect("interaction_requested", callback)


func connect_elder_dialogue():
	if elder == null:
		return

	if elder.has_signal("dialogue_finished"):
		var callback: Callable = Callable(self, "_on_elder_dialogue_finished")
		if not elder.is_connected("dialogue_finished", callback):
			elder.connect("dialogue_finished", callback)

func connect_banshees():
	for banshee in banshees:
		if banshee == null:
			continue

		if banshee.has_signal("defeated"):
			var defeated_callback: Callable = Callable(self, "_on_banshee_defeated")
			if not banshee.is_connected("defeated", defeated_callback):
				banshee.connect("defeated", defeated_callback)

		if banshee.has_signal("player_detected_for_reveal"):
			var reveal_callback: Callable = Callable(self, "_on_banshee_detected_player_for_reveal")
			if not banshee.is_connected("player_detected_for_reveal", reveal_callback):
				banshee.connect("player_detected_for_reveal", reveal_callback)


func get_banshees() -> Array[Node]:
	var hostile_root: Node = get_node_or_null(hostile_root_path)
	var found_banshees: Array[Node] = []
	if hostile_root == null:
		return found_banshees

	for child in hostile_root.get_children():
		if child.is_in_group("hostile_npcs"):
			found_banshees.append(child)

	return found_banshees


func collect_banshee_states() -> Array:
	var hostile_root: Node = get_node_or_null(hostile_root_path)
	return SaveManager.collect_story_actor_states(get_parent(), hostile_root, "hostile_npcs")


func collect_villager_states() -> Array:
	var npc_root: Node = get_node_or_null(npc_root_path)
	return SaveManager.collect_story_actor_states(get_parent(), npc_root, "villagers")


func parse_saved_banshee_states(raw_states: Variant) -> Dictionary:
	return SaveManager.parse_actor_snapshot_lookup(raw_states)


func apply_intro_defaults():
	state_generation += 1
	quest_stage = STAGE_INTRO
	banshee_kill_count = 0
	cleared_villager_paths.clear()
	revealed_banshee_paths.clear()
	defeated_banshees.clear()
	saved_banshee_states.clear()
	saved_villager_states.clear()
	restore_stage_world_state()


func restore_stage_world_state():
	# Full restore is for fresh init, save load, and first quest activation only.
	# Mid-quest UI/dialogue updates should call refresh_quest_presentation() instead.
	refresh_quest_presentation()

	if quest_stage == STAGE_INTRO:
		apply_banshee_villager_presentation(false)
		return

	apply_banshee_villager_presentation(true)


func refresh_quest_presentation():
	# Presentation refresh must not reset actor position, health, death, or patrol state.
	if quest_stage == STAGE_INTRO:
		set_elder_sequence(elder_reveal_sequence)
	elif quest_stage == STAGE_READY_TO_REPORT or quest_stage == STAGE_REPORT_COMPLETE:
		set_elder_sequence(elder_respawning_sequence)
	else:
		set_elder_sequence(elder_waiting_sequence)

	update_elder_flag()
	update_kill_counter()
	update_dulluhan_visibility()


func restore_saved_villager_states():
	SaveManager.apply_story_actor_states(get_parent(), saved_villager_states)


func apply_banshee_villager_presentation(combat_enabled: bool):
	for banshee in banshees:
		var banshee_path: String = get_relative_node_path(banshee)
		var saved_state: Dictionary = {}
		if saved_banshee_states.has(banshee_path):
			var raw_saved_state: Variant = saved_banshee_states[banshee_path]
			if raw_saved_state is Dictionary:
				saved_state = raw_saved_state

		var villager: Node = get_banshee_assigned_villager(banshee)
		var villager_path: String = get_relative_node_path(villager)
		var villager_is_clear: bool = cleared_villager_paths.has(villager_path)
		var saved_dead: bool = bool(saved_state.get("dead", false))

		if saved_dead or villager_is_clear:
			set_villager_clear_sequence(villager)
			apply_cleared_banshee_state(banshee, saved_state)
			defeated_banshees[banshee] = true
			if saved_dead:
				schedule_banshee_respawn(banshee)
			continue

		set_villager_stalked_sequence(villager)
		if saved_state.is_empty() and saved_villager_states.is_empty():
			reset_villager_stalk_state(villager)
		apply_active_banshee_state(banshee, combat_enabled, saved_state)


func apply_active_banshee_state(banshee: Node, combat_enabled: bool, saved_state: Dictionary = {}):
	if banshee == null:
		return

	var banshee_path: String = get_relative_node_path(banshee)
	var is_revealed: bool = combat_enabled and revealed_banshee_paths.has(banshee_path)
	if saved_state.has("revealed"):
		is_revealed = combat_enabled and bool(saved_state.get("revealed", false))

	var alpha: float = hidden_banshee_alpha
	if is_revealed:
		alpha = 1.0

	if not saved_state.is_empty() and banshee.has_method("restore_from_story_save"):
		banshee.restore_from_story_save(saved_state, hidden_banshee_alpha, combat_enabled, is_revealed)
		return

	if banshee.has_method("restore_for_story_load"):
		banshee.restore_for_story_load(hidden_banshee_alpha, combat_enabled, is_revealed)
		return

	if banshee.has_method("restore_after_load"):
		banshee.restore_after_load()

	if banshee.has_method("set_story_combat_enabled"):
		if combat_enabled and banshee.has_method("enable_story_combat"):
			banshee.enable_story_combat(alpha)
		elif not combat_enabled and banshee.has_method("disable_story_combat"):
			banshee.disable_story_combat(alpha)
		else:
			banshee.set_story_combat_enabled(combat_enabled, alpha)

	if banshee.has_method("set_story_revealed"):
		banshee.set_story_revealed(is_revealed, hidden_banshee_alpha)


func apply_cleared_banshee_state(banshee: Node, saved_state: Dictionary = {}):
	if banshee == null:
		return

	var banshee_path: String = get_relative_node_path(banshee)
	revealed_banshee_paths.erase(banshee_path)

	if not saved_state.is_empty() and banshee.has_method("restore_dead_from_story_save"):
		banshee.restore_dead_from_story_save(saved_state, hidden_banshee_alpha)
	elif banshee.has_method("hide_as_story_defeated"):
		banshee.hide_as_story_defeated(hidden_banshee_alpha)


func set_elder_sequence(sequence: DialogueSequence):
	if elder != null:
		set_villager_dialogue_override(elder, sequence)


func set_villager_stalked_sequence(villager: Node):
	if villager == null or villager == elder:
		return

	set_villager_dialogue_override(villager, get_villager_sequence(villager, true))


func set_villager_clear_sequence(villager: Node):
	if villager == null or villager == elder:
		return

	set_villager_dialogue_override(villager, get_villager_sequence(villager, false))


func set_villager_dialogue_override(villager: Node, sequence: DialogueSequence):
	if villager == null:
		return

	if villager.has_method("set_dialogue_override"):
		villager.set_dialogue_override(sequence)
	else:
		villager.set("dialogue_override_sequence", sequence)


func reset_villager_stalk_state(villager: Node):
	if villager == null or villager == elder:
		return

	if villager.has_method("reset_banshee_stalk_state"):
		villager.reset_banshee_stalk_state()


func get_villager_sequence(villager: Node, is_stalked: bool) -> DialogueSequence:
	var lower_name: String = villager.name.to_lower()
	var is_female: bool = lower_name.contains("female")
	if is_stalked:
		if is_female:
			return female_stalked_sequence

		return male_stalked_sequence

	if is_female:
		return female_clear_sequence

	return male_clear_sequence


func get_banshee_assigned_villager(banshee: Node) -> Node:
	if banshee != null and banshee.has_method("get_assigned_villager"):
		return banshee.get_assigned_villager()

	return null


func is_banshee_defeated_or_waiting(banshee: Node) -> bool:
	if banshee == null:
		return false

	if defeated_banshees.has(banshee):
		return true

	if bool(banshee.get("dead")):
		return true

	var health_node: Node = banshee.get_node_or_null("Health")
	if health_node != null and bool(health_node.get("dead")):
		return true

	return false


func get_relative_node_path(node: Node) -> String:
	var level: Node = get_parent()
	if level != null and node != null and level.is_ancestor_of(node):
		return str(level.get_path_to(node))

	return ""


func get_valid_stage(stage: String) -> String:
	if stage == STAGE_COMBAT_ACTIVE or stage == STAGE_READY_TO_REPORT or stage == STAGE_REPORT_COMPLETE:
		return stage

	return STAGE_INTRO


func begin_combat_stage():
	close_elder_choice_prompt(false)
	state_generation += 1
	quest_stage = STAGE_COMBAT_ACTIVE
	banshee_kill_count = 0
	cleared_villager_paths.clear()
	revealed_banshee_paths.clear()
	defeated_banshees.clear()
	restore_stage_world_state()


func begin_ready_to_report_stage():
	quest_stage = STAGE_READY_TO_REPORT
	refresh_quest_presentation()


func complete_report_stage():
	close_elder_choice_prompt(false)
	quest_stage = STAGE_REPORT_COMPLETE
	refresh_quest_presentation()


func _on_player_interaction_requested(interactable: Node2D):
	if interactable == null or not interactable.has_method("interact"):
		return

	if interactable == elder and elder_choice_bubble != null and is_instance_valid(elder_choice_bubble):
		elder_choice_bubble.confirm_selection()
		return

	interactable.interact(player)


func _on_elder_dialogue_finished(_villager: Node):
	if quest_stage == STAGE_INTRO:
		open_elder_choice_prompt()
	elif quest_stage == STAGE_READY_TO_REPORT:
		complete_report_stage()


func open_elder_choice_prompt():
	if elder == null:
		return

	if elder_choice_bubble != null and is_instance_valid(elder_choice_bubble):
		return

	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(true)
	if player != null and player.has_method("set_dialogue_input_locked"):
		player.set_dialogue_input_locked(true)

	elder_choice_bubble = DIALOGUE_CHOICE_BUBBLE_SCENE.instantiate() as DialogueChoiceBubble
	elder.add_child(elder_choice_bubble)

	var selected_callback: Callable = Callable(self, "_on_elder_choice_selected")
	if not elder_choice_bubble.choice_selected.is_connected(selected_callback):
		elder_choice_bubble.choice_selected.connect(selected_callback)

	var closed_callback: Callable = Callable(self, "_on_elder_choice_closed")
	if not elder_choice_bubble.closed.is_connected(closed_callback):
		elder_choice_bubble.closed.connect(closed_callback)

	elder_choice_bubble.open()


func close_elder_choice_prompt(accepted: bool):
	if elder_choice_bubble == null or not is_instance_valid(elder_choice_bubble):
		elder_choice_bubble = null
		return

	var bubble: DialogueChoiceBubble = elder_choice_bubble
	elder_choice_bubble = null
	bubble.close(accepted)
	if player != null and player.has_method("set_dialogue_input_locked"):
		player.set_dialogue_input_locked(false)
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(false)


func _on_elder_choice_selected(accepted: bool):
	if accepted:
		begin_combat_stage()
		SaveManager.save_game("banshee_quest_accept", get_parent())


func _on_elder_choice_closed(_accepted: bool):
	elder_choice_bubble = null
	if player != null and player.has_method("set_dialogue_input_locked"):
		player.set_dialogue_input_locked(false)
	if CombatStateManager != null:
		CombatStateManager.set_dialogue_active(false)


func _on_banshee_defeated(banshee: Node):
	if quest_stage == STAGE_INTRO or defeated_banshees.has(banshee):
		return

	defeated_banshees[banshee] = true
	banshee_kill_count += 1
	var banshee_path: String = get_relative_node_path(banshee)
	revealed_banshee_paths.erase(banshee_path)

	var villager: Node = get_banshee_assigned_villager(banshee)
	var villager_path: String = get_relative_node_path(villager)
	if villager_path != "":
		cleared_villager_paths[villager_path] = true
	set_villager_clear_sequence(villager)
	update_kill_counter()
	schedule_banshee_respawn(banshee)

	if quest_stage == STAGE_COMBAT_ACTIVE and banshee_kill_count >= report_kill_threshold:
		begin_ready_to_report_stage()


func _on_banshee_detected_player_for_reveal(banshee: Node):
	if quest_stage == STAGE_INTRO or banshee == null:
		return

	if defeated_banshees.has(banshee):
		return

	var banshee_path: String = get_relative_node_path(banshee)
	if banshee_path == "":
		return

	revealed_banshee_paths[banshee_path] = true
	if banshee.has_method("set_story_revealed"):
		banshee.set_story_revealed(true, hidden_banshee_alpha)


func schedule_banshee_respawn(banshee: Node):
	if banshee == null:
		return

	var scheduled_generation: int = state_generation
	await get_tree().create_timer(respawn_delay_seconds).timeout
	if scheduled_generation != state_generation:
		return

	respawn_banshee(banshee)


func respawn_banshee(banshee: Node):
	if quest_stage == STAGE_INTRO or banshee == null or not is_instance_valid(banshee):
		return

	if not defeated_banshees.has(banshee):
		return

	defeated_banshees.erase(banshee)
	revealed_banshee_paths.erase(get_relative_node_path(banshee))

	var villager: Node = get_banshee_assigned_villager(banshee)
	var villager_path: String = get_relative_node_path(villager)
	if villager_path != "":
		cleared_villager_paths.erase(villager_path)
	set_villager_stalked_sequence(villager)
	reset_villager_stalk_state(villager)

	if banshee.has_method("respawn_for_story"):
		banshee.respawn_for_story(hidden_banshee_alpha)
	elif banshee.has_method("restore_after_load"):
		banshee.restore_after_load()
		if banshee.has_method("enable_story_combat"):
			banshee.enable_story_combat(hidden_banshee_alpha)
		elif banshee.has_method("set_story_combat_enabled"):
			banshee.set_story_combat_enabled(true, hidden_banshee_alpha)


func update_kill_counter():
	if kill_counter == null:
		return

	var should_show: bool = quest_stage == STAGE_COMBAT_ACTIVE or quest_stage == STAGE_READY_TO_REPORT
	kill_counter.visible = should_show
	if not should_show:
		return

	var shown_count: int = mini(banshee_kill_count, report_kill_threshold)
	kill_counter.text = "Banshees: %d/%d" % [shown_count, report_kill_threshold]


func update_elder_flag():
	if elder_flag == null:
		return

	if quest_stage == STAGE_INTRO or quest_stage == STAGE_READY_TO_REPORT:
		elder_flag.set_effects(["flag"])
	else:
		elder_flag.clear_effects()


func update_dulluhan_visibility():
	if dulluhan == null:
		return

	var should_show: bool = quest_stage == STAGE_REPORT_COMPLETE
	if dulluhan.has_method("set_story_visible"):
		dulluhan.set_story_visible(should_show)
	else:
		dulluhan.visible = should_show
