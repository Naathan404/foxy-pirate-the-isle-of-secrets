extends WeaponAttack

const SPRITE_FEEDBACK: Script = preload("res://gameplay/weapons/dagger_sprite_feedback.gd")

# Dao boomerang: bay thẳng khi ném, hết tầm hoặc gặp tường thì quay về người ném

# Tốc độ bay đi và bay về
@export var speed: float = 12.0
@export var return_speed: float = 16.0
# Tự hủy sau thời gian này nếu chưa về tới người ném
@export var lifetime: float = 6.0
# Khoảng cách đủ gần để coi như người ném đã bắt được dao
@export var catch_distance: float = 0.5
@export var height_offset: float = 0.9

@export_group("Game Feel")
@export_range(0.0, 0.3, 0.01) var launch_recoil: float = 0.14
@export_range(0.0, 0.3, 0.01) var enemy_recoil: float = 0.18
@export_range(0.0, 0.05, 0.001) var launch_hitstop: float = 0.022
@export_range(0.0, 6.0, 0.1) var launch_shake: float = 1.8

var max_distance: float = 10.0
var flight_direction: Vector3
# tính quãng đường lượt đi
var distance_travelled: float = 0.0
var returning: bool = false
var thrower: Node3D
# Thời gian đã bay
var age: float = 0.0

@onready var hit_area: HitBox = $HitBox
@onready var _vfx: Node3D = $ThrowVFX
@onready var _blade: AnimatedSprite3D = $AnimatedSprite3D


# windup
func _ready() -> void:
	set_physics_process(false)
	hit_area.hit_confirmed.connect(_on_hit_confirmed)
	hit_area.damage_prepared.connect(_on_damage_prepared)
	hit_area.body_entered.connect(_on_body_entered)


func validate() -> bool:
	return (
		get_node_or_null("HitBox") is HitBox
		and speed > 0.0
		and return_speed > 0.0
		and lifetime > 0.0
		and catch_distance > 0.0
	)


# gọi khi kết thúc windup
func activate() -> void:
	if context == null or not is_instance_valid(context.actor):
		return
	super.activate()
	max_distance = context.range_units
	global_position = context.actor.global_position + Vector3.UP * height_offset
	launch(context.direction, context.actor)

	# setup hitbox
	hit_area.actor = context.actor
	hit_area.team = context.team
	hit_area.collision_layer = CombatLayers.PLAYER_ATTACK
	hit_area.collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY_HURTBOX
	hit_area.scale = Vector3.ONE * context.hitbox_multiplier

	_begin_damage_pass()
	_vfx.start(_blade)
	_play_launch_feedback()
	set_physics_process(true)


# phongs dao trên mặt phẳng xz
func launch(direction: Vector3, player: Node3D) -> void:
	flight_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	thrower = player
	# Giữ độ cao tương đối này khi dao đuổi theo người ném ở lượt về
	height_offset = global_position.y - player.global_position.y
	distance_travelled = 0.0
	returning = false
	age = 0.0


func _physics_process(delta: float) -> void:
	age += delta
	# Dọn dao nếu foxy dead hoặc dao tồn tại quá lâu
	if not is_instance_valid(thrower) or age >= lifetime:
		_vfx.finish()
		queue_free()
		return

	if returning:
		var target = thrower.global_position + Vector3.UP * height_offset
		global_position = global_position.move_toward(target, return_speed * delta)
		if global_position.distance_to(target) <= catch_distance:
			_vfx.finish(true)
			queue_free()
	else:
		# Giới hạn bước di chuyển để dao không bay quá tầm
		var distance: float = minf(speed * delta, max_distance - distance_travelled)
		var destination: Vector3 = global_position + flight_direction * distance
		# Quét đoạn đường sắp bay để tránh xuyên tường mỏng khi frame chậm.
		# Ray kiểm tra môi trường
		var query := PhysicsRayQueryParameters3D.create(
			global_position, destination, CombatLayers.WORLD
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit.position
			_vfx.impact(global_position)
			_begin_return()
			return
		global_position = destination
		distance_travelled += distance
		if distance_travelled >= max_distance:
			_begin_return()


func _begin_return() -> void:
	# Va chạm và kiểm tra tầm có thể cùng yêu cầu quay về; chỉ chuyển một lần.
	if returning:
		return
	returning = true
	_vfx.turn()
	_begin_damage_pass()


func _begin_damage_pass() -> void:
	hit_area.begin_attack_with_context(context.create_damage_context())


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	context.damage_prepared.emit(damage, target)


# Chuyển hit đã gây sát thương về context để controller xử lý chaos và hiệu ứng vũ khí
func _on_hit_confirmed(damage: DamageContext, target: Node, applied_hp: float) -> void:
	context.damage_applied.emit(damage, target, applied_hp)
	if applied_hp > 0:
		var direction := flight_direction
		if returning and is_instance_valid(thrower):
			direction = (thrower.global_position - global_position).normalized()
		var at := _blade.global_position
		if (
			is_instance_valid(target)
			and target is EnemyBase
			and is_instance_valid(target.visual)
			and is_instance_valid(target.visual.sprite)
		):
			var sprite: Sprite3D = target.visual.sprite
			var center := sprite.global_transform * sprite.get_aabb().get_center()
			at = center + (at - center).limit_length(0.25)
			_sprite_feedback(sprite).kick(direction, enemy_recoil, true)
		_vfx.impact(at, direction)


func _play_launch_feedback() -> void:
	if context.actor is Player and is_instance_valid(context.actor.visual.sprite):
		_sprite_feedback(context.actor.visual.sprite).kick(-flight_direction, launch_recoil)
	get_node("/root/HitstopController").request(launch_hitstop)
	get_node("/root/ScreenShakeController").request(launch_shake, 0.1)


func _sprite_feedback(sprite: Sprite3D) -> Node:
	var feedback := sprite.get_node_or_null("DaggerFeedback")
	if feedback == null:
		feedback = SPRITE_FEEDBACK.new()
		feedback.name = "DaggerFeedback"
		sprite.add_child(feedback)
	return feedback


# HitBox chạm môi trường thì yêu cầu quay về
func _on_body_entered(body: Node3D) -> void:
	if launched and body is PhysicsBody3D and (body.collision_layer & CombatLayers.WORLD) != 0:
		_begin_return()
