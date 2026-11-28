class_name KrakenTentacle
extends Node3D
## Each slam has a readable windup and one impact, never contact damage every frame.

signal target_requested
signal struck(at: Vector3, eruption: bool)

enum State { RISING, IDLE, WINDUP, SWING, RECOVER, RETRACT }

const RISE_SECONDS := 0.22
const SWING_SECONDS := 0.12
const RECOVER_SECONDS := 0.32
const RETRACT_SECONDS := 0.3
const SEEK_INTERVAL_SECONDS := 0.12
const ROOT_FRACTION := Vector2(0.38, 0.92)
const STANDING_HEIGHT_UNITS := 2.5
const STANDING_HEIGHT_FRACTION := 0.76
const IDLE_SWAY_RADIANS := 0.025

var definition: CharmData
var facing := Vector3.BACK
var state := State.RISING
var _clock := 0.0
var _age := 0.0
var _remaining := 0.0
var _seek_clock := 0.0
var _cooldown := 0.0
var _strike_position := Vector3.ZERO
var _primer: CharmVfx

@onready var _sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	var cell := _sprite.texture.get_size() / Vector2(_sprite.hframes, _sprite.vframes)
	_sprite.pixel_size = STANDING_HEIGHT_UNITS / (cell.y * STANDING_HEIGHT_FRACTION)
	_sprite.offset = Vector2((0.5 - ROOT_FRACTION.x) * cell.x, (ROOT_FRACTION.y - 0.5) * cell.y)
	_remaining = definition.get_param_float(&"lifetime_seconds")
	_update_facing()
	_sprite.frame = 0


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
	_sprite.rotation.z = 0.0
	_sprite.frame = 3
	_update_facing()
	_primer = CharmVfx.spawn(
		get_parent(),
		_strike_position,
		Color("b190ff"),
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
			_sprite.frame = 0 if _clock < RISE_SECONDS * 0.4 else 1
			if _clock >= RISE_SECONDS:
				state = State.IDLE
				_clock = 0.0
				_sprite.frame = 2
				struck.emit(global_position, true)
		State.IDLE:
			_sprite.frame = 2
			_sprite.rotation.z = sin(_age * 3.0) * IDLE_SWAY_RADIANS
			_seek_clock -= delta
			if _seek_clock <= 0.0 and _cooldown <= 0.0:
				_seek_clock = SEEK_INTERVAL_SECONDS
				target_requested.emit()
		State.WINDUP:
			if _clock >= definition.get_param_float(&"slam_windup_seconds"):
				state = State.SWING
				_clock = 0.0
				_sprite.frame = 4
		State.SWING:
			if _clock >= SWING_SECONDS:
				_sprite.frame = 5
				state = State.RECOVER
				_clock = 0.0
				_cooldown = definition.get_param_float(&"slam_interval_seconds")
				struck.emit(_strike_position, false)
		State.RECOVER:
			if _clock > RECOVER_SECONDS * 0.4:
				_sprite.frame = 6
			if _clock >= RECOVER_SECONDS:
				state = State.IDLE
				_clock = 0.0
		State.RETRACT:
			_sprite.scale.y = maxf(0.0, 1.0 - _clock / RETRACT_SECONDS)
			_sprite.modulate.a = _sprite.scale.y
			if _clock >= RETRACT_SECONDS:
				queue_free()


func _update_facing() -> void:
	var camera := get_viewport().get_camera_3d()
	var screen_right := camera.global_basis.x if camera != null else Vector3.RIGHT
	_sprite.flip_h = facing.dot(screen_right) < 0.0
	# Mirroring must preserve the ground root, not shift it sideways.
	var cell_width := float(_sprite.texture.get_width()) / _sprite.hframes
	_sprite.offset.x = (0.5 - ROOT_FRACTION.x) * cell_width * (-1.0 if _sprite.flip_h else 1.0)


func _start_retract() -> void:
	state = State.RETRACT
	_clock = 0.0
	_sprite.frame = 7
	_sprite.rotation.z = 0.0
	if is_instance_valid(_primer):
		_primer.queue_free()
	_primer = null


func _exit_tree() -> void:
	if is_instance_valid(_primer):
		_primer.queue_free()
