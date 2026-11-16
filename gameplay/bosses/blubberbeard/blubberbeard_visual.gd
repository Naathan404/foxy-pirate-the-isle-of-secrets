class_name BlubberbeardVisual
extends Sprite3D
## Four generated poses are animated with breathing, anticipation and follow-through.

enum Pose { IDLE, WINDUP, CHARGE, RECOVERY }

var pose: Pose = Pose.IDLE
var windup_progress: float = 0.0
var enraged: bool = false
var _kind: int = 0
var _clock: float = 0.0
var _hit_flash: float = 0.0
var _lean: float = 1.0
var _rest_position: Vector3
var _rest_scale: Vector3
var _dying: bool = false
var _impact_left: float = 0.0
var _impact_duration: float = 0.0
var _impact_power: float = 0.0


func _ready() -> void:
	_rest_position = position
	_rest_scale = scale


func _process(delta: float) -> void:
	if _dying:
		return
	var owner_boss := get_parent() as BossBase
	var hitstop := get_node_or_null("/root/HitstopController")
	if hitstop != null and hitstop.is_frozen(owner_boss):
		return
	_clock += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_impact_left = maxf(0.0, _impact_left - delta)
	var size := 1.1 if enraged else 1.0
	var breathing := sin(_clock * (5.0 if enraged else 3.0)) * 0.025
	var desired_scale := _rest_scale * size * Vector3(1.0 + breathing, 1.0 - breathing, 1.0)
	var desired_position := _rest_position
	desired_position.y += _rest_position.y * (size - 1.0)
	var desired_rotation := 0.0
	match pose:
		Pose.WINDUP:
			var anticipation := sin(windup_progress * PI * 0.5)
			desired_scale *= Vector3(1.0 + 0.13 * anticipation, 1.0 - 0.12 * anticipation, 1.0)
			desired_rotation = -0.09 * anticipation * _lean
			desired_position.x += sin(_clock * 34.0) * 0.07 * anticipation
		Pose.CHARGE:
			desired_scale *= Vector3(1.1, 0.9, 1.0)
			desired_rotation = 0.16 * _lean
			desired_position.y += sin(_clock * 20.0) * 0.05
		Pose.RECOVERY:
			desired_scale *= Vector3(1.08, 0.9, 1.0)
			desired_rotation = -0.08 * _lean
	if _impact_left > 0.0 and _impact_duration > 0.0:
		var weight := _impact_left / _impact_duration
		desired_scale *= Vector3(1.0 + _impact_power * weight, 1.0 - _impact_power * weight, 1.0)
		desired_rotation += sin(_clock * 42.0) * _impact_power * weight
	var blend := 1.0 - exp(-12.0 * delta)
	scale = scale.lerp(desired_scale, blend)
	position = position.lerp(desired_position, blend)
	rotation.z = lerpf(rotation.z, desired_rotation, blend)
	modulate = Color(2.0, 2.0, 2.0) if _hit_flash > 0.0 else _phase_color()


func begin_windup(kind: int) -> void:
	_kind = kind
	windup_progress = 0.0
	pose = Pose.WINDUP
	frame = kind + 1


func begin_charge(direction: Vector3) -> void:
	face_direction(direction)
	pose = Pose.CHARGE
	frame = 2


func face_direction(direction: Vector3) -> void:
	_lean = -1.0 if direction.x < 0.0 else 1.0
	flip_h = direction.x < 0.0


func begin_recovery(kind: int) -> void:
	pose = Pose.RECOVERY if kind == BlubberbeardSkillData.Kind.BELLY_CHARGE else Pose.IDLE
	frame = 3 if enraged else 0


func set_enraged(value: bool) -> void:
	enraged = value
	if pose == Pose.IDLE or pose == Pose.RECOVERY:
		frame = 3 if enraged else 0


func flash_hit() -> void:
	_hit_flash = 0.12


func impact(power: float, duration: float) -> void:
	_impact_power = clampf(power, 0.0, 0.5)
	_impact_duration = maxf(duration, 0.01)
	_impact_left = _impact_duration


func play_death(finished: Callable) -> void:
	_dying = true
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(self, "scale", scale * Vector3(1.25, 0.1, 1.0), 0.55)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(self, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(finished)


func _phase_color() -> Color:
	return Color(1.0, 0.72, 0.65) if enraged else Color.WHITE
