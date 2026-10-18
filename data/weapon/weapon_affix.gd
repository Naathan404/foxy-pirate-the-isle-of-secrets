class_name WeaponAffix
extends Resource

# thuộc tính rèn của vũ khí
@export var affix_id: StringName = &"pristine"
@export_range(0.01, 5.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0.01, 5.0, 0.01) var attack_speed_multiplier: float = 1.0
# thuộc tính rèn đặc trưng
@export_range(0.01, 5.0, 0.01) var hitbox_multiplier: float = 1.0
@export_range(0.01, 5.0, 0.01) var range_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.01) var stamina_cost_multiplier: float = 1.0
