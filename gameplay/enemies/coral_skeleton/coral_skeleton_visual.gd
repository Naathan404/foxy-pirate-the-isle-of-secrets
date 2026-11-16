extends EnemyVisual

const IDLE_SHEET := preload("res://assets/sprites/enemies/coral_skeleton/idle_6.png")
const WALK_SHEET := preload("res://assets/sprites/enemies/coral_skeleton/walk_6.png")
const WALK_OPPOSITE_SHEET := preload(
	"res://assets/sprites/enemies/coral_skeleton/walk_opposite_6.png"
)
const SLEEP_SHEET := preload("res://assets/sprites/enemies/coral_skeleton/sleep_6.png")
const SHOOT_SHEET := preload("res://assets/sprites/enemies/coral_skeleton/shoot_6.png")
const HIT_DEATH_SHEET := preload("res://assets/sprites/enemies/coral_skeleton/hit_death_6.png")
const BONE_CURL_SHEET := preload("res://assets/sprites/enemies/coral_skeleton/bone_curl_6.png")
const DEATH_ANIMATION := &"coral_death"
const DEATH_DURATION := 0.8
const BONE_CURL_DURATION := 0.75
const BONE_REASSEMBLE_DURATION := 0.75
const SHOT_FEEDBACK_DURATION := 0.24

@export_range(0.005, 0.03, 0.0005) var character_pixel_size := 0.012
@export_range(1.0, 24.0, 0.5) var idle_fps := 5.0
@export_range(1.0, 24.0, 0.5) var walk_fps := 12.0
@export_range(0.5, 24.0, 0.5) var sleep_fps := 3.0

@export_group("Sleep indicator")
@export var show_sleep_indicator := true
@export_range(2, 3, 1) var sleep_indicator_count := 3
@export_range(0.3, 10.0, 0.1, "suffix:s") var sleep_indicator_lifetime := 2.4
@export_range(0.0, 5.0, 0.1, "suffix:m") var sleep_indicator_rise := 1.0
@export_range(-2.0, 2.0, 0.05, "suffix:m") var sleep_indicator_drift := 0.4
@export_range(0.1, 3.0, 0.05) var sleep_indicator_start_scale := 0.65
@export_range(0.1, 3.0, 0.05) var sleep_indicator_end_scale := 1.45

var action: StringName = &"idle"
var elapsed := 0.0
var fire_feedback_remaining := 0.0
var flinch_remaining := 0.0
var _sleep_indicators: Array[Label3D] = []
var _sleep_indicator_origin := Vector3.ZERO
var _sleep_indicator_base_color := Color.WHITE
@onready var sleep_indicator: Label3D = get_node_or_null(^"SleepIndicator") as Label3D


func _ready() -> void:
	super()
	if is_instance_valid(sleep_indicator):
		_sleep_indicator_origin = sleep_indicator.position
		_sleep_indicator_base_color = sleep_indicator.modulate
		_sleep_indicators.append(sleep_indicator)
		for index in 2:
			var indicator := sleep_indicator.duplicate() as Label3D
			indicator.name = "SleepIndicator%d" % (index + 2)
			indicator.visible = false
			add_child(indicator)
			_sleep_indicators.append(indicator)
	# EnemyDeath uses AnimationPlayer's completion signal before freeing the enemy.
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = DEATH_DURATION
	library.add_animation(DEATH_ANIMATION, animation)
	if animation_player.has_animation_library(&""):
		animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", library)


func play_directional(next_action: StringName, direction: Vector3, restart: bool = false) -> bool:
	if action != next_action or restart:
		elapsed = 0.0
	action = next_action
	set_facing(direction)
	if action == &"death":
		flinch_remaining = 0.0
		animation_player.play(DEATH_ANIMATION)
	return true


func play_hit_feedback() -> void:
	super()
	if action != &"death":
		flinch_remaining = 0.2


func show_fire() -> void:
	fire_feedback_remaining = SHOT_FEEDBACK_DURATION


func _process(delta: float) -> void:
	if not is_instance_valid(sprite):
		return
	var step := maxf(0.0, delta)
	elapsed += step
	fire_feedback_remaining = maxf(0.0, fire_feedback_remaining - step)
	flinch_remaining = maxf(0.0, flinch_remaining - step)
	_update_sleep_indicators()
	var screen_direction := _get_screen_direction()
	var row := 0
	if absf(screen_direction.x) > absf(screen_direction.z):
		row = 1
		sprite.flip_h = screen_direction.x < 0.0
	else:
		sprite.flip_h = false
		if screen_direction.z < 0.0:
			row = 2
	var column := 0
	var texture := IDLE_SHEET
	match action:
		&"sleep":
			texture = SLEEP_SHEET
			column = int(elapsed * sleep_fps) % 6
		&"walk":
			var walk_frame := int(elapsed * walk_fps) % 12
			texture = WALK_SHEET if walk_frame < 6 else WALK_OPPOSITE_SHEET
			column = walk_frame % 6
		&"shoot":
			texture = SHOOT_SHEET
			if fire_feedback_remaining > 0.0:
				column = mini(5, 3 + int((SHOT_FEEDBACK_DURATION - fire_feedback_remaining) / 0.08))
			else:
				var skeleton := get_parent() as CoralSkeleton
				var charge := skeleton.fire_delay if is_instance_valid(skeleton) else 0.4
				column = mini(2, int(elapsed / maxf(0.01, charge) * 3.0))
		&"hit":
			texture = HIT_DEATH_SHEET
			column = mini(2, int(elapsed * 12.0))
		&"death":
			texture = HIT_DEATH_SHEET
			column = mini(5, 2 + int(elapsed / DEATH_DURATION * 4.0))
		&"bone_curl":
			texture = BONE_CURL_SHEET
			var curl_dur := _get_revive_duration(&"curl_duration", BONE_CURL_DURATION)
			column = mini(4, int(elapsed / curl_dur * 5.0))
		&"bone_dormant":
			texture = BONE_CURL_SHEET
			column = 4 if int(elapsed * 2.5) % 2 == 0 else 5
		&"bone_revive":
			texture = BONE_CURL_SHEET
			var revive_dur := _get_revive_duration(&"reassemble_duration", BONE_REASSEMBLE_DURATION)
			column = maxi(0, 4 - int(elapsed / revive_dur * 5.0))
		_:
			column = int(elapsed * idle_fps) % 6
	var in_bone_curl := action in [&"bone_curl", &"bone_dormant", &"bone_revive"]
	if flinch_remaining > 0.0 and action != &"death" and not in_bone_curl:
		texture = HIT_DEATH_SHEET
		column = 1 if flinch_remaining > 0.1 else 2
	if sprite.texture != texture:
		sprite.texture = texture
	sprite.hframes = 6
	sprite.vframes = 3
	sprite.pixel_size = character_pixel_size
	sprite.offset = Vector2(0.0, 135.0)
	sprite.frame = row * 6 + column
	super._process(delta)


func _update_sleep_indicators() -> void:
	var count := clampi(sleep_indicator_count, 2, 3)
	var duration := maxf(0.3, sleep_indicator_lifetime)
	for index in _sleep_indicators.size():
		var indicator := _sleep_indicators[index]
		var local_time := elapsed - float(index) * duration / float(count)
		indicator.visible = (
			show_sleep_indicator and action == &"sleep" and index < count and local_time >= 0.0
		)
		if not indicator.visible:
			continue
		var progress := fposmod(local_time, duration) / duration
		indicator.position = _sleep_indicator_origin + Vector3(
			sleep_indicator_drift * progress, sleep_indicator_rise * progress, 0.0
		)
		var size := lerpf(sleep_indicator_start_scale, sleep_indicator_end_scale, progress)
		indicator.scale = Vector3.ONE * size
		var fade_in := clampf(progress / 0.12, 0.0, 1.0)
		var fade_out := clampf((1.0 - progress) / 0.35, 0.0, 1.0)
		indicator.modulate = _sleep_indicator_base_color
		indicator.modulate.a *= minf(fade_in, fade_out)


func _get_revive_duration(property_name: StringName, fallback: float) -> float:
	var owner_node := get_parent()
	if not is_instance_valid(owner_node):
		return fallback
	var revive_node := owner_node.get_node_or_null(^"States/Revive")
	if is_instance_valid(revive_node):
		var value: Variant = revive_node.get(property_name)
		if value is float or value is int:
			return maxf(0.05, float(value))
	return fallback
