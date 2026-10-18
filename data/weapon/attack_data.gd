class_name AttackData
extends Resource

enum AimMode { FACING, CURSOR_DIRECTION, CURSON_POSITION }

# Phần prefix của tên animation
@export var animation_prefix: String = "attack_dagger"
# scene thực hiện đòn đnahs
@export var attack_scene: PackedScene
@export var aim_mode: AimMode = AimMode.FACING
@export_range(1, 1000, 1) var damage_hp: int = 1
### Cấu hình mốc thời gain của đòn đánh
# Chuẩn bị ra đòn -> không dmg
@export_range(0.0, 10.0, 0.001) var windup_seconds: float = 0.125
# Ra đòn -> gây dmg
@export_range(0.001, 10.0, 0.001) var active_seconds: float = 0.125
# Hồi phục sau khi ra đòn
@export_range(0.0, 10.0, 0.001) var recovery_seconds: float = 0.125
#
@export_range(0.0, 60.0, 0.01) var cooldown_seconds: float = 0.0
#### Config tầm nhấm và thầm bay. Cận chieenns chỉnh trực tiếp oewr hitbox
@export_range(0.01, 100.0, 0.01) var range_units: float = 1.5
@export_range(0.0, 10000.0, 1.0) var stamina_cost: float = 0.0
@export var ammo_id: StringName = &""
@export_range(0, 100, 1) var ammo_cost: int = 0


func is_valid() -> bool:
	return (
		attack_scene != null
		and not animation_prefix.is_empty()
		and damage_hp > 0
		and windup_seconds >= 0.0
		and active_seconds > 0.0
		and recovery_seconds >= 0.0
		and cooldown_seconds >= 0.0
		and range_units > 0.0
		and stamina_cost >= 0.0
		and ammo_cost >= 0
		and (ammo_cost == 0 or not ammo_id.is_empty())
		and not (stamina_cost > 0.0 and ammo_cost > 0)
	)
