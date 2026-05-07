# Story NPC Template Checklist

Use for named NPCs with story-state dialogue or progression signals.

- Scene: `res://scenes/characters/npcs/<npc_name>/<NpcName>.tscn`
- Controller: `res://scripts/characters/npcs/<npc_name>/<NpcName>Controller.gd`
- Animation resource: `res://resources/characters/npcs/<npc_name>/<npc_name>.tres`
- Dialogue profile: `res://resources/dialogue/npcs/<npc_name>/<npc_name>_story_profile.tres`
- Use `DialogueProfile` keys for story states.
- Story progression reacts to completion signals, not text content.

Validation:
- Dialogue profile has every key the controller asks for.
- Completion signals still fire after the final page.
- Save/load restores story visibility, completed state, and any level-owned flags.
