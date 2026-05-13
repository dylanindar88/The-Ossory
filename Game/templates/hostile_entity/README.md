# Hostile Entity Template Checklist

Use for combat enemies and hostile projectiles/entities.

- Scene: `res://scenes/characters/hostile_npcs/<entity_group>/<EntityName>.tscn`
- Script: `res://scripts/characters/hostile_npcs/<entity_group>/`
- Animation resource: `res://resources/characters/hostile_npcs/<entity_group>/<entity_name>.tres`
- Tuning resource when values are shared or designer-edited.
- Keep public actor methods stable if level flow or save/load calls them.
- Use generic hostile save naming such as `defeated_hostiles` unless a content-specific system requires a narrower name.

Validation:
- Scene references external `SpriteFrames`.
- Combat areas use deferred monitoring changes when toggled during signals.
- Save/load paths preserve story defeat/reveal state when the level owns hostiles.
