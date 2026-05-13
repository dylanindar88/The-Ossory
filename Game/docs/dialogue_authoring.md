# Dialogue Authoring

Most NPC dialogue is edited through Godot resources in `res://resources/dialogue/`.

For full NPC and level setup conventions, see `res://docs/content_authoring.md`.

## Resource Types

- `DialogueSequence` is the core text resource. Edit its `pages` array to change the lines shown in a dialogue bubble.
- `DialogueBank` is for simple NPC defaults, such as male and female villager chatter. It supports one fixed sequence or a random pool.
- `DialogueProfile` is for NPCs or levels with multiple named story lines. Each `DialogueEntry.key` is used by code to pick the right editable `DialogueSequence`.

## Current Editing Locations

- Villager defaults: `res://resources/dialogue/npcs/celtic_villagers/`.
- Banshee Village story lines: `res://resources/dialogue/levels/banshee_village/`.
- Dulluhan story lines: `res://resources/dialogue/npcs/dulluhan/dulluhan_story_profile.tres`.
- Vincent house dialogue: `res://resources/dialogue/npcs/vincent/vincent_story_profile.tres`.

## Rules

- Story progression should react to dialogue completion signals, not to the text content.
- Keep entry keys stable unless the controller code is updated in the same change.
- Use one `DialogueSequence` page for each intentional page. The dialogue bubble may still paginate long pages visually.
- Generic NPC save/collision systems should use `non_hostile_npcs`; use `celtic_villagers` only for actual Celtic villager dialogue or ambient behavior.
