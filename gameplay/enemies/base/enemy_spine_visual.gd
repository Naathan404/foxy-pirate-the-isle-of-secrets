class_name EnemySpineVisual
extends EnemyVisual
## Draws an enemy with a Spine skeleton instead of its sprite sheet. The sprite's
## AnimationPlayer still times gameplay (attack phases, death, hitstop, stun), as for Foxy.
## Every clip it plays, and actions only Spine has (such as `charge`), are mapped to a Spine
## clip through `clip_map`. Actions without a mapping (hit, death) keep the current pose under
## the hit and death feedback. Builds without the spine-godot extension keep the sprite sheet.

const SPINE_SPRITE_CLASS := "SpineSprite3D"
## SpineSprite3D.update_mode values.
const SPINE_UPDATE_PROCESS := 0
## SpineSprite3D.shadow_casting: Double-Sided, as for Foxy, so the artwork grounds itself.
const SPINE_SHADOW_DOUBLE_SIDED := 2
## Suffixes stripped from a directional clip name to find its action in `clip_map`.
const DIRECTION_SUFFIXES: Array[String] = ["_down", "_up", "_side", "_left", "_right"]
## Lets an AnimationPlayer clip that ended on its last key count as finished, not paused.
const END_TOLERANCE_SECONDS := 0.001
const DEATH_SHRINK_SCALE := 0.25
## Glow added over the artwork at the peak of an elite wind-up.
const TELEGRAPH_COLOR := Color(1.0, 0.82, 0.45)
## Screen-sideways share of the facing needed to turn the artwork around.
const MIRROR_FACING_THRESHOLD := 0.2
## Actions that last as long as their state, so their Spine clip loops. Every other clip
## plays once and holds its last frame. Kept in code: this must not depend on scene data.
const CONTINUOUS_ACTIONS: Array[StringName] = [&"idle", &"run", &"attack", &"charge_run"]

## Skeleton data by path, shared by every enemy of a kind; loading it uploads the atlas.
static var _skeleton_data_cache: Dictionary[String, Resource] = {}

@export_file("*.tres") var skeleton_data_path: String = ""
## Action or AnimationPlayer clip name to Spine clip. A directional name (`shoot_up`) wins over
## its action (`shoot`). Unmapped names keep the current Spine pose.
@export var clip_map: Dictionary[StringName, String] = {}
## Where a mapped action starts inside its Spine clip, keyed like `clip_map`. Lets a short
## gameplay beat play the middle of a longer clip (a slam inside a full attack).
@export var action_start_seconds: Dictionary[StringName, float] = {}
## World units per Spine unit. The skeleton root is placed at the enemy's feet.
@export_range(0.0001, 0.1, 0.0001, "or_greater") var spine_pixel_size: float = 0.0027
## Raises the skeleton when its drawing reaches below the root, so the feet meet the ground.
@export_range(-2.0, 2.0, 0.005, "suffix:m") var lift_meters: float = 0.0
## Cross-fade between Spine clips, so poses blend instead of snapping.
@export_range(0.0, 1.0, 0.01, "suffix:s") var mix_seconds: float = 0.15
## Whether the artwork faces left.
@export var artwork_faces_left: bool = false
## On: mirror from the enemy's facing on screen, keeping the last side while it faces up
## or down (side-view and strafing art). Off: mirror when the sprite sheet would flip.
@export var mirror_from_facing: bool = false
## Spine clips drawn towards another side than `artwork_faces_left` says (clip name to
## "faces left"), such as a one-sided claw swing. With `mirror_from_facing` they turn
## towards the target rather than the walking direction.
@export var clip_faces_left: Dictionary[String, bool] = {}

var _spine: Node3D
var _spine_clip: String = ""
## Hit flash, drawn through Spine's two-colour tint: the dark colour fills what the texture
## leaves, so dark = white with a white light colour paints the artwork solid white.
var _flash_strength: float = 0.0
var _tint: Color = Color.WHITE
var _fade: float = 1.0
var _squash: Vector3 = Vector3.ONE
var _telegraph_strength: float = 0.0
var _telegraph_scale: float = 1.0
var _faces_screen_left: bool = false


func _ready() -> void:
	super()
	if _create_spine() and is_instance_valid(sprite):
		sprite.visible = false


func _process(delta: float) -> void:
	super(delta)
	if not is_instance_valid(_spine):
		return
	_spine.set("time_scale", 0.0 if _is_animation_frozen() else 1.0)
	_face_camera()
	_spine.get_skeleton().set_color(Color(_tint, _tint.a * _fade))


func set_tint(color: Color) -> void:
	_tint = color
	super(color)


func get_tint() -> Color:
	return _tint if is_instance_valid(_spine) else super()


func set_telegraph_pulse(strength: float, size_scale: float = 1.0) -> void:
	_telegraph_strength = clampf(strength, 0.0, 1.0)
	_telegraph_scale = size_scale


## Top of the current pose, from the skeleton bones (so it follows the lid popping open).
func get_top_y() -> float:
	if not is_instance_valid(_spine):
		return super()
	var bounds: Rect2 = _spine.get_skeleton().get_bounds()
	if not bounds.has_area():
		return super()
	# Spine's y axis points down: the top is the bounds' smallest y.
	return _spine.to_global(Vector3(0.0, -bounds.position.y * spine_pixel_size, 0.0)).y


func play_hit_feedback() -> void:
	if not is_instance_valid(_spine):
		super()
		return
	_kill_feedback_tweens()
	_flash_strength = 1.0
	_squash = Vector3(hit_pulse_scale, hit_squash_scale, 1.0)
	_hit_flash_tween = create_tween().set_ignore_time_scale(true)
	_hit_flash_tween.tween_interval(hit_flash_hold_duration)
	_hit_flash_tween.tween_property(self, ^"_flash_strength", 0.0, hit_flash_duration)
	_hit_pose_tween = create_tween().set_ignore_time_scale(true)
	_hit_pose_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_pose_tween.tween_property(
		self, ^"_squash", Vector3(hit_squash_scale, hit_pulse_scale, 1.0), hit_rebound_duration
	)
	_hit_pose_tween.tween_property(self, ^"_squash", Vector3.ONE, hit_settle_duration)


func play_death_feedback() -> bool:
	if not is_instance_valid(_spine):
		return super()
	_kill_feedback_tweens()
	_flash_strength = 0.0
	_squash = Vector3.ONE
	_death_feedback_tween = create_tween().set_parallel()
	_death_feedback_tween.tween_property(self, ^"_fade", 0.0, death_fade_duration)
	_death_feedback_tween.tween_property(
		self, ^"_squash", Vector3.ONE * DEATH_SHRINK_SCALE, death_fade_duration
	)
	_death_feedback_tween.finished.connect(_on_death_feedback_finished, CONNECT_ONE_SHOT)
	return true


func _play(animation_name: StringName, restart: bool) -> bool:
	var played := super(animation_name, restart)
	if not is_instance_valid(_spine):
		return played
	var key := _mapping_key_for(animation_name)
	if key.is_empty():
		return played
	var clip: String = clip_map[key]
	if restart or clip != _spine_clip:
		_play_spine(clip, _is_continuous(key), action_start_seconds.get(key, 0.0))
	return true


## The `clip_map` key that covers `animation_name`, or empty when none does.
func _mapping_key_for(animation_name: StringName) -> StringName:
	if clip_map.has(animation_name):
		return animation_name
	var clip_name := String(animation_name)
	for suffix in DIRECTION_SUFFIXES:
		if clip_name.ends_with(suffix):
			var action := StringName(clip_name.trim_suffix(suffix))
			return action if clip_map.has(action) else &""
	return &""


## Whether `key` (an action, possibly with a direction suffix) is a continuous action.
func _is_continuous(key: StringName) -> bool:
	var action := String(key)
	for suffix in DIRECTION_SUFFIXES:
		action = action.trim_suffix(suffix)
	return CONTINUOUS_ACTIONS.has(StringName(action))


func _play_spine(clip: String, loop: bool, start_seconds: float = 0.0) -> void:
	var entry = _spine.get_animation_state().set_animation(clip, loop, 0)
	if entry == null:
		push_warning("EnemySpineVisual: no Spine clip '%s' in %s." % [clip, skeleton_data_path])
		return
	entry.set_mix_duration(mix_seconds)
	if start_seconds > 0.0:
		entry.set_track_time(start_seconds)
	_spine_clip = clip


func _create_spine() -> bool:
	# Avoid a hard dependency on the extension: builds without it keep the sprite sheet.
	if (
		skeleton_data_path.is_empty()
		or not ClassDB.class_exists(SPINE_SPRITE_CLASS)
		or not ResourceLoader.exists(skeleton_data_path)
	):
		return false
	var skeleton_data: Resource = _skeleton_data_cache.get(skeleton_data_path)
	if skeleton_data == null:
		skeleton_data = load(skeleton_data_path)
		_skeleton_data_cache[skeleton_data_path] = skeleton_data
	_spine = ClassDB.instantiate(SPINE_SPRITE_CLASS) as Node3D
	_spine.name = "Spine"
	_spine.set("skeleton_data_res", skeleton_data)
	_spine.set("pixel_size", spine_pixel_size)
	_spine.set("update_mode", SPINE_UPDATE_PROCESS)
	_spine.set("shadow_casting", SPINE_SHADOW_DOUBLE_SIDED)
	_spine.position = Vector3.UP * lift_meters
	add_child(_spine)
	if _spine.get_skeleton() == null:
		push_warning("EnemySpineVisual: could not load %s." % skeleton_data_path)
		_spine.free()
		_spine = null
		return false
	_spine.world_transforms_changed.connect(_apply_flash)
	return true


## Runs after the clip is applied each frame and before the meshes are built.
func _apply_flash(_sprite: Node) -> void:
	var glow := TELEGRAPH_COLOR * _telegraph_strength
	var flash := hit_flash_color * _flash_strength
	var dark := Color(maxf(flash.r, glow.r), maxf(flash.g, glow.g), maxf(flash.b, glow.b))
	for slot in _spine.get_skeleton().get_slots():
		var pose = slot.get_applied_pose()
		pose.set_has_dark_color(true)
		pose.set_dark_color(dark)


## Hitstop sets the AnimationPlayer speed to 0 and a charm stun pauses it mid-clip; the Spine
## pose freezes with it. A clip that simply ended is not a pause.
func _is_animation_frozen() -> bool:
	if not is_instance_valid(animation_player):
		return false
	if is_zero_approx(animation_player.speed_scale):
		return true
	if animation_player.is_playing() or animation_player.assigned_animation.is_empty():
		return false
	var clip := animation_player.get_animation(animation_player.assigned_animation)
	return (
		clip != null
		and animation_player.current_animation_position < clip.length - END_TOLERANCE_SECONDS
	)


## Faces the camera like a billboard sprite, keeping this node's world scale (elite size,
## charge pulse) and the hit squash.
func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	var facing := (
		camera.global_basis.orthonormalized()
		if is_instance_valid(camera)
		else global_basis.orthonormalized()
	)
	var world_scale := global_basis.get_scale() * _squash * _telegraph_scale
	if _is_mirrored():
		world_scale.x = -world_scale.x
	_spine.global_basis = facing * Basis.from_scale(world_scale)


func _is_mirrored() -> bool:
	var faces_left: bool = clip_faces_left.get(_spine_clip, artwork_faces_left)
	if not mirror_from_facing:
		return is_instance_valid(sprite) and sprite.flip_h != faces_left
	var side := _get_look_screen_x()
	if absf(side) > MIRROR_FACING_THRESHOLD:
		_faces_screen_left = side < 0.0
	return _faces_screen_left != faces_left


## Screen-sideways direction to turn to. A one-sided clip points at the target, since the
## enemy may still face up or down (a charge leaves along z first) while Foxy is to a side.
func _get_look_screen_x() -> float:
	var enemy := get_parent() as EnemyBase
	var camera := get_viewport().get_camera_3d()
	if (
		not clip_faces_left.has(_spine_clip)
		or enemy == null
		or not enemy.has_target()
		or not is_instance_valid(camera)
	):
		return _get_screen_direction().x
	var offset := enemy.target.global_position - enemy.global_position
	offset.y = 0.0
	return offset.normalized().dot(camera.global_basis.x.normalized())


func _kill_feedback_tweens() -> void:
	for tween in [_hit_flash_tween, _hit_pose_tween, _death_feedback_tween]:
		if tween != null:
			tween.kill()
