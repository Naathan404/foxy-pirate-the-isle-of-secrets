extends Node3D
## Sand dust under Foxy's feet while she runs: a puff at each footfall on alternating feet, a
## kick of dust when she sets off, a skid when she stops or turns sharply, and a faint trail
## between steps at full speed. Puffs are hand-drawn sprites (run_dust_puffs.png, built by
## tools/vfx/make_run_dust_puffs.py) standing on the ground from their bottom edge.
##
## Foxy moves on physics ticks and is drawn interpolated between them; the dust follows the
## drawn feet, so it never leads or trails the art by a tick. The emitters jump to the feet
## for each puff, from wherever they were (the room origin in a freshly entered room). Both
## physics interpolation and particle `interpolate` would turn that jump into a slide and
## spray dust along it, so both are off.

## Burst emitters reused in turn; enough for a few overlapping steps and a skid.
const BURST_POOL_SIZE := 8
## Direction changes wider than this while running read as a sharp turn.
const TURN_SKID_DEGREES := 100.0

@export var player: Player
@export_range(0.0, 5.0, 0.01) var minimum_speed: float = 0.3
## How far behind the feet, along the run, the dust leaves the ground.
@export_range(0.0, 2.0, 0.01, "suffix:m") var heel_offset: float = 0.12

@export_group("Steps")
## Ground covered per footfall; one puff per footfall, on alternating feet.
@export_range(0.3, 3.0, 0.05, "suffix:m") var step_distance: float = 0.95
## Sideways distance from the run line to each foot.
@export_range(0.0, 0.5, 0.01, "suffix:m") var step_width: float = 0.14
@export_range(0, 8) var step_puffs: int = 2
@export_range(0, 12) var start_puffs: int = 5
@export_range(0, 12) var stop_puffs: int = 4
## Ground clearance under the puffs' bottom edge.
@export_range(0.0, 0.3, 0.01, "suffix:m") var ground_clearance: float = 0.02

@export_group("Trail")
## Share of Foxy's full speed from which the faint trail between steps shows.
@export_range(0.0, 1.0, 0.05) var trail_speed_ratio: float = 0.85

var _was_running: bool = false
var _distance_since_step: float = 0.0
var _step_side: float = 1.0
var _next_burst: int = 0
var _last_direction: Vector3 = Vector3.BACK
var _bursts: Array[GPUParticles3D] = []

@onready var _puff: GPUParticles3D = $Puff
@onready var _trail: GPUParticles3D = $Trail
@onready var _trail_material := _trail.process_material as ParticleProcessMaterial


func _ready() -> void:
	# Placed by hand every frame from the drawn feet; the children inherit this.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_trail.emitting = false
	_trail.top_level = true
	_create_bursts()


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.fsm) or player.data == null:
		_stop_running(false)
		return
	# Kept under the feet even while off, so switching it on never starts from an old spot.
	_trail.global_position = _get_foot_position() - _last_direction * heel_offset
	var movement := player.get_real_velocity()
	movement.y = 0.0
	var running: bool = player.fsm.current_state == player.fsm.states.get("run")
	if (
		not running
		or player.dead
		or player.environment_is_water
		or not player.is_on_floor()
		or movement.length() <= minimum_speed
	):
		var idle: bool = player.fsm.current_state == player.fsm.states.get("idle")
		_stop_running(idle and not player.dead and player.is_on_floor())
		return
	_update_running(movement, delta)


func _create_bursts() -> void:
	_puff.emitting = false
	for index in BURST_POOL_SIZE:
		var burst := _puff.duplicate() as GPUParticles3D
		burst.name = "DustPuff%d" % index
		# Each burst aims its own way, so each needs its own material.
		burst.process_material = _puff.process_material.duplicate()
		add_child(burst)
		burst.top_level = true
		_bursts.append(burst)


func _update_running(movement: Vector3, delta: float) -> void:
	var speed := movement.length()
	var direction := movement.normalized()
	var foot := _get_foot_position()
	if not _was_running:
		_burst(foot - direction * heel_offset, -direction, start_puffs, 1.25, 50.0)
		_was_running = true
		_distance_since_step = 0.0
	elif rad_to_deg(_last_direction.angle_to(direction)) > TURN_SKID_DEGREES:
		_burst(foot + _last_direction * heel_offset, _last_direction, stop_puffs, 1.1, 70.0)
		_distance_since_step = 0.0
	_last_direction = direction

	var speed_ratio := clampf(speed / maxf(0.1, player.data.move_speed), 0.0, 1.0)
	_trail.global_position = foot - direction * heel_offset
	_trail_material.direction = (-direction + Vector3.UP * 0.15).normalized()
	_trail.emitting = speed_ratio >= trail_speed_ratio

	_distance_since_step += speed * maxf(0.0, delta)
	if _distance_since_step < step_distance:
		return
	_distance_since_step = fmod(_distance_since_step, step_distance)
	var side := direction.cross(Vector3.UP).normalized() * step_width * _step_side
	# Kicked back and a little out to the side of the foot that pushed off.
	var kick := (-direction + side.normalized() * 0.35 * signf(_step_side)).normalized()
	_burst(foot + side - direction * heel_offset, kick, step_puffs, 1.0, 30.0)
	_step_side = -_step_side


func _stop_running(play_stop_burst: bool) -> void:
	_trail.emitting = false
	if _was_running and play_stop_burst and is_instance_valid(player):
		# A skid: the dust is pushed on ahead of the feet that braked.
		var foot := _get_foot_position()
		_burst(foot + _last_direction * heel_offset, _last_direction, stop_puffs, 1.15, 70.0)
	_was_running = false
	_distance_since_step = 0.0
	_step_side = 1.0


## Throws `count` puffs from `origin` along the ground towards `heading`, `size` times their
## normal scale, fanned over `spread_degrees`.
func _burst(
	origin: Vector3, heading: Vector3, count: int, size: float, spread_degrees: float
) -> void:
	if count <= 0:
		return
	var burst := _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % _bursts.size()
	burst.global_position = origin
	burst.amount = count
	var material := burst.process_material as ParticleProcessMaterial
	material.direction = (heading.normalized() + Vector3.UP * 0.15).normalized()
	material.spread = spread_degrees
	var template := _puff.process_material as ParticleProcessMaterial
	material.scale_min = template.scale_min * size
	material.scale_max = template.scale_max * size
	burst.restart()


## Bottom of Foxy's capsule where she is drawn this frame.
func _get_foot_position() -> Vector3:
	var drawn := player.get_global_transform_interpolated()
	var foot := Vector3.ZERO
	var collider := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and collider.shape is CapsuleShape3D:
		var capsule := collider.shape as CapsuleShape3D
		foot = collider.position + Vector3.DOWN * capsule.height * 0.5
	return drawn * foot + Vector3.UP * ground_clearance
