# Boss Template Checklist

Use the hostile entity pattern first, then add boss-specific pieces.

- Scene: `res://scenes/characters/hostile_npcs/<boss_name>/<BossName>.tscn`
- Controller/state machine keeps public scene API.
- Helpers may own phases, arena locks, special attacks, or story lifecycle.
- Tuning and animation resources live under `res://resources/characters/hostile_npcs/<boss_name>/`.
- Level flow owns quest progression, arena gates, save state, and reward handoff.

Validation:
- Boss can be spawned or direct-loaded with all resources present.
- Death/clear signals fire once.
- Save/load preserves phase or defeat state according to the level contract.
- Route exits or arena gates unlock exactly when progression expects.
