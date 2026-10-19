class_name WeaponEffect
extends Node

# hiệu ứng vũ khí ddang trag bị
var actor: Node3D
var weapon: WeaponInstance


# gọi khi vũ khí vừa được trang bị, thêm chỉ số hặc gọi hiệu ứng
func on_equip() -> void:
	pass


# gỡ bỏ những gì đã làm trong on_equip()
func on_unequip() -> void:
	pass


# xử lý trước khi trừ máu
func modify_incoming_damage(amount_hp: int, _damage: DamageContext) -> int:
	return amount_hp


# lượng máu target thật sự mất
func on_damage_dealt(_damage: DamageContext, _target: Node, _applied_hp: int) -> void:
	pass


func on_dash_started() -> void:
	pass


func on_dash_finished(_interrupted: bool) -> void:
	pass
