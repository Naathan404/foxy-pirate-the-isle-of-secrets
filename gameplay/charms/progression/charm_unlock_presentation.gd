extends CanvasLayer
## Runs in real time while the gameplay tree is paused.

const INTRO := 3.4
const CHARGE := 1.0
const FLIGHT := 1.0
const BURST := 1.0
const RETURN := 1.5
const SPEED := 1.25
const UNLOCK_UI := preload("res://gameplay/charms/progression/charm_unlock_ui.tscn")

const SHOCKWAVE_DURATION := 0.9
const SHOCKWAVE_STRENGTH := 0.06
const IMPACT_RING_SPEED_PIXELS := 265.0
const IMPACT_RING_DURATION := 1.15
const IMPACT_RING_WIDTH_PIXELS := 8.0
const IMPACT_RING_SEGMENTS := 96
const IMPACT_GLOW_LAYERS := 5
const IMPACT_FLASH_RADIUS_PIXELS := 74.0
const FLIGHT_TRAIL_SPREAD_PIXELS := 22.0
const FLIGHT_TRAIL_LAG := 0.30
const FLIGHT_TRAIL_WAVE := 1.5
const FLIGHT_HEAD_FLARE_PIXELS := 8.0
const RIBBON_MIN_SEGMENT_PIXELS := 0.3
const RIBBON_TAPER_EXPONENT := 0.8

var pickup: ItemPickup
var player: Player
var camera: Camera3D
var charm: CharmData
var phase := 0  # intro, waiting, outro
var elapsed := 0.0
var clock := 0.0
var committed := false
var base_zoom := 0.0
var base_position := Vector3.ZERO
var focus_position := Vector3.ZERO
var base_h := 0.0
var base_v := 0.0
var start_world := Vector3.ZERO
var _surface: Control
var _icon_surface: Control
var _icon_center := Vector2.ZERO
var _icon_alpha := 0.0
var _icon_pulse := 1.0
var _panel: VBoxContainer
var _info_frame: PanelContainer
var _heading: Label
var _name_label: Label
var _description: Label
var _prompt: Label
var _vignette: ColorRect
var _sound: AudioStreamPlayer
var _music_bus := -1
var _music_volume := 0.0
var _previous_pause := false
var _restored := false
var _animator: AnimationPlayer
var _spine_preview: Node
var _animator_mode := Node.PROCESS_MODE_INHERIT
var _animator_callback := AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
var _spine_mode := Node.PROCESS_MODE_INHERIT


func begin(source: ItemPickup, actor: Player) -> void:
	pickup = source
	player = actor
	charm = pickup.item.charm
	camera = player.camera if is_instance_valid(player.camera) else get_viewport().get_camera_3d()
	start_world = pickup.sprite.global_position
	_previous_pause = get_tree().paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	if is_instance_valid(camera):
		base_zoom = (
			camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else camera.fov
		)
		base_position = camera.global_position
		var local_target := camera.to_local(player.global_position + Vector3.UP)
		focus_position = (
			base_position
			+ camera.global_basis.x * local_target.x
			+ camera.global_basis.y * local_target.y
		)
		base_h = camera.h_offset
		base_v = camera.v_offset
	player.clear_gameplay_input()
	var visual := player.get_node_or_null("Visual") as PlayerVisual
	if is_instance_valid(visual) and is_instance_valid(visual.animation_player):
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
	pickup.sprite.hide()
	_build_ui()
	_music_bus = AudioServer.get_bus_index("Music")
	if _music_bus >= 0:
		_music_volume = AudioServer.get_bus_volume_db(_music_bus)
		AudioServer.set_bus_volume_db(_music_bus, _music_volume - 8.0)
	get_tree().paused = true
	_play_tone(440.0, 0.5)


func _build_ui() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	uniform float strength = 0.0;
	void fragment() {
		vec2 p = (UV - vec2(0.5)) * vec2(1.15, 1.0);
		float edge = smoothstep(0.12, 0.78, length(p));
		COLOR = vec4(0.008, 0.025, 0.065, strength * (0.26 + edge * 0.70));
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
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
	var ui := UNLOCK_UI.instantiate() as Control
	add_child(ui)
	_heading = ui.get_node("Heading") as Label
	_info_frame = ui.get_node("InfoFrame") as PanelContainer
	_panel = ui.get_node("InfoFrame/Rows") as VBoxContainer
	_name_label = ui.get_node("InfoFrame/Rows/CharmName") as Label
	_description = ui.get_node("InfoFrame/Rows/Description") as Label
	_prompt = ui.get_node("InfoFrame/Rows/Prompt") as Label
	_name_label.text = charm.display_name
	_description.text = charm.description
	_info_frame.modulate.a = 0.0
	_heading.modulate.a = 0.0
	_sound = AudioStreamPlayer.new()
	_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	_sound.bus = &"UI"
	add_child(_sound)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(pickup):
		_finish(false)
		return
	if is_instance_valid(_animator):
		_animator.advance(delta)
	clock += delta * SPEED
	elapsed += delta * SPEED
	if phase == 0 and elapsed >= INTRO:
		phase = 1
		elapsed = 0.0
		_play_tone(660.0, 0.35)
	if phase == 2 and not committed and elapsed >= CHARGE + FLIGHT:
		if (
			not is_instance_valid(player.charm_registry)
			or not player.charm_registry.set_owned(charm.charm_id, true)
		):
			_finish(false)
			return
		committed = true
		_play_tone(220.0, 0.8)
		get_node("/root/ShockwaveController").request_world(
			player.global_position + Vector3.UP, SHOCKWAVE_DURATION, SHOCKWAVE_STRENGTH
		)
	if phase == 2 and elapsed >= CHARGE + FLIGHT + BURST + RETURN:
		_finish(true)
		return
	_update_camera()
	var fade := minf(clock / 0.8, 1.0)
	if phase == 2:
		fade *= 1.0 - smoothstep(CHARGE + FLIGHT + BURST, CHARGE + FLIGHT + BURST + RETURN, elapsed)
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", fade)
	var text_alpha := (
		smoothstep(2.6, INTRO, clock) if phase < 2 else 1.0 - smoothstep(0.0, 0.35, elapsed)
	)
	_info_frame.modulate.a = text_alpha
	_heading.modulate.a = text_alpha
	_prompt.modulate.a = 0.7 + 0.3 * sin(clock * 3.0)
	_surface.queue_redraw()
	_icon_surface.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if phase != 1 or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_SPACE:
		phase = 2
		elapsed = 0.0
		_play_tone(520.0, 0.55)
		get_viewport().set_input_as_handled()


func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var weight := smoothstep(0.0, 0.8, clock)
	if phase == 2:
		weight *= (
			1.0 - smoothstep(CHARGE + FLIGHT + BURST, CHARGE + FLIGHT + BURST + RETURN, elapsed)
		)
	camera.global_position = base_position.lerp(focus_position, weight)
	var zoom := lerpf(base_zoom, base_zoom * 0.77, weight)
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = zoom
	else:
		camera.fov = zoom
	var shake := 0.0
	if phase == 0 and clock > 2.55 and clock < 2.85:
		shake = 0.025 * (1.0 - (clock - 2.55) / 0.3)
	elif phase == 2 and elapsed >= 2.0 and elapsed < 2.5:
		shake = 0.07 * (1.0 - (elapsed - 2.0) / 0.5)
	camera.h_offset = base_h + sin(clock * 61.0) * shake
	camera.v_offset = base_v + cos(clock * 47.0) * shake


func _draw_effects() -> void:
	if _restored or not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var screen_size := _surface.size
	var origin := camera.unproject_position(start_world)
	var destination := camera.unproject_position(player.global_position + Vector3.UP)
	var rising := smoothstep(0.5, 2.6, clock)
	var high_target := _get_high_target(destination, screen_size)
	var high := origin.lerp(high_target, rising)
	var center := high
	var alpha := 1.0
	if phase == 2:
		var flight := smoothstep(CHARGE, CHARGE + FLIGHT, elapsed)
		center = high.lerp(destination, flight) + Vector2(0, -80.0 * sin(flight * PI))
		alpha = 1.0 - smoothstep(1.8, 2.0, elapsed)
	var accent := _charm_color()
	var pulse := 1.0 + 0.08 * sin(clock * 4.0)
	_icon_center = center
	_icon_alpha = alpha
	_icon_pulse = pulse
	if alpha > 0.0:
		if phase < 2 or elapsed < CHARGE:
			_surface.draw_arc(
				origin + Vector2(0, 18),
				44.0 * rising,
				0.0,
				TAU,
				64,
				Color(accent, alpha * 0.5),
				2.0,
				true
			)
		if phase == 2 and elapsed >= CHARGE:
			_draw_flight_trails(high, destination, alpha)
		for i in range(5, 0, -1):
			_surface.draw_circle(center, (22.0 + i * 13.0) * pulse, Color(accent, alpha * 0.025))
		var orbit_alpha := alpha
		if phase == 2:
			orbit_alpha *= 1.0 - smoothstep(CHARGE, CHARGE + 0.35, elapsed)
		_draw_energy_streams(center, orbit_alpha)
	if phase == 2 and elapsed >= 2.0:
		var t := elapsed - 2.0
		var strength := maxf(0.0, 1.0 - t / 1.3)
		_draw_absorption_flash(destination, t)
		_draw_impact_streaks(destination, t, strength)
		for i in range(36):
			var angle := float(i) * TAU / 36.0
			var distance := 25.0 + t * (110.0 + (i % 4) * 35.0)
			_surface.draw_circle(
				destination + Vector2(cos(angle), sin(angle)) * distance,
				2.5 * strength,
				Color("ffe0a3", strength)
			)


func _draw_icon() -> void:
	if (
		_restored
		or not is_instance_valid(pickup)
		or pickup.item == null
		or pickup.item.icon == null
	):
		return
	if _icon_alpha > 0.0:
		var icon_size := Vector2(68, 68) * _icon_pulse
		_icon_surface.draw_texture_rect(
			pickup.item.icon,
			Rect2(_icon_center - icon_size / 2.0, icon_size),
			false,
			Color(1, 1, 1, _icon_alpha)
		)


func _get_high_target(destination: Vector2, screen_size: Vector2) -> Vector2:
	return Vector2(
		destination.x,
		clampf(
			destination.y - minf(screen_size.y * 0.22, 180.0),
			screen_size.y * 0.26,
			screen_size.y * 0.50
		)
	)


func _draw_energy_streams(center: Vector2, alpha: float) -> void:
	if alpha <= 0.001:
		return
	# Connected, tapered silhouettes instead of short lines: no joints or visible segments.
	var jade := Color("35e2b3")
	for stream in range(5):
		var direction := 1.0 if stream % 2 == 0 else -1.0
		var head := clock * (4.8 + 0.22 * stream) * direction + stream * TAU / 5.0
		var radius := 81.0 + (stream % 2) * 7.0
		var tilt := -1.2 + stream * 0.6
		var points := PackedVector2Array()
		for segment in range(49):
			var t := float(segment) / 48.0
			var angle := head - direction * t * (1.65 + 0.13 * (stream % 2))
			var ellipse := Vector2(cos(angle) * radius, sin(angle) * radius * 0.64)
			points.append(center + ellipse.rotated(tilt))
		var flash := 0.65 + 0.35 * pow(maxf(0.0, sin(clock * 8.0 + stream * 1.7)), 6.0)
		_draw_ribbon(points, 56.0, Color(jade, alpha * 0.018 * flash))
		_draw_ribbon(points, 40.0, Color(jade, alpha * 0.035 * flash))
		_draw_ribbon(points, 27.0, Color(jade, alpha * 0.07 * flash))
		_draw_ribbon(points, 16.0, Color(jade, alpha * 0.16 * flash))
		_draw_ribbon(points, 8.0, Color(jade, alpha * 0.50 * flash))
		_draw_ribbon(points, 2.5, Color("d1ffed", alpha * 0.65 * flash))
		# A sharp flare punctuates each moving stroke, echoing the reference's energy spikes.
		var tip := points[10]
		_surface.draw_circle(tip, 8.0 + 5.0 * flash, Color(jade, alpha * 0.18 * flash))
		_surface.draw_circle(tip, 2.5 + 1.5 * flash, Color("edfff7", alpha * flash))
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
		_surface.draw_colored_polygon(spike, Color(jade, alpha * 0.72))


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
	var progress := smoothstep(CHARGE, CHARGE + FLIGHT, elapsed)
	var jade := Color("35e2b3")
	for strand in range(3):
		var points := PackedVector2Array()
		for i in range(33):
			var t := float(i) / 32.0
			var flight_t := maxf(0.0, progress - (1.0 - t) * FLIGHT_TRAIL_LAG)
			var point := high.lerp(destination, flight_t) + Vector2(0, -80.0 * sin(flight_t * PI))
			var spread := sin(t * PI) * (1.0 - flight_t) * FLIGHT_TRAIL_SPREAD_PIXELS
			point.x += (strand - 1) * spread
			point.x += sin(t * TAU * FLIGHT_TRAIL_WAVE + clock * 5.0 + strand) * spread * 0.3
			points.append(point)
		if points[0].distance_squared_to(points[32]) < RIBBON_MIN_SEGMENT_PIXELS:
			continue
		_draw_ribbon(points, 26.0, Color(jade, alpha * 0.045))
		_draw_ribbon(points, 13.0, Color(jade, alpha * 0.15))
		_draw_ribbon(points, 5.0, Color(jade, alpha * 0.55))
		_draw_ribbon(points, 1.8, Color("eafff6", alpha * 0.95))
	var head := high.lerp(destination, progress) + Vector2(0, -80.0 * sin(progress * PI))
	_surface.draw_circle(head, FLIGHT_HEAD_FLARE_PIXELS * 2.0, Color(jade, alpha * 0.12))
	_surface.draw_circle(head, FLIGHT_HEAD_FLARE_PIXELS, Color("eafff6", alpha * 0.3))
	_surface.draw_circle(head, FLIGHT_HEAD_FLARE_PIXELS * 0.3, Color.WHITE * alpha)


func _draw_absorption_flash(center: Vector2, time: float) -> void:
	var life := 1.0 - smoothstep(0.0, IMPACT_RING_DURATION, time)
	if life <= 0.0:
		return
	var jade := Color("35e2b3")
	var radius := IMPACT_FLASH_RADIUS_PIXELS + time * IMPACT_RING_SPEED_PIXELS
	for layer in range(IMPACT_GLOW_LAYERS, 0, -1):
		var fraction := float(layer) / IMPACT_GLOW_LAYERS
		_surface.draw_circle(
			center, IMPACT_FLASH_RADIUS_PIXELS * fraction, Color(jade, life * 0.018)
		)
	_surface.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		IMPACT_RING_SEGMENTS,
		Color(jade, life * 0.12),
		IMPACT_RING_WIDTH_PIXELS * 3.0,
		true
	)
	_surface.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		IMPACT_RING_SEGMENTS,
		Color(jade, life * 0.42),
		IMPACT_RING_WIDTH_PIXELS,
		true
	)
	_surface.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		IMPACT_RING_SEGMENTS,
		Color("eafff6", life * 0.85),
		IMPACT_RING_WIDTH_PIXELS * 0.25,
		true
	)


func _draw_impact_streaks(center: Vector2, time: float, strength: float) -> void:
	if strength <= 0.0:
		return
	var radius := 18.0 + time * 150.0
	var jade := Color("48eac0")
	for streak in range(9):
		var angle := streak * TAU / 9.0 + time * (0.7 if streak % 2 == 0 else -0.7)
		var points := PackedVector2Array()
		for segment in range(25):
			var fraction := float(segment) / 24.0
			var theta := angle + (fraction - 0.5) * (0.35 + 0.09 * (streak % 3))
			var radial := radius * (0.9 + 0.1 * fraction)
			points.append(center + Vector2(cos(theta), sin(theta) * 0.72) * radial)
		_draw_ribbon(points, 13.0 * strength, Color(jade, strength * 0.18))
		_draw_ribbon(points, 5.0 * strength, Color(jade, strength * 0.85))
		_draw_ribbon(points, 1.5 * strength, Color("eafff6", strength))


func _charm_color() -> Color:
	match charm.charm_id:
		&"life_steal", &"backstabber", &"shadow_lunge":
			return Color("ed7f92")
		&"gale_pace", &"arrow_rain":
			return Color("a5efc4")
		&"chaos_collector", &"buckshot_salvo", &"crescent_cleave":
			return Color("ffc97e")
		_:
			return Color("77e5e9")


func _play_tone(frequency: float, duration: float) -> void:
	# Small synthesized chime: the project currently has no bundled audio files.
	var rate := 22050
	var data := PackedByteArray()
	data.resize(int(rate * duration) * 2)
	for i in range(int(rate * duration)):
		var t := float(i) / rate
		var envelope := minf(t * 20.0, 1.0) * exp(-t * 5.0)
		var sample := int(
			(
				clampf(
					(
						(sin(TAU * frequency * t) + 0.3 * sin(TAU * frequency * 2.01 * t))
						* envelope
						* 0.16
					),
					-1.0,
					1.0
				)
				* 32767.0
			)
		)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	_sound.stream = stream
	_sound.play()


func _finish(success: bool) -> void:
	if _restored:
		return
	_restored = true
	if is_instance_valid(camera):
		camera.global_position = base_position
		camera.h_offset = base_h
		camera.v_offset = base_v
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = base_zoom
		else:
			camera.fov = base_zoom
	if _music_bus >= 0:
		AudioServer.set_bus_volume_db(_music_bus, _music_volume)
	if is_instance_valid(_animator):
		_animator.callback_mode_process = _animator_callback
		_animator.process_mode = _animator_mode
	if is_instance_valid(_spine_preview):
		_spine_preview.process_mode = _spine_mode
	if is_instance_valid(pickup):
		if success and committed:
			pickup.queue_free()
		else:
			pickup.sprite.show()
			pickup._collecting = false
			pickup._attraction.set_enabled(true)
			pickup._start_idle_animation()
	get_tree().paused = _previous_pause
	queue_free()


func _exit_tree() -> void:
	if not _restored:
		_finish(false)
