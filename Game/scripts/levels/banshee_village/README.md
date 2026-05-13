# Banshee Village Flow Helpers

The scene keeps `BansheeVillageFlowController` as the public coordinator and save provider. Helpers in this folder may own focused behavior, but they should not become independent save providers unless the coordinator owns the packed save shape for the active schema version.

- `BansheeVillageStageRules.gd` owns stage validation and derived stage predicates.
- `BansheeVillageDevPresetBuilder.gd` owns temporary debug boot states.
- `BansheeVillageProgressionController.gd` owns quest transitions and progression reactions.
- `BansheeVillageInteriorTravelController.gd` owns Vincent house player transfer and active-room state.
- `BansheeVillageStoryPromptController.gd` owns the story wolf prompt and story transformation lock coordination.
- `BansheeVillagePresentationController.gd` owns route gates, flags, kill counter text, Dulluhan visibility, and exterior Vincent presentation.
- `BansheeVillageEncounterController.gd` owns banshee and Celtic villager story presentation, reveal state, clear state, combat variants, and respawn timing.

Future levels can follow the same pattern: one scene-attached coordinator, small internal helpers, and one coordinator-owned save dictionary.

Broader architecture and smoke-test guardrails live in `res://docs/refactor/BansheeVillageFlowRefactor.md` and `res://docs/refactor/MaintainabilityArchitecture.md`.

New level setup guidance lives in `res://docs/content_authoring.md` and `res://templates/level/README.md`.
