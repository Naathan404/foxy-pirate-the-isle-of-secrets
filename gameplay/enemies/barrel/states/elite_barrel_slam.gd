class_name EliteBarrelSlam
extends EnemyState
## The answer to a crowding Foxy: the elite crouches over a filling ink ring, leaps, slams
## down in an ink burst around itself and is left open for a moment.

enum Phase { WINDUP, LEAP, RECOVER }

@export_group("Timing")
@export_range(0.2, 3.0, 0.01, "suffix:s") var windup_seconds: float = 0.75
@export_range(0.1, 1.0, 0.01, "suffix:s") var leap_seconds: float = 0.3
## Punish window after the impact.
@export_range(0.1, 3.0, 0.01, "suffix:s") var recover_seconds: float = 0.9
## Pause before the next volley once the barrel has recovered.
@export_range(0.0, 5.0, 0.01, "suffix:s") var volley_delay_seconds: float = 0.8

@export_group("Body")
@export_range(0.0, 5.0, 0.05, "suffix:m") var leap_height_meters: float = 1.7
## Width and height of the barrel squeezed down at the end of the wind-up.
@export var crouch_scale := Vector2(1.18, 0.78)
@export var stretch_scale := Vector2(0.88, 1.18)
@export var landing_scale := Vector2(1.28, 0.72)
@export_range(0.0, 0.5, 0.01, "suffix:m") var shake_meters: float = 0.09

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _rest_position := Vector3.ZERO
var _rest_scale := Vector3.ONE
var _warning: MeshInstance3D
var _bubbles: CPUParticles3D


func _enter() -> void:
	var barrel := enemy as EliteBarrel
	if barrel == null or not is_instance_valid(barrel.visual):
		request_state(&"idle")
		return
	barrel.stop_movement()
	barrel.start_slam_cooldown()
	_rest_position = barrel.visual.position
	_rest_scale = barrel.visual.scale
	_phase = Phase.WINDUP
	_elapsed = 0.0
	if not barrel.play_directional_animation(&"charge", true):
		barrel.play_directional_animation(&"idle", true)
	_warning = EliteBarrelInkVfx.zone(
		barrel, barrel.global_position, barrel.slam_radius, EliteBarrelInkVfx.Zone.WARNING
	)
	_bubbles = EliteBarrelInkVfx.bubbles(barrel, barrel.slam_radius * 0.5)


func _exit() -> void:
	_clear_warning()
	var barrel := enemy as EliteBarrel
	if barrel != null and is_instance_valid(barrel.visual):
		barrel.visual.position = _rest_position
		barrel.visual.scale = _rest_scale
		barrel.visual.set_telegraph_pulse(0.0, 1.0)


func _update(delta: float) -> void:
	var barrel := enemy as EliteBarrel
	if barrel == null:
		request_state(&"idle")
		return
	barrel.stop_movement(delta)
	_elapsed += maxf(0.0, delta)
	match _phase:
		Phase.WINDUP:
			_update_windup(barrel)
		Phase.LEAP:
			_update_leap(barrel)
		Phase.RECOVER:
			_update_recover(barrel)


func _update_windup(barrel: EliteBarrel) -> void:
	var share := clampf(_elapsed / windup_seconds, 0.0, 1.0)
	EliteBarrelInkVfx.set_progress(_warning, share)
	_pose(barrel, Vector2.ONE.lerp(crouch_scale, ease(share, 0.5)))
	barrel.visual.position.x = _rest_position.x + sin(_elapsed * 55.0) * shake_meters * share
	barrel.visual.set_telegraph_pulse(share * (0.25 + 0.2 * sin(_elapsed * 22.0)), 1.0)
	if share >= 1.0:
		_phase = Phase.LEAP
		_elapsed = 0.0
		barrel.visual.position.x = _rest_position.x
		barrel.visual.set_telegraph_pulse(0.0, 1.0)
		barrel.play_directional_animation(&"shoot_up", true)


## Only the artwork leaves the ground: the body and its hurtbox stay where they are.
func _update_leap(barrel: EliteBarrel) -> void:
	var share := clampf(_elapsed / leap_seconds, 0.0, 1.0)
	# Slow off the top, fast into the ground.
	var arc := sin(PI * share * share)
	barrel.visual.position.y = _rest_position.y + arc * leap_height_meters
	_pose(barrel, crouch_scale.lerp(stretch_scale, minf(1.0, share * 3.0)))
	if share >= 1.0:
		_phase = Phase.RECOVER
		_elapsed = 0.0
		barrel.visual.position = _rest_position
		_clear_warning()
		barrel.erupt_ink()


func _update_recover(barrel: EliteBarrel) -> void:
	var share := clampf(_elapsed / recover_seconds, 0.0, 1.0)
	var spring := clampf(share * 2.2, 0.0, 1.0)
	_pose(barrel, landing_scale.lerp(Vector2.ONE, ease(spring, -2.0)))
	if share < 1.0:
		return
	barrel.visual.scale = _rest_scale
	barrel.start_attack_cooldown(volley_delay_seconds)
	# Leave first: the charged look must start from the restored pose, not the squashed one.
	request_state(&"idle")
	barrel.complete_normal_attack()


func _pose(barrel: EliteBarrel, size: Vector2) -> void:
	barrel.visual.scale = _rest_scale * Vector3(size.x, size.y, size.x)


func _clear_warning() -> void:
	for node: Node in [_warning, _bubbles]:
		if is_instance_valid(node):
			node.queue_free()
	_warning = null
	_bubbles = null
