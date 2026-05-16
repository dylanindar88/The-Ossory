# Banshee Hostile NPC Scene

`Banshee.tscn` is the reusable Banshee actor scene used by level flow and encounter controllers.

- `ProjectileSpawn` is the editable right-facing origin for ranged Banshee projectiles. The actor script mirrors its X offset when firing left.
- `AttackBox/CollisionShape2D` remains the melee hit shape and follows the shared attack-box convention.
- Banshee story, respawn, and wolf-clear policy stay owned by level encounter controllers.
