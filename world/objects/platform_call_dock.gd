class_name PlatformCallDock
extends StaticBody3D

## A fixed landing with a lever that calls its sibling moving platform.

@export var call_end := false

@onready var hurtbox: HurtBox = $Lever/HurtBox
@onready var _lever_sprite: AnimatedSprite3D = $Lever/AnimatedSprite3D


func _ready() -> void:
	hurtbox.actor = self
	hurtbox.team = CombatTeams.ENEMY
	hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	_lever_sprite.animation_finished.connect(_on_lever_animation_finished)
	_lever_sprite.play(&"idle")


func receive_damage(damage: DamageContext) -> float:
	if damage == null or damage.source_team != CombatTeams.PLAYER or damage.amount_hp <= 0.0:
		return 0.0
	var moving_platform := get_parent() as MovingPlatform
	if moving_platform == null:
		return 0.0
	moving_platform.request_destination(call_end)
	_lever_sprite.stop()
	_lever_sprite.play(&"active")
	return damage.amount_hp


func _on_lever_animation_finished() -> void:
	if _lever_sprite.animation == &"active":
		_lever_sprite.play(&"idle")
