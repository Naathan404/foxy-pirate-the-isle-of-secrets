class_name BuckshotProjectileAttack
extends CharmActiveAttack
## Tangible pellet sprite follows the same execution that owns its hitbox.

const SHEET: Texture2D = preload("res://assets/sprites/effects/charms/buckshot_projectile.png")

var _projectile: CharmSpriteVfx


func _start_trail() -> void:
	_projectile = CharmSpriteVfx.spawn(
		self, global_position, SHEET, 0, 1.2, 0.12, context.direction, true, Vector2(0.71, 0.52)
	)
	_update_trail(context.direction)


func _update_trail(direction: Vector3) -> void:
	if not is_instance_valid(_projectile):
		return
	_projectile.global_position = (
		global_position + direction * forward_offset + Vector3.UP * trail_height
	)


func _on_charm_hit(_damage: DamageContext, target: Node, applied_hp: float) -> void:
	if applied_hp <= 0.0:
		return
	var at := global_position + Vector3.UP * trail_height
	if target is Node3D:
		at = (target as Node3D).global_position + Vector3.UP * 0.7
	CharmSpriteVfx.spawn(get_parent(), at, SHEET, 1, 1.2, 0.22)
	_apply_impact_feedback(target)
