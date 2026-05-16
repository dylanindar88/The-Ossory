# Campfire Base Resources

This folder is reserved for campfire base tuning and art resources.

Campfire bases are wolf-vulnerable structures used by knight encounters. Destroying one disables linked knight respawns for the current level visit; leaving and re-entering the level restores the campfire and its linked respawns.

Campfire variant resources point to hand-authored layout scenes and future knight spawn tuning. Layout scenes contain normal or flipped `CampfireBaseTent`, plus collision-bearing `Campfire` and `MeleeBanner` world prop instances. A live base keeps its variant; a destroyed base rerolls when it respawns.

If a layout is drafted in Aseprite, use stable layer names such as `Tent1`, `campfire`, and `Banner`; the Godot layout scene should place matching nodes from those layers while keeping the variant resource path stable.
