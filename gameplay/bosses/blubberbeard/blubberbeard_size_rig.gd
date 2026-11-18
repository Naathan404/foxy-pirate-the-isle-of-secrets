class_name BlubberbeardSizeRig
extends RefCounted
## Đồng bộ kích thước sprite, body collision, vùng gây sát thương và HurtBox của boss.

const HURT_CLEARANCE_ABOVE_BODY_METERS := 0.55
const HURT_CLEARANCE_ABOVE_HIT_METERS := 0.75
const BASE_GRAPPLE_STOP_METERS := 1.8

var _boss: BossBase
var _visual: BlubberbeardVisual
var _body_collider: CollisionShape3D
var _body_base_dims := Vector3(1.25, 3.6, 1.8)
var _hurt_collider: CollisionShape3D
var _hurt_base_dims := Vector3(1.85, 4.4, 2.2)
var _charge_collider: CollisionShape3D
var _charge_base_dims := Vector3(1.0, 1.0, 1.15)


func setup(owner_boss: BossBase, boss_visual: BlubberbeardVisual) -> void:
	_boss = owner_boss
	_visual = boss_visual
	if not is_instance_valid(_boss):
		return
	_body_collider = _boss.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(_body_collider) and _body_collider.shape is CylinderShape3D:
		var body_cyl := _body_collider.shape.duplicate() as CylinderShape3D
		_body_collider.shape = body_cyl
		_body_base_dims = Vector3(body_cyl.radius, body_cyl.height, _body_collider.position.y)
	_hurt_collider = _boss.get_node_or_null("HurtBox/CollisionShape3D") as CollisionShape3D
	if is_instance_valid(_hurt_collider) and _hurt_collider.shape is CapsuleShape3D:
		var hurt_cap := _hurt_collider.shape.duplicate() as CapsuleShape3D
		_hurt_collider.shape = hurt_cap
		_hurt_base_dims = Vector3(hurt_cap.radius, hurt_cap.height, _hurt_collider.position.y)
	_charge_collider = _boss.get_node_or_null("ChargeHitBox/CollisionShape3D") as CollisionShape3D
	if is_instance_valid(_charge_collider) and _charge_collider.shape is SphereShape3D:
		var charge_sph := _charge_collider.shape.duplicate() as SphereShape3D
		_charge_collider.shape = charge_sph
		_charge_base_dims = Vector3(
			charge_sph.radius, charge_sph.radius, _charge_collider.position.y
		)


func apply_base_scale(boss_size_scale: float) -> void:
	if is_instance_valid(_visual):
		_visual.set_base_size_scale(boss_size_scale)
	if is_instance_valid(_boss):
		_boss.grapple_stop_distance = BASE_GRAPPLE_STOP_METERS * boss_size_scale
	sync(boss_size_scale)


func sync(boss_size_scale: float) -> void:
	var active_mult := _visual.get_active_size_multiplier() if is_instance_valid(_visual) else 1.0
	var mult := boss_size_scale * active_mult
	var body_rad := _body_base_dims.x * mult
	var charge_rad := _charge_base_dims.x * mult
	if is_instance_valid(_body_collider) and _body_collider.shape is CylinderShape3D:
		var body_cyl := _body_collider.shape as CylinderShape3D
		body_cyl.radius = body_rad
		body_cyl.height = _body_base_dims.y * mult
		_body_collider.position.y = _body_base_dims.z * mult
	if is_instance_valid(_charge_collider) and _charge_collider.shape is SphereShape3D:
		var charge_sph := _charge_collider.shape as SphereShape3D
		charge_sph.radius = charge_rad
		_charge_collider.position.y = _charge_base_dims.z * mult
	if is_instance_valid(_hurt_collider) and _hurt_collider.shape is CapsuleShape3D:
		var hurt_cap := _hurt_collider.shape as CapsuleShape3D
		# Luôn giữ HurtBox rộng hơn cả Body và ChargeHitBox để Player đánh gần an toàn.
		var min_safe := maxf(
			body_rad + HURT_CLEARANCE_ABOVE_BODY_METERS,
			charge_rad + HURT_CLEARANCE_ABOVE_HIT_METERS
		)
		hurt_cap.radius = maxf(_hurt_base_dims.x * mult, min_safe)
		hurt_cap.height = _hurt_base_dims.y * mult
		_hurt_collider.position.y = _hurt_base_dims.z * mult


func get_damage_scale(boss_size_scale: float, phase_index: int) -> float:
	var enraged_mult := (
		_visual.ENRAGED_SCALE if is_instance_valid(_visual) and phase_index > 0 else 1.0
	)
	return boss_size_scale * enraged_mult
