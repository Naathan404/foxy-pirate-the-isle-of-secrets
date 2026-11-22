class_name WorldMap
extends CanvasLayer
## Full-screen map opened with M. The world layer shows every biome; choosing an open biome
## zooms into its rooms. GameManager owns the tree pause (State.WORLD_MAP); this node only
## asks for it, like the pause menu.

enum Phase { CLOSED, OPENING, WORLD, ZOOMING, BIOME, CLOSING }

const TOGGLE_ACTION := &"open_world_map"
const CANCEL_ACTION := &"ui_cancel"
const ACCEPT_ACTION := &"ui_accept"
const NAVIGATION_ACTIONS: Dictionary[StringName, Vector2i] = {
	&"ui_left": Vector2i.LEFT,
	&"ui_right": Vector2i.RIGHT,
	&"ui_up": Vector2i.UP,
	&"ui_down": Vector2i.DOWN,
}
const INK_PROGRESS_PARAM := &"progress"
const INK_HIDDEN := 0.0
const INK_SHOWN := 1.0
const WORLD_TITLE := "World Map"
const ROOMS_FORMAT := "%d / %d rooms explored"
const LOCKED_TEXT := "Locked - the way is not open yet"
const UNCHARTED_TEXT := "Uncharted waters"
const UNCHARTED_NAME := "???"
const SUBTITLE_FORMAT := "%s  -  %s"
const WORLD_HINT := "Arrows  Select      Enter  Explore      M / Esc  Close"
const BIOME_HINT := "Esc / Right click  Back      M  Close"
const DENIED_SHAKE_COUNT := 2.0
## Keyboard focus prefers islands straight ahead over ones off to the side.
const SIDEWAYS_COST_WEIGHT := 2

@export_group("Motion")
@export_range(0.1, 1.5, 0.01, "suffix:s") var ink_open_seconds: float = 0.5
@export_range(0.05, 1.0, 0.01, "suffix:s") var ink_close_seconds: float = 0.3
@export_range(0.05, 1.0, 0.01, "suffix:s") var content_fade_seconds: float = 0.25
@export_range(0.1, 1.5, 0.01, "suffix:s") var zoom_seconds: float = 0.45
@export_range(0.0, 40.0, 1.0, "suffix:px") var denied_shake_pixels: float = 10.0
@export_range(0.05, 0.6, 0.01, "suffix:s") var denied_shake_seconds: float = 0.24

var _phase: Phase = Phase.CLOSED
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _tween: Tween
var _shake_tween: Tween

@onready var _root: Control = %Root
@onready var _background: TextureRect = %Background
@onready var _content: Control = %Content
@onready var _canvas: WorldMapCanvas = %Canvas
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _hint: Label = %Hint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_canvas.biome_hovered.connect(_on_biome_hovered)
	_canvas.biome_pressed.connect(_on_biome_pressed)
	_canvas.back_pressed.connect(_go_back)


# Unhandled, like the pause menu: panels that consume a key first keep it.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	match _phase:
		Phase.CLOSED:
			if event.is_action_pressed(TOGGLE_ACTION) and _open():
				get_viewport().set_input_as_handled()
		Phase.WORLD, Phase.BIOME:
			if _handle_open_input(event):
				get_viewport().set_input_as_handled()
		_:
			# Opening, zooming or closing: swallow map keys so they cannot stack up.
			if event.is_action_pressed(TOGGLE_ACTION) or event.is_action_pressed(CANCEL_ACTION):
				get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_kill_tweens()
	if _phase == Phase.CLOSED:
		return
	Input.mouse_mode = _previous_mouse_mode
	get_node("/root/GameManager").exit_world_map()


func is_open() -> bool:
	return _phase != Phase.CLOSED


func _handle_open_input(event: InputEvent) -> bool:
	if event.is_action_pressed(TOGGLE_ACTION):
		_close()
		return true
	if event.is_action_pressed(CANCEL_ACTION):
		_go_back()
		return true
	if _phase != Phase.WORLD:
		return false
	if event.is_action_pressed(ACCEPT_ACTION):
		_enter_biome(_canvas.focused_index)
		return true
	for action: StringName in NAVIGATION_ACTIONS:
		if event.is_action_pressed(action):
			_move_focus(NAVIGATION_ACTIONS[action])
			return true
	return false


func _open() -> bool:
	var player := get_parent() as Player
	if player != null and (player.dead or player.is_gameplay_input_blocked()):
		return false
	var manager := get_node("/root/GameManager")
	if _canvas.world_map == null or not manager.enter_world_map():
		return false
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_canvas.show_progress(manager.map_progress, _unlocked_biomes(manager))
	_canvas.zoom_progress = 0.0
	_canvas.zoom_index = WorldMapCanvas.NO_BIOME
	_canvas.focused_index = _initial_focus()
	_show_world_header()

	_phase = Phase.OPENING
	_root.show()
	_set_ink_progress(INK_HIDDEN)
	_content.modulate.a = 0.0
	_kill_tweens()
	_tween = _create_tween()
	var ink := _tween.tween_method(_set_ink_progress, INK_HIDDEN, INK_SHOWN, ink_open_seconds)
	ink.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_content, "modulate:a", 1.0, content_fade_seconds)
	_tween.chain().tween_callback(_set_phase.bind(Phase.WORLD))
	return true


func _close() -> void:
	_phase = Phase.CLOSING
	_kill_tweens()
	_tween = _create_tween()
	var ink := _tween.tween_method(
		_set_ink_progress, _ink_progress(), INK_HIDDEN, ink_close_seconds
	)
	ink.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_content, "modulate:a", 0.0, content_fade_seconds)
	_tween.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	_root.hide()
	_phase = Phase.CLOSED
	Input.mouse_mode = _previous_mouse_mode
	get_node("/root/GameManager").exit_world_map()


## Esc and right click step back one layer: rooms -> world -> closed.
func _go_back() -> void:
	match _phase:
		Phase.BIOME:
			_zoom_to(0.0, Phase.WORLD)
			_show_world_header()
		Phase.WORLD:
			_close()


func _enter_biome(index: int) -> void:
	if index == WorldMapCanvas.NO_BIOME:
		return
	var status := _canvas.get_status(index)
	if status in [BiomeMapData.Status.UNCHARTED, BiomeMapData.Status.LOCKED]:
		_shake_denied()
		return
	_canvas.focused_index = index
	_canvas.zoom_index = index
	_zoom_to(1.0, Phase.BIOME)
	_show_biome_header(index)


func _zoom_to(target: float, arrival: Phase) -> void:
	_phase = Phase.ZOOMING
	_kill_tweens()
	_tween = _create_tween()
	var zoom := _tween.tween_property(_canvas, "zoom_progress", target, zoom_seconds)
	zoom.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_callback(_set_phase.bind(arrival))


## Picks the closest biome whose island lies in `direction` from the focused one.
func _move_focus(direction: Vector2i) -> void:
	if _canvas.focused_index == WorldMapCanvas.NO_BIOME:
		return
	var biomes := _canvas.world_map.biomes
	var from := biomes[_canvas.focused_index].world_cell
	var best := WorldMapCanvas.NO_BIOME
	var best_cost := INF
	for index in biomes.size():
		var offset := biomes[index].world_cell - from
		var forward := offset.x * direction.x + offset.y * direction.y
		if forward <= 0:
			continue
		var sideways := absi(offset.x * direction.y) + absi(offset.y * direction.x)
		var cost := float(forward + sideways * SIDEWAYS_COST_WEIGHT)
		if cost < best_cost:
			best_cost = cost
			best = index
	if best != WorldMapCanvas.NO_BIOME:
		_focus(best)


func _focus(index: int) -> void:
	if index == _canvas.focused_index:
		return
	_canvas.focused_index = index
	InventoryMenuFx.pop(_title)
	_show_world_header()


func _on_biome_hovered(index: int) -> void:
	if _phase == Phase.WORLD:
		_focus(index)


func _on_biome_pressed(index: int) -> void:
	if _phase == Phase.WORLD:
		_enter_biome(index)


func _show_world_header() -> void:
	_title.text = WORLD_TITLE
	var index := _canvas.focused_index
	if index == WorldMapCanvas.NO_BIOME:
		_subtitle.text = ""
	else:
		var biome := _canvas.world_map.biomes[index]
		var status := _canvas.get_status(index)
		var biome_name := UNCHARTED_NAME
		if status != BiomeMapData.Status.UNCHARTED:
			biome_name = biome.display_name
		_subtitle.text = SUBTITLE_FORMAT % [biome_name, _status_text(index, status)]
	_hint.text = WORLD_HINT


func _show_biome_header(index: int) -> void:
	_title.text = _canvas.world_map.biomes[index].display_name
	_subtitle.text = _status_text(index, _canvas.get_status(index))
	_hint.text = BIOME_HINT


func _status_text(index: int, status: BiomeMapData.Status) -> String:
	match status:
		BiomeMapData.Status.UNCHARTED:
			return UNCHARTED_TEXT
		BiomeMapData.Status.LOCKED:
			return LOCKED_TEXT
	var biome := _canvas.world_map.biomes[index]
	var progress := _canvas.get_progress()
	return ROOMS_FORMAT % [biome.count_visited(progress), biome.count_known(progress)]


func _initial_focus() -> int:
	var current := _canvas.get_current_biome_index()
	if current != WorldMapCanvas.NO_BIOME:
		return current
	return 0 if not _canvas.world_map.biomes.is_empty() else WorldMapCanvas.NO_BIOME


func _unlocked_biomes(manager: Node) -> Dictionary[StringName, bool]:
	var unlocked: Dictionary[StringName, bool] = {}
	for biome: BiomeMapData in _canvas.world_map.biomes:
		unlocked[biome.biome_id] = (
			biome.unlock_flag.is_empty() or manager.has_story_flag(biome.unlock_flag)
		)
	return unlocked


## A locked or uncharted island shakes its head instead of opening.
func _shake_denied() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		return
	_shake_tween = _create_tween()
	_shake_tween.tween_method(_apply_shake, 0.0, 1.0, denied_shake_seconds)


func _apply_shake(progress: float) -> void:
	var wave := sin(progress * TAU * DENIED_SHAKE_COUNT)
	_canvas.shake_offset_pixels = wave * denied_shake_pixels * (1.0 - progress)


func _set_phase(phase: Phase) -> void:
	_phase = phase


func _create_tween() -> Tween:
	var tween := create_tween().set_parallel()
	tween.set_ignore_time_scale(true)
	return tween


func _set_ink_progress(progress: float) -> void:
	(_background.material as ShaderMaterial).set_shader_parameter(INK_PROGRESS_PARAM, progress)


func _ink_progress() -> float:
	return float((_background.material as ShaderMaterial).get_shader_parameter(INK_PROGRESS_PARAM))


func _kill_tweens() -> void:
	for tween: Tween in [_tween, _shake_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_tween = null
	_shake_tween = null
	_canvas.shake_offset_pixels = 0.0
