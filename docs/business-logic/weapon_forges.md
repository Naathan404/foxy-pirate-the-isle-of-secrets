# Weapon Forges

Shared pool: 19 Universal + 6 Wildcard. All weapon categories can roll any entry. The supplied weights sum to 111; chance = weight / 111.

| Group | Forge | Effect | Weight |
| --- | --- | --- | --- |
| Universal | Pristine | Damage +8%, Attack Speed +8%, Knockback +8% | 4.0 |
| Universal | Heavy Edge | Damage +25%, Attack Speed -18%, Knockback +20%, Stagger +15% | 8.0 |
| Universal | Swift Flow | Attack Speed +30%, Damage -20%, Knockback -20% | 8.0 |
| Universal | Brittle Force | Damage +45%, Attack Speed -30%, Startup +10% | 4.0 |
| Universal | Long Reach | Attack Range +25%, Damage -10% | 7.0 |
| Universal | Close Quarters | Damage +20%, Attack Range -20%, Stagger +15% | 6.0 |
| Universal | Quickdraw | Startup -25%, Recovery +15% | 6.0 |
| Universal | Measured Strike | Startup +15%, Recovery -25% | 6.0 |
| Universal | Keen Edge | Critical Rate +10 pp, Damage -5% | 6.0 |
| Universal | Precision Edge | Critical Rate +12 pp, Critical Damage -20 pp | 5.0 |
| Universal | Executioner | Critical Rate +5 pp, Critical Damage +40%, Attack Speed -5% | 5.0 |
| Universal | Blunt Impact | Damage +15%, Critical Rate -5 pp, Knockback +20%, Stagger +20% | 6.0 |
| Universal | Concussive Edge | Stagger +45%, Damage -10% | 5.0 |
| Universal | Anchor Breaker | Knockback +45%, Stagger +20%, Attack Speed -15% | 4.0 |
| Universal | Shattering Blow | Critical Damage +35%, Stagger +25%, Damage -5% | 4.0 |
| Universal | Relentless | Recovery -25%, Damage -10% | 5.0 |
| Universal | Crippling Weight | Damage +45%, Attack Speed -30%, Recovery +15%, Stagger +40% | 3.0 |
| Universal | Frenzied Steel | Attack Speed +50%, Damage -30%, Stagger -40% | 3.0 |
| Universal | Doomsday Edge | Damage +75%, Attack Speed -40%, Startup +20%, Knockback +40%, Stagger +40% | 1.0 |
| Wildcard | Titan Sweep | Melee Hitbox +25%, Attack Speed -10% | 3.0 |
| Wildcard | Crusher Arc | Melee Hitbox +15%, Stagger +30%, Damage -12% | 3.0 |
| Wildcard | True Flight | Projectile Range +25%, Projectile Speed +15%, Damage -10% | 3.0 |
| Wildcard | Sniper Sight | Projectile Range +25%, Critical Rate +7 pp, Attack Speed -15% | 2.0 |
| Wildcard | Overcharge | Skill Damage +25%, SP Cost +30% | 2.0 |
| Wildcard | Arcane Efficiency | SP Cost -25%, Skill Damage -10% | 2.0 |

## Resolution rules

- HP damage = max(0, attack damage * combo damage * forge damage multiplier + flat damage). Secondary weapon skills additionally multiply by `skill_damage_multiplier`, regardless of SP, CP or ammo cost. Existing charm modifiers apply afterward.
- Overcharge grants +25% skill damage and +30% SP cost. Arcane Efficiency grants -25% SP cost and -10% skill damage. Neither skill modifier affects normal attacks; CP and ammo costs stay unchanged.
- Critical rate bonuses add percentage points, clamped to 0-100%. Critical damage = max(1, weapon critical multiplier * forge critical multiplier + forge critical bonus). At base x1.5: Precision Edge gives x1.3, Executioner x2.1, Shattering Blow x2.025. Critical hits do not increase stagger.
- Stagger per hit = WeaponData.stagger_damage * AttackData.stagger_multiplier * combo stagger multiplier * forge stagger multiplier. The combo factor applies only to normal combo attacks. HP damage, knockback, critical damage and stagger are independent.
- Attack Speed divides startup, active, recovery and cooldown durations. Startup and Recovery modifiers affect their own durations before speed division.
- For held projectiles, holding pays down the forged startup. Releasing early completes only
  the remaining startup; releasing after preparation launches immediately. Holding never
  zeroes the authored startup. Ranged animation follows the controller's aim/windup,
  active and recovery clocks, so separate phase modifiers remain visible.
- `charge_seconds` is the separate power-charge duration and is not divided by Attack Speed.
  Charge strength and CP expenditure keep their authored progression. The old `tap_seconds`
  field remains loadable for compatibility but is hidden from the Inspector; startup is
  controlled by `windup_seconds`, `windup_multiplier` and `attack_speed_multiplier`.
- Melee Hitbox affects MELEE delivery only; Projectile Range affects PROJECTILE delivery only. Projectile Speed affects arrows and both outward/return travel of thrown daggers.
- The controller snapshots damage, critical and stagger stats when an attack starts. Target copies and every volley arrow retain that snapshot; later forge changes cannot alter an attack in flight.
- Enemy HP loss gives visual feedback and damage numbers. Only reaching the stagger threshold enters Hit; full knockback applies on stagger or death. Boss knockback immunity remains unchanged.
- Retired forge resources stay loadable for existing references, with weight zero and no entry in the shared pool. They cannot appear in new shared-pool rolls.
- Fractional HP and damage are preserved; display formatting never rounds combat calculations.

## Inspector tuning

- WeaponData: `stagger_damage` (Dagger 20, Bow 35).
- AttackData and MeleeComboStep: `stagger_multiplier`. Dagger finisher is x1.75, returning dagger x1.25, volley arrows x0.5 each.
- EnemyData: `stagger_threshold` (normal 60, elite 120, War Lord Turtle 240), `stagger_decay_delay` (1.25s), `stagger_decay_per_second` (30), `stagger_immunity_duration` (1s after recovery).
- WeaponForge: `stagger_multiplier`, `critical_damage_multiplier`, `critical_damage_bonus`, `skill_damage_multiplier`, plus the existing rate, timing, range and knockback fields.

## Integration

Assign `WeaponController.default_forge` for a fixed initial forge. `WeaponInstance.reforge(pool, rng)` replaces its forge using the weighted shared pool; it never mutates shared WeaponData. Equipment displays the forged base stagger and critical multiplier.

CI membership stays fixed in `.github/godot-tests.txt`; existing forge, enemy, combo and equipment tests were updated for these rules.
