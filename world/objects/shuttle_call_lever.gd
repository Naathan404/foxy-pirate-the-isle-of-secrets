class_name ShuttleCallLever
extends PlatformLever
## Shore lever that calls a shuttle. It stays buried until `reveal` is called, and the owner
## of the shuttle suspends it while the shuttle is busy. It only reports the hit with
## `called`; it does not move any platform itself.

signal called

@export_range(0.1, 3.0, 0.05, "suffix:s") var rise_seconds: float = 0.7
@export_range(0.5, 5.0, 0.1, "suffix:m") var buried_depth_meters: float = 2.0

var _resting_y: float = 0.0
var _revealed: bool = false
var _suspended: bool = false
var _rising: bool = false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_resting_y = position.y
	_bury()


func receive_damage(damage: DamageContext) -> float:
	if not hurtbox.enabled or damage == null or damage.source_team != CombatTeams.PLAYER:
		return 0.0
	if damage.amount_hp <= 0.0:
		return 0.0
	called.emit()
	_lever_sprite.stop()
	_lever_sprite.play(&"active")
	return damage.amount_hp


func is_revealed() -> bool:
	return _revealed


## Lifts the lever out of the ground; it can be hit once it has finished rising.
func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
	position.y = _resting_y - buried_depth_meters
	_rising = true
	var tween := create_tween()
	tween.tween_property(self, "position:y", _resting_y, rise_seconds)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_risen)
	_refresh_usable()


## For rooms entered after the lever was already earned.
func reveal_immediately() -> void:
	_revealed = true
	_rising = false
	visible = true
	position.y = _resting_y
	_refresh_usable()


## While suspended the lever ignores hits, for example while the shuttle is travelling.
func set_suspended(suspended: bool) -> void:
	_suspended = suspended
	_refresh_usable()


func _on_risen() -> void:
	_rising = false
	_refresh_usable()


func _bury() -> void:
	_revealed = false
	visible = false
	position.y = _resting_y - buried_depth_meters
	_refresh_usable()


func _refresh_usable() -> void:
	hurtbox.enabled = _revealed and not _suspended and not _rising
