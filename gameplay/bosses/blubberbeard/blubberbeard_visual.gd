class_name BlubberbeardVisual
extends Sprite3D
## Drives 4-directional sprite sheets, 8-frame charge sprints, and barrel throw sync.

enum Pose { IDLE, WINDUP, CHARGE, RECOVERY }
enum Clip {
	IDLE,
	MOVE,
	BARREL_THROW,
	BELLY_CHARGE_WINDUP,
	BELLY_CHARGE,
	BELLY_CHARGE_RECOVERY,
	INFLATE_WINDUP,
	INFLATE_BURST,
	HIT,
	DEATH,
}
enum FacingDir { DOWN = 0, SIDE = 1, UP = 2 }

const IDLE_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_idle_4dir.png"
)
const MOVE_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_move_4dir.png"
)
const INFLATE_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_inflate_4dir.png"
)
const CHARGE_PREP_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_charge_prep_4dir.png"
)
const CHARGE_RUN_DOWN_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_charge_run_down.png"
)
const CHARGE_RUN_SIDE_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_charge_run_side.png"
)
const CHARGE_RUN_UP_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_charge_run_up.png"
)
const ATTACKS_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_attacks.png"
)
const HIT_DEATH_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_hit_death.png"
)
const DEFLATE_FRONT := preload("res://assets/sprites/bosses/blubberbeard/deflate_front.png")
const DEFLATE_SIDE := preload("res://assets/sprites/bosses/blubberbeard/deflate_side.png")
const DEFLATE_BACK := preload("res://assets/sprites/bosses/blubberbeard/deflate_back.png")

const CELL_SIZE := 400.0
# Offset in pixels from cell center to the hoisted barrel in attacks frame (1, 0).
const BARREL_HAND_OFFSET_PX := Vector2(106.5, 115.5)
const THROW_RELEASE_PROGRESS := 0.35
const CHARGE_RECOVERY_ANIMATION_TIME := 0.3
const HURT_DURATION := 0.65
const HURT_FLASH_DURATION := 0.22

@export_range(1.0, 24.0, 0.5) var idle_fps: float = 5.0
@export_range(1.0, 24.0, 0.5) var move_fps: float = 7.5
@export_range(1.0, 30.0, 0.5) var charge_fps: float = 14.0

var pose: Pose = Pose.IDLE
var clip: Clip = Clip.IDLE
var moving: bool = false:
	set(value):
		if moving == value:
			return
		moving = value
		if pose == Pose.IDLE and _burst_left <= 0.0 and not _dying:
			_set_clip(Clip.MOVE if moving else Clip.IDLE)
			_update_active_frame()
var windup_progress: float = 0.0:
	set(value):
		windup_progress = value
		if pose == Pose.WINDUP and not _dying:
			if _kind == BlubberbeardSkillData.Kind.POWDER_BARREL and windup_progress >= 0.96:
				if clip == Clip.BARREL_THROW:
					_set_clip(Clip.MOVE if moving else Clip.IDLE)
			_update_active_frame()
var enraged: bool = false
var _kind: int = 0
var _clock: float = 0.0
var _clip_time: float = 0.0
var _hit_flash: float = 0.0
var _hit_clip_left: float = 0.0
var _hit_clip_duration: float = HURT_DURATION
var _evade_clip_left: float = 0.0
var _evade_clip_duration: float = 0.0
var _burst_left: float = 0.0
var _facing: Vector3 = Vector3.BACK
var _lean: float = 1.0
var _rest_position: Vector3
var _rest_scale: Vector3
var _rest_pixel_size: float
var _dying: bool = false
var _death_time: float = 0.0
var _impact_left: float = 0.0
var _impact_duration: float = 0.0
var _impact_power: float = 0.0


func _ready() -> void:
	_rest_position = position
	_rest_scale = scale
	_rest_pixel_size = pixel_size
	_apply_clip_frame(Clip.IDLE, 0.0)


func _process(delta: float) -> void:
	if _dying:
		_death_time += maxf(0.0, delta)
		_apply_clip_frame(Clip.DEATH, _death_time)
		return
	var owner_boss := get_parent() as BossBase
	var hitstop := get_node_or_null("/root/HitstopController")
	if hitstop != null and hitstop.is_frozen(owner_boss):
		return
	var step := maxf(0.0, delta)
	_clock += step
	_clip_time += step
	_hit_flash = maxf(0.0, _hit_flash - step)
	_hit_clip_left = maxf(0.0, _hit_clip_left - step)
	var was_evading := _evade_clip_left > 0.0
	_evade_clip_left = maxf(0.0, _evade_clip_left - step)
	if was_evading and _evade_clip_left <= 0.0:
		position = _rest_position
		rotation.z = 0.0
	_impact_left = maxf(0.0, _impact_left - step)
	if pose == Pose.RECOVERY and _clip_time >= CHARGE_RECOVERY_ANIMATION_TIME:
		pose = Pose.IDLE
		_set_clip(Clip.MOVE if moving else Clip.IDLE)
	if _burst_left > 0.0:
		_burst_left = maxf(0.0, _burst_left - step)
		if _burst_left <= 0.0 and pose == Pose.IDLE:
			_set_clip(Clip.MOVE if moving else Clip.IDLE)
	if pose == Pose.IDLE and _burst_left <= 0.0:
		var wanted := Clip.MOVE if moving else Clip.IDLE
		if clip != wanted:
			_set_clip(wanted)
	elif pose == Pose.WINDUP and _kind == BlubberbeardSkillData.Kind.POWDER_BARREL:
		if windup_progress >= 0.96 and clip == Clip.BARREL_THROW:
			_set_clip(Clip.MOVE if moving else Clip.IDLE)

	var size := 1.1 if enraged else 1.0
	var breathing := sin(_clock * (5.0 if enraged else 3.0)) * 0.02
	var desired_scale := _rest_scale * size * Vector3(1.0 + breathing, 1.0 - breathing, 1.0)
	var desired_position := _rest_position
	desired_position.y += _rest_position.y * (size - 1.0)
	var desired_rotation := 0.0
	match pose:
		Pose.WINDUP:
			var anticipation := sin(windup_progress * PI * 0.5)
			desired_scale *= Vector3(1.0 + 0.08 * anticipation, 1.0 - 0.07 * anticipation, 1.0)
			desired_rotation = -0.06 * anticipation * _lean
			if _kind != BlubberbeardSkillData.Kind.POWDER_BARREL or windup_progress < THROW_RELEASE_PROGRESS:
				desired_position.x += sin(_clock * 32.0) * 0.05 * anticipation
		Pose.CHARGE:
			desired_scale *= Vector3(1.06, 0.94, 1.0)
			desired_rotation = 0.1 * _lean
			desired_position.y += sin(_clock * 20.0) * 0.05
		Pose.RECOVERY:
			desired_scale *= Vector3(1.05, 0.94, 1.0)
			desired_rotation = -0.06 * _lean
	if _impact_left > 0.0 and _impact_duration > 0.0:
		var weight := _impact_left / _impact_duration
		desired_scale *= Vector3(1.0 + _impact_power * weight, 1.0 - _impact_power * weight, 1.0)
		desired_rotation += sin(_clock * 40.0) * _impact_power * 0.7 * weight
	var blend := 1.0 - exp(-12.0 * step)
	scale = scale.lerp(desired_scale, blend)
	position = position.lerp(desired_position, blend)
	rotation.z = lerp_angle(rotation.z, desired_rotation, blend)
	var flash_weight := _hit_flash / HURT_FLASH_DURATION
	modulate = _phase_color().lerp(Color(2.0, 1.65, 1.55), flash_weight)
	_update_active_frame()


func begin_windup(kind: int) -> void:
	_kind = kind
	windup_progress = 0.0
	_burst_left = 0.0
	pose = Pose.WINDUP
	match kind:
		BlubberbeardSkillData.Kind.POWDER_BARREL:
			_set_clip(Clip.BARREL_THROW)
		BlubberbeardSkillData.Kind.BELLY_CHARGE:
			_set_clip(Clip.BELLY_CHARGE_WINDUP)
		BlubberbeardSkillData.Kind.SPIKY_INFLATION:
			_set_clip(Clip.INFLATE_WINDUP)
		_:
			_set_clip(Clip.IDLE)
	_update_active_frame()


func begin_charge(direction: Vector3) -> void:
	face_direction(direction)
	pose = Pose.CHARGE
	_burst_left = 0.0
	_set_clip(Clip.BELLY_CHARGE)
	_update_active_frame()


func begin_spike_burst() -> void:
	pose = Pose.IDLE
	_burst_left = 0.45
	_set_clip(Clip.INFLATE_BURST)
	_update_active_frame()


func face_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not flat.is_zero_approx():
		_facing = flat.normalized()
	_lean = -1.0 if _get_screen_direction().x < 0.0 else 1.0
	_update_active_frame()


func begin_recovery(kind: int) -> void:
	if kind == BlubberbeardSkillData.Kind.BELLY_CHARGE:
		pose = Pose.RECOVERY
		_set_clip(Clip.BELLY_CHARGE_RECOVERY)
	elif kind == BlubberbeardSkillData.Kind.SPIKY_INFLATION:
		begin_spike_burst()
	else:
		pose = Pose.IDLE
		_set_clip(Clip.MOVE if moving else Clip.IDLE)
	_update_active_frame()


func set_enraged(value: bool) -> void:
	enraged = value
	if pose == Pose.IDLE and _burst_left <= 0.0:
		_set_clip(Clip.MOVE if moving else Clip.IDLE)


func flash_hit() -> void:
	_hit_flash = HURT_FLASH_DURATION
	impact(0.16, 0.35)
	_hit_clip_duration = HURT_FLASH_DURATION if pose in [Pose.WINDUP, Pose.CHARGE] else HURT_DURATION
	_hit_clip_left = _hit_clip_duration
	_update_active_frame()


func begin_deflate_evade(duration: float) -> void:
	_evade_clip_duration = maxf(duration, 0.01)
	_evade_clip_left = _evade_clip_duration
	_hit_clip_left = 0.0
	_update_active_frame()


func impact(power: float, duration: float) -> void:
	_impact_power = clampf(power, 0.0, 0.5)
	_impact_duration = maxf(duration, 0.01)
	_impact_left = _impact_duration


func play_death(finished: Callable) -> void:
	_dying = true
	_death_time = 0.0
	_hit_flash = 0.0
	_hit_clip_left = 0.0
	_evade_clip_left = 0.0
	pixel_size = _rest_pixel_size
	_apply_clip_frame(Clip.DEATH, 0.0)
	var tween := create_tween()
	tween.tween_interval(0.95)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tween.tween_callback(finished)


func get_barrel_release_world_position() -> Vector3:
	var dir_x := -1.0 if flip_h else 1.0
	var local_offset := Vector3(
		BARREL_HAND_OFFSET_PX.x * dir_x * pixel_size,
		BARREL_HAND_OFFSET_PX.y * pixel_size,
		0.0
	)
	return to_global(local_offset)


func _set_clip(next_clip: Clip) -> void:
	if clip == next_clip:
		return
	clip = next_clip
	_clip_time = 0.0


func _update_active_frame() -> void:
	if _evade_clip_left > 0.0:
		var row := _resolve_facing_row(Clip.IDLE)
		var sheet: Texture2D = [DEFLATE_FRONT, DEFLATE_SIDE, DEFLATE_BACK][row]
		_set_sheet(sheet, 4, 2)
		pixel_size = _rest_pixel_size * 400.0 / (float(sheet.get_width()) / 4.0)
		var progress := 1.0 - _evade_clip_left / _evade_clip_duration
		if progress < 0.158:
			frame = mini(3, int(progress / 0.158 * 4.0))
		elif progress < 0.816:
			frame = 4
		else:
			frame = mini(7, 5 + int((progress - 0.816) / 0.184 * 3.0))
		return
	pixel_size = _rest_pixel_size
	if _hit_clip_left > 0.0:
		var hit_progress := 1.0 - _hit_clip_left / _hit_clip_duration
		_apply_clip_frame(Clip.HIT, hit_progress * HURT_DURATION)
		return
	_apply_clip_frame(clip, _clip_time)


func _apply_clip_frame(active_clip: Clip, time_in_clip: float) -> void:
	var dir_row := _resolve_facing_row(active_clip)
	match active_clip:
		Clip.IDLE:
			_set_sheet(IDLE_4DIR_SHEET, 4, 3)
			frame = dir_row * 4 + (int(time_in_clip * idle_fps) % 4)
		Clip.MOVE:
			_set_sheet(MOVE_4DIR_SHEET, 4, 3)
			frame = dir_row * 4 + (int(time_in_clip * move_fps) % 4)
		Clip.BARREL_THROW:
			_set_sheet(ATTACKS_SHEET, 4, 3)
			if windup_progress < 0.16:
				frame = 0
			elif windup_progress < THROW_RELEASE_PROGRESS:
				frame = 1
			elif windup_progress < 0.58:
				frame = 2
			else:
				frame = 3
		Clip.BELLY_CHARGE_WINDUP:
			_set_sheet(CHARGE_PREP_4DIR_SHEET, 4, 3)
			var windup_col := 0 if windup_progress < 0.5 else 1
			frame = dir_row * 4 + windup_col
		Clip.BELLY_CHARGE:
			match dir_row:
				FacingDir.SIDE:
					_set_sheet(CHARGE_RUN_SIDE_SHEET, 4, 2)
				FacingDir.UP:
					_set_sheet(CHARGE_RUN_UP_SHEET, 4, 2)
				_:
					_set_sheet(CHARGE_RUN_DOWN_SHEET, 4, 2)
			frame = int(time_in_clip * charge_fps) % 8
		Clip.BELLY_CHARGE_RECOVERY:
			_set_sheet(CHARGE_PREP_4DIR_SHEET, 4, 3)
			frame = dir_row * 4 + (2 if time_in_clip < 0.12 else 3)
		Clip.INFLATE_WINDUP:
			_set_sheet(INFLATE_4DIR_SHEET, 4, 3)
			var col := 0
			if windup_progress >= 0.90:
				col = 2
			elif windup_progress >= 0.45:
				col = 1
			frame = dir_row * 4 + col
		Clip.INFLATE_BURST:
			_set_sheet(INFLATE_4DIR_SHEET, 4, 3)
			frame = dir_row * 4 + (2 if time_in_clip < 0.22 else 3)
		Clip.HIT:
			_set_sheet(HIT_DEATH_SHEET, 4, 2)
			frame = mini(3, int(time_in_clip / HURT_DURATION * 4.0))
		Clip.DEATH:
			_set_sheet(HIT_DEATH_SHEET, 4, 2)
			frame = 4 + mini(3, int(time_in_clip / 0.85 * 4.0))


func _resolve_facing_row(active_clip: Clip) -> int:
	var screen_dir := _get_screen_direction()
	_lean = -1.0 if screen_dir.x < 0.0 else 1.0
	if active_clip in [Clip.BARREL_THROW, Clip.HIT, Clip.DEATH]:
		flip_h = screen_dir.x < -0.05
		return FacingDir.DOWN
	if absf(screen_dir.x) > absf(screen_dir.z):
		flip_h = screen_dir.x < 0.0
		return FacingDir.SIDE
	flip_h = false
	if screen_dir.z < 0.0:
		return FacingDir.UP
	return FacingDir.DOWN


func _get_screen_direction() -> Vector3:
	if not is_inside_tree():
		return _facing
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if not is_instance_valid(camera):
		return _facing
	var camera_right: Vector3 = camera.global_basis.x
	var camera_back: Vector3 = camera.global_basis.z
	camera_right.y = 0.0
	camera_back.y = 0.0
	if camera_right.is_zero_approx() or camera_back.is_zero_approx():
		return _facing
	return Vector3(
		_facing.dot(camera_right.normalized()),
		0.0,
		_facing.dot(camera_back.normalized())
	)


func _set_sheet(sheet: Texture2D, cols: int, rows: int) -> void:
	if texture != sheet:
		texture = sheet
	if hframes != cols:
		hframes = cols
	if vframes != rows:
		vframes = rows


func _phase_color() -> Color:
	return Color(1.0, 0.72, 0.65) if enraged else Color.WHITE
