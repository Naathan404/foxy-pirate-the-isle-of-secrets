class_name VoidFallSequence
extends CanvasLayer
## One fall into the void, played by BaseRoom. The camera holds still while Foxy drops away
## and the darkness closes in on her. Behind black she is put back at a door of the same room
## (BaseRoom.get_void_respawn_position) with a small HP cost, then the darkness opens on her
## there. If that cost would kill her, she dies instead and the normal death flow takes her
## to the campfire; this layer then stays black until that transition replaces the room.

signal finished

const IRIS_SHADER: Shader = preload("res://world/components/void_fall_iris.gdshader")
## Just under the scene transition overlay (128), which covers this layer after a death.
const OVERLAY_LAYER := 120
## Circle radius, in screen heights, that leaves the whole screen open.
const OPEN_RADIUS := 1.5
## Height above Foxy's feet the circle centres on.
const FOCUS_HEIGHT_METERS := 0.8
## Share of the screen kept between the circle's centre and each edge.
const SCREEN_INSET := 0.1
## Physics ticks given to Foxy to settle on the floor before the screen opens.
const LANDING_TICKS := 2

var close_seconds: float = 0.85
var hold_seconds: float = 0.25
var open_seconds: float = 0.5
var fall_damage: float = 1.0

var _room: BaseRoom
var _player: Player
var _material: ShaderMaterial


func _init(room: BaseRoom, player: Player) -> void:
	_room = room
	_player = player
	layer = OVERLAY_LAYER
	name = "VoidFallSequence"
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = IRIS_SHADER
	_material.set_shader_parameter("radius", OPEN_RADIUS)
	rect.material = _material
	add_child(rect)


func _ready() -> void:
	_run()


func _process(_delta: float) -> void:
	_center_on_player()


func _run() -> void:
	var fall_point := _player.global_position
	_player.begin_void_fall()
	var camera := _player.camera as BoundedFollowCamera3D
	if is_instance_valid(camera):
		camera.begin_dialogue_override()
	_center_on_player()
	await _tween_iris(OPEN_RADIUS, 0.0, close_seconds, Tween.EASE_IN)
	_material.set_shader_parameter("darkness", 1.0)
	await get_tree().create_timer(hold_seconds, false).timeout
	if not is_instance_valid(_player):
		return
	var ground_mask := _player.collision_mask & ~CombatLayers.PLAYER_BOUNDARY
	var respawn := _room.get_void_respawn_position(fall_point, ground_mask)
	_player.finish_void_fall(respawn, fall_damage)
	if _player.dead:
		# The death flow fades to its campfire behind this black layer.
		return
	if is_instance_valid(camera):
		camera.snap_to_follow()
	for _tick in LANDING_TICKS:
		await get_tree().physics_frame
	_center_on_player()
	_material.set_shader_parameter("darkness", 0.0)
	await _tween_iris(0.0, OPEN_RADIUS, open_seconds, Tween.EASE_OUT)
	finished.emit()
	queue_free()


func _tween_iris(from: float, to: float, seconds: float, ease_type: Tween.EaseType) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	tween.tween_method(_set_radius, from, to, maxf(seconds, 0.01))
	await tween.finished


func _set_radius(radius: float) -> void:
	_material.set_shader_parameter("radius", radius)


func _center_on_player() -> void:
	if not is_instance_valid(_player):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var focus := (
		_player.get_global_transform_interpolated().origin + Vector3.UP * FOCUS_HEIGHT_METERS
	)
	if camera.is_position_behind(focus):
		return
	var screen := camera.unproject_position(focus) / get_viewport().get_visible_rect().size
	# Foxy may already be under the bottom edge; the circle still closes on screen.
	var inset := Vector2.ONE * SCREEN_INSET
	_material.set_shader_parameter("center", screen.clamp(inset, Vector2.ONE - inset))
