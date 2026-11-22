extends DestructibleProp
## A permanent target: every valid hit is reported without reducing its health.

const DAMAGE_POPUP = preload("res://gameplay/combat/damage_popup_presenter.gd")

@export_group("Training Feedback")
## Height above the dummy origin in local units, before the dummy's scale.
@export_range(0.0, 10.0, 0.1, "suffix:m") var damage_popup_height: float = 3.0


func _ready() -> void:
	super()
	add_to_group("training_dummy")
	add_to_group(&"immovable")


func receive_damage(damage: DamageContext) -> float:
	if (
		damage == null
		or damage.source_team != CombatTeams.PLAYER
		or not is_finite(damage.amount_hp)
		or damage.amount_hp <= 0.0
	):
		return 0.0
	var amount := damage.amount_hp
	if is_instance_valid(damage.source) and damage.source.has_signal("combat_activity"):
		damage.source.emit_signal("combat_activity")
	damaged.emit(amount)
	_play_hit_feedback()
	_spawn_smoke(hit_smoke_amount)
	DAMAGE_POPUP.show_damage(
		get_parent(), to_global(Vector3.UP * damage_popup_height), damage, amount
	)
	return amount
