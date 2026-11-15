extends RefCounted
## Shared popup selection for enemies and training targets.

const DEFAULT_CONFIG: Resource = preload("res://gameplay/combat/damage_popup_config.tres")


static func show_damage(
	parent: Node, position: Vector3, damage: DamageContext, amount: float, size_multiplier: float = 1.0
) -> Label3D:
	if not is_instance_valid(parent) or damage == null or not is_finite(amount) or amount <= 0.0:
		return null
	var scene: PackedScene = (
		DEFAULT_CONFIG.emphasized_scene if DEFAULT_CONFIG.is_emphasized(damage, amount)
		else DEFAULT_CONFIG.normal_scene
	)
	if scene == null:
		return null
	var instance := scene.instantiate()
	var popup := instance as Label3D
	if popup == null:
		instance.free()
		push_warning("Damage popup scene must have a Label3D root")
		return null
	parent.add_child(popup)
	if is_finite(size_multiplier) and size_multiplier > 0.0:
		popup.pixel_size *= size_multiplier
	popup.global_position = position
	popup.call("show_damage", amount)
	return popup
