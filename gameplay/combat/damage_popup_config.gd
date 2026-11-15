class_name DamagePopupConfig
extends Resource
## A hit is emphasized if critical, explicitly marked, or at/above this damage.

@export var normal_scene: PackedScene
@export var emphasized_scene: PackedScene
## Set to 0 to disable automatic emphasis by damage amount.
@export_range(0.0, 100000.0, 0.25) var high_damage_threshold: float = 0.0


func is_emphasized(damage: DamageContext, applied_hp: float) -> bool:
	return (
		damage != null
		and (damage.is_critical or damage.emphasize_popup
			or (high_damage_threshold > 0.0 and applied_hp >= high_damage_threshold))
	)
