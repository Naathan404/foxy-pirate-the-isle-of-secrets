class_name WeaponData
extends Resource

enum WeaponCategory { MELEE, RANGED, STAFF }

@export var weapon_id: StringName = &"dagger"
@export var display_name: String = "Dagger"
@export var category: WeaponCategory = WeaponCategory.MELEE
# Đòn chính
@export var normal_attack: AttackData
# Đòn phụ, trống nếu vũ khí không có
@export var secondary_attack: AttackData

# Hiệu ứng vũ khí khi người hcoiw đang trang bị vũ khi
@export var equipped_effect_scene: PackedScene
