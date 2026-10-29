class_name DaggerAttack
extends WeaponAttack

@export var hitbox: HitBox
@export var forward_offset: float = 0.8


# validate trước khi node vào scenetree
func validate() -> bool:
	return is_instance_valid(hitbox)


func _ready() -> void:
	if not hitbox.damage_prepared.is_connected(_on_damage_prepared):
		hitbox.damage_prepared.connect(_on_damage_prepared)
	if not hitbox.damage_applied.is_connected(_on_damage_applied):
		hitbox.damage_applied.connect(_on_damage_applied)


func activate() -> void:
	if context == null or not is_instance_valid(hitbox) or not is_instance_valid(context.actor):
		return

	super.activate()
	global_position = context.actor.global_position

	# forward là trục -Z
	look_at(global_position + context.direction, Vector3.UP)

	hitbox.position.z = -forward_offset
	hitbox.scale = Vector3.ONE * context.hitbox_multiplier

	hitbox.begin_attack_with_context(context.create_damage_context())


func tick_active(_delta: float) -> void:
	if context != null and is_instance_valid(context.actor):
		global_position = context.actor.global_position


func deactivate() -> void:
	super.deactivate()
	if is_instance_valid(hitbox):
		hitbox.end_attack()


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	if context != null:
		context.damage_prepared.emit(damage, target)


func _on_damage_applied(damage: DamageContext, target: Node, applied_hp: int) -> void:
	if context != null:
		context.damage_applied.emit(damage, target, applied_hp)
