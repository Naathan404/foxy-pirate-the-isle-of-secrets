class_name BuckshotProjectileAttack
extends CharmActiveAttack
## One Buckshot Salvo pellet: a large blazing shot with a fire trail, following the execution
## that owns its hitbox.

signal pellet_hit(at: Vector3)

const SHEET: Texture2D = preload("res://assets/sprites/effects/charms/buckshot_projectile.png")
const FIRE_TRAIL: PackedScene = preload("res://assets/vfx/fire_trails/Fire_Trail.tscn")
const PELLET_WIDTH_METERS := 2.0
const IMPACT_WIDTH_METERS := 1.9
## Shrinks the authored fire trail to pellet size.
const TRAIL_WIDTH_SCALE := 0.42
const TRAIL_TIME_SCALE := 0.16
## The flame leaves from just behind the pellet's head.
const TRAIL_BACK_METERS := 0.35

var _projectile: CharmSpriteVfx
var _fire_trail: ProjectileFireTrail


func _start_trail() -> void:
	_projectile = CharmSpriteVfx.spawn(
		self,
		global_position,
		SHEET,
		0,
		PELLET_WIDTH_METERS,
		0.12,
		context.direction,
		true,
		Vector2(0.71, 0.52)
	)
	_fire_trail = ProjectileFireTrail.new(
		FIRE_TRAIL, get_parent(), _trail_anchor(context.direction), TRAIL_WIDTH_SCALE,
		TRAIL_TIME_SCALE
	)
	_update_trail(context.direction)


func _update_trail(direction: Vector3) -> void:
	if is_instance_valid(_projectile):
		_projectile.global_position = (
			global_position + direction * forward_offset + Vector3.UP * trail_height
		)
	if _fire_trail != null:
		_fire_trail.follow(_trail_anchor(direction))


func _trail_anchor(direction: Vector3) -> Vector3:
	return (
		global_position
		+ direction * (forward_offset - TRAIL_BACK_METERS)
		+ Vector3.UP * trail_height
	)


func _exit_tree() -> void:
	super._exit_tree()
	if _fire_trail != null and context != null:
		_fire_trail.release(_trail_anchor(context.direction))
	_fire_trail = null


func _on_charm_hit(_damage: DamageContext, target: Node, applied_hp: float) -> void:
	if applied_hp <= 0.0:
		return
	var at := global_position + Vector3.UP * trail_height
	if target is Node3D:
		at = (target as Node3D).global_position + Vector3.UP * 0.7
	CharmSpriteVfx.spawn(get_parent(), at, SHEET, 1, IMPACT_WIDTH_METERS, 0.22)
	CharmVfx.spawn(get_parent(), at, CharmVfx.GOLD, 0.7)
	CharmFeel.local_hitstop(self, null, target as Node3D, hitstop_seconds)
	pellet_hit.emit(at)
