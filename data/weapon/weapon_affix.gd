class_name WeaponForge
extends Resource

enum ForgeGroup { UNIVERSAL, WILDCARD }

# thuộc tính rèn của vũ khí
@export var forge_id: StringName = &"pristine"
@export var display_name: String = "Pristine"
@export_multiline var description: String = "Không thay đổi chỉ số"
@export var forge_group: ForgeGroup = ForgeGroup.UNIVERSAL
@export var acquisition_source: StringName = &""
## Relative chance in the shared pool; zero excludes this forge from random rolls.
@export_range(0.0, 1000.0, 0.01) var drop_weight: float = 1.0
@export_range(0.01, 5.0, 0.01) var damage_multiplier: float = 1.0
## Additional damage multiplier only when the attack pays a positive SP cost.
@export_range(0.01, 5.0, 0.01) var stamina_damage_multiplier: float = 1.0
@export_range(0.01, 5.0, 0.01) var attack_speed_multiplier: float = 1.0
@export_range(0.01, 5.0, 0.01) var windup_multiplier: float = 1.0
@export_range(0.01, 5.0, 0.01) var recovery_multiplier: float = 1.0
# thuộc tính rèn đặc trưng
@export_range(0.01, 5.0, 0.01) var hitbox_multiplier: float = 1.0
@export_range(0.01, 5.0, 0.01) var range_multiplier: float = 1.0
@export_range(0.01, 5.0, 0.01) var melee_hitbox_multiplier: float = 1.0
@export_range(0.01, 5.0, 0.01) var projectile_range_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.01) var stamina_cost_multiplier: float = 1.0


func is_valid() -> bool:
	if forge_id.is_empty() or display_name.is_empty():
		return false
	if not is_finite(drop_weight) or drop_weight < 0.0:
		return false
	if not is_finite(stamina_cost_multiplier) or stamina_cost_multiplier < 0.0:
		return false
	for multiplier: float in [
		damage_multiplier,
		stamina_damage_multiplier,
		attack_speed_multiplier,
		windup_multiplier,
		recovery_multiplier,
		hitbox_multiplier,
		range_multiplier,
		melee_hitbox_multiplier,
		projectile_range_multiplier
	]:
		if not is_finite(multiplier) or multiplier <= 0.0:
			return false
	return true
