extends CanvasLayer
## Charm reveal: a sigil wakes under the pickup, the Charm rises, names itself and waits for
## the player, then pours its energy into Foxy. Runs in real seconds while the tree is paused.

enum Phase { INTRO, WAITING, OUTRO }

const CONFIRM_KEY := KEY_SPACE
const CONFIRM_PROMPT := "to absorb"
const CONFIRM_KEY_PREFIX := "SPACE"
const EQUIP_HINT := "Equip it from the Charms tab of your Inventory."
const MIN_TIME_SCALE := 0.01
const TIME_EPSILON := 0.0001
const MUSIC_BUS := &"Music"
const PLAYER_FOCUS_OFFSET := Vector3.UP
const GENERIC_ACCENT := Color("77e5e9")
const ACTIVE_ACCENT := Color("ffb45f")
const PASSIVE_ACCENT := Color("56e8bd")
const ACCENT_BY_CHARM := {
	&"life_steal": Color("ed7f92"),
	&"backstabber": Color("ed7f92"),
	&"shadow_lunge": Color("ed7f92"),
	&"gale_pace": Color("a5efc4"),
	&"arrow_rain": Color("a5efc4"),
	&"chaos_collector": Color("ffc97e"),
	&"buckshot_salvo": Color("ffc97e"),
	&"crescent_cleave": Color("ffc97e"),
}
const VEIL_BASE_COLOR := Color(0.008, 0.025, 0.065)
const VEIL_ACCENT_MIX := 0.1

# Intro layout, as fractions of intro_seconds.
const RISE_START_FRACTION := 0.18
const AWAKEN_FRACTION := 0.62
const TEXT_START_FRACTION := 0.66
const TEXT_FULL_FRACTION := 0.86
const SIGIL_FULL_FRACTION := 0.3
const CAMERA_FOCUS_SECONDS := 0.8
const OUTRO_TEXT_FADE_SECONDS := 0.35
const ICON_START_SCALE := 0.5
const ICON_PUNCH_SCALE := 0.2
const ICON_PUNCH_FRACTION := 0.12
const ICON_GATHER_SCALE := 0.7
const ICON_LANDING_SCALE := 0.45
const ICON_PULSE_AMOUNT := 0.05
const ICON_PULSE_SPEED := 4.0
const ICON_BOB_PIXELS := 5.0
const ICON_BOB_SPEED := 2.2
const ICON_TREMBLE_PIXELS := 1.6
const ICON_FADE_FRACTION := 0.14
const FLIGHT_ARC_PIXELS := 80.0
const HIGH_TARGET_OFFSET_MAX_PIXELS := 200.0
const HIGH_TARGET_OFFSET_RATIO := 0.26
const HIGH_TARGET_Y_RANGE := Vector2(0.3, 0.5)
const GROUND_OFFSET_PIXELS := 18.0
const SIGIL_FLATTENING := 0.4
const SIGIL_GLYPH_COUNT := 12
const SIGIL_GLYPH_SIZE_PIXELS := 7.0
const MIN_GLYPH_SIZE_PIXELS := 0.5
const SIGIL_SPIN_SPEED := 0.35
const SIGIL_ALPHA := 0.7
const COLUMN_WIDTH_PIXELS := 34.0
const COLUMN_ALPHA := 0.32
const AWAKEN_RING_SECONDS := 0.6
const AWAKEN_RING_GROWTH := 1.9
const RUNE_RING_SPIN_SPEED := 0.28
const RUNE_RING_ALPHA := 0.6
const GLOW_LAYERS := 5
const GLOW_BASE_RADIUS_PIXELS := 22.0
const GLOW_LAYER_STEP_PIXELS := 13.0
const GLOW_LAYER_ALPHA := 0.03
const STREAM_COUNT := 4
const STREAM_SEGMENTS := 48
const STREAM_ARC_RADIANS := 1.65
const STREAM_RADIUS_PIXELS := 84.0
const STREAM_CONTRACT_RATIO := 0.4
const STREAM_GATHER_SPIN := 2.0
const MOTE_COUNT := 22
const MOTE_RISE_PIXELS := 90.0
const MOTE_SPEED := 0.22
const PHYLLOTAXIS_ANGLE := 2.399963
const AURA_HEIGHT_PIXELS := 190.0
const AURA_WIDTH_PIXELS := 62.0
const AURA_ALPHA := 0.5
const AURA_RING_COUNT := 2
const AURA_RING_SPEED_PIXELS := 150.0
const AURA_MOTE_COUNT := 18
const BURST_DOT_COUNT := 36
const IMPACT_RING_SPEED_PIXELS := 265.0
const IMPACT_RING_DURATION := 1.15
const IMPACT_RING_WIDTH_PIXELS := 8.0
const IMPACT_RING_SEGMENTS := 96
const IMPACT_GLOW_LAYERS := 5
const IMPACT_FLASH_RADIUS_PIXELS := 74.0
const FLIGHT_TRAIL_SPREAD_PIXELS := 22.0
const FLIGHT_TRAIL_LAG := 0.3
const FLIGHT_TRAIL_WAVE := 1.5
const FLIGHT_HEAD_FLARE_PIXELS := 8.0
const RIBBON_MIN_SEGMENT_PIXELS := 0.3
const RIBBON_TAPER_EXPONENT := 0.8
const SHAKE_FREQUENCY := Vector2(61.0, 47.0)
const REVEAL_SHAKE_SECONDS := 0.3

@export_group("Timeline")
@export_range(1.0, 6.0, 0.05, "suffix:s") var intro_seconds := 2.72
@export_range(0.1, 2.0, 0.05, "suffix:s") var gather_seconds := 0.6
@export_range(0.2, 2.0, 0.05, "suffix:s") var flight_seconds := 1.0
@export_range(0.2, 2.0, 0.05, "suffix:s") var impact_seconds := 0.8
@export_range(0.2, 3.0, 0.05, "suffix:s") var release_seconds := 1.2
@export_group("Framing")
@export_range(0.5, 1.0, 0.01) var zoom_ratio := 0.77
@export_range(60.0, 240.0, 1.0, "suffix:px") var icon_size_pixels := 136.0
@export_range(40.0, 200.0, 1.0, "suffix:px") var sigil_radius_pixels := 112.0
@export_range(0.0, 0.1, 0.001) var reveal_shake_units := 0.02
@export_range(0.0, 0.15, 0.001) var impact_shake_units := 0.06
@export_group("Absorb")
@export_range(0.1, 2.0, 0.05, "suffix:s") var shockwave_seconds := 0.9
@export_range(0.0, 0.12, 0.001) var shockwave_strength := 0.06
@export_range(0.0, 16.0, 0.5, "suffix:dB") var music_duck_db := 8.0

var pickup: ItemPickup
var player: Player
var camera: Camera3D
var charm: CharmData
var phase := Phase.INTRO
var elapsed := 0.0
var clock := 0.0
var committed := false
var base_zoom := 0.0
var base_position := Vector3.ZERO
var focus_position := Vector3.ZERO
var base_h := 0.0
var base_v := 0.0
var start_world := Vector3.ZERO
var _accent := GENERIC_ACCENT
var _surface: Control
var _icon_surface: Control
var _icon_center := Vector2.ZERO
var _icon_scale := 1.0
var _icon_alpha := 0.0
var _heading: Label
var _card: RewardCard
var _name_label: Label
var _vignette: ColorRect
var _music_index := -1
var _music_volume := 0.0
var _previous_pause := false
var _restored := false
var _revealed := false
var _pickup_lost := false
var _animator: AnimationPlayer
var _spine_preview: Node
var _animator_mode := Node.PROCESS_MODE_INHERIT
var _animator_callback := AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
var _spine_mode := Node.PROCESS_MODE_INHERIT

@onready var _awaken_sound: AudioStreamPlayer = $AwakenSound
@onready var _reveal_sound: AudioStreamPlayer = $RevealSound
@onready var _confirm_sound: AudioStreamPlayer = $ConfirmSound
@onready var _absorb_sound: AudioStreamPlayer = $AbsorbSound


func _process(delta: float) -> void:
	if not _dependencies_valid():
		_finish(false)
		return
	# Engine.time_scale (hitstop, slow motion) scales delta; the reveal runs on real time.
	var seconds := delta / maxf(Engine.time_scale, MIN_TIME_SCALE)
	if is_instance_valid(_animator):
		_animator.advance(seconds)
	clock += seconds
	elapsed += seconds
	if phase == Phase.INTRO and _reached(intro_seconds):
		phase = Phase.WAITING
		elapsed = 0.0
	if phase == Phase.OUTRO and not committed and _reached(gather_seconds + flight_seconds):
		if not _commit_ownership():
			_finish(false)
			return
	if phase == Phase.OUTRO and _reached(_outro_seconds()):
		_finish(true)
		return
	_update_camera()
	_update_ui()
	_surface.queue_redraw()
	_icon_surface.queue_redraw()


func _input(event: InputEvent) -> void:
	if _restored or not (event is InputEventKey or event is InputEventMouseButton):
		return
	# One confirmation path; every key and click is consumed so nothing reaches gameplay.
	_unhandled_input(event)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.WAITING or not event is InputEventKey:
		return
	var key := event as InputEventKey
	# Space held while the pickup was collected only produces echo events, never a press.
	if key.pressed and not key.echo and key.keycode == CONFIRM_KEY:
		phase = Phase.OUTRO
		elapsed = 0.0
		_confirm_sound.play()


func _exit_tree() -> void:
	if not _restored:
		_finish(false)


func begin(source: ItemPickup, actor: Player) -> void:
	pickup = source
	player = actor
	charm = pickup.item.charm
	camera = player.camera if is_instance_valid(player.camera) else get_viewport().get_camera_3d()
	start_world = pickup.sprite.global_position
	_accent = _resolve_accent()
	_previous_pause = get_tree().paused
	if is_instance_valid(camera):
		base_zoom = (
			camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else camera.fov
		)
		base_position = camera.global_position
		var local_target := camera.to_local(player.global_position + PLAYER_FOCUS_OFFSET)
		focus_position = (
			base_position
			+ camera.global_basis.x * local_target.x
			+ camera.global_basis.y * local_target.y
		)
		base_h = camera.h_offset
		base_v = camera.v_offset
	player.clear_gameplay_input()
	_prepare_player_idle()
	pickup.sprite.hide()
	pickup.tree_exiting.connect(_on_pickup_exiting, CONNECT_ONE_SHOT)
	player.tree_exiting.connect(_on_player_exiting, CONNECT_ONE_SHOT)
	_build_ui()
	_music_index = AudioServer.get_bus_index(MUSIC_BUS)
	if _music_index >= 0:
		_music_volume = AudioServer.get_bus_volume_db(_music_index)
	get_tree().paused = true
	_awaken_sound.play()


func _dependencies_valid() -> bool:
	return (
		is_instance_valid(player)
		and not player.is_queued_for_deletion()
		and is_instance_valid(pickup)
		and not pickup.is_queued_for_deletion()
		and charm != null
	)


func _prepare_player_idle() -> void:
	var visual := player.get_node_or_null("Visual") as PlayerVisual
	if visual == null or not is_instance_valid(visual.animation_player):
		return
	_animator = visual.animation_player
	_animator_mode = _animator.process_mode
	_animator_callback = _animator.callback_mode_process
	_spine_preview = visual.get_node_or_null("SpineIdlePreview")
	if is_instance_valid(_spine_preview):
		_spine_mode = _spine_preview.process_mode
		_spine_preview.process_mode = Node.PROCESS_MODE_ALWAYS
	_animator.process_mode = Node.PROCESS_MODE_ALWAYS
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	visual.play_cinematic_idle_down(camera)


func _build_ui() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	uniform float strength = 0.0;
	uniform vec3 tint = vec3(0.008, 0.025, 0.065);
	void fragment() {
		vec2 p = (UV - vec2(0.5)) * vec2(1.15, 1.0);
		float edge = smoothstep(0.12, 0.78, length(p));
		COLOR = vec4(tint, strength * (0.26 + edge * 0.70));
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", _veil_tint())
	_vignette.material = material
	add_child(_vignette)
	_surface = Control.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light_blend := CanvasItemMaterial.new()
	light_blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_surface.material = light_blend
	_surface.draw.connect(_draw_effects)
	add_child(_surface)
	_icon_surface = Control.new()
	_icon_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_surface.draw.connect(_draw_icon)
	add_child(_icon_surface)
	var ui := preload("res://gameplay/charms/progression/charm_unlock_ui.tscn").instantiate()
	add_child(ui)
	_heading = ui.get_node("%Heading") as Label
	_card = ui.get_node("%Card") as RewardCard
	_card.setup(
		"Active Charm" if charm.is_active() else "Passive Charm",
		charm.display_name,
		charm.description,
		EQUIP_HINT,
		_chip_texts(),
		_accent
	)
	_card.set_prompt(CONFIRM_KEY_PREFIX, CONFIRM_PROMPT)
	_name_label = _card.title_label
	_heading.add_theme_color_override(&"font_color", _accent.lightened(0.55))
	_card.modulate.a = 0.0
	_heading.modulate.a = 0.0


func _chip_texts() -> PackedStringArray:
	var chips := PackedStringArray()
	if charm.is_active() and charm.cooldown_seconds > 0.0:
		chips.append("Cooldown %ss" % _short_number(charm.cooldown_seconds))
	if charm.proc_chance < 1.0 - TIME_EPSILON:
		chips.append("Chance %d%%" % roundi(charm.proc_chance * 100.0))
	return chips


func _short_number(value: float) -> String:
	return ("%.1f" % value).trim_suffix(".0")


func _resolve_accent() -> Color:
	if ACCENT_BY_CHARM.has(charm.charm_id):
		return ACCENT_BY_CHARM[charm.charm_id]
	if charm.is_active():
		return ACTIVE_ACCENT
	return PASSIVE_ACCENT if charm.is_passive() else GENERIC_ACCENT


func _veil_tint() -> Vector3:
	var mixed := VEIL_BASE_COLOR.lerp(_accent.darkened(0.6), VEIL_ACCENT_MIX)
	return Vector3(mixed.r, mixed.g, mixed.b)


func _commit_ownership() -> bool:
	if not is_instance_valid(player.charm_registry):
		return false
	if not player.charm_registry.set_owned(charm.charm_id, true):
		return false
	committed = true
	_absorb_sound.play()
	get_node("/root/ShockwaveController").request_world(
		player.global_position + PLAYER_FOCUS_OFFSET, shockwave_seconds, shockwave_strength, _accent
	)
	return true


func _reached(seconds: float) -> bool:
	return elapsed + TIME_EPSILON >= seconds


func _outro_seconds() -> float:
	return gather_seconds + flight_seconds + impact_seconds + release_seconds


func _intro_progress() -> float:
	return minf(clock / intro_seconds, 1.0)


func _focus_weight() -> float:
	var weight := smoothstep(0.0, CAMERA_FOCUS_SECONDS, clock)
	if phase == Phase.OUTRO:
		var release_start := gather_seconds + flight_seconds + impact_seconds
		weight *= 1.0 - smoothstep(release_start, _outro_seconds(), elapsed)
	return weight


func _update_camera() -> void:
	var weight := _focus_weight()
	if is_instance_valid(camera):
		camera.global_position = base_position.lerp(focus_position, weight)
		var zoom := lerpf(base_zoom, base_zoom * zoom_ratio, weight)
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = zoom
		else:
			camera.fov = zoom
		var shake := _shake_amount()
		camera.h_offset = base_h + sin(clock * SHAKE_FREQUENCY.x) * shake
		camera.v_offset = base_v + cos(clock * SHAKE_FREQUENCY.y) * shake
	if _music_index >= 0:
		AudioServer.set_bus_volume_db(_music_index, _music_volume - music_duck_db * weight)
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", weight)


func _shake_amount() -> float:
	var awaken_time := intro_seconds * AWAKEN_FRACTION
	if phase == Phase.INTRO and clock >= awaken_time:
		return reveal_shake_units * (1.0 - (clock - awaken_time) / REVEAL_SHAKE_SECONDS)
	if phase == Phase.OUTRO:
		var since_impact := elapsed - gather_seconds - flight_seconds
		if since_impact >= 0.0 and since_impact < impact_seconds:
			return impact_shake_units * (1.0 - since_impact / impact_seconds)
	return 0.0


func _update_ui() -> void:
	var progress := _intro_progress()
	var alpha := smoothstep(TEXT_START_FRACTION, TEXT_FULL_FRACTION, progress)
	if phase == Phase.OUTRO:
		alpha = 1.0 - smoothstep(0.0, OUTRO_TEXT_FADE_SECONDS, elapsed)
	_card.modulate.a = alpha
	_heading.modulate.a = alpha
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * lerpf(0.94, 1.0, alpha)
	_card.pulse_prompt(clock)
	if not _revealed and phase == Phase.INTRO and progress >= AWAKEN_FRACTION:
		_revealed = true
		_reveal_sound.play()


## Eases past the target and settles back, which gives the rise some weight.
func _ease_out_back(value: float) -> float:
	const OVERSHOOT := 1.4
	var shifted := value - 1.0
	return 1.0 + shifted * shifted * ((OVERSHOOT + 1.0) * shifted + OVERSHOOT)


func _icon_position(origin: Vector2, high: Vector2, destination: Vector2) -> Vector2:
	var progress := _intro_progress()
	var rise := _ease_out_back(
		clampf(inverse_lerp(RISE_START_FRACTION, AWAKEN_FRACTION, progress), 0.0, 1.0)
	)
	var center := origin.lerp(high, rise)
	var tremble := 1.0 - smoothstep(RISE_START_FRACTION, AWAKEN_FRACTION, progress)
	center += Vector2(sin(clock * 71.0), cos(clock * 53.0)) * ICON_TREMBLE_PIXELS * tremble
	if phase == Phase.INTRO and progress < RISE_START_FRACTION:
		return center
	center.y += sin(clock * ICON_BOB_SPEED) * ICON_BOB_PIXELS * smoothstep(0.0, 1.0, rise)
	if phase != Phase.OUTRO:
		return center
	var flight := smoothstep(gather_seconds, gather_seconds + flight_seconds, elapsed)
	return high.lerp(destination, flight) + Vector2(0.0, -FLIGHT_ARC_PIXELS * sin(flight * PI))


func _icon_scale_now() -> float:
	var progress := _intro_progress()
	var rise := smoothstep(RISE_START_FRACTION, AWAKEN_FRACTION, progress)
	var scale_value := lerpf(ICON_START_SCALE, 1.0, rise)
	var punch := clampf((progress - AWAKEN_FRACTION) / ICON_PUNCH_FRACTION, 0.0, 1.0)
	scale_value *= 1.0 + sin(punch * PI) * ICON_PUNCH_SCALE
	scale_value *= 1.0 + ICON_PULSE_AMOUNT * sin(clock * ICON_PULSE_SPEED) * rise
	if phase == Phase.OUTRO:
		scale_value *= lerpf(1.0, ICON_GATHER_SCALE, smoothstep(0.0, gather_seconds, elapsed))
		var flight := smoothstep(gather_seconds, gather_seconds + flight_seconds, elapsed)
		scale_value *= lerpf(1.0, ICON_LANDING_SCALE / ICON_GATHER_SCALE, flight)
	return scale_value


func _icon_alpha_now() -> float:
	var alpha := smoothstep(0.0, RISE_START_FRACTION, _intro_progress())
	if phase == Phase.OUTRO:
		var landing := gather_seconds + flight_seconds
		alpha *= 1.0 - smoothstep(landing * (1.0 - ICON_FADE_FRACTION), landing, elapsed)
	return alpha


func _draw_effects() -> void:
	if _restored or not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var screen_size := _surface.size
	var origin := camera.unproject_position(start_world)
	var destination := camera.unproject_position(player.global_position + PLAYER_FOCUS_OFFSET)
	var feet := camera.unproject_position(player.global_position)
	var high := _get_high_target(destination, screen_size)
	var center := _icon_position(origin, high, destination)
	_icon_center = center
	_icon_scale = _icon_scale_now()
	_icon_alpha = _icon_alpha_now()
	var progress := _intro_progress()
	var awakened := smoothstep(AWAKEN_FRACTION, AWAKEN_FRACTION + ICON_PUNCH_FRACTION, progress)
	if _icon_alpha > 0.0:
		_draw_ground_sigil(origin, progress)
		_draw_light_column(origin, center, progress)
		_draw_glow(center)
		_draw_awaken_ring(center)
		_draw_rune_rings(center, awakened)
		_draw_motes(center, awakened)
		if phase == Phase.OUTRO and elapsed >= gather_seconds:
			_draw_flight_trails(high, destination, _icon_alpha)
		_draw_energy_streams(center, _icon_alpha * awakened)
	if phase == Phase.OUTRO and committed:
		_draw_absorption(destination, feet, elapsed - gather_seconds - flight_seconds)


func _draw_icon() -> void:
	if _restored or _icon_alpha <= 0.0 or not is_instance_valid(pickup):
		return
	var icon_size := Vector2.ONE * icon_size_pixels * _icon_scale
	var texture := _icon_texture()
	if texture == null:
		_draw_missing_icon(_icon_surface, _icon_center, icon_size.x * 0.5)
		return
	_icon_surface.draw_texture_rect(
		texture,
		Rect2(_icon_center - icon_size / 2.0, icon_size),
		false,
		Color(1.0, 1.0, 1.0, _icon_alpha)
	)


func _icon_texture() -> Texture2D:
	if pickup.item != null and pickup.item.icon != null:
		return pickup.item.icon
	return charm.sprite


## A plain diamond keeps the reveal readable when a Charm has no art yet.
func _draw_missing_icon(canvas: Control, center: Vector2, radius: float) -> void:
	var diamond := PackedVector2Array(
		[
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0)
		]
	)
	canvas.draw_colored_polygon(diamond, Color(_accent.darkened(0.55), _icon_alpha))
	canvas.draw_polyline(
		PackedVector2Array(diamond + PackedVector2Array([diamond[0]])),
		Color(_accent.lightened(0.4), _icon_alpha),
		3.0,
		true
	)


func _get_high_target(destination: Vector2, screen_size: Vector2) -> Vector2:
	return Vector2(
		destination.x,
		clampf(
			(
				destination.y
				- minf(screen_size.y * HIGH_TARGET_OFFSET_RATIO, HIGH_TARGET_OFFSET_MAX_PIXELS)
			),
			screen_size.y * HIGH_TARGET_Y_RANGE.x,
			screen_size.y * HIGH_TARGET_Y_RANGE.y
		)
	)


func _ellipse_points(
	center: Vector2, radius: float, flattening: float, sweep: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := maxi(2, ceili(IMPACT_RING_SEGMENTS * clampf(sweep / TAU, 0.05, 1.0)))
	for step in range(steps + 1):
		var angle := sweep * float(step) / steps
		points.append(center + Vector2(cos(angle), sin(angle) * flattening) * radius)
	return points


## The sigil is the anticipation beat: a ring and twelve glyphs light up under the pickup.
func _draw_ground_sigil(origin: Vector2, progress: float) -> void:
	var draw_in := smoothstep(0.0, SIGIL_FULL_FRACTION, progress)
	var fade := 1.0 - smoothstep(AWAKEN_FRACTION, 1.0, progress)
	if phase != Phase.INTRO:
		fade = 0.0
	var alpha := draw_in * fade * SIGIL_ALPHA
	if alpha <= 0.0:
		return
	var ground := origin + Vector2(0.0, GROUND_OFFSET_PIXELS)
	var radius := sigil_radius_pixels * (0.6 + 0.4 * draw_in)
	_surface.draw_polyline(
		_ellipse_points(ground, radius, SIGIL_FLATTENING, TAU * draw_in),
		Color(_accent, alpha),
		2.0,
		true
	)
	_surface.draw_polyline(
		_ellipse_points(ground, radius * 0.72, SIGIL_FLATTENING, TAU * draw_in),
		Color(_accent, alpha * 0.5),
		1.5,
		true
	)
	for glyph in range(SIGIL_GLYPH_COUNT):
		if float(glyph) / SIGIL_GLYPH_COUNT > draw_in:
			break
		var angle := glyph * TAU / SIGIL_GLYPH_COUNT + clock * SIGIL_SPIN_SPEED
		var at := ground + Vector2(cos(angle), sin(angle) * SIGIL_FLATTENING) * radius
		_draw_diamond(_surface, at, SIGIL_GLYPH_SIZE_PIXELS, Color(_accent.lightened(0.4), alpha))


func _draw_diamond(canvas: Control, at: Vector2, size: float, color: Color) -> void:
	if size < MIN_GLYPH_SIZE_PIXELS:
		return
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[
				at + Vector2(0.0, -size),
				at + Vector2(size * 0.6, 0.0),
				at + Vector2(0.0, size),
				at + Vector2(-size * 0.6, 0.0)
			]
		),
		color
	)


## A soft column links the ground to the rising Charm so the eye follows it up.
func _draw_light_column(origin: Vector2, center: Vector2, progress: float) -> void:
	if phase != Phase.INTRO or progress < RISE_START_FRACTION:
		return
	var life := 1.0 - smoothstep(AWAKEN_FRACTION, AWAKEN_FRACTION + 0.18, progress)
	if life <= 0.0:
		return
	var ground := origin + Vector2(0.0, GROUND_OFFSET_PIXELS)
	var half := COLUMN_WIDTH_PIXELS * 0.5 * life
	var points := PackedVector2Array(
		[
			ground + Vector2(-half, 0.0),
			ground + Vector2(half, 0.0),
			center + Vector2(half * 0.3, 0.0),
			center + Vector2(-half * 0.3, 0.0)
		]
	)
	var strong := Color(_accent, COLUMN_ALPHA * life)
	var clear := Color(_accent, 0.0)
	_surface.draw_polygon(points, PackedColorArray([strong, strong, clear, clear]))


func _draw_glow(center: Vector2) -> void:
	var pulse := 1.0 + 0.08 * sin(clock * ICON_PULSE_SPEED)
	for glow_layer in range(GLOW_LAYERS, 0, -1):
		var radius := (GLOW_BASE_RADIUS_PIXELS + glow_layer * GLOW_LAYER_STEP_PIXELS) * pulse
		_surface.draw_circle(
			center, radius * _icon_scale, Color(_accent, _icon_alpha * GLOW_LAYER_ALPHA)
		)


func _draw_awaken_ring(center: Vector2) -> void:
	var since := clock - intro_seconds * AWAKEN_FRACTION
	if phase != Phase.INTRO or since < 0.0 or since > AWAKEN_RING_SECONDS:
		return
	var life := 1.0 - since / AWAKEN_RING_SECONDS
	var radius := sigil_radius_pixels * (0.5 + AWAKEN_RING_GROWTH * (1.0 - life * life))
	_surface.draw_arc(
		center, radius, 0.0, TAU, IMPACT_RING_SEGMENTS, Color(_accent, life * 0.32), 5.0, true
	)
	_surface.draw_arc(
		center, radius, 0.0, TAU, IMPACT_RING_SEGMENTS, Color("eafff6", life * 0.55), 1.5, true
	)


## Two counter-rotating rune rings; each glyph ignites as the awakening sweeps round.
func _draw_rune_rings(center: Vector2, awakened: float) -> void:
	var alpha := _icon_alpha * awakened * RUNE_RING_ALPHA
	if alpha <= 0.0:
		return
	if phase == Phase.OUTRO:
		alpha *= 1.0 - smoothstep(0.0, gather_seconds, elapsed)
	var spin := clock * RUNE_RING_SPIN_SPEED
	var radius := sigil_radius_pixels * _icon_scale
	_surface.draw_arc(
		center, radius, 0.0, TAU * awakened, IMPACT_RING_SEGMENTS, Color(_accent, alpha), 1.5, true
	)
	_surface.draw_arc(
		center,
		radius * 0.82,
		0.0,
		TAU * awakened,
		IMPACT_RING_SEGMENTS,
		Color(_accent, alpha * 0.6),
		1.0,
		true
	)
	for glyph in range(SIGIL_GLYPH_COUNT):
		var lit := clampf(awakened * SIGIL_GLYPH_COUNT - glyph, 0.0, 1.0)
		var angle := glyph * TAU / SIGIL_GLYPH_COUNT + spin
		var at := center + Vector2.from_angle(angle) * radius
		_draw_diamond(
			_surface, at, SIGIL_GLYPH_SIZE_PIXELS * lit, Color(_accent.lightened(0.5), alpha)
		)
		var inner := center + Vector2.from_angle(-angle * 0.8) * radius * 0.82
		_surface.draw_circle(inner, 2.0 * lit, Color("eafff6", alpha))


func _draw_motes(center: Vector2, awakened: float) -> void:
	var alpha := _icon_alpha * awakened
	if alpha <= 0.0:
		return
	for index in range(MOTE_COUNT):
		var cycle := fposmod(clock * MOTE_SPEED + float(index) / MOTE_COUNT, 1.0)
		var angle := index * PHYLLOTAXIS_ANGLE
		var radius := sigil_radius_pixels * _icon_scale * (0.7 + 0.5 * cycle)
		var at := center + Vector2.from_angle(angle) * radius
		at.y -= cycle * MOTE_RISE_PIXELS * 0.5
		_surface.draw_circle(
			at, 2.4 * sin(cycle * PI), Color(_accent.lightened(0.5), alpha * sin(cycle * PI))
		)


func _draw_energy_streams(center: Vector2, alpha: float) -> void:
	if alpha <= 0.001:
		return
	var gather := 0.0
	if phase == Phase.OUTRO:
		gather = smoothstep(0.0, gather_seconds, elapsed)
		alpha *= 1.0 - smoothstep(gather_seconds, gather_seconds + 0.35, elapsed)
	var spin_speed := 1.0 + gather * STREAM_GATHER_SPIN
	var radius_scale := lerpf(1.0, STREAM_CONTRACT_RATIO, gather) * _icon_scale
	var bright := _accent.lightened(0.55)
	# Connected, tapered silhouettes instead of short lines: no joints or visible segments.
	for stream in range(STREAM_COUNT):
		var direction := 1.0 if stream % 2 == 0 else -1.0
		var head := (
			clock * spin_speed * (4.4 + 0.22 * stream) * direction + stream * TAU / STREAM_COUNT
		)
		var radius := (STREAM_RADIUS_PIXELS + (stream % 2) * 7.0) * radius_scale
		var tilt := -1.2 + stream * 0.6
		var points := PackedVector2Array()
		for segment in range(STREAM_SEGMENTS + 1):
			var t := float(segment) / STREAM_SEGMENTS
			var angle := head - direction * t * (STREAM_ARC_RADIANS + 0.13 * (stream % 2))
			var ellipse := Vector2(cos(angle) * radius, sin(angle) * radius * 0.64)
			points.append(center + ellipse.rotated(tilt))
		var flash := 0.65 + 0.35 * pow(maxf(0.0, sin(clock * 8.0 + stream * 1.7)), 6.0)
		_draw_ribbon(points, 56.0, Color(_accent, alpha * 0.018 * flash))
		_draw_ribbon(points, 40.0, Color(_accent, alpha * 0.035 * flash))
		_draw_ribbon(points, 27.0, Color(_accent, alpha * 0.07 * flash))
		_draw_ribbon(points, 16.0, Color(_accent, alpha * 0.16 * flash))
		_draw_ribbon(points, 8.0, Color(_accent, alpha * 0.5 * flash))
		_draw_ribbon(points, 2.5, Color(bright, alpha * 0.65 * flash))
		var tip := points[10]
		_surface.draw_circle(tip, 8.0 + 5.0 * flash, Color(_accent, alpha * 0.18 * flash))
		_surface.draw_circle(tip, 2.5 + 1.5 * flash, Color(bright, alpha * flash))
		var tangent := (points[11] - points[9]).normalized()
		var outward := Vector2(-tangent.y, tangent.x)
		if outward.dot(tip - center) < 0.0:
			outward = -outward
		var spike := PackedVector2Array(
			[
				tip - tangent * 6.0,
				tip + outward * (17.0 + 4.0 * sin(clock * 2.0 + stream)),
				tip + tangent * 7.0
			]
		)
		_surface.draw_colored_polygon(spike, Color(_accent, alpha * 0.72))


func _draw_ribbon(points: PackedVector2Array, width: float, color: Color) -> void:
	if points.size() < 2 or color.a <= 0.0:
		return
	# One indexed mesh shares vertices between triangles, so translucent
	# segments neither overlap nor leave visible seams. Explicit indices also
	# avoid Godot's polygon triangulation on a curved, tapered silhouette.
	var filtered := PackedVector2Array()
	for point in points:
		if (
			filtered.is_empty()
			or (
				filtered[-1].distance_squared_to(point)
				>= RIBBON_MIN_SEGMENT_PIXELS * RIBBON_MIN_SEGMENT_PIXELS
			)
		):
			filtered.append(point)
	if filtered.size() < 2:
		return
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var last := filtered.size() - 1
	for i in filtered.size():
		var t := float(i) / last
		var tangent := (filtered[mini(i + 1, last)] - filtered[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var thickness := maxf(0.1, width * pow(sin(PI * t), RIBBON_TAPER_EXPONENT))
		vertices.append(filtered[i] + normal * thickness * 0.5)
		vertices.append(filtered[i] - normal * thickness * 0.5)
		colors.append(color)
		colors.append(color)
		if i == 0:
			continue
		var previous := (i - 1) * 2
		var current := i * 2
		indices.append_array(
			PackedInt32Array([previous, previous + 1, current, previous + 1, current + 1, current])
		)
	RenderingServer.canvas_item_add_triangle_array(
		_surface.get_canvas_item(), indices, vertices, colors, PackedVector2Array()
	)


func _draw_flight_trails(high: Vector2, destination: Vector2, alpha: float) -> void:
	var progress := smoothstep(gather_seconds, gather_seconds + flight_seconds, elapsed)
	var bright := _accent.lightened(0.6)
	for strand in range(3):
		var points := PackedVector2Array()
		for i in range(33):
			var t := float(i) / 32.0
			var flight_t := maxf(0.0, progress - (1.0 - t) * FLIGHT_TRAIL_LAG)
			var point := (
				high.lerp(destination, flight_t)
				+ Vector2(0.0, -FLIGHT_ARC_PIXELS * sin(flight_t * PI))
			)
			var spread := sin(t * PI) * (1.0 - flight_t) * FLIGHT_TRAIL_SPREAD_PIXELS
			point.x += (strand - 1) * spread
			point.x += sin(t * TAU * FLIGHT_TRAIL_WAVE + clock * 5.0 + strand) * spread * 0.3
			points.append(point)
		if points[0].distance_squared_to(points[32]) < RIBBON_MIN_SEGMENT_PIXELS:
			continue
		_draw_ribbon(points, 26.0, Color(_accent, alpha * 0.045))
		_draw_ribbon(points, 13.0, Color(_accent, alpha * 0.15))
		_draw_ribbon(points, 5.0, Color(_accent, alpha * 0.55))
		_draw_ribbon(points, 1.8, Color(bright, alpha * 0.95))
	var head := (
		high.lerp(destination, progress) + Vector2(0.0, -FLIGHT_ARC_PIXELS * sin(progress * PI))
	)
	_surface.draw_circle(head, FLIGHT_HEAD_FLARE_PIXELS * 2.0, Color(_accent, alpha * 0.12))
	_surface.draw_circle(head, FLIGHT_HEAD_FLARE_PIXELS, Color(bright, alpha * 0.3))
	_surface.draw_circle(head, FLIGHT_HEAD_FLARE_PIXELS * 0.3, Color(Color.WHITE, alpha))


## The payoff: Foxy glows from the feet up, then the energy settles into a calm aura.
func _draw_absorption(destination: Vector2, feet: Vector2, since: float) -> void:
	if since < 0.0:
		return
	var life_seconds := impact_seconds + release_seconds * 0.5
	var strength := maxf(0.0, 1.0 - since / life_seconds)
	_draw_absorption_flash(destination, since)
	_draw_impact_streaks(destination, since, strength)
	_draw_aura(feet, since, strength)
	for i in range(BURST_DOT_COUNT):
		var angle := float(i) * TAU / BURST_DOT_COUNT
		var distance := 25.0 + since * (110.0 + (i % 4) * 35.0)
		_surface.draw_circle(
			destination + Vector2(cos(angle), sin(angle)) * distance,
			2.5 * strength,
			Color(_accent.lightened(0.5), strength)
		)


func _draw_aura(feet: Vector2, since: float, strength: float) -> void:
	if strength <= 0.0:
		return
	var rise := smoothstep(0.0, 0.18, since)
	var half := AURA_WIDTH_PIXELS * 0.5
	var top := feet + Vector2(0.0, -AURA_HEIGHT_PIXELS * rise)
	var strong := Color(_accent, AURA_ALPHA * strength)
	var clear := Color(_accent, 0.0)
	_surface.draw_polygon(
		PackedVector2Array(
			[
				feet + Vector2(-half, 0.0),
				feet + Vector2(half, 0.0),
				top + Vector2(half * 0.45, 0.0),
				top + Vector2(-half * 0.45, 0.0)
			]
		),
		PackedColorArray([strong, strong, clear, clear])
	)
	for ring in range(AURA_RING_COUNT):
		var delay := ring * 0.18
		var radius := 22.0 + maxf(0.0, since - delay) * AURA_RING_SPEED_PIXELS
		var fade := maxf(0.0, 1.0 - maxf(0.0, since - delay) / IMPACT_RING_DURATION)
		_surface.draw_polyline(
			_ellipse_points(feet, radius, SIGIL_FLATTENING, TAU),
			Color(_accent.lightened(0.3), fade * 0.8),
			3.0,
			true
		)
	for index in range(AURA_MOTE_COUNT):
		var cycle := fposmod(since * 0.9 + float(index) / AURA_MOTE_COUNT, 1.0)
		var at := feet + Vector2(sin(index * PHYLLOTAXIS_ANGLE) * half, -cycle * AURA_HEIGHT_PIXELS)
		_surface.draw_circle(at, 2.2, Color(_accent.lightened(0.6), strength * sin(cycle * PI)))


func _draw_absorption_flash(center: Vector2, time: float) -> void:
	var life := 1.0 - smoothstep(0.0, IMPACT_RING_DURATION, time)
	if life <= 0.0:
		return
	var radius := IMPACT_FLASH_RADIUS_PIXELS + time * IMPACT_RING_SPEED_PIXELS
	for glow_layer in range(IMPACT_GLOW_LAYERS, 0, -1):
		var fraction := float(glow_layer) / IMPACT_GLOW_LAYERS
		_surface.draw_circle(
			center, IMPACT_FLASH_RADIUS_PIXELS * fraction, Color(_accent, life * 0.018)
		)
	_surface.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		IMPACT_RING_SEGMENTS,
		Color(_accent, life * 0.12),
		IMPACT_RING_WIDTH_PIXELS * 3.0,
		true
	)
	_surface.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		IMPACT_RING_SEGMENTS,
		Color(_accent, life * 0.42),
		IMPACT_RING_WIDTH_PIXELS,
		true
	)
	_surface.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		IMPACT_RING_SEGMENTS,
		Color(_accent.lightened(0.7), life * 0.85),
		IMPACT_RING_WIDTH_PIXELS * 0.25,
		true
	)


func _draw_impact_streaks(center: Vector2, time: float, strength: float) -> void:
	if strength <= 0.0:
		return
	var radius := 18.0 + time * 150.0
	var bright := _accent.lightened(0.7)
	for streak in range(9):
		var angle := streak * TAU / 9.0 + time * (0.7 if streak % 2 == 0 else -0.7)
		var points := PackedVector2Array()
		for segment in range(25):
			var fraction := float(segment) / 24.0
			var theta := angle + (fraction - 0.5) * (0.35 + 0.09 * (streak % 3))
			var radial := radius * (0.9 + 0.1 * fraction)
			points.append(center + Vector2(cos(theta), sin(theta) * 0.72) * radial)
		_draw_ribbon(points, 13.0 * strength, Color(_accent, strength * 0.18))
		_draw_ribbon(points, 5.0 * strength, Color(_accent, strength * 0.85))
		_draw_ribbon(points, 1.5 * strength, Color(bright, strength))


func _on_pickup_exiting() -> void:
	_pickup_lost = true
	_finish(false)


func _on_player_exiting() -> void:
	_finish(false)


## Idempotent: success, cancel, a lost Player or pickup, and scene changes all end here.
func _finish(success: bool) -> void:
	if _restored:
		return
	_restored = true
	set_process(false)
	if is_instance_valid(camera):
		camera.global_position = base_position
		camera.h_offset = base_h
		camera.v_offset = base_v
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = base_zoom
		else:
			camera.fov = base_zoom
	if _music_index >= 0:
		AudioServer.set_bus_volume_db(_music_index, _music_volume)
	if is_instance_valid(_animator):
		_animator.callback_mode_process = _animator_callback
		_animator.process_mode = _animator_mode
	if is_instance_valid(_spine_preview):
		_spine_preview.process_mode = _spine_mode
	if is_instance_valid(player) and not player.is_queued_for_deletion():
		player.clear_gameplay_input()
	if is_instance_valid(pickup) and not _pickup_lost and not pickup.is_queued_for_deletion():
		pickup.finish_reward_presentation(success and committed)
	get_tree().paused = _previous_pause
	if not is_queued_for_deletion():
		queue_free()
