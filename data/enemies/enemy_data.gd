class_name EnemyData
extends Resource

## Base stats shared by every enemy. Individual enemies can override these in a .tres resource.

@export_group("Health")
@export_range(1, 100000, 1) var max_hp: int = 3

@export_group("Movement")
@export_range(0.0, 100.0, 0.1) var move_speed: float = 3.0
@export_range(0.0, 100.0, 0.1) var acceleration: float = 14.0
@export_range(0.0, 100.0, 0.1) var deceleration: float = 20.0

@export_group("Combat")
@export_range(1, 100000, 1) var attack_damage: int = 1

@export_group("Hit Reaction")
@export_range(0.01, 10.0, 0.01) var hit_duration: float = 0.2
@export_range(0.0, 10.0, 0.01) var hit_recovery_duration: float = 0.3
@export_range(0.0, 100.0, 0.1) var hit_knockback_speed: float = 6.0
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0
@export_range(0.0, 100.0, 0.1) var hit_deceleration: float = 30.0

@export_group("Loot")
@export var drop_item: BaseItem
@export_range(1, 99, 1) var drop_quantity: int = 1
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0
