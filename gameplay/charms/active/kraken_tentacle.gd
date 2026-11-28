class_name KrakenTentacle
extends Node3D
## Each slam has a readable windup and one impact, never contact damage every frame.
## A decorative tentacle only bursts out and sinks back: it never seeks or hits.

signal target_requested
signal struck(at: Vector3, eruption: bool)

enum State { RISING, IDLE, WINDUP, SWING, RECOVER, RETRACT }

const CRIMSON := Color("f7122f")
const RISE_SECONDS := 0.16
const SWING_SECONDS := 0.12
const RECOVER_SECONDS := 0.32
const RETRACT_SECONDS := 0.3
const DECORATIVE_HOLD_SECONDS := 0.32
const SEEK_INTERVAL_SECONDS := 0.12
const HEIGHT_UNITS := 3.4
const HALF_WIDTH_UNITS := 0.46
const ERUPTION_STRETCH := 0.22
const SETTLE_SECONDS := 0.28
const WINDUP_BEND_RADIANS := -0.75
const SLAM_BEND_RADIANS := 2.15
const IDLE_CURL_RADIANS := 1.25
const SLAM_CURL_RADIANS := 0.5
const IDLE_SWAY_RADIANS := 0.34
const IDLE_SWAY_SPEED := 3.4
const THRASH_SWAY_RADIANS := 0.55
const THRASH_SWAY_SPEED := 22.0
const FLASH_SECONDS := 0.14

var definition: CharmData
var facing := Vector3.BACK
var state := State.RISING
var size_scale := 1.0
var lean := 0.0
## Which side of the screen the tip curls toward and the suckers sit on: 1 right, -1 left.
var curl_side := 1.0
var decorative := false
var _clock := 0.0
var _age := 0.0
var _remaining := 0.0
var _seek_clock := 0.0
var _cooldown := 0.0
var _strike_position := Vector3.ZERO
var _primer: CharmVfx
var _material: ShaderMaterial

@onready var _flesh: KrakenTentacleMesh = $Flesh


func _ready() -> void:
	_material = _flesh.material_override.duplicate() as ShaderMaterial
	_flesh.material_override = _material
	_material.set_shader_parameter("sucker_side", -curl_side)
	_material.set_shader_parameter("flame_phase", randf() * TAU)
	_flesh.height = HEIGHT_UNITS * size_scale
	_flesh.base_half_width = HALF_WIDTH_UNITS * size_scale
	_flesh.lean = lean
	_flesh.curl = IDLE_CURL_RADIANS * curl_side
	_flesh.phase = randf() * TAU
	_remaining = (
		DECORATIVE_HOLD_SECONDS if decorative else definition.get_param_float(&"lifetime_seconds")
	)
	_flesh.rebuild()


func begin_slam(target: Vector3) -> void:
	if state != State.IDLE or _cooldown > 0.0:
		return
	facing = target - global_position
	facing.y = 0.0
	if facing.is_zero_approx():
		facing = Vector3.BACK
	facing = facing.normalized()
	_strike_position = global_position + facing * definition.get_param_float(&"slam_reach_units")
	_clock = 0.0
	state = State.WINDUP
	_flesh.bend_direction = facing
	_primer = CharmVfx.spawn(
		get_parent(),
		_strike_position,
		CRIMSON,
		definition.get_param_float(&"slam_radius_units"),
		definition.get_param_float(&"slam_windup_seconds") + SWING_SECONDS,
		CharmVfx.Style.TARGET
	)


func _physics_process(delta: float) -> void:
	_clock += delta
	_age += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if state != State.RISING and state != State.RETRACT:
		_remaining -= delta
		if _remaining <= 0.0:
			_start_retract()
	match state:
		State.RISING:
			var share := clampf(_clock / RISE_SECONDS, 0.0, 1.0)
			_flesh.growth = ease(share, 0.35) * (1.0 + ERUPTION_STRETCH * share)
			if _clock >= RISE_SECONDS:
				state = State.IDLE
				_clock = 0.0
				if not decorative:
					struck.emit(global_position, true)
		State.IDLE:
			var settle := clampf(_age / (RISE_SECONDS + SETTLE_SECONDS), 0.0, 1.0)
			_flesh.growth = 1.0 + ERUPTION_STRETCH * (1.0 - settle) * cos(settle * PI * 2.0)
			_seek_clock -= delta
			if not decorative and _seek_clock <= 0.0 and _cooldown <= 0.0:
				_seek_clock = SEEK_INTERVAL_SECONDS
				target_requested.emit()
		State.WINDUP:
			var windup := definition.get_param_float(&"slam_windup_seconds")
			var share := clampf(_clock / windup, 0.0, 1.0)
			_flesh.growth = 1.0
			_flesh.bend = WINDUP_BEND_RADIANS * ease(share, 0.4)
			if _clock >= windup:
				state = State.SWING
				_clock = 0.0
		State.SWING:
			var share := clampf(_clock / SWING_SECONDS, 0.0, 1.0)
			_flesh.bend = lerpf(WINDUP_BEND_RADIANS, SLAM_BEND_RADIANS, share * share)
			_flesh.curl = lerpf(IDLE_CURL_RADIANS, SLAM_CURL_RADIANS, share) * curl_side
			if _clock >= SWING_SECONDS:
				state = State.RECOVER
				_clock = 0.0
				_cooldown = definition.get_param_float(&"slam_interval_seconds")
				struck.emit(_strike_position, false)
		State.RECOVER:
			var back := smoothstep(0.35, 1.0, _clock / RECOVER_SECONDS)
			_flesh.bend = SLAM_BEND_RADIANS * (1.0 - back)
			_flesh.curl = lerpf(SLAM_CURL_RADIANS, IDLE_CURL_RADIANS, back) * curl_side
			if _clock >= RECOVER_SECONDS:
				state = State.IDLE
				_clock = 0.0
		State.RETRACT:
			var share := clampf(_clock / RETRACT_SECONDS, 0.0, 1.0)
			_flesh.growth = 1.0 - share * share
			_flesh.bend = lerpf(_flesh.bend, 0.0, share)
			if _clock >= RETRACT_SECONDS:
				queue_free()
	_animate_flesh(delta)


func _animate_flesh(delta: float) -> void:
	# It thrashes while bursting out and diving back, and only breathes while it guards.
	var thrashing := state == State.RISING or state == State.RETRACT
	_flesh.sway = THRASH_SWAY_RADIANS if thrashing else IDLE_SWAY_RADIANS
	_flesh.sway_speed = THRASH_SWAY_SPEED if thrashing else IDLE_SWAY_SPEED
	_material.set_shader_parameter("flash", clampf(1.0 - _age / FLASH_SECONDS, 0.0, 1.0))
	_flesh.advance(delta)


func _start_retract() -> void:
	state = State.RETRACT
	_clock = 0.0
	if is_instance_valid(_primer):
		_primer.queue_free()
	_primer = null


func _exit_tree() -> void:
	if is_instance_valid(_primer):
		_primer.queue_free()
