class_name MainMenu
extends Control
## Entry scene: Play starts the gameplay scene through GameManager, Quit closes the game.
## Ambient effects (embers, dust, parallax, title glint, vignette) live here and never touch
## gameplay state, so they stay on screen without affecting the transition.

const INK_PROGRESS_PARAM := &"progress"
const INK_HIDDEN := 0.0
const INK_SHOWN := 1.0
const SWEEP_PARAM := &"sweep"
const BACKGROUND_BASE_SCALE := 1.06
const PARALLAX_SMOOTHING := 4.0
const HALF_RATIO := 0.5
const EMBER_BAND_HEIGHT_PIXELS := 14.0
const GLOW_PULSE_SPEED := 1.6
const GLOW_MIN_ALPHA := 0.35
const GLOW_MAX_ALPHA := 0.8

## First gameplay scene of a run. Progress is kept in memory only, so Play always starts here.
@export_file("*.tscn") var gameplay_scene: String = "res://world/biomes/hub/map/castaway_cove.tscn"
@export_group("Intro")
@export_range(0.1, 2.0, 0.05, "suffix:s") var ink_open_seconds: float = 0.9
@export_range(0.05, 1.0, 0.05, "suffix:s") var title_fade_seconds: float = 0.5
@export_range(1.0, 1.6, 0.01) var title_slam_scale: float = 1.2
@export_range(0.1, 1.5, 0.05, "suffix:s") var title_slam_seconds: float = 0.6
@export_range(0.0, 1.0, 0.05, "suffix:s") var buttons_delay_seconds: float = 0.45
@export_range(1.0, 1.3, 0.01) var button_lift: float = 1.06
@export_group("Ambient")
@export_range(0.0, 40.0, 1.0, "suffix:px") var parallax_pixels: float = 14.0
@export_range(0.0, 0.08, 0.005) var breathe_amount: float = 0.025
@export_range(2.0, 30.0, 0.5, "suffix:s") var breathe_seconds: float = 12.0
@export_range(1.0, 20.0, 0.5, "suffix:s") var glint_interval_seconds: float = 5.0
@export_range(0.3, 3.0, 0.1, "suffix:s") var glint_seconds: float = 1.4
@export_group("Play Flash")
@export_range(0.0, 1.0, 0.05) var flash_alpha: float = 0.5
@export_range(0.05, 1.0, 0.05, "suffix:s") var flash_seconds: float = 0.3

var _intro_tween: Tween
var _flash_tween: Tween
var _starting: bool = false
var _ready_for_feedback: bool = false
var _clock: float = 0.0
var _glint_clock: float = 0.0
var _parallax: Vector2 = Vector2.ZERO

@onready var _background: TextureRect = %Background
@onready var _title_block: Control = %TitleBlock
@onready var _title: Label = %Title
@onready var _title_glow: Label = %TitleGlow
@onready var _embers: CPUParticles2D = %Embers
@onready var _dust: CPUParticles2D = %Dust
@onready var _flash: ColorRect = %Flash
@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	# A fresh session starts at the menu; saved files are never touched.
	get_node("/root/GameManager").reset_session()
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for button: Button in [_play_button, _quit_button]:
		InventoryHoverFeedback.attach(button, null, button_lift)
		button.mouse_entered.connect(_on_button_highlighted.bind(button))
		button.focus_entered.connect(_on_button_highlighted.bind(button))
	_title_glow.text = _title.text
	get_viewport().size_changed.connect(_layout_particles)
	_layout_particles()
	_background.resized.connect(_update_pivots)
	_update_pivots()
	_play_intro()
	_play_button.grab_focus()


func _process(delta: float) -> void:
	_clock += delta
	_update_background(delta)
	_update_glow()
	_update_glint(delta)


func _exit_tree() -> void:
	for tween: Tween in [_intro_tween, _flash_tween]:
		if tween != null and tween.is_valid():
			tween.kill()


func _play_intro() -> void:
	_set_ink_progress(INK_HIDDEN)
	_title_block.modulate.a = 0.0
	_title_block.scale = Vector2.ONE * title_slam_scale
	_set_glint(1.0)
	_intro_tween = create_tween().set_parallel()
	_intro_tween.set_ignore_time_scale(true)
	var ink := _intro_tween.tween_method(_set_ink_progress, INK_HIDDEN, INK_SHOWN, ink_open_seconds)
	ink.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_title_block, "modulate:a", 1.0, title_fade_seconds)
	var slam := _intro_tween.tween_property(_title_block, "scale", Vector2.ONE, title_slam_seconds)
	slam.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(_on_title_landed).set_delay(title_slam_seconds)
	(
		_intro_tween
		. tween_callback(InventoryMenuFx.stagger_in.bind([_play_button, _quit_button]))
		. set_delay(buttons_delay_seconds)
	)


func _on_title_landed() -> void:
	_ready_for_feedback = true
	_glint_clock = 0.0
	InventoryMenuFx.burst(_title)


func _update_background(delta: float) -> void:
	var screen := get_viewport_rect().size
	var target := (get_viewport().get_mouse_position() / screen - Vector2.ONE * HALF_RATIO) * 2.0
	target = target.clamp(-Vector2.ONE, Vector2.ONE)
	_parallax = _parallax.lerp(target, 1.0 - exp(-delta * PARALLAX_SMOOTHING))
	var breathe := sin(_clock * TAU / breathe_seconds) * breathe_amount
	_background.scale = Vector2.ONE * (BACKGROUND_BASE_SCALE + breathe)
	_background.position = -_parallax * parallax_pixels


func _update_glow() -> void:
	var pulse := (sin(_clock * GLOW_PULSE_SPEED) + 1.0) * HALF_RATIO
	_title_glow.modulate.a = lerpf(GLOW_MIN_ALPHA, GLOW_MAX_ALPHA, pulse) * _title_block.modulate.a


func _update_glint(delta: float) -> void:
	if not _ready_for_feedback:
		return
	_glint_clock += delta
	_set_glint(clampf(_glint_clock / glint_seconds, 0.0, 1.0))
	if _glint_clock >= glint_interval_seconds:
		_glint_clock = 0.0


func _set_glint(progress: float) -> void:
	(_title.material as ShaderMaterial).set_shader_parameter(SWEEP_PARAM, progress)


func _update_pivots() -> void:
	_background.pivot_offset = _background.size * HALF_RATIO
	_title_block.pivot_offset = _title_block.size * HALF_RATIO


## Embers rise from the bottom edge; dust drifts over the whole screen.
func _layout_particles() -> void:
	var screen := get_viewport_rect().size
	_embers.position = Vector2(screen.x * HALF_RATIO, screen.y + EMBER_BAND_HEIGHT_PIXELS)
	_embers.emission_rect_extents = Vector2(screen.x * HALF_RATIO, EMBER_BAND_HEIGHT_PIXELS)
	_dust.position = screen * HALF_RATIO
	_dust.emission_rect_extents = screen * HALF_RATIO


func _set_ink_progress(progress: float) -> void:
	(_background.material as ShaderMaterial).set_shader_parameter(INK_PROGRESS_PARAM, progress)


func _on_button_highlighted(button: Button) -> void:
	if _ready_for_feedback and not _starting and not button.disabled:
		InventoryMenuFx.burst(button)


func _on_play_pressed() -> void:
	if _starting:
		return
	_starting = true
	_set_buttons_disabled(true)
	InventoryMenuFx.burst(_play_button)
	_play_flash()
	if not get_node("/root/GameManager").change_scene(gameplay_scene):
		push_error("MainMenu: cannot start %s" % gameplay_scene)
		_starting = false
		_set_buttons_disabled(false)
		_play_button.grab_focus()


func _play_flash() -> void:
	_flash.modulate.a = flash_alpha
	_flash_tween = create_tween()
	_flash_tween.set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, flash_seconds)


func _on_quit_pressed() -> void:
	if _starting:
		return
	_starting = true
	get_tree().quit()


func _set_buttons_disabled(disabled: bool) -> void:
	_play_button.disabled = disabled
	_quit_button.disabled = disabled
