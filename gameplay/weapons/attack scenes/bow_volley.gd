extends WeaponAttack
## Charge presentation and release of independently simulated, snapshotted arrows.

const ARROW: PackedScene = preload("res://gameplay/weapons/attack scenes/bow_arrow.tscn")

@export_group("Arrow Fan")
## Maximum sideways Bezier control offset at full charge. Retains existing scene overrides.
@export_range(0.0, 10.0, 0.1) var spread_factor: float = 3.0
## Maximum deviation from aim for an outer arrow, in radians.
@export_range(0.0, 0.5, 0.001) var spread_angle_radians: float = 0.08
@export_range(0.0, 1.0, 0.01) var curve_base_height: float = 0.1
@export_range(0.0, 1.0, 0.01) var curve_outer_height_bonus: float = 0.15

@export_group("Charge Presentation")
@export var charge_vfx_scene: PackedScene = preload("res://gameplay/weapons/bow_charge_vfx.tscn")
@export_range(0.0, 3.0, 0.05) var charge_vfx_height: float = 0.9

@export_group("Release Feedback")
@export_range(0.0, 20.0, 0.5) var release_shake_base_pixels: float = 2.0
@export_range(0.0, 20.0, 0.5) var release_shake_charge_bonus_pixels: float = 10.0
@export_range(0.0, 1.0, 0.01) var release_shake_seconds: float = 0.2
@export_range(0.0, 0.3, 0.005) var release_hitstop_seconds: float = 0.1

@export_group("Release Audio")
@export var release_sound: AudioStream = preload("res://assets/audio/combat/bow_release.wav")
@export_range(-80.0, 6.0, 1.0) var release_volume_db: float = -10.0
@export_range(0.1, 3.0, 0.05) var release_pitch_base: float = 0.7
@export_range(0.0, 2.0, 0.05) var release_pitch_charge_bonus: float = 0.25

var _vfx: Node3D
var _released: bool = false


func validate() -> bool:
	return charge_vfx_scene != null


func update_charge(progress: float) -> void:
	if not is_instance_valid(_vfx):
		_vfx = charge_vfx_scene.instantiate() as Node3D
		get_parent().add_child(_vfx)
	_vfx.global_position = context.actor.global_position + Vector3.UP * charge_vfx_height
	_vfx.call("set_aim", context.direction)
	_vfx.call("set_progress", progress)


func activate() -> void:
	if context == null or not is_instance_valid(context.actor):
		return
	super.activate()
	_released = true
	var strength := context.charge_progress
	var count := context.projectile_count
	for index in count:
		var arrow := ARROW.instantiate() as WeaponAttack
		var snapshot := AttackContext.new()
		snapshot.actor = context.actor
		snapshot.team = context.team
		snapshot.weapon = context.weapon
		snapshot.weapon_category = context.weapon_category
		snapshot.attack_id = context.attack_id
		snapshot.action = context.action
		snapshot.origin = context.actor.global_position
		snapshot.damage_hp = context.damage_hp
		snapshot.range_units = context.range_units
		snapshot.hitbox_multiplier = context.hitbox_multiplier
		snapshot.knockback_multiplier = context.knockback_multiplier
		# Normalized fan coordinate: left edge -1, right edge +1, single arrow at 0.
		var spread := lerpf(-1.0, 1.0, float(index) / (count - 1)) if count > 1 else 0.0
		snapshot.direction = context.direction.rotated(
			Vector3.UP, spread * strength * spread_angle_radians
		)
		snapshot.damage_prepared.connect(context.damage_prepared.emit)
		snapshot.damage_applied.connect(context.damage_applied.emit)
		arrow.context = snapshot
		arrow.set("curve_offset", spread * strength * spread_factor)
		# Keep the arc within existing enemy hurtbox height; the fan curves mostly on XZ.
		arrow.set(
			"curve_height",
			(
				(curve_base_height + absf(spread) * curve_outer_height_bonus) * strength
				if count > 1
				else 0.0
			)
		)
		arrow.set("energy_strength", strength if count > 1 else 0.0)
		get_parent().add_child(arrow)
		arrow.activate()
	if is_instance_valid(_vfx):
		if count > 1:
			_vfx.call("burst", strength)
		else:
			_vfx.queue_free()
	if count > 1:
		get_node("/root/ScreenShakeController").request(
			release_shake_base_pixels + strength * release_shake_charge_bonus_pixels,
			release_shake_seconds
		)
		get_node("/root/HitstopController").request_local(
			context.actor, null, release_hitstop_seconds * strength
		)
		get_node("/root/AudioManager").play_sfx_3d(
			release_sound,
			context.actor.global_position,
			release_volume_db,
			release_pitch_base + strength * release_pitch_charge_bonus
		)


func _exit_tree() -> void:
	if not _released and is_instance_valid(_vfx):
		_vfx.queue_free()
