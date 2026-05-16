# Knight Hostile NPC Scenes

This folder contains the scene framework for basic knight hostiles.

- `BasicKnightMelee.tscn` and `BasicKnightRanged.tscn` share `KnightController` behavior but use separate tuning resources.
- `KnightArrowProjectile.tscn` is the ranged knight projectile scaffold.
- `BasicKnightRanged.tscn` owns `ProjectileSpawn`; `BasicKnightMelee.tscn` intentionally does not because melee attacks use `AttackBox/CollisionShape2D`.
- Knight scenes should stay in the `hostile_npcs` group and use generic hostile save/collision terms.
- Knight respawns are controlled by linked campfire bases. Destroying a campfire in wolf form disables linked respawns only for the current level visit.

Future sprite work should update the variant animation resources under `res://resources/characters/hostile_npcs/knights/` without changing these scene paths.
