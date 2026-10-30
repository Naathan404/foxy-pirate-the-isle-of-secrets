# CONTRACT.md — FOXY PIRATE / GODOT GDSCRIPT ENGINEERING CONTRACT

**Status:** Project-wide engineering rules for Codex and contributors

**Scope:** Godot 4.x · GDScript · scenes, scripts, resources, signals, tests

**Priority:** Maintainable gameplay code for a small student team — SOLID without overengineering.

> **MANDATORY FOR CODEX:** Read this file, the relevant existing project files, and applicable feature specifications **before editing code**. This file is a working contract, not a request to implement every system mentioned here. Implement **only** the feature/fix in the current task.

---

## 1. Project context and source of truth

- Project: **Foxy Pirate: The Isle of Secrets**, a 2.5D top-down action RPG built in **Godot + GDScript**.
- Small team: **3 gameplay developers, 1 artist, 1 level/map builder**. Optimize for code that another student can understand and maintain.
- Gameplay uses an isometric 3D world with **8-direction movement on the XZ plane**. Respect Y as the vertical axis when working on 3D movement/physics.
- The project's **actual Godot version**, enabled addons, node trees, and folder layout must be read from the repository. **Do not assume a version or restructure based on this document.**
- If present, read the relevant portions of:
  - `project.godot`, `README.md`, existing scenes/scripts/resources;
  - the current game design document (GDD);
  - any task-specific acceptance criteria.
- **Priority if instructions conflict:** explicit current user task → current approved feature specification/GDD → this contract → established repository conventions → generic advice. If two authoritative requirements materially conflict, report the conflict instead of silently inventing a resolution.
- Never interpret examples below as permission to create files/classes that do not serve the task.

## 2. Non-negotiable engineering rules

1. **Inspect before coding.** Search for existing scripts, scenes, utilities, components, signals, and data models with similar responsibility. Reuse or extend them when appropriate.
2. **Smallest correct change.** Touch only the files necessary to satisfy the task. Avoid unrelated refactors, renames, formatting changes, or scene reorganizations.
3. **No speculative architecture.** Do not create classes, interfaces, managers, service layers, factories, repositories, event buses, enums, or configuration files “for the future.”
4. **No duplicate behavior.** Keep **one clear owner** for each gameplay rule, calculation, or persistent piece of state. Do not implement the same logic in Player, Enemy, Weapon, and UI separately.
5. **Data-driven only where useful.** Use `Resource` for shared configuration/definitions; use `Node`/scene scripts for behavior and lifecycle. Do not replace ordinary short code with an unnecessary framework.
6. **Preserve contracts.** Do not break existing scene paths, signals, exported variables, save formats, input actions, collision layers, animations, or resource references without task necessity.
7. **Do not invent design rules.** If damage, cooldown, timing, balance, compatibility, or state transitions are unspecified, preserve the existing behavior. Surface the missing decision; use a clearly labeled placeholder only when required for a runnable prototype.
8. **No unfinished stubs disguised as features.** Do not leave `pass`, hard-coded fake responses, disconnected UI, or TODO-only implementations and claim completion.
9. **No silent destructive changes.** Never overwrite unrelated work, run `git reset --hard`, force-push, delete assets, or rebuild broad parts of the project without explicit authorization.
10. **Verify honestly.** Report what actually ran, what passed, what failed, and what could not be tested. Never claim “tested” based solely on reading code.

### Decision filter: should a new class/script be created?

Create a new script **only if** it has an independently useful responsibility **and** at least one is true:
- an existing script is becoming hard to reason about because of unrelated responsibilities;
- a behavior must be reused by multiple features/entities;
- a scene/component has its own Godot lifecycle, signals, or configuration;
- the change becomes meaningfully more testable, replaceable, or readable.

Otherwise, add a focused method to an existing owner. **A file per tiny method is not SOLID.**

## 3. SOLID in Godot — pragmatic application

### S — Single Responsibility Principle
- A class/scene should have **one primary reason to change**.
- Example: Player movement handles locomotion; a damage/health owner handles HP changes; HUD displays state. The HUD must not calculate damage or modify HP directly.
- Do not split a small, cohesive feature merely to increase the number of classes.

### O — Open/Closed Principle
- Prefer adding a **new data definition or focused behavior** over editing many unrelated weapon/enemy conditionals.
- Example: a new weapon attack should usually reuse the existing attack data and execution scene pattern, without copying a new `PlayerAttack` implementation.
- Do not build a universal plugin/strategy framework before there are real variations to support.

### L — Liskov Substitution Principle
- A specialized node/resource must honor the behavior expected by code using its base type.
- Example: an enemy type inheriting from an existing enemy base must preserve its expected damage, death, and signal contracts; it must not make callers special-case that enemy just to avoid errors.
- Prefer composition when subclasses require many exceptions or incompatible overrides.

### I — Interface Segregation Principle
- Expose **small, purposeful APIs** (e.g., `take_damage`, `try_attack`, `equip`) rather than giant “do everything” managers.
- GDScript does not require an invented interface file for every contract. Use typed references, documented signals, and existing base classes where they genuinely help.
- No component should be forced to implement unrelated callbacks.

### D — Dependency Inversion Principle
- High-level gameplay flow should depend on **stable, narrow contracts**, not deep knowledge of another scene's internal child paths.
- The owning parent may inject/configure references (`@export`, explicit setup methods) and subscribe to signals.
- Use a direct method call when one scene clearly owns another. Use signals for events and to decouple unrelated listeners.
- Avoid reaching across the entire tree with `get_node("/root/...")` or creating new Autoloads just to access nearby objects.

**Order of preference:** existing simple solution → composition/reusable component → minimal abstraction. Inheritance depth and architectural layers are **not** quality metrics.

## 4. Godot design contracts

### Scenes, Nodes, and Resources
- **Scene (`.tscn`)**: owns the hierarchy, visual parts, collision setup, and local composition of an entity/feature.
- **Node script (`.gd`)**: owns lifecycle, input, runtime state, physics, and gameplay behavior relevant to that node.
- **Resource (`.tres` + Resource script)**: owns authorable configuration such as weapon data, attack parameters, enemy archetypes, and forge modifiers.
- **Do not mutate shared Resource definitions at runtime.** Store per-instance HP, cooldowns, equipped items, and combat state on runtime instances; duplicate a Resource only when mutable per-instance data truly requires it.
- Use existing scene inheritance/components when suitable; avoid duplicating entire Player/Enemy scenes just to change numbers.
- Each state/data field must have **one owner**. UI observes ownership; it does not keep its own competing gameplay truth.

### Communication / coupling
- **Direct calls:** within a tightly owned scene hierarchy where the reference is explicit and stable.
- **Signals:** to announce events (`health_changed`, `died`, `attack_finished`, `weapon_changed`) without knowing all listeners.
- **Autoload:** for genuinely cross-scene, shared lifecycle responsibilities (e.g., an existing SaveManager). Do not create a new global singleton for every system or use it as a global variable bag.
- **Groups:** for suitable many-object queries or notifications; do not use stringly typed groups to hide dependencies when a direct reference is clearer.
- Connect signals once, at a clear ownership point. Disconnect/guard lifetime where needed; avoid duplicate connections and callbacks on freed nodes.

### Physics, input, and timing
- For 3D gameplay, respect the established `CharacterBody3D`/`AnimatableBody3D` usage and collision architecture; don't swap body types without verifying behavior.
- Movement and collision-dependent updates belong in `_physics_process(delta)` unless the existing implementation has a justified alternative.
- Keep input reading distinct from gameplay decisions where that separation actually helps; reuse Input Map actions, **do not rename them casually**.
- No frame-count-based gameplay timing: use seconds, `delta`, timers, or explicit animation/physics events.
- Animation must not be the **only** authority for hit validation if it causes inconsistent hitboxes/state. Align startup/active/recovery with the established combat implementation.
- Do not use arbitrary timers or `await` as a workaround for unclear initialization/order dependencies.

### State machines
- Reuse an existing player/enemy state machine if present.
- Add a state only when it represents **meaningfully different behavior or transitions**; don't introduce a State class for every tiny animation or input branch.
- State transitions must be explicit, avoid contradictory flags, and have predictable enter/exit behavior.

### Feature boundaries for Foxy Pirate
- **Player movement:** locomotion, dash, movement-specific state — not weapon stats or UI rendering.
- **Combat/attack:** validates attacks, applies hits/damage, exposes attack lifecycle — not inventory persistence.
- **Weapon Base:** identity, attack pattern/moveset, base stats and weapon skill.
- **Forge:** preserve the existing `WeaponForge` Resource and per-weapon modifiers on `WeaponInstance.forge`.
- **Charm:** player-wide active/passive ability system, managed separately from weapon data.
- **Save:** serializes authoritative state; does not implement gameplay rules.
- **UI:** renders data and sends commands; never owns the canonical HP, Gold, CP, SP, or equipment data.

**Source priority:** Preserve the existing forge implementation unless the user explicitly requests a change. Do not introduce new equipment systems or crafting flows from a reference document alone.

## 5. GDScript coding conventions

Use the official Godot GDScript style guide unless this repository already has a consistent convention.

| Item | Convention | Example |
|---|---|---|
| Script file | `snake_case.gd` | `weapon_controller.gd` |
| `class_name`, node name | `PascalCase` | `WeaponController`, `Hitbox` |
| Method / signal / variable | `snake_case` | `apply_damage`, `health_changed` |
| Constant | `CONSTANT_CASE` | `MAX_STAMINA` |
| Private helper/field | leading `_` | `_calculate_damage()` |

- Use static typing for exported fields, function parameters, return types, and important runtime variables **where practical**.
- Prefer explicit, descriptive names over abbreviated identifiers (`attack_recovery_time`, not `art`; `current_health`, not `ch`).
- Prefer `@onready`/`@export` references to repeated deep hard-coded node paths.
- Use `@export` only for data that designers actually need to configure; don't export every private implementation detail.
- Keep calculations in small named functions when it improves clarity. Use early returns for invalid conditions.
- Prefer simple `if`/`match` over clever metaprogramming or dynamic `call()` when the possible states are small and known.
- Avoid magic numbers: move gameplay-tunable numbers into a relevant exported field, config Resource, or named constant **once**.
- Add comments for **why**, invariants, units, and unintuitive edge cases; avoid comments that merely paraphrase obvious code.
- Preserve existing comments, editor-visible property names, and serialized paths unless specifically changing those contracts.
- Use `push_warning`/`push_error` for meaningful invalid setup; do not hide failures with blanket catch-all patterns or `print()` spam.

## 6. Avoid duplication and overengineering

**Do not do any of the following without a demonstrated need:**

- Create `GameManager`, `CombatManager`, `WeaponManager`, `ComponentManager`, `EventBus`, `ServiceLocator`, or other global managers merely because the name sounds architectural.
- Add `Base*`, `Abstract*`, `I*` classes or multiple inheritance levels around a single implementation.
- Copy/paste the same damage, stamina, cooldown, status effect, inventory transfer, or saving logic across scripts.
- Create “universal” component factories, plugin registries, dependency injection containers, generic behavior trees, or custom serialization frameworks for a single use case.
- Store the same mutable fact in multiple places and synchronize it manually.
- Introduce a third-party addon/test framework unless the task genuinely needs it and existing approaches are insufficient.
- Add fallback code for hypothetical states that cannot occur by contract, or create future-proof branches without a real requirement.
- Change 3D to 2D APIs or vice versa based on engine examples without checking the actual scenes.
- Reformat hundreds of `.tscn`/`.tres` files, commit editor caches, or modify import-generated assets as a side effect of a small feature.

**Reuse guideline:** If logic is repeated and diverging, centralize it into the **existing owner** first. Extract a reusable script/component only when it clearly improves two or more real consumers or separates distinct lifecycles.

## 7. Codex execution workflow — required for every coding task

### Phase A — Discover (read-only)
1. Check `git status` and identify pre-existing user changes. **Never discard them.**
2. Read the relevant GDD/README and locate the scene tree, scripts, resources, signals, input actions, and tests for the requested feature.
3. Identify the current owners of the affected state and behavior.
4. Describe the **smallest integration point**, what files must change, and risks to existing features.
5. For routine fixes, proceed with a minimal edit. For major refactors or irreversible changes, ask before proceeding unless already explicitly authorized.

### Phase B — Implement
1. Write a short implementation plan, then implement it — **do not stop at pseudocode** when the user asked for working code.
2. Prefer editing current files over adding a parallel system.
3. Avoid introducing new dependencies outside the requested feature.
4. Keep code and scene changes consistent. Any exported node paths, signals, or Input Map names must be wired and valid.
5. Preserve user-owned changes. Review the diff while working; revert only **agent-created** accidental edits.

### Phase C — Verify
1. Check parse errors, typed GDScript warnings relevant to the changes, missing resources, signal wiring, and scene instantiation.
2. Run existing project tests, if any. For a locally available compatible Godot executable, a basic validation option is:
   ```bash
   godot --headless --editor --path . --quit
   ```
   Use the **actual installed executable** and repo-supported test commands. This import/parse check is **not a substitute for gameplay testing**.
3. Manually or programmatically exercise the feature's happy path and important edge cases where the environment permits.
4. Read `git diff --check` and inspect the final diff for unrelated changes and duplicated behavior.
5. Report what could not be verified rather than claiming success.

### Phase D — Report (short and factual)
- **Implemented:** behavior changed, and why.
- **Files changed:** actual paths.
- **SOLID / reuse decision:** what was reused; why any new abstraction was necessary.
- **Verification:** commands/tests run, with results.
- **Remaining limitations:** only genuine outstanding items.

## 8. Definition of Done (DoD)

A task is complete only when:

- [ ] It satisfies **only** the requested behavior and relevant GDD acceptance criteria.
- [ ] Existing behavior and scene references remain compatible, or intentional differences are explicitly described.
- [ ] Responsibilities are clear; no second owner of the same data/logic was introduced.
- [ ] No unused files/classes, speculative abstractions, placeholder features, or duplicate calculations were added.
- [ ] Node references, signals, Resource ownership, scene paths, and serialized configuration remain valid.
- [ ] Inputs and relevant gameplay edge cases have been checked.
- [ ] The final diff is scoped; no unrelated work was removed.
- [ ] Test results and remaining uncertainty are reported accurately.

## 9. Task-specific review checklist

Use only the applicable checks; do not invent an entire test suite for every tiny change.

**Player/physics:** 8-direction XZ movement, dash SP cost, collisions, state transitions, delta timing, animator synchronization.

**Combat:** hitbox active windows, no duplicate hit/damage application, knockback, correct CP/SP/ammo/HP costs, damage feedback, no infinite status-effect event chains.

**Weapons:** per-instance equipment and cooldowns, derived stats don't mutate base Resources, no duplicate Charm bonus, weapon skill identity preserved.

**Forge:** preserve `WeaponForge` multipliers, per-instance isolation, attack costs, damage and timing calculations.

**Inventory:** ownership and counts, no duplication or item loss.

**Save/load:** canonical data only, stable IDs, round-trip behavior, backwards compatibility if a save format already exists.

**Team collaboration:** avoid edits to other members' feature areas without necessity; mention shared contracts/signals when they change.

---

## Reminder to Codex

> **Make the smallest maintainable implementation that passes the requested behavior. SOLID is a way to clarify responsibilities and dependencies — not a reason to generate more code. Respect the existing Godot project before proposing a new architecture.**
