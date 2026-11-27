class_name CharmProcFeedback
extends Control
## Presentation of one HUD charm slot. It follows the slot's CharmRuntime and shows:
## - a proc (`proc_triggered`): icon flash and punch, frame bounce, a diamond ring in the proc
##   colour and the proc word above the slot;
## - a cast of an Active Charm (`activated`): the same, stronger, with a second ring and the
##   charm's name, all in the charm's own colour (taken from its icon);
## - a press that could not cast (`activation_rejected`): the slot shakes, the icon flashes red
##   and a small word says why;
## - the end of a cooldown (`cooldown_ready`): a short glint and a thin ring.
## One restartable animation per slot, so repeated events never stack scale or labels.
##
## This node sits above the whole HUD (`z_index`), and the slot is lifted while it animates, so
## neither the word nor the grown icon is hidden behind the neighbouring slots.

## Events closer together than this replay nothing; they would only restart the same pop.
const MIN_REPLAY_MSEC := 120
## Draw order of the slot while it animates, just above its neighbours.
const LIFTED_SLOT_Z := 1
## Draw order of the icon while it punches: above the slot's own cooldown shade, which starts
## the moment a charm is cast and would otherwise dim the flash.
const LIFTED_ICON_Z := 1
## Over 1 brightens past white: the flash an icon starts a proc or cast with.
const FLASH_COLOR := Color(2.4, 2.4, 2.4, 1.0)
## Space kept between the word and the screen edge; the Q slot sits near the left edge.
const SCREEN_MARGIN_PIXELS := 6.0
## Used when a charm icon has no clear colour of its own.
const FALLBACK_ACCENT := Color(1.0, 0.82, 0.4)
const REJECT_COLOR := Color(1.0, 0.36, 0.3)
const REJECT_WORDS := {
	CharmRuntime.REJECTED_COOLDOWN: "NOT READY",
	CharmRuntime.REJECTED_COST: "NO SP",
}
## Icon pixels below this saturation or alpha do not count towards the accent colour.
const ACCENT_MIN_SATURATION := 0.35
const ACCENT_MIN_ALPHA := 0.5
## Icons are sampled on a coarse grid; the accent only needs the overall hue.
const ACCENT_SAMPLE_STEP := 4

## Accent colour per icon texture, shared by every slot.
static var _accent_cache: Dictionary = {}

@export_group("Icon")
@export_range(1.0, 2.0, 0.01) var punch_scale: float = 1.45
@export_range(1.0, 2.0, 0.01) var cast_punch_scale: float = 1.6
@export_range(1.0, 1.5, 0.01) var ready_punch_scale: float = 1.18
@export_range(0.01, 0.3, 0.005, "suffix:s") var punch_in_seconds: float = 0.07
@export_range(0.05, 0.8, 0.01, "suffix:s") var punch_out_seconds: float = 0.3
@export_range(1.0, 1.4, 0.01) var frame_punch_scale: float = 1.12
@export_range(0.05, 1.0, 0.01, "suffix:s") var flash_seconds: float = 0.4

@export_group("Ring")
@export_range(1.0, 3.0, 0.05) var ring_end_scale: float = 1.75
@export_range(0.05, 1.5, 0.01, "suffix:s") var ring_seconds: float = 0.45
## Delay of the second ring of a cast after the first.
@export_range(0.0, 0.5, 0.01, "suffix:s") var second_ring_delay: float = 0.12

@export_group("Word")
@export_range(0.1, 1.0, 0.05) var word_start_scale: float = 0.45
@export_range(1.0, 1.6, 0.01) var word_pop_scale: float = 1.2
## Size of a rejection word compared with a proc or cast word.
@export_range(0.3, 1.0, 0.05) var reject_word_scale: float = 0.75
@export_range(0.0, 60.0, 1.0, "suffix:px") var word_rise_pixels: float = 18.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var word_hold_seconds: float = 0.65
@export_range(0.05, 1.5, 0.05, "suffix:s") var word_fade_seconds: float = 0.35

@export_group("Rejection")
@export_range(0.0, 20.0, 0.5, "suffix:px") var shake_pixels: float = 5.0
@export_range(0.05, 0.6, 0.01, "suffix:s") var shake_seconds: float = 0.24

var _icon: TextureRect
var _slot: Control
var _runtime: CharmRuntime
var _rest_scale: Vector2 = Vector2.ONE
var _slot_rest_scale: Vector2 = Vector2.ONE
var _slot_rest_position: Vector2 = Vector2.ZERO
var _slot_rest_z: int = 0
var _tween: Tween
var _shake_tween: Tween
var _last_event_msec: int = -1000

@onready var _ring: Panel = $Ring
@onready var _ring_2: Panel = $Ring2
@onready var _label: Label = $Label
@onready var _label_origin: Vector2 = _label.position


func _exit_tree() -> void:
	bind_runtime(null)


func bind_icon(icon: TextureRect) -> void:
	_icon = icon
	_rest_scale = icon.scale
	_slot = icon.get_parent() as Control
	if _slot != null:
		_slot_rest_scale = _slot.scale
		_slot_rest_position = _slot.position
		_slot_rest_z = _slot.z_index


## Follows the charm now in this slot (null when empty); the previous one is let go.
func bind_runtime(runtime: CharmRuntime) -> void:
	if runtime == _runtime:
		return
	if _runtime != null:
		_runtime.proc_triggered.disconnect(play)
		_runtime.activated.disconnect(_on_activated)
		_runtime.activation_rejected.disconnect(_on_activation_rejected)
		_runtime.cooldown_ready.disconnect(_on_cooldown_ready)
	_runtime = runtime
	if _runtime != null:
		_runtime.proc_triggered.connect(play)
		_runtime.activated.connect(_on_activated)
		_runtime.activation_rejected.connect(_on_activation_rejected)
		_runtime.cooldown_ready.connect(_on_cooldown_ready)
	if is_inside_tree():
		reset()


## A proc: `message` in `color`.
func play(message: String, color: Color) -> void:
	if not _begin():
		return
	_punch_icon(color, punch_scale)
	_punch_frame()
	_spread_ring(_ring, color, 0.0)
	_pop_word(message, color, 1.0)
	_tween.chain().tween_callback(_finish)


## Casting an Active Charm: the charm's name in its own colour, with a double ring.
func play_cast(message: String, color: Color) -> void:
	if not _begin():
		return
	_punch_icon(color, cast_punch_scale)
	_punch_frame()
	_spread_ring(_ring, color, 0.0)
	_spread_ring(_ring_2, color, second_ring_delay)
	_pop_word(message, color, 1.0)
	_tween.chain().tween_callback(_finish)


## A press that did nothing: shake, red flash and a short reason.
func play_rejected(message: String) -> void:
	if not _begin():
		return
	_icon.modulate = REJECT_COLOR
	_tween.tween_property(_icon, "modulate", Color.WHITE, shake_seconds * 1.5)
	_shake_slot()
	_pop_word(message, REJECT_COLOR, reject_word_scale)
	_tween.chain().tween_callback(_finish)


## The cooldown just ended: a short glint, no word.
func play_ready(color: Color) -> void:
	if not _begin():
		return
	_punch_icon(color, ready_punch_scale)
	_spread_ring(_ring, color, 0.0)
	_tween.chain().tween_callback(_finish)


func reset() -> void:
	for tween: Tween in [_tween, _shake_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_finish()
	_last_event_msec = -1000


## Starts a new animation over the last one; false when there is nothing to animate.
func _begin() -> bool:
	if not is_instance_valid(_icon) or not _icon.visible:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_event_msec < MIN_REPLAY_MSEC:
		return false
	reset()
	_last_event_msec = now
	if is_instance_valid(_slot):
		_slot.z_index = _slot_rest_z + LIFTED_SLOT_Z
	_tween = create_tween().set_ignore_time_scale(true).set_parallel()
	return true


func _on_activated() -> void:
	play_cast(_runtime.definition.display_name.to_upper(), _accent_color())


func _on_activation_rejected(reason: StringName) -> void:
	play_rejected(REJECT_WORDS.get(reason, "NOT READY"))


func _on_cooldown_ready() -> void:
	play_ready(_accent_color())


func _punch_icon(color: Color, peak_scale: float) -> void:
	_icon.pivot_offset = _icon.size * 0.5
	_icon.modulate = FLASH_COLOR
	_icon.z_index = LIFTED_ICON_Z
	_tween.tween_callback(_lower_icon).set_delay(punch_in_seconds + punch_out_seconds)
	(
		_tween
		. tween_property(_icon, "scale", _rest_scale * peak_scale, punch_in_seconds)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. tween_property(_icon, "scale", _rest_scale, punch_out_seconds)
		. set_delay(punch_in_seconds)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)
	# White flash, then a moment in the colour, then back to normal.
	var tint := color.lightened(0.35)
	_tween.tween_property(_icon, "modulate", tint, flash_seconds * 0.35)
	_tween.tween_property(_icon, "modulate", Color.WHITE, flash_seconds * 0.65).set_delay(
		flash_seconds * 0.35
	)


func _punch_frame() -> void:
	if not is_instance_valid(_slot):
		return
	_slot.pivot_offset = _slot.size * 0.5
	(
		_tween
		. tween_property(_slot, "scale", _slot_rest_scale * frame_punch_scale, punch_in_seconds)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. tween_property(_slot, "scale", _slot_rest_scale, punch_out_seconds)
		. set_delay(punch_in_seconds)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _shake_slot() -> void:
	if not is_instance_valid(_slot):
		return
	var step := shake_seconds / 5.0
	_shake_tween = create_tween().set_ignore_time_scale(true)
	for offset: float in [1.0, -1.0, 0.6, -0.6, 0.0]:
		_shake_tween.tween_property(
			_slot, "position:x", _slot_rest_position.x + offset * shake_pixels, step
		)
	_tween.tween_interval(shake_seconds)


func _spread_ring(ring: Panel, color: Color, delay: float) -> void:
	ring.scale = Vector2.ONE * 0.9
	ring.self_modulate = Color(color.lightened(0.2), 0.0 if delay > 0.0 else 1.0)
	ring.show()
	if delay > 0.0:
		_tween.tween_property(ring, "self_modulate:a", 1.0, 0.0).set_delay(delay)
	(
		_tween
		. tween_property(ring, "scale", Vector2.ONE * ring_end_scale, ring_seconds)
		. set_delay(delay)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. tween_property(ring, "self_modulate:a", 0.0, ring_seconds)
		. set_delay(delay)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)


func _pop_word(message: String, color: Color, word_scale: float) -> void:
	_label.text = message
	_label.add_theme_color_override("font_color", color.lightened(0.25))
	var origin := _label_origin + Vector2(_screen_overhang(message, word_scale), 0.0)
	_label.position = origin
	_label.scale = Vector2.ONE * word_start_scale * word_scale
	_label.modulate = Color.WHITE
	_label.show()
	var pop_seconds := punch_in_seconds * 1.5
	(
		_tween
		. tween_property(_label, "scale", Vector2.ONE * word_pop_scale * word_scale, pop_seconds)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. tween_property(_label, "scale", Vector2.ONE * word_scale, punch_out_seconds * 0.5)
		. set_delay(pop_seconds)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	var total := word_hold_seconds + word_fade_seconds
	(
		_tween
		. tween_property(_label, "position", origin + Vector2.UP * word_rise_pixels, total)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. tween_property(_label, "modulate:a", 0.0, word_fade_seconds)
		. set_delay(word_hold_seconds)
	)


## Sideways shift, in this node's pixels, that keeps the centred word inside the screen.
func _screen_overhang(message: String, word_scale: float) -> float:
	var font := _label.get_theme_font(&"font")
	var font_size := _label.get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# The word grows past its rest size while it pops; leave room for that too.
	var half_width := text_width * 0.5 * word_pop_scale * word_scale
	var to_screen := get_global_transform_with_canvas()
	var centre := to_screen * (_label_origin + _label.size * 0.5)
	var screen_width := get_viewport_rect().size.x
	var shift := 0.0
	if centre.x - half_width < SCREEN_MARGIN_PIXELS:
		shift = SCREEN_MARGIN_PIXELS - (centre.x - half_width)
	elif centre.x + half_width > screen_width - SCREEN_MARGIN_PIXELS:
		shift = screen_width - SCREEN_MARGIN_PIXELS - (centre.x + half_width)
	return shift / maxf(to_screen.get_scale().x, 0.001)


## The charm's own colour: the average of the clearly coloured pixels of its icon.
func _accent_color() -> Color:
	if _runtime == null or _runtime.definition == null or _runtime.definition.sprite == null:
		return FALLBACK_ACCENT
	var texture := _runtime.definition.sprite
	if not _accent_cache.has(texture):
		_accent_cache[texture] = _measure_accent(texture)
	return _accent_cache[texture]


static func _measure_accent(texture: Texture2D) -> Color:
	var image := texture.get_image()
	if image == null:
		return FALLBACK_ACCENT
	if image.is_compressed():
		image.decompress()
	var total := Color(0, 0, 0, 0)
	var weight := 0.0
	for y in range(0, image.get_height(), ACCENT_SAMPLE_STEP):
		for x in range(0, image.get_width(), ACCENT_SAMPLE_STEP):
			var pixel := image.get_pixel(x, y)
			if pixel.a < ACCENT_MIN_ALPHA or pixel.s < ACCENT_MIN_SATURATION:
				continue
			# Vivid pixels speak for the charm more than muted ones.
			total += pixel * pixel.s
			weight += pixel.s
	if weight <= 0.0:
		return FALLBACK_ACCENT
	var accent := Color(total.r / weight, total.g / weight, total.b / weight)
	# Keep it bright enough to read on the dark HUD.
	return Color.from_hsv(accent.h, clampf(accent.s, 0.45, 0.85), maxf(accent.v, 0.85))


func _lower_icon() -> void:
	if is_instance_valid(_icon):
		_icon.z_index = 0


func _finish() -> void:
	_lower_icon()
	if is_instance_valid(_icon):
		_icon.scale = _rest_scale
		_icon.modulate = Color.WHITE
	if is_instance_valid(_slot):
		_slot.z_index = _slot_rest_z
		_slot.scale = _slot_rest_scale
		_slot.position = _slot_rest_position
	_ring.hide()
	_ring_2.hide()
	_label.hide()
