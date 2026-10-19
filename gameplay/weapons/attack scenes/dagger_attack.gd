class_name DaggerAttack
extends WeaponAttack

@export var hitbox: HitBox
@export var forward_offset: float = 0.8

# validate trước khi node vào scenetree
func validate() -> bool:
	return is_instance_valid(hitbox)


func activate() -> void:
	if (
		context == null
		or not is_instance_valid(hitbox)
		or not is_instance_valid(context.actor)
	):
		return
	
	super.activate()

	# forward là trục -Z
	look_at(global_position + context.direction, Vector3.UP)

	hitbox.position.z = -forward_offset
	hitbox.scale = Vector3.ONE * context.hitbox_multiplier

	hitbox.actor = context.actor
	hitbox.team = context.team
	hitbox.begin_attack(context.damage_hp, context.attack_id, context.action)


func deactivate() -> void:
	super.deactivate()
	if is_instance_valid(hitbox):
		hitbox.end_attack()
