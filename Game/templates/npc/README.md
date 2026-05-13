# NPC Template Checklist

Use for simple non-story NPCs.

- Scene: `res://scenes/characters/npcs/<group_or_name>/<NpcName>.tscn`
- Script: reuse or create a controller under `res://scripts/characters/npcs/<group_or_name>/`
- Animation resource: `res://resources/characters/npcs/<group_or_name>/<npc_name>.tres`
- Dialogue bank: `res://resources/dialogue/npcs/<group_or_name>/<npc_name>_default.tres`
- Expected generic group: `non_hostile_npcs`.
- Content-specific group: use `celtic_villagers` only for actual Celtic villager behavior.

Validation:
- Scene references external `SpriteFrames`.
- Dialogue opens, advances, locks player input, and closes.
- NPC can be saved by level/provider only if the level intentionally owns its story state.
