class_name MovingPlatform
extends Node3D

## A hit on the lever toggles the destination, including while the platform moves.

signal destination_reached(at_end: bool)

@export_range(0.1, 30.0, 0.1, "suffix:m/s") var move_speed := 3.0

var _moving := false
var _target_end := false

@onready var platform: AnimatableBody3D = $Platform
@onready var start_marker: Marker3D = $Start
@onready var end_marker: Marker3D = $End
@onready var lever_hurtbox: HurtBox = $Platform/Lever/HurtBox
@onready var _lever_sprite: AnimatedSprite3D = $Platform/Lever/AnimatedSprite3D


func _ready() -> void:
	platform.position = start_marker.position
	lever_hurtbox.actor = self
	lever_hurtbox.team = CombatTeams.ENEMY
	lever_hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	lever_hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	_lever_sprite.animation_finished.connect(_on_lever_animation_finished)
	_lever_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	var destination := end_marker.position if _target_end else start_marker.position
	platform.position = platform.position.move_toward(destination, move_speed * delta)
	if platform.position.is_equal_approx(destination):
		platform.position = destination
		_moving = false
		destination_reached.emit(_target_end)


func receive_damage(damage: DamageContext) -> float:
	if damage == null or damage.source_team != CombatTeams.PLAYER or damage.amount_hp <= 0.0:
		return 0.0
	request_destination(not _target_end)
	_lever_sprite.stop()
	_lever_sprite.play(&"active")
	return damage.amount_hp


func _on_lever_animation_finished() -> void:
	if _lever_sprite.animation == &"active":
		_lever_sprite.play(&"idle")


func request_destination(at_end: bool) -> void:
	_target_end = at_end
	var destination := end_marker.position if at_end else start_marker.position
	_moving = not platform.position.is_equal_approx(destination)


func is_targeting_end() -> bool:
	return _target_end
