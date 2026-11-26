class_name EnemyHealthBar
extends Control
## A small ink-framed health strip, projected above the artwork at a fixed UI size.

const INK := Color("171212")
const RIM := Color("592b25")
const EMPTY := Color("321b1b")
const BLOOD := Color("c03c35")
const BLOOD_SHADE := Color("852622")
const HIGHLIGHT := Color("ef8061")
const BORDER_PIXELS := 3.0
const BAR_HEIGHT_PIXELS := 11.0
const SHADE_HEIGHT_PIXELS := 2.0

@export_range(16.0, 160.0, 1.0, "suffix:px") var normal_width_pixels: float = 54.0
@export_range(16.0, 160.0, 1.0, "suffix:px") var elite_width_pixels: float = 76.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var hold_seconds: float = 3.0
@export_range(0.05, 3.0, 0.05, "suffix:s") var fade_seconds: float = 0.6
@export_range(0.0, 40.0, 1.0, "suffix:px") var headroom_pixels: float = 12.0
@export_range(0.0, 10.0, 0.1, "suffix:m") var minimum_height_meters: float = 1.5
## Atlas regions include transparent padding above the painted silhouette.
@export_range(0.0, 0.5, 0.01) var artwork_top_padding_ratio: float = 0.2

var _enemy: EnemyBase
var _width_pixels: float = 0.0
var _health_ratio: float = 1.0
var _elapsed_since_hit: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	hide()
	set_process(false)
	_enemy = get_parent() as EnemyBase
	if _enemy == null:
		push_error("EnemyHealthBar requires an EnemyBase parent.")
		return
	# Children are ready before EnemyBase binds its HealthComponent and artwork.
	if _enemy.is_node_ready():
		_bind_enemy()
	else:
		_enemy.ready.connect(_bind_enemy, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	_elapsed_since_hit += maxf(0.0, delta)
	var fade_progress := maxf(0.0, _elapsed_since_hit - hold_seconds) / fade_seconds
	if _enemy.dead or fade_progress >= 1.0:
		_hide_bar()
		return
	modulate.a = 1.0 - fade_progress
	visible = _update_screen_position()


func _draw() -> void:
	var width := _width_pixels
	var height := BAR_HEIGHT_PIXELS
	# Uneven bevels and a warm inner rim echo the game's heavy hand-inked outlines.
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(0, 3),
				Vector2(3, 0),
				Vector2(width - 5, 1),
				Vector2(width - 1, 0),
				Vector2(width, height - 3),
				Vector2(width - 3, height),
				Vector2(3, height - 1),
				Vector2(0, height),
			]
		),
		INK
	)
	draw_rect(Rect2(2, 2, width - 4, height - 4), RIM)
	var inner := Rect2(
		BORDER_PIXELS, BORDER_PIXELS, width - BORDER_PIXELS * 2.0, height - BORDER_PIXELS * 2.0
	)
	draw_rect(inner, EMPTY)
	var fill_width := inner.size.x * _health_ratio
	if fill_width <= 0.0:
		return
	draw_rect(Rect2(inner.position, Vector2(fill_width, inner.size.y)), BLOOD)
	draw_rect(
		Rect2(
			inner.position + Vector2(0, inner.size.y - SHADE_HEIGHT_PIXELS),
			Vector2(fill_width, SHADE_HEIGHT_PIXELS)
		),
		BLOOD_SHADE
	)
	draw_line(inner.position, inner.position + Vector2(fill_width, 0), HIGHLIGHT)


func _bind_enemy() -> void:
	# EliteFeedback is the existing elite marker, independent of HP and model scale.
	_width_pixels = (
		elite_width_pixels
		if _enemy.get_node_or_null("EliteFeedback") is EliteFeedback
		else normal_width_pixels
	)
	size = Vector2(_width_pixels, BAR_HEIGHT_PIXELS)
	_enemy.hp.hp_changed.connect(_on_health_changed)
	_enemy.damaged.connect(_on_damaged)
	_enemy.died.connect(_hide_bar)
	_on_health_changed(_enemy.hp.current_hp, _enemy.hp.get_max_hp())


func _on_health_changed(current_hp: float, maximum_hp: float) -> void:
	_health_ratio = clampf(current_hp / maximum_hp, 0.0, 1.0) if maximum_hp > 0.0 else 0.0
	queue_redraw()


func _on_damaged(_applied_hp: float) -> void:
	if _enemy.dead or not _enemy.hp.is_alive():
		_hide_bar()
		return
	_elapsed_since_hit = 0.0
	modulate.a = 1.0
	visible = _update_screen_position()
	set_process(true)


func _hide_bar() -> void:
	hide()
	set_process(false)


func _update_screen_position() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not _enemy.is_visible_in_tree():
		return false
	var anchor := _enemy.global_position
	anchor.y += minimum_height_meters
	if is_instance_valid(_enemy.visual):
		var top := _enemy.visual.get_top_position()
		if top.is_finite() and top.y > anchor.y:
			anchor = _enemy.global_position.lerp(top, 1.0 - artwork_top_padding_ratio)
	if camera.is_position_behind(anchor):
		return false
	position = (
		camera.unproject_position(anchor)
		- Vector2(_width_pixels * 0.5, BAR_HEIGHT_PIXELS + headroom_pixels)
	)
	return get_viewport_rect().intersects(Rect2(position, size))
