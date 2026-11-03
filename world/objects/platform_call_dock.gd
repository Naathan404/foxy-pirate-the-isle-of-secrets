class_name PlatformCallDock
extends StaticBody3D

## A fixed landing with a lever that calls its sibling moving platform.

@export var call_end := false

@onready var hurtbox: HurtBox = $Lever/HurtBox
@onready var _animator: AnimationPlayer = (
	$Lever/Visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
)


func _ready() -> void:
	hurtbox.actor = self
	hurtbox.team = CombatTeams.ENEMY
	hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK


func receive_damage(damage: DamageContext) -> float:
	if damage == null or damage.source_team != CombatTeams.PLAYER or damage.amount_hp <= 0.0:
		return 0.0
	var moving_platform := get_parent() as MovingPlatform
	if moving_platform == null:
		return 0.0
	moving_platform.request_destination(call_end)
	if is_instance_valid(_animator):
		_animator.stop(true)
		_animator.play(&"toggle-on", 0.1)
		_animator.queue(&"toggle-off")
	return damage.amount_hp
