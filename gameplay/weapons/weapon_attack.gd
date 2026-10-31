class_name WeaponAttack
extends Node3D

# interface chung cho các scene đòn đánh
@export var persist_after_release: bool = false
var context: AttackContext

var active: bool = false
var launched: bool = false


# Validate trước khi attack controller lưu
func validate() -> bool:
	return true


# hàm được gọi khi vừa bắt đầu tấn công
func activate() -> void:
	active = true
	launched = true


# xử lí liên tục trong lúc ra đòn đánh, cận chiến thì chắc hông cần
func tick_active(_delta: float) -> void:
	pass


## Optional presentation hook for an attack held before its windup/release.
func update_charge(_progress: float) -> void:
	pass


# hàm được gọi khi đòn tấn công vừa kết thúc
func deactivate() -> void:
	active = false


# hủy đòn đánh
func cancel() -> void:
	if persist_after_release and launched:
		return
	deactivate()
	queue_free()


# Đòn đánh đã được triển khai xong
func release() -> void:
	if not persist_after_release:
		queue_free()
