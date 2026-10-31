# Weapon Forges

Shared pool: 20 Universal + 6 Wildcard; all weapon categories may roll any forge. The supplied weights sum to 102; they are preserved and normalized relatively (chance = weight / 102).

| Group | Forge | Effect | Weight |
| --- | --- | --- | --- |
| Universal | Pristine | Không thay đổi chỉ số | 3% |
| Universal | Heavy Edge | Damage +30%, Attack Speed -20%, Knockback +35% | 8% |
| Universal | Swift Flow | Attack Speed +30%, Damage -20%, Knockback -30% | 8% |
| Universal | Brittle Force | Damage +50%, Attack Speed -35%, Knockback +20% | 4% |
| Universal | Long Reach | Attack Range +25%, Damage -12% | 6% |
| Universal | Close Quarters | Damage +25%, Attack Range -25%, Knockback -40% | 6% |
| Universal | Quickdraw | Startup -30%, Recovery +20% | 5% |
| Universal | Measured Strike | Startup +20%, Recovery -30% | 5% |
| Universal | Keen Edge | Critical Rate +15 điểm %, Damage -5% | 5% |
| Universal | Blunt Impact | Damage +15%, Critical Rate -10 điểm %, Knockback +20% | 5% |
| Universal | Sharpened Soul | Flat Damage +0.5, Attack Speed -20% | 5% |
| Universal | Brutal Core | Flat Damage +1.0, Attack Speed -40%, Knockback +30% | 5% |
| Universal | Leviathan’s Fang | Flat Damage +2.0, Attack Speed -60%, Recovery +20% | 1% |
| Universal | Rusted Blade | Damage -20%, Attack Speed -15%, Knockback -15% | 4% |
| Universal | Broken Edge | Flat Damage -0.5, Attack Speed -10% | 3% |
| Universal | Crippling Weight | Damage +60%, Attack Speed -35%, Recovery +20%, Knockback +60% | 3% |
| Universal | Cursed Scrap | Damage -15%, Attack Speed -15%, Critical Rate -5 điểm % | 3% |
| Universal | Doomsday Edge | Damage +100%, Attack Speed -55%, Knockback +80% | 2% |
| Universal | Frenzied Steel | Attack Speed +70%, Damage -40%, Knockback -60% | 3% |
| Universal | Hollow Edge | Flat Damage -0.5, Attack Speed +90% | 3% |
| Wildcard | Overcharge | Damage +20%, SP Cost +40% | 3% |
| Wildcard | Titan Sweep | Melee Hitbox +30%, Attack Speed -10%, Knockback +25% | 3% |
| Wildcard | True Flight | Projectile Range +25%, Attack Speed +10%, Damage -12%, Projectile Knockback +20% | 3% |
| Wildcard | Arcane Efficiency | Damage -15%, SP Cost -30% | 2% |
| Wildcard | Sniper Sight | Projectile Range +30%, Attack Speed -15%, Critical Rate +5 điểm % | 2% |
| Wildcard | Misaligned Shot | Projectile Speed -40%, Damage -10% | 2% |

## Resolution rules

- Damage = max(0, attack damage × combo multiplier × forge damage multiplier + flat damage), followed by existing charm modifiers. Flat damage is applied once per hit, after percentage modifiers from the forge.
- Attack Speed divides startup, active, recovery and cooldown durations. Startup/Recovery modifiers multiply their own durations before the speed division.
- Overcharge now grants +20% damage to all attacks; only SP costs increase by 40%. Ammo and CP costs do not change.
- Critical Rate is configured on WeaponData (default 5%); forge bonuses add percentage points, clamped to 0–100%. Critical damage defaults to ×1.5 and is configurable per weapon.
- The controller snapshots stats when accepting an attack. Each target hit rolls once before outgoing charm modifiers; hit copies reset the roll. Bow volleys preserve these stats on every arrow. Changing forge during flight cannot change existing attacks.
- Positive critical damage received by an enemy spawns a red, outlined damage number showing actual HP removed (up to remaining HP), with two decimal places at most. It rises, falls slightly, fades and frees after 0.7 seconds. It belongs to the world so lethal hits remain visible.
- Melee Hitbox affects MELEE delivery only; Projectile Range/Knockback affect PROJECTILE delivery only. Misaligned Shot slows both outward and return flight of thrown daggers and all bow arrows; melee speed is unaffected by its projectile speed penalty.
- Knockback multiplies combo knockback and enemy resistance through the existing hit/death path. Existing impact feedback uses the same snapshot.
- Damage and HP remain fractional; display formatting does not round gameplay values.

## Integration

Assign `WeaponController.default_forge` in Inspector for a fixed initial forge. `WeaponInstance.reforge(pool, rng)` replaces the current forge using the shared weighted pool. It does not change shared weapon definitions or implement payment/NPC UI.

Run `test/weapon_forge_test.gd` and `test/critical_hit_test.gd` through Godot with `--headless --path . --script <path>`.
