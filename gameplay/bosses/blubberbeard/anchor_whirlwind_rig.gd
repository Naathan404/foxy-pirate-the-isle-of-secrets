class_name BlubberbeardWhirlwindRig
extends Node3D
## Dựng và điều khiển mỏ neo dây xích xoay 3D, vệt chém và hitbox quét vòng.

signal whirlwind_hit(target: Node)

const PROPS_SHEET := preload("res://assets/sprites/bosses/blubberbeard/anchor_whirlwind_props.png")
const PROP_BASE_PIXEL_SIZE := 0.0056
const CHAIN_LINK_COUNT := 10
const ARM_HEIGHT_METERS := 1.05
const ANCHOR_OUTWARD_ROLL_RAD := PI * 0.5
const ANCHOR_SWAY_AMPLITUDE_RAD := 0.14

var hitbox: HitBox

var _boss: BossBase
var _arm_pivot: Node3D
var _anchor_sprite: Sprite3D
var _swivel_sprite: Sprite3D
var _cleave_sprite: Sprite3D
var _chain_links: Array[Sprite3D] = []
var _warning_seal: Sprite3D
var _warning_disc: MeshInstance3D
var _warning_material: StandardMaterial3D
var _capsule_shape: CapsuleShape3D
var _hitbox_collider: CollisionShape3D

var _spinning: bool = false
var _angle_rad: float = 0.0
var _angular_speed: float = 7.2
var _traveled_rad: float = 0.0
var _target_rad: float = TAU
var _reach_radius: float = 6.0
var _damage_amount: float = 5.0
var _current_lap: int = 1


func setup(owner_boss: BossBase) -> void:
	_boss = owner_boss
	_build_warning_telegraph()
	_build_rotating_arm()
	_build_hitbox()
	hide_all()


func begin_windup(reach_radius: float, start_angle_rad: float, enraged: bool) -> void:
	_spinning = false
	_reach_radius = maxf(2.0, reach_radius)
	_angle_rad = start_angle_rad
	_layout_arm(_reach_radius)
	_arm_pivot.visible = false
	_update_warning_geometry(_reach_radius, enraged)
	_warning_seal.visible = true
	_warning_disc.visible = true


func update_windup(progress: float) -> void:
	var pulse := 0.16 + clampf(progress, 0.0, 1.0) * 0.34
	if is_instance_valid(_warning_material):
		_warning_material.albedo_color.a = pulse
	if is_instance_valid(_warning_seal):
		_warning_seal.rotate_y(0.02)
		_warning_seal.modulate.a = 0.45 + clampf(progress, 0.0, 1.0) * 0.5


func begin_spin(
	reach_radius: float,
	start_angle_rad: float,
	angular_speed_rad: float,
	rotations: int,
	damage_amount: float,
	enraged: bool
) -> void:
	_reach_radius = maxf(2.0, reach_radius)
	_angle_rad = start_angle_rad
	_angular_speed = maxf(1.0, angular_speed_rad)
	_traveled_rad = 0.0
	_target_rad = TAU * float(maxi(1, rotations))
	_damage_amount = maxf(0.1, damage_amount)
	_current_lap = 1
	_layout_arm(_reach_radius)
	_arm_pivot.visible = true
	_arm_pivot.rotation.y = _angle_rad
	if is_instance_valid(_anchor_sprite):
		_anchor_sprite.rotation.z = ANCHOR_OUTWARD_ROLL_RAD
	_cleave_sprite.frame = 5 if enraged else 4
	_cleave_sprite.modulate.a = 0.88
	_warning_seal.visible = true
	_warning_disc.visible = true
	if is_instance_valid(_warning_material):
		_warning_material.albedo_color.a = 0.14
	_begin_lap_hitbox()


func tick_spin(delta: float) -> bool:
	if not _spinning:
		return false
	var step := maxf(0.0, delta)
	var delta_angle := _angular_speed * step
	_angle_rad += delta_angle
	_traveled_rad += delta_angle
	_arm_pivot.rotation.y = _angle_rad
	if is_instance_valid(_anchor_sprite):
		_anchor_sprite.rotation.z = (
			ANCHOR_OUTWARD_ROLL_RAD + sin(_traveled_rad * 2.0) * ANCHOR_SWAY_AMPLITUDE_RAD
		)
	if is_instance_valid(_cleave_sprite):
		_cleave_sprite.modulate.a = 0.7 + sin(_traveled_rad * 4.0) * 0.22
	var lap_now := int(floor(_traveled_rad / TAU)) + 1
	if lap_now > _current_lap and _traveled_rad < _target_rad:
		_current_lap = lap_now
		_begin_lap_hitbox()
	if _traveled_rad >= _target_rad:
		_spinning = false
		if is_instance_valid(hitbox):
			hitbox.end_attack()
		return false
	return true


func hide_all() -> void:
	_spinning = false
	if is_instance_valid(_arm_pivot):
		_arm_pivot.visible = false
	if is_instance_valid(_warning_seal):
		_warning_seal.visible = false
	if is_instance_valid(_warning_disc):
		_warning_disc.visible = false
	if is_instance_valid(hitbox):
		hitbox.end_attack()


func get_current_angle() -> float:
	return _angle_rad


func _build_warning_telegraph() -> void:
	_warning_disc = MeshInstance3D.new()
	_warning_disc.name = "WhirlwindWarningDisc"
	_warning_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cyl := CylinderMesh.new()
	cyl.top_radius = _reach_radius
	cyl.bottom_radius = _reach_radius
	cyl.height = 0.02
	_warning_disc.mesh = cyl
	_warning_material = StandardMaterial3D.new()
	_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warning_material.albedo_color = Color(0.95, 0.22, 0.08, 0.22)
	_warning_disc.material_override = _warning_material
	_warning_disc.position = Vector3(0.0, 0.04, 0.0)
	add_child(_warning_disc)

	_warning_seal = Sprite3D.new()
	_warning_seal.name = "WhirlwindCompassSeal"
	_warning_seal.texture = PROPS_SHEET
	_warning_seal.hframes = 4
	_warning_seal.vframes = 2
	_warning_seal.frame = 3
	_warning_seal.pixel_size = 0.02
	_warning_seal.rotation.x = -PI * 0.5
	_warning_seal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_warning_seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warning_seal.position = Vector3(0.0, 0.06, 0.0)
	add_child(_warning_seal)


func _build_rotating_arm() -> void:
	_arm_pivot = Node3D.new()
	_arm_pivot.name = "WhirlwindArmPivot"
	_arm_pivot.position = Vector3(0.0, ARM_HEIGHT_METERS, 0.0)
	add_child(_arm_pivot)

	for idx in CHAIN_LINK_COUNT:
		var link := Sprite3D.new()
		link.name = "ChainLink_%d" % idx
		link.texture = PROPS_SHEET
		link.hframes = 4
		link.vframes = 2
		link.frame = 1
		link.pixel_size = PROP_BASE_PIXEL_SIZE * (0.64 if idx % 2 == 0 else 0.58)
		link.rotation = Vector3(-PI * 0.5, 0.0, PI * 0.5)
		link.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arm_pivot.add_child(link)
		_chain_links.append(link)

	_swivel_sprite = Sprite3D.new()
	_swivel_sprite.name = "SwivelShackle"
	_swivel_sprite.texture = PROPS_SHEET
	_swivel_sprite.hframes = 4
	_swivel_sprite.vframes = 2
	_swivel_sprite.frame = 2
	_swivel_sprite.pixel_size = PROP_BASE_PIXEL_SIZE * 0.72
	_swivel_sprite.rotation = Vector3(-PI * 0.5, 0.0, PI * 0.5)
	_swivel_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_swivel_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arm_pivot.add_child(_swivel_sprite)

	_anchor_sprite = Sprite3D.new()
	_anchor_sprite.name = "SpinningAnchorHead"
	_anchor_sprite.texture = PROPS_SHEET
	_anchor_sprite.hframes = 4
	_anchor_sprite.vframes = 2
	_anchor_sprite.frame = 0
	_anchor_sprite.pixel_size = PROP_BASE_PIXEL_SIZE * 1.45
	# Nằm ngang trên mặt phẳng xoay XZ (không billboard) với mũi neo hướng ra ngoài (+X).
	_anchor_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_anchor_sprite.rotation = Vector3(-PI * 0.5, 0.0, ANCHOR_OUTWARD_ROLL_RAD)
	_anchor_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_anchor_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_arm_pivot.add_child(_anchor_sprite)

	_cleave_sprite = Sprite3D.new()
	_cleave_sprite.name = "WhirlwindCleaveArc"
	_cleave_sprite.texture = PROPS_SHEET
	_cleave_sprite.hframes = 4
	_cleave_sprite.vframes = 2
	_cleave_sprite.frame = 4
	_cleave_sprite.pixel_size = PROP_BASE_PIXEL_SIZE * 2.1
	_cleave_sprite.rotation.x = -PI * 0.5
	_cleave_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cleave_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arm_pivot.add_child(_cleave_sprite)


func _build_hitbox() -> void:
	hitbox = HitBox.new()
	hitbox.name = "WhirlwindHitBox"
	hitbox.actor = _boss
	hitbox.team = CombatTeams.ENEMY
	hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	hitbox.damage_prepared.connect(_on_damage_prepared)
	hitbox.damage_applied.connect(_on_damage_applied)

	_hitbox_collider = CollisionShape3D.new()
	_capsule_shape = CapsuleShape3D.new()
	_capsule_shape.radius = 0.78
	_capsule_shape.height = _reach_radius
	_hitbox_collider.shape = _capsule_shape
	_hitbox_collider.rotation.z = PI * 0.5
	_arm_pivot.add_child(hitbox)
	hitbox.add_child(_hitbox_collider)


func _layout_arm(reach_radius: float) -> void:
	var inner := maxf(0.5, reach_radius * 0.11)
	var outer := maxf(inner + 1.2, reach_radius - 1.15)
	for idx in _chain_links.size():
		var t := float(idx + 1) / float(_chain_links.size() + 1)
		_chain_links[idx].position = Vector3(lerpf(inner, outer, t), 0.01 * float(idx % 2), 0.0)
	if is_instance_valid(_swivel_sprite):
		_swivel_sprite.position = Vector3(outer, 0.015, 0.0)
	if is_instance_valid(_anchor_sprite):
		_anchor_sprite.position = Vector3(reach_radius - 0.45, 0.02, 0.0)
	if is_instance_valid(_cleave_sprite):
		var arc_scale := reach_radius / 5.5
		_cleave_sprite.scale = Vector3.ONE * arc_scale
		_cleave_sprite.position = Vector3(reach_radius * 0.35, -0.35, -reach_radius * 0.35)
	if is_instance_valid(_capsule_shape) and is_instance_valid(_hitbox_collider):
		_capsule_shape.height = reach_radius
		_hitbox_collider.position = Vector3(reach_radius * 0.5, 0.0, 0.0)


func _update_warning_geometry(reach_radius: float, enraged: bool) -> void:
	if is_instance_valid(_warning_disc):
		var cyl := _warning_disc.mesh as CylinderMesh
		if cyl != null:
			cyl.top_radius = reach_radius
			cyl.bottom_radius = reach_radius
	if is_instance_valid(_warning_seal):
		_warning_seal.pixel_size = (reach_radius * 2.0) / 380.0
		_warning_seal.modulate = (
			Color(1.0, 0.72, 0.55, 0.8) if enraged else Color(1.0, 0.85, 0.75, 0.72)
		)


func _begin_lap_hitbox() -> void:
	if not is_instance_valid(hitbox) or not is_instance_valid(_boss):
		return
	var context := DamageContext.new()
	context.source = _boss
	context.source_team = CombatTeams.ENEMY
	context.base_amount_hp = _damage_amount
	context.amount_hp = _damage_amount
	context.attack_id = _current_lap
	context.tag = &"boss_whirlwind"
	context.knockback_multiplier = 1.55
	_spinning = hitbox.begin_attack_with_context(context, HitBox.RehitPolicy.ONCE_PER_ATTACK)


func _on_damage_prepared(damage: DamageContext, hit_target: Node) -> void:
	if damage == null or not is_instance_valid(_boss):
		return
	damage.origin = _boss.global_position
	var radial := Vector3.RIGHT
	if hit_target is Node3D:
		radial = (hit_target as Node3D).global_position - _boss.global_position
	elif is_instance_valid(_arm_pivot):
		radial = _arm_pivot.global_basis.x
	radial.y = 0.0
	if radial.is_zero_approx():
		radial = Vector3.RIGHT
	radial = radial.normalized()
	damage.direction = Vector3.UP.cross(radial).normalized()
	damage.tag = &"boss_whirlwind"
	damage.knockback_multiplier = 1.55


func _on_damage_applied(_damage: DamageContext, hit_target: Node, _applied: float) -> void:
	whirlwind_hit.emit(hit_target)
