class_name BarrelBullet
extends RigidBody3D

@export_range(0.1, 30.0, 0.1, "suffix:s") var lifetime: float = 4.0
@export_group("Movement")
@export_range(0.0, 1.0, 0.01) var bounce_strength: float = 0.8

var _source: Node
var _source_team: int = 0
var _direction: Vector3 = Vector3.FORWARD
var _speed: float = 0.0
var _damage: int = 0
var _remaining_lifetime: float = 0.0

@onready var hitbox: HitBox = $HitBox


func launch(source: Node, source_team: int, direction: Vector3, speed: float, damage: int) -> void:
	_source = source
	_source_team = source_team
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_speed = maxf(0.0, speed)
	_damage = max(0, damage)


func _ready() -> void:
	_remaining_lifetime = lifetime
	collision_layer = 0
	collision_mask = CombatLayers.WORLD
	if physics_material_override != null:
		physics_material_override.bounce = bounce_strength
	linear_velocity = _direction * _speed
	hitbox.actor = _source
	hitbox.team = _source_team
	hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	if is_instance_valid(_source) and _damage > 0:
		hitbox.begin_attack(_damage, 0, &"projectile")
	hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	_remaining_lifetime -= maxf(0.0, delta)
	if _remaining_lifetime <= 0.0:
		queue_free()


func _on_hitbox_area_entered(area: Area3D) -> void:
	if area is HurtBox:
		queue_free()
