# Boss framework

Boss-specific scenes and behavior belong in `gameplay/bosses/<boss_name>/`, tuning
resources in `data/bosses/`, and sprites in `assets/sprites/bosses/<boss_name>/`.
Ordinary enemies have corresponding directories under `enemies/`.

`BossBase` joins both the `boss` and `enemy` groups: `boss` identifies the encounter
type, while `enemy` lets shared hostile-target effects such as Dead Man's Salute find it.
Effects that apply only to ordinary enemies must explicitly exclude the `boss` group,
as Abyssal Whirlpool does. Bosses also use the enemy combat team and collision layers.

`BossBase` owns the shared health, team/hurtbox, activation, phase transitions,
fight signals and optional reward scene. Set `boss_data` to a `BossData` resource with
phases ordered from highest to lowest HP threshold. HP is shared between phases. A lethal
hit ends the fight directly instead of entering any skipped phases.

`BossEncounter` can be added to a room to keep the defeat, chest and outstanding item
pickups in `GameManager` while changing scenes during a session. Set a unique encounter ID
and assign its boss. It does not yet provide disk persistence. Bosses respect the room's
ground boundaries by default, and `grapple_stop_distance` keeps a player pulled by Tide
Grapple outside a large boss's body.

Add a child extending `BossBehavior` and assign it to the boss's `behavior` property.
Implement whichever callbacks the encounter needs:

- `setup(owner_boss)`: cache scene nodes, initialize the behavior and connect feedback.
- `fight_started()`: initialize encounter-specific state.
- `fight_tick(delta)`: choose skills, move the body and advance the encounter. This is
  called in the physics loop while a target exists and pauses during boss hitstop. The
  behavior owns gravity, movement and its own state machine or other decision system.
- `phase_entered(index)`: react to the new phase; it runs before `phase_changed` emits.
- `fight_ended()`: cancel attacks, stop emitters, clean up hazards and play the death
  sequence. It runs once after the boss is marked dead and before `fight_finished`.

`BossSkillData` contains common optional tuning; extend it with fields specific to a new
boss. `BossPhaseData.skills` accepts these derived resources and does not assume a fixed
skill enum. A behavior may use that list in any order, or implement different selection
and attack patterns entirely. Projectiles and telegraphs should be owned or tracked so
that they cannot keep dealing damage after `fight_ended`.

The Blubberbeard behavior is one example, not a required state machine for other bosses.
Run `res://test/boss_behavior_test.gd` to check that another behavior receives the shared
lifecycle independently; `res://test/blubberbeard_boss_test.gd` covers its encounter.
