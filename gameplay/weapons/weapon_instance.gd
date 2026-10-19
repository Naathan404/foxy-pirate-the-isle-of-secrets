class_name WeaponInstance
extends Resource

### Instance của vũ khí chứa data, khả năng sử dụng, forge rèn

# data vũ khí cụ thể người chơi sở hữu, chứa chỉ số gốc
@export var definition: WeaponData
# thuộc tính rèn của vũ khí
@export var forge: WeaponForge
# khóa toàn bô vũ khí
# lúc dagger ném đi và chưa nhạt lại
var unavailable_seconds: float = 0.0
# thời gian cooldown cho đòn đánh thường và đòn phụ
var cooldowns: Dictionary[StringName, float] = {}


# Gọi advance cho tất cả vũ khí, vũ khí không được trang bị thời gian vẫn được giảm
func advance(delta: float) -> void:
	unavailable_seconds = maxf(0.0, unavailable_seconds - delta)
	for action: StringName in cooldowns:
		cooldowns[action] = maxf(0.0, cooldowns[action] - delta)


# Lấy cấu hinh đòn đánh được request
# null nếu vũ khí không có đòn đánh
func get_attack(action: StringName) -> AttackData:
	if definition == null:
		return null
	if action == &"normal":
		return definition.normal_attack
	if action == &"secondary":
		return definition.secondary_attack
	return null
