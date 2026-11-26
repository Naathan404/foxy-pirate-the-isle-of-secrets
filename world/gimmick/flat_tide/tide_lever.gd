class_name TideLever
extends StaticBody3D
## A sluice lever: striking it floods one lane of the room right away. The surge sweeps and
## stuns every enemy in the lane (and Foxy, if he stands there), so the tide becomes a weapon.
## The lever is ready again once the tide has gone out and the controller is waiting.

signal pulled

const SPENT_TINT := Color(0.45, 0.5, 0.55, 1.0)

@export var controller: FlatTideController
## The lane this lever floods; must be one of the controller's zones.
@export var zone: FlatTideZone

@onready var hurtbox: HurtBox = $Lever/HurtBox
@onready var _lever_sprite: AnimatedSprite3D = $Lever/AnimatedSprite3D


func _ready() -> void:
	if controller == null or zone == null or not controller.zones.has(zone):
		push_error("TideLever: assign the controller and one of its zones.")
		return
	hurtbox.actor = self
	hurtbox.team = CombatTeams.ENEMY
	hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	_lever_sprite.animation_finished.connect(_on_lever_animation_finished)
	_lever_sprite.play(&"idle")
	controller.state_changed.connect(_on_tide_state_changed)
	_refresh_ready_tint()


func receive_damage(damage: DamageContext) -> float:
	if damage == null or damage.source_team != CombatTeams.PLAYER or damage.amount_hp <= 0.0:
		return 0.0
	if not controller.request_cycle_for(zone):
		return 0.0
	_lever_sprite.stop()
	_lever_sprite.play(&"active")
	pulled.emit()
	return damage.amount_hp


func _on_tide_state_changed(_state: FlatTideController.State) -> void:
	_refresh_ready_tint()


func _refresh_ready_tint() -> void:
	_lever_sprite.modulate = (
		Color.WHITE if controller.state == FlatTideController.State.LOW else SPENT_TINT
	)


func _on_lever_animation_finished() -> void:
	if _lever_sprite.animation == &"active":
		_lever_sprite.play(&"idle")
