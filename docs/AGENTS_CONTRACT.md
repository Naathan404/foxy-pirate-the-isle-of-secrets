# AGENTS.md — Godot Engineering Contract

> **Applies to:** all AI coding agents working in this Godot repository.
> **Goal:** deliver correct, maintainable, testable gameplay code with pragmatic SOLID, Clean Code, and appropriate design patterns — without over-engineering.
> **Language:** GDScript for gameplay unless the repository or task explicitly requires otherwise.

## 1. Operating rules

1. **MUST inspect before editing.** Read `project.godot`, the relevant scenes/scripts/resources, existing conventions, and nearby tests. Check the actual Godot version and installed add-ons; never assume an API exists.
2. **MUST preserve existing behavior** outside the requested change. Prefer the smallest coherent solution and a focused diff.
3. **MUST fit the current architecture.** Reuse existing components, contracts, signals, folders, and patterns instead of creating parallel systems.
4. **MUST distinguish facts from assumptions.** Never claim that a scene, feature, import, or test works without checking it.
5. **MUST NOT silently introduce** dependencies, plugins, autoloads, project-wide refactors, new global state, or breaking public APIs.
6. **SHOULD choose simple code over speculative abstraction.** SOLID is guidance for maintainability, not a requirement to create extra classes or patterns for every feature.

### Source-of-truth precedence

For implementation details: (1) explicit task requirements, (2) the actual repository and its documented interfaces, (3) this contract, (4) official Godot documentation for the project's engine version. If sources conflict or a breaking change is required, explain the conflict and seek approval before making broad changes.

## 2. Architecture: Godot-native, scene-first

- A **scene** owns a cohesive game object or feature; a **node** has a clear responsibility; a **Resource** holds reusable configuration/data; a **RefCounted** object can hold non-Node domain logic.
- Prefer **composition over deep inheritance**. Build a character from focused pieces (for example `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `StateMachine`, `AnimationController`) only when each piece provides real reuse or separation.
- A scene root coordinates its own children. **Siblings communicate through their owner/parent or an explicit API**, not by reaching into one another's implementation details.
- Scenes should be runnable or testable in isolation where practical. Do not hardcode paths to unrelated scenes, global level nodes, or `/root/...` unless the dependency is explicitly global.
- Use `@onready` references to stable owned child nodes, `@export` for editor-configurable values/references, and explicit `setup(...)` / `initialize(...)` methods for runtime dependencies. Validate required references.
- **Signals represent events** (`health_changed`, `died`, `interacted`); **methods represent commands/queries** (`take_damage`, `interact`, `can_attack`). Avoid turning every direct method call into an event.
- Autoloads are only for truly cross-scene responsibilities such as save data, game flow, or shared audio. Do not use an autoload as a universal registry or a dumping ground for player/enemy logic.
- Prefer `class_name` only for useful, reusable types with unambiguous names. Avoid polluting the global class namespace for every small script.
- Keep editor-owned structure in `.tscn`/`.tres` when appropriate. Do not recreate large scene hierarchies in code without a concrete reason.
- Do not mutate a shared `.tres` Resource as if it were per-instance state. Store runtime state on instances, or intentionally duplicate/use per-scene resources where required.

## 3. SOLID acceptance rules

| Principle | What the agent MUST do in Godot |
| --- | --- |
| **S — Single Responsibility** | Each script/component has one coherent reason to change. Split large scripts when independent responsibilities actually emerge; do not split trivial logic just to add files. |
| **O — Open/Closed** | Prefer extending behavior via components, configuration Resources, or small polymorphic implementations instead of repeatedly editing giant type-specific conditionals. |
| **L — Liskov Substitution** | Subclasses must honor the base type's documented inputs, outputs, signals, lifecycle, and invariants. Do not create subclass behavior that breaks existing callers. |
| **I — Interface Segregation** | Consumers depend on the smallest needed behavior (for example `take_damage`) rather than a large all-purpose manager. In GDScript, use focused base classes, typed references, signals, or carefully checked duck typing; do not invent a C#-style interface framework. |
| **D — Dependency Inversion** | High-level gameplay orchestration should not know low-level node internals. Pass references/configuration through scenes, exports, or setup methods; favor stable component APIs and events. |

**SOLID review question:** Does this change make future feature additions safer and easier without adding unjustified complexity? If not, simplify.

## 4. Design-pattern decision rules

| Pattern | Use when | Avoid when |
| --- | --- | --- |
| **Composition / Component** | Multiple actors need a self-contained capability (health, interaction, hit detection). | The capability is a one-line, single-use detail. |
| **State** | An actor has multiple exclusive states, distinct transitions, or state-specific behavior. | One or two conditions are clearer as simple branching. |
| **Observer (Godot signals)** | One object announces something that happened; listeners may vary. | A known caller simply needs to invoke a known dependency. |
| **Strategy** | An algorithm/behavior must be swappable independently (attack policy, targeting, movement behavior). | Only parameters differ; use a configuration Resource instead. |
| **Factory** | Creation involves selection, configuration, or repeated complex setup. | A direct `PackedScene.instantiate()` is enough. |
| **Object Pool** | Profiling shows costly repeated allocation of short-lived instances (projectiles/VFX). | There is no measured need, or reset/lifetime semantics are unclear. |
| **Dependency Injection** | A component requires an external collaborator to function/test. | It adds a container/framework to wire two simple nodes. |

**MUST NOT force a pattern.** Each new nontrivial abstraction needs a one-sentence justification. Follow existing patterns where they already solve the problem.

## 5. GDScript clean-code standard

- Follow the official style guide for the project's Godot version. Use **tabs** for indentation.
- Naming: files/functions/variables/signals `snake_case`; classes and node names `PascalCase`; constants `CONSTANT_CASE`; private helpers/state begin with `_`.
- Use **typed GDScript** for parameters, returns, member variables, and node references where practical. Limit `Variant` and untyped `Dictionary` to genuinely dynamic boundaries, with validation.
- Functions should have one purpose and descriptive, action-oriented names. Use guard clauses to avoid unnecessary nesting.
- Keep an authoritative source of truth for each runtime property. Do not duplicate health, position, currency, cooldown, or state across managers/components without an explicit synchronization contract.
- Use `@export` for game-design tuning, constants for actual invariants, and configuration Resources for reusable sets of data. Avoid magic numbers and magic strings.
- Comment **why**, assumptions, invariants, and non-obvious engine behavior; do not narrate self-explanatory code. Document public component APIs and signal payloads.
- Never leave dead code, placeholder pass-through implementations, unexplained TODOs, broad catch-all workarounds, or debug prints in completed features.
- Do not hide invalid state with silent fallbacks. Validate expected input, report errors clearly, and fail gracefully for player-driven invalid states. Do not rely on `assert()` as the only runtime validation.
- Prefer simple explicit control flow; minimize unnecessary utility wrappers and clever one-liners.
- Avoid broad use of `get_node_or_null`, `find_child`, or `get_nodes_in_group` to conceal missing structural contracts. Use them only when dynamic discovery is intended.

## 6. Godot lifecycle, physics, and performance

- Use `_physics_process(delta)` for physics-based movement/collision logic and `_process(delta)` for frame-based presentation where appropriate; do not tie movement speed to FPS.
- Use Godot's intended APIs for the actual body type (`CharacterBody2D/3D`, `Area2D/3D`, etc.). Never mix 2D and 3D coordinate assumptions. For a 2.5D/isometric project, confirm which axes represent ground movement and height before implementing movement or aiming.
- Connect signals once; avoid duplicate listeners. Handle the lifecycle of spawned/freed nodes and use `is_instance_valid()` when references may have been freed.
- Keep per-frame logic lean: avoid repeated scene-tree searches, repeated resource loads, expensive allocations, and unnecessary polling. Cache only when the cached reference cannot silently become stale.
- Prefer event-driven updates when there is no need to process every frame. Disable processing on inactive components when appropriate.
- Respect Godot scene-tree mutation rules; defer operations when necessary during physics or signal callbacks.
- Preserve scene serialization, UID references, import metadata, resource ownership, and currently installed add-ons (including animation/Spine integrations when present).

## 7. Cross-system integration contract

Before changing an interface shared by systems (Player, Enemy, Combat, NPC, Dialogue, UI, Save, Map, Animation), identify its existing contract:

- Input/action names and ownership.
- Node types, expected scene tree paths, exported dependencies, and collision layers/masks.
- Public functions, signal names, argument types, and lifecycle expectations.
- Data Resources, save schemas, and backward-compatibility requirements.
- Asset/animation names, transitions, and ownership of animation decisions.

**MUST NOT rename, delete, or change these silently.** Prefer a compatible adapter or a staged migration. If a public contract must change, list all affected consumers and update them consistently in the same approved task.

For graphics/animation, gameplay state should request meaningful actions (`play_attack`, `set_facing`, `play_hit`) through a narrow controller API. Gameplay logic should not depend on low-level Spine/Sprite3D skeleton or track details unless that is the controller's responsibility.

## 8. Files, ownership, and Git hygiene

- Follow the repository's actual folder structure; add a folder only if it clarifies ownership. Keep reusable core components separate from character/level-specific scenes where the project already does so.
- Edit only files relevant to the task. Do not reformat unrelated code or rewrite entire scenes to implement a small change.
- Never edit the `.godot/` cache or generated imported files by hand. Do not overwrite binary assets, Spine exports, original art, or third-party add-on code without an explicit task.
- Never change `project.godot`, Input Map, autoload configuration, physics layers/masks, rendering settings, or shared base scenes as a side effect. Such changes require an explicit reason and must be reported.
- Do not discard human edits, force-push, reset branches, or revert unrelated changes. Preserve `.uid` files and resource references as required by the project's engine version.
- When several people work in parallel, agree on public APIs before changing shared interfaces. Prefer separate scenes/scripts/resources and small PRs to reduce merge conflicts.

## 9. Task execution protocol

**Before coding**
1. Summarize the requested behavior and acceptance criteria.
2. Inspect related code, scenes, assets, version, and project configuration.
3. Identify affected modules/contracts and whether an existing component/pattern can be reused.
4. For cross-system or multi-file tasks, state a short plan and risks. Avoid broad speculative redesign.

**While coding**
5. Implement the smallest coherent change, with typed GDScript and explicit ownership.
6. Ensure signals, node paths, Resources, exports, and initializations are wired correctly.
7. Use existing tests or a reproducible manual verification scenario for nontrivial behavior. Per user instruction, do not create additional tests or CI checks unless explicitly requested. CI runs lint and the fixed suite in `.github/godot-tests.txt`; do not expand that list or restore automatic test discovery without an explicit user request. Project import remains a prerequisite for running the fixed Godot tests.
8. Keep changes limited to the task. If a blocker requires a breaking change or unapproved architecture shift, explain it instead of silently proceeding.

**After coding**
9. Review syntax, unused references, lifecycle behavior, changed scene links, and affected callers.
10. If available, run a project import/parse check and a smoke test using the project's Godot executable, such as:

    ```bash
    godot --headless --path . --editor --quit
    godot --headless --path . --quit-after 5
    ```

    Adapt these commands to the installed Godot binary and project setup. An import/parse check and a short headless run do **not** replace gameplay tests.
11. Report what actually ran, what passed/failed, and what was not tested. **Never fabricate validation results.**

## 10. Definition of Done (mandatory checklist)

- [ ] Implements the requested behavior and stated edge cases.
- [ ] Consistent with existing scene architecture, SOLID, and the minimum useful patterns.
- [ ] No needless extra managers, autoloads, inheritance layers, or global state.
- [ ] Typed, readable GDScript; no magic values, dead code, or accidental duplicated state.
- [ ] Signals, references, exports, layers, and resources are connected correctly.
- [ ] No unintended breaking changes to other modules, scene contracts, or save data.
- [ ] Relevant checks/tests were actually performed, or blockers are clearly disclosed.
- [ ] Changed files, design choices, and integration instructions are reported.

## 11. Required final response from the agent

Always provide:

1. **Summary:** what behavior changed.
2. **Files:** exact files created/modified and why.
3. **Architecture:** SOLID/pattern decisions **only where relevant**, including why extra abstractions were not needed.
4. **Verification:** commands/tests/manual steps actually completed and their results.
5. **Risks / integration notes:** editor wiring, missing assets, scene setup, compatibility changes, and unverified behavior.

**Do not claim "SOLID-compliant" or "tested" without evidence. Readability, correct gameplay, and maintainability take priority over pattern count.**

## 12. Example of the desired boundaries

```gdscript
# health_component.gd
class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal died

@export_range(1, 10000, 1) var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	if amount <= 0 or current_health == 0:
		return

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		died.emit()
```

```gdscript
# enemy.gd — example consumer, not a universal enemy architecture
extends CharacterBody3D

@onready var _health: HealthComponent = $HealthComponent

func _ready() -> void:
	_health.died.connect(_on_died)

func _on_died() -> void:
	queue_free()
```

The `HealthComponent` owns health and emits events; the enemy owns its response to death. Do not put animation, loot, UI, save logic, and scene changes inside the health component.

---

**Reference:** Godot documentation for [GDScript style](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), [scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html), [scenes vs. scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html), and [autoloads vs. regular nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html). Always consult the documentation corresponding to the project's installed Godot version.
