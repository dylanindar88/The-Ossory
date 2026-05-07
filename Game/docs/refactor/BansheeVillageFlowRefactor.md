# Banshee Village Flow Refactor Guardrails

This refactor is for maintainability only. The village should play, save, load, and feel the same after each pass.

## Behavior Checklist

- Intro elder dialogue starts the first banshee hunt.
- First hunt counts defeated banshees until the report threshold.
- Reporting to the elder reveals the Dulluhan story step.
- Dulluhan grants the wolf transformation and enables the wolf hunt.
- Wolf-form clears can permanently clear banshees according to the existing policy.
- The Vincent house teaser, interior conversation, third wave, bishop prompt, and route gates retain their current order.
- Save/load works at every major stage, including dev presets and pending scene loads.
- Player death, life respawn, combat save blocking, and story wolf transformation locking retain current behavior.

## Save Compatibility

`BansheeVillageFlowController.collect_level_state()` remains the public save interface until a later explicit migration. These level-state keys must stay compatible:

- `state_version`
- `quest_stage`
- `banshee_kill_count`
- `revealed_banshee_paths`
- `permanently_cleared_banshee_paths`
- `final_dulluhan_teaser_completed`
- `story_transform_prompt_consumed`
- `story_wolf_lock_active`
- `final_wolf_instruction_shown`
- `active_interior_id`
- `third_wave_spawned`
- `dulluhan_transformation_granted_for_level`
- `vincent_house_dialogue_completed_for_level`
- `bishop_confrontation_accepted_for_level`
- `dulluhan`
- `banshees`
- `villagers`

## Level Flow Convention

Future story-heavy levels should use one scene-attached coordinator as the public save provider. Optional helper scripts may own progression, encounter, presentation, interior travel, prompts, or dev setup, but helpers must not create separate save schemas unless the coordinator owns migration and compatibility.

## Completed Helper Layout

`BansheeVillageFlowController` remains the scene-attached coordinator. It owns node lookup, signal wiring, save/load entrypoints, and dispatch into focused helpers:

- `BansheeVillageStageRules.gd` validates quest stages and derived stage predicates.
- `BansheeVillageDevPresetBuilder.gd` builds debug boot states without changing normal saves.
- `BansheeVillageProgressionController.gd` owns quest transitions and story reactions.
- `BansheeVillageInteriorTravelController.gd` owns Vincent house transfer and active interior state.
- `BansheeVillageStoryPromptController.gd` owns the story wolf prompt and transformation lock.
- `BansheeVillagePresentationController.gd` owns route gates, flags, kill counter text, Dulluhan visibility, and exterior Vincent presentation.
- `BansheeVillageEncounterController.gd` owns banshee/villager story state, reveal/clear rules, combat variants, and respawn timing.

## Manual Smoke Checklist

After future changes to this flow, smoke test:

- New game arrival, elder intro, first hunt, first report, Dulluhan reveal, wolf unlock, wolf hunt, Vincent house, third wave, and bishop path.
- Save/load at intro, combat active, ready to report, Dulluhan available, wolf hunt, Vincent house, third wave, and bishop path.
- Dev presets, route exits, Vincent house entry/exit, player death/respawn, story transformation lock, banshee reveal/defeat/respawn, and wolf permanent clear.
