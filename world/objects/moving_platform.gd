class_name MovingPlatform
extends Node3D

## Hits toggle endpoints, or follow Start -> Center -> End -> Center when enabled.
## A hit can change the destination while the platform is moving.

signal destination_reached(at_end: bool)

@export_range(0.1, 30.0, 0.1, "suffix:m/s") var move_speed := 3.0
## Start at Center; each lever hit advances the four-step route.
@export var center_stop_enabled: bool = false

var _moving := false
var _target_end := false
var _next_center_stop_index := 0
var _target_marker: Marker3D

@onready var platform: AnimatableBody3D = $Platform
@onready var start_marker: Marker3D = $Start
@onready var end_marker: Marker3D = $End
@onready var lever_hurtbox: HurtBox = $Platform/Lever/HurtBox
@onready var _lever_sprite: AnimatedSprite3D = $Platform/Lever/AnimatedSprite3D
@onready var _center_marker: Marker3D = get_node_or_null("Center") as Marker3D
@onready var _center_route: Array[Marker3D] = [
	start_marker,
	_center_marker,
	end_marker,
	_center_marker,
]


func _ready() -> void:
	if center_stop_enabled and _center_marker == null:
		push_error("MovingPlatform: center_stop_enabled requires a Center marker.")
		set_physics_process(false)
		return
	_target_marker = _center_marker if center_stop_enabled else start_marker
	platform.position = _target_marker.position
	lever_hurtbox.actor = self
	lever_hurtbox.team = CombatTeams.ENEMY
	lever_hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	lever_hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	_lever_sprite.animation_finished.connect(_on_lever_animation_finished)
	_lever_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	var destination := _target_marker.position
	platform.position = platform.position.move_toward(destination, move_speed * delta)
	if platform.position.is_equal_approx(destination):
		platform.position = destination
		_moving = false
		if _target_marker != _center_marker:
			destination_reached.emit(_target_end)


func receive_damage(damage: DamageContext) -> float:
	if damage == null or damage.source_team != CombatTeams.PLAYER or damage.amount_hp <= 0.0:
		return 0.0
	if center_stop_enabled:
		_request_stop(_center_route[_next_center_stop_index])
		_next_center_stop_index = (_next_center_stop_index + 1) % _center_route.size()
	else:
		request_destination(not _target_end)
	_lever_sprite.stop()
	_lever_sprite.play(&"active")
	return damage.amount_hp


func _on_lever_animation_finished() -> void:
	if _lever_sprite.animation == &"active":
		_lever_sprite.play(&"idle")


func request_destination(at_end: bool) -> void:
	_request_stop(end_marker if at_end else start_marker)


func is_targeting_end() -> bool:
	return _target_end


func _request_stop(marker: Marker3D) -> void:
	_target_marker = marker
	_target_end = marker == end_marker
	_moving = not platform.position.is_equal_approx(marker.position)
