extends CanvasLayer
## Owns the pause, camera and unlock transaction. All timings are real seconds.

enum Phase { REVEAL, WAITING, ABSORB, RETURN }

const CONFIRM_KEY := KEY_SPACE
const CONFIRM_KEY_TEXT := "SPACE"
const CONFIRM_PROMPT := "to take the plan"
const FORGE_HINT := "Bring the materials to Master Tortuga to forge it."
const EYEBROW_TEXT := "Weapon Blueprint"
const RECIPE_CHIP := "Forge recipe"
const FALLBACK_DESCRIPTION := "A new weapon design, drawn but not yet forged."
const MUSIC_BUS := &"Music"
const MUSIC_DUCK_DB := 8.0
const PLAYER_FOCUS_OFFSET := Vector3.UP
const UI_FADE_SECONDS := 0.25
const SHAKE_FREQUENCY := Vector2(61.0, 47.0)
const RESTING_ICON_SCALE := 0.92
const CLOSED_PAPER_WIDTH := 0.12
const START_ICON_SCALE := 0.35
const FLIGHT_ARC_PIXELS := 65.0
const IDLE_BOB_PIXELS := 4.0
const IDLE_BOB_SPEED := 2.0
const HIGH_TARGET_Y_RANGE := Vector2(0.34, 0.38)
const HEADER_REVEAL_FRACTION := 0.70
const ROLL_FRACTION := 0.25
const ABSORB_FADE_FRACTION := 0.80
const MICROSECONDS_PER_SECOND := 1000000.0
const PAPER_SWAY_DEGREES := 3.0
const SHEET_OPEN_FRACTION := 0.8
const SHEET_FADE_FRACTION := 0.35
const STAMP_START_FRACTION := 0.8
const STAMP_START_SCALE := 2.4
const STAMP_OFFSET_PIXELS := Vector2(26.0, 90.0)
const STAMP_ROTATION_DEGREES := -8.0
const STAMP_SHAKE_SECONDS := 0.2
const STAMP_FADE_IN_FRACTION := 0.5
const CARD_START_SCALE := 0.94

@export_group("Timeline")
@export_range(0.1, 2.0, 0.05) var focus_seconds := 0.7
@export_range(0.1, 3.0, 0.05) var lift_seconds := 1.3
@export_range(0.1, 3.0, 0.05) var reveal_seconds := 1.0
@export_range(0.1, 3.0, 0.05) var absorb_seconds := 0.8
@export_range(0.1, 3.0, 0.05) var impact_seconds := 0.7
@export_range(0.1, 3.0, 0.05) var return_seconds := 1.3
@export_group("Framing")
@export_range(0.5, 1.0, 0.01) var zoom_ratio := 0.83
@export_range(0.1, 0.4, 0.01) var elevation_viewport_ratio := 0.20
@export_range(80.0, 300.0, 1.0) var icon_size_pixels := 164.0
@export_range(0.0, 0.1, 0.001) var impact_shake_units := 0.035
@export_group("Stamp")
@export_range(0.05, 1.0, 0.01, "suffix:s") var stamp_slam_seconds := 0.22
@export_range(0.0, 0.05, 0.001) var stamp_shake_units := 0.012
@export_group("Shockwave")
@export_range(0.1, 2.0, 0.05) var shockwave_seconds := 0.55
@export_range(0.0, 0.08, 0.001) var shockwave_strength := 0.012
@export_range(20.0, 600.0, 1.0) var shockwave_radius_pixels := 230.0

var _phase := Phase.REVEAL
var _elapsed := 0.0
var _clock := 0.0
var _pickup: ItemPickup
var _player: Player
var _camera: Camera3D
var _weapon: WeaponData
var _origin_world := Vector3.ZERO
var _base_position := Vector3.ZERO
var _focus_position := Vector3.ZERO
var _base_zoom := 0.0
var _base_offsets := Vector2.ZERO
var _music_index := -1
var _music_volume := 0.0
var _previous_pause := false
var _started := false
var _finished := false
var _committed := false
var _animator: AnimationPlayer
var _animator_mode := Node.PROCESS_MODE_INHERIT
var _animator_callback := AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
var _spine: Node
var _spine_mode := Node.PROCESS_MODE_INHERIT
var _last_usec := 0
var _revealed := false
var _stamped := false

@onready var _veil: ColorRect = $Veil
@onready var _effects: Control = $Effects
@onready var _sheet: Control = $Sheet
@onready var _icon: TextureRect = $Icon
@onready var _stamp: Control = $Stamp
@onready var _heading: Control = $UI/Heading
@onready var _card: RewardCard = $UI/Card
@onready var _discovery_sound: AudioStreamPlayer = $DiscoverySound
@onready var _reveal_sound: AudioStreamPlayer = $RevealSound
@onready var _receive_sound: AudioStreamPlayer = $ReceiveSound
@onready var _stamp_sound: AudioStreamPlayer = $StampSound


func _ready() -> void:
	_heading.modulate.a = 0.0
	_card.modulate.a = 0.0
	_stamp.modulate.a = 0.0
	_icon.modulate.a = 0.0
	set_process(false)


func _process(_delta: float) -> void:
	if not _dependencies_valid():
		_finish()
		return
	var now := Time.get_ticks_usec()
	var seconds := (now - _last_usec) / MICROSECONDS_PER_SECOND
	_last_usec = now
	_elapsed += seconds
	_clock += seconds
	if is_instance_valid(_animator):
		_animator.advance(seconds)
	_update_phase()
	if not _finished:
		_update_presentation()


func _input(event: InputEvent) -> void:
	if not _started or _finished:
		return
	# Consume Space before gameplay/menu input; holding it cannot skip the reveal.
	if event is InputEventKey and _phase == Phase.WAITING:
		if event.pressed and not event.echo and event.keycode == CONFIRM_KEY:
			_phase = Phase.ABSORB
			_elapsed = 0.0
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_finish()


func begin(source: ItemPickup, actor: Player) -> void:
	_pickup = source
	_player = actor
	_weapon = source.item.weapon_blueprint
	_camera = actor.camera if is_instance_valid(actor.camera) else get_viewport().get_camera_3d()
	if not _dependencies_valid():
		_finish()
		return
	_previous_pause = get_tree().paused
	_origin_world = source.sprite.global_position
	_base_position = _camera.global_position
	_base_zoom = (
		_camera.size if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL else _camera.fov
	)
	_base_offsets = Vector2(_camera.h_offset, _camera.v_offset)
	var local_target := _camera.to_local(actor.global_position + PLAYER_FOCUS_OFFSET)
	_focus_position = (
		_base_position
		+ _camera.global_basis.x * local_target.x
		+ _camera.global_basis.y * local_target.y
	)
	_icon.texture = source.item.icon
	_fill_card()
	_player.clear_gameplay_input()
	_prepare_idle()
	source.sprite.hide()
	_music_index = AudioServer.get_bus_index(MUSIC_BUS)
	if _music_index >= 0:
		_music_volume = AudioServer.get_bus_volume_db(_music_index)
	_pickup.tree_exiting.connect(_finish, CONNECT_ONE_SHOT)
	_player.tree_exiting.connect(_finish, CONNECT_ONE_SHOT)
	_started = true
	get_tree().paused = true
	_last_usec = Time.get_ticks_usec()
	set_process(true)
	_discovery_sound.play()
	_update_presentation()


func _dependencies_valid() -> bool:
	return (
		is_instance_valid(_player)
		and not _player.is_queued_for_deletion()
		and is_instance_valid(_pickup)
		and not _pickup.is_queued_for_deletion()
		and is_instance_valid(_camera)
		and is_instance_valid(_player.weapon_controller)
		and _weapon != null
		and _player.weapon_controller.has_weapon_definition(_weapon.weapon_id)
	)


func _prepare_idle() -> void:
	var visual := _player.get_node_or_null("Visual") as PlayerVisual
	if visual == null or not is_instance_valid(visual.animation_player):
		return
	_animator = visual.animation_player
	_animator_mode = _animator.process_mode
	_animator_callback = _animator.callback_mode_process
	_animator.process_mode = Node.PROCESS_MODE_ALWAYS
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_spine = visual.get_node_or_null("SpineIdlePreview")
	if is_instance_valid(_spine):
		_spine_mode = _spine.process_mode
		_spine.process_mode = Node.PROCESS_MODE_ALWAYS
	visual.play_cinematic_idle_down(_camera)


func _update_phase() -> void:
	match _phase:
		Phase.REVEAL:
			if not _revealed and _elapsed >= focus_seconds + lift_seconds:
				_revealed = true
				_reveal_sound.play()
			if _elapsed >= focus_seconds + lift_seconds + reveal_seconds:
				_phase = Phase.WAITING
				_elapsed = 0.0
		Phase.ABSORB:
			if _elapsed >= absorb_seconds:
				_committed = _player.weapon_controller.set_blueprint_unlocked(
					_weapon.weapon_id, true
				)
				if not _committed:
					_finish()
					return
				_phase = Phase.RETURN
				_elapsed = 0.0
				_receive_sound.play()
				get_node("/root/ShockwaveController").request_world(
					_player.global_position + PLAYER_FOCUS_OFFSET,
					shockwave_seconds,
					shockwave_strength,
					_effects.gold_color,
					shockwave_radius_pixels
				)
		Phase.RETURN:
			if _elapsed >= impact_seconds + return_seconds:
				_finish()


func _update_presentation() -> void:
	var focus := smoothstep(0.0, focus_seconds, _clock)
	if _phase == Phase.RETURN:
		focus *= 1.0 - smoothstep(impact_seconds, impact_seconds + return_seconds, _elapsed)
	_camera.global_position = _base_position.lerp(_focus_position, focus)
	var zoom := lerpf(_base_zoom, _base_zoom * zoom_ratio, focus)
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = zoom
	else:
		_camera.fov = zoom
	var shake := 0.0
	if _phase == Phase.RETURN:
		shake = impact_shake_units * (1.0 - smoothstep(0.0, impact_seconds, _elapsed))
	elif _stamp_since() >= 0.0 and _stamp_since() < STAMP_SHAKE_SECONDS:
		shake = stamp_shake_units * (1.0 - _stamp_since() / STAMP_SHAKE_SECONDS)
	_camera.h_offset = _base_offsets.x + sin(_clock * SHAKE_FREQUENCY.x) * shake
	_camera.v_offset = _base_offsets.y + cos(_clock * SHAKE_FREQUENCY.y) * shake
	if _music_index >= 0:
		AudioServer.set_bus_volume_db(_music_index, _music_volume - MUSIC_DUCK_DB * focus)
	(_veil.material as ShaderMaterial).set_shader_parameter("strength", focus)
	var viewport_size := get_viewport().get_visible_rect().size
	var destination := _camera.unproject_position(_player.global_position + PLAYER_FOCUS_OFFSET)
	var high := Vector2(
		destination.x,
		clampf(
			destination.y - viewport_size.y * elevation_viewport_ratio,
			viewport_size.y * HIGH_TARGET_Y_RANGE.x,
			viewport_size.y * HIGH_TARGET_Y_RANGE.y
		)
	)
	var rise := smoothstep(focus_seconds, focus_seconds + lift_seconds, _clock)
	var reveal := smoothstep(
		focus_seconds + lift_seconds, focus_seconds + lift_seconds + reveal_seconds, _clock
	)
	var center := _camera.unproject_position(_origin_world).lerp(high, rise)
	center.y += sin(_clock * IDLE_BOB_SPEED) * IDLE_BOB_PIXELS * rise
	var flight := 0.0
	var fold := 0.0
	var alpha := 1.0
	if _phase == Phase.ABSORB:
		fold = smoothstep(0.0, absorb_seconds * ROLL_FRACTION, _elapsed)
		flight = smoothstep(absorb_seconds * ROLL_FRACTION, absorb_seconds, _elapsed)
		center = high.lerp(destination, flight)
		center.y -= sin(flight * PI) * FLIGHT_ARC_PIXELS
		alpha = 1.0 - smoothstep(ABSORB_FADE_FRACTION, 1.0, flight)
	elif _phase == Phase.RETURN:
		alpha = 0.0
	var icon_scale := lerpf(START_ICON_SCALE, RESTING_ICON_SCALE, rise)
	icon_scale *= 1.0 + sin(reveal * PI) * (1.0 - RESTING_ICON_SCALE)
	_icon.size = Vector2.ONE * icon_size_pixels
	_icon.pivot_offset = _icon.size / 2.0
	_icon.position = center - _icon.pivot_offset
	_icon.scale = Vector2(icon_scale * lerpf(1.0, CLOSED_PAPER_WIDTH, fold), icon_scale)
	_icon.rotation = (
		sin(_clock * IDLE_BOB_SPEED) * deg_to_rad(PAPER_SWAY_DEGREES) * (1.0 - flight)
	)
	_icon.modulate.a = alpha * smoothstep(0.0, focus_seconds, _clock)
	var icon_material := _icon.material as ShaderMaterial
	icon_material.set_shader_parameter("unfold", reveal)
	icon_material.set_shader_parameter("sweep", reveal)
	var text_alpha := smoothstep(HEADER_REVEAL_FRACTION, 1.0, reveal)
	if _phase == Phase.ABSORB:
		text_alpha *= 1.0 - smoothstep(0.0, UI_FADE_SECONDS, _elapsed)
	elif _phase == Phase.RETURN:
		text_alpha = 0.0
	_heading.modulate.a = text_alpha
	_card.modulate.a = text_alpha
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * lerpf(CARD_START_SCALE, 1.0, text_alpha)
	_card.pulse_prompt(_clock)
	var camera_alpha := alpha * smoothstep(0.0, focus_seconds, _clock)
	var sheet_alpha := camera_alpha
	if _phase == Phase.ABSORB:
		sheet_alpha *= 1.0 - smoothstep(0.0, absorb_seconds * SHEET_FADE_FRACTION, _elapsed)
	var stamp_point := center + STAMP_OFFSET_PIXELS
	_sheet.present(
		center,
		smoothstep(0.0, SHEET_OPEN_FRACTION, reveal) * (1.0 - fold),
		sheet_alpha,
		_clock,
		stamp_point,
		_stamp_since()
	)
	_update_stamp(stamp_point, sheet_alpha)
	_effects.present(
		center,
		destination,
		high,
		_clock,
		reveal,
		camera_alpha,
		flight,
		_elapsed if _phase == Phase.RETURN else -1.0
	)


func _stamp_landing_seconds() -> float:
	return focus_seconds + lift_seconds + reveal_seconds * STAMP_START_FRACTION + stamp_slam_seconds


## Seconds since the stamp landed on the sheet; negative while it is still in the air.
func _stamp_since() -> float:
	return _clock - _stamp_landing_seconds()


## The stamp slams down late in the reveal, which marks this paper as a plan, not a weapon.
func _update_stamp(point: Vector2, sheet_alpha: float) -> void:
	var slam := clampf((_stamp_since() + stamp_slam_seconds) / stamp_slam_seconds, 0.0, 1.0)
	_stamp.pivot_offset = _stamp.size / 2.0
	_stamp.position = point - _stamp.pivot_offset
	_stamp.scale = Vector2.ONE * lerpf(STAMP_START_SCALE, 1.0, slam * slam)
	_stamp.rotation = deg_to_rad(STAMP_ROTATION_DEGREES)
	_stamp.modulate.a = sheet_alpha * smoothstep(0.0, STAMP_FADE_IN_FRACTION, slam)
	if not _stamped and _stamp_since() >= 0.0 and _phase != Phase.RETURN:
		_stamped = true
		_stamp_sound.play()


func _fill_card() -> void:
	var chips := PackedStringArray([_category_name(), RECIPE_CHIP])
	var body := _weapon.description if not _weapon.description.is_empty() else FALLBACK_DESCRIPTION
	_card.setup(EYEBROW_TEXT, _weapon.display_name, body, FORGE_HINT, chips, _effects.gold_color)
	_card.set_prompt(CONFIRM_KEY_TEXT, CONFIRM_PROMPT)


func _category_name() -> String:
	return String(WeaponData.WeaponCategory.keys()[_weapon.category]).capitalize()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	if _started:
		if is_instance_valid(_camera):
			_camera.global_position = _base_position
			_camera.h_offset = _base_offsets.x
			_camera.v_offset = _base_offsets.y
			if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
				_camera.size = _base_zoom
			else:
				_camera.fov = _base_zoom
		if _music_index >= 0:
			AudioServer.set_bus_volume_db(_music_index, _music_volume)
		if is_instance_valid(_animator):
			_animator.process_mode = _animator_mode
			_animator.callback_mode_process = _animator_callback
		if is_instance_valid(_spine):
			_spine.process_mode = _spine_mode
		if is_instance_valid(_player):
			_player.clear_gameplay_input()
		get_tree().paused = _previous_pause
	if is_instance_valid(_pickup) and not _pickup.is_queued_for_deletion():
		_pickup.finish_blueprint_presentation(_committed)
	if not is_queued_for_deletion():
		queue_free()
