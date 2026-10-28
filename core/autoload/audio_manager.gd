extends Node
## Shared one-shot audio. Gameplay owns when/what to play; this node owns the voices.

@export_range(1, 64, 1) var sfx_voice_count: int = 12
@export_range(1, 64, 1) var spatial_voice_count: int = 16
@export_range(1, 16, 1) var ui_voice_count: int = 4
## The gameplay camera sits about 28 units above/behind Foxy
@export var spatial_unit_size: float = 32.0
@export var spatial_max_distance: float = 80.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _spatial_pool: Array[AudioStreamPlayer3D] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0
var _next_spatial: int = 0
var _next_ui: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_flat_pool(_sfx_pool, maxi(1, sfx_voice_count), &"SFX", Node.PROCESS_MODE_PAUSABLE)
	_create_flat_pool(_ui_pool, maxi(1, ui_voice_count), &"UI", Node.PROCESS_MODE_ALWAYS)
	for index in maxi(1, spatial_voice_count):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "SpatialSFX%d" % index
		voice.bus = &"SFX"
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		voice.unit_size = maxf(0.01, spatial_unit_size)
		voice.max_distance = maxf(0.0, spatial_max_distance)
		voice.finished.connect(_release_voice.bind(voice))
		add_child(voice)
		_spatial_pool.append(voice)


func play_sfx(
	stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0
) -> AudioStreamPlayer:
	if stream == null or get_tree().paused:
		return null
	var index := _find_voice(_sfx_pool, _next_sfx)
	_next_sfx = (index + 1) % _sfx_pool.size()
	var voice := _sfx_pool[index]
	voice.stop()
	voice.stream = stream
	voice.volume_db = clampf(volume_db, -80.0, 6.0)
	voice.pitch_scale = clampf(pitch_scale, 0.01, 4.0)
	voice.play()
	return voice


func play_sfx_3d(
	stream: AudioStream, at: Vector3, volume_db: float = 0.0, pitch_scale: float = 1.0
) -> AudioStreamPlayer3D:
	if stream == null or get_tree().paused:
		return null
	var index := _find_voice(_spatial_pool, _next_spatial)
	_next_spatial = (index + 1) % _spatial_pool.size()
	var voice := _spatial_pool[index]
	voice.stop()
	voice.stream = stream
	voice.global_position = at
	voice.volume_db = clampf(volume_db, -80.0, 6.0)
	voice.pitch_scale = clampf(pitch_scale, 0.01, 4.0)
	voice.play()
	return voice


func play_ui(
	stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0
) -> AudioStreamPlayer:
	if stream == null:
		return null
	var index := _find_voice(_ui_pool, _next_ui)
	_next_ui = (index + 1) % _ui_pool.size()
	var voice := _ui_pool[index]
	voice.stop()
	voice.stream = stream
	voice.volume_db = clampf(volume_db, -80.0, 6.0)
	voice.pitch_scale = clampf(pitch_scale, 0.01, 4.0)
	voice.play()
	return voice


func stop_all_sfx() -> void:
	for pool in [_sfx_pool, _spatial_pool, _ui_pool]:
		for voice in pool:
			voice.stop()
			voice.stream = null
	_next_sfx = 0
	_next_spatial = 0
	_next_ui = 0


func _find_voice(pool: Array, cursor: int) -> int:
	# Prefer a free voice. When full, replace one in round-robin order.
	for offset in pool.size():
		var index := (cursor + offset) % pool.size()
		if not pool[index].playing:
			return index
	return cursor


func _create_flat_pool(
	pool: Array[AudioStreamPlayer], count: int, bus: StringName, mode: ProcessMode
) -> void:
	for index in count:
		var voice := AudioStreamPlayer.new()
		voice.name = "%s%d" % [bus, index]
		voice.bus = bus
		voice.process_mode = mode
		voice.finished.connect(_release_voice.bind(voice))
		add_child(voice)
		pool.append(voice)


func _release_voice(voice: Node) -> void:
	# Finished voices stay in the pool but release their stream reference.
	voice.set(&"stream", null)
