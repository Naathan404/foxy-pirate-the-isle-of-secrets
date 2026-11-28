class_name BlubberbeardArenaRoom
extends BaseRoom
## Captain Blubberbeard's arena (room_08).
##
## The bridge to the island breaks the moment the fight starts and never comes back: after the
## boss is beaten, Foxy crosses the gap with the Tide Grapple he just won (posts on both sides).
## Losing the fight sends Foxy to his campfire, and the next visit finds the bridge whole again.
##
## Once the boss is beaten the arena becomes a safe room: a campfire flares up at its centre, so
## Foxy can rest, save and change Charms (the Tide Grapple is needed to leave).
##
## The grapple posts stop catching the hook while the fight is on, so the Tide Grapple cannot
## carry Foxy over the broken bridge before the boss is beaten.
##
## The sea follows the fight: calm at first, violet from phase two, and red while the boss winds
## up or performs one of its signature skills.

const COLLAPSE_SOUND := preload("res://gameplay/bosses/blubberbeard/boss_explosion.wav")
const COLLAPSE_SHAKE := 8.5
const COLLAPSE_SHAKE_SECONDS := 0.3
const CAMPFIRE_FLARE_SECONDS := 0.8
const CAMPFIRE_FLARE_SHAKE := 4.0
const FURY_STATES: Array[BlubberbeardBoss.State] = [
	BlubberbeardBoss.State.WINDUP,
	BlubberbeardBoss.State.SKYDIVE_LEAP,
	BlubberbeardBoss.State.WHIRLWIND,
]

@export_group("Fight")
@export var boss: BlubberbeardBoss
@export var encounter: BossEncounter

## Hidden until the boss is beaten; then the arena is a safe room with this campfire.
@export var victory_campfire: Node3D
## Ownership persists through the existing Charm pickup and save flow.
@export var victory_charm: ItemPickup

@export_group("Bridge")
## Each span pivots at its outer end; the inner ends drop into the water.
@export var bridge_spans: Array[Node3D] = []
@export var bridge_floor: CollisionShape3D
@export var bridge_splash: CPUParticles3D
@export_range(0.1, 3.0, 0.05, "suffix:s") var collapse_seconds: float = 0.6
@export var collapse_drop_meters: float = 3.2
@export_range(0.0, 1.5, 0.01, "suffix:rad") var collapse_tilt: float = 0.6
## Tide Grapple anchors across the gap; they only catch the hook outside the fight.
@export var grapple_posts: Array[Node3D] = []

@export_group("Sea mood")
@export var mood: SeaMood
@export var calm_palette: SeaPalette
@export var phase_two_palette: SeaPalette
@export var fury_palette: SeaPalette
## Skills that turn the sea red while they wind up and play out.
@export var fury_skills: Array[BlubberbeardSkillData.Kind] = [
	BlubberbeardSkillData.Kind.SKY_DIVE,
	BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND,
]
@export_range(0.05, 3.0, 0.05, "suffix:s") var fury_blend_seconds: float = 0.35
@export_range(0.05, 3.0, 0.05, "suffix:s") var mood_blend_seconds: float = 1.2

var _fight_active := false


func _ready() -> void:
	var defeated := not Engine.is_editor_hint() and _is_boss_defeated()
	# Set before the base class grants the safe-room permission of an already won arena.
	if defeated:
		safe_room = true
	super()
	if Engine.is_editor_hint():
		return
	_set_campfire_lit(defeated)
	_set_charm_available(defeated)
	if defeated:
		_break_bridge(false)
		return
	if is_instance_valid(boss):
		boss.fight_started.connect(_on_fight_started)
		boss.fight_finished.connect(_on_fight_finished)


func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or mood == null:
		return
	var target := _target_palette()
	if target != null and target != mood.get_palette():
		mood.blend_to(target, fury_blend_seconds if target == fury_palette else mood_blend_seconds)


func _target_palette() -> SeaPalette:
	if not _fight_active or not is_instance_valid(boss) or boss.dead:
		return calm_palette
	if boss.skill != null and fury_skills.has(boss.skill.kind) and FURY_STATES.has(boss.state):
		return fury_palette
	return phase_two_palette if boss.phase_index >= 1 else calm_palette


func _is_boss_defeated() -> bool:
	if encounter == null or encounter.encounter_id.is_empty():
		return false
	var state: Dictionary = get_node("/root/GameManager").boss_encounters.get(
		encounter.encounter_id, {}
	)
	return bool(state.get("defeated", false))


func _on_fight_started() -> void:
	_fight_active = true
	_set_grapple_posts_enabled(false)
	_break_bridge(true)


func _on_fight_finished() -> void:
	_fight_active = false
	if is_instance_valid(boss) and boss.dead:
		_set_grapple_posts_enabled(true)
		_set_charm_available(true)
		_become_safe()


func _become_safe() -> void:
	safe_room = true
	_grant_safe_room()
	_set_campfire_lit(true)
	if victory_campfire == null:
		return
	var rest_scale := victory_campfire.scale
	victory_campfire.scale = rest_scale * 0.1
	var flare := create_tween().tween_property(
		victory_campfire, "scale", rest_scale, CAMPFIRE_FLARE_SECONDS
	)
	flare.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_node("/root/ScreenShakeController").request(CAMPFIRE_FLARE_SHAKE, CAMPFIRE_FLARE_SECONDS)


func _set_campfire_lit(lit: bool) -> void:
	if victory_campfire == null:
		return
	victory_campfire.visible = lit
	# Disabled nodes leave the physics space, so the hidden fire blocks and offers nothing.
	victory_campfire.process_mode = Node.PROCESS_MODE_INHERIT if lit else Node.PROCESS_MODE_DISABLED


func _set_charm_available(available: bool) -> void:
	if not is_instance_valid(victory_charm):
		return
	victory_charm.visible = available
	var mode := Node.PROCESS_MODE_INHERIT if available else Node.PROCESS_MODE_DISABLED
	victory_charm.set_deferred("process_mode", mode)


# Disabled nodes leave the physics space: the post stays in view but the hook passes through.
func _set_grapple_posts_enabled(enabled: bool) -> void:
	for post: Node3D in grapple_posts:
		if is_instance_valid(post):
			post.process_mode = (
				Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
			)


func _break_bridge(animated: bool) -> void:
	if bridge_floor != null:
		# The fight starts inside a physics callback; shapes change after the flush, and the
		# island boundary is rebuilt afterwards so the gap becomes a wall.
		bridge_floor.set_deferred("disabled", true)
		queue_boundary_rebuild()
	if not animated:
		for span: Node3D in bridge_spans:
			span.hide()
		return
	if bridge_splash != null:
		bridge_splash.restart()
		bridge_splash.emitting = true
	get_node("/root/AudioManager").play_sfx_3d(
		COLLAPSE_SOUND, bridge_floor.global_position if bridge_floor else global_position, -6.0
	)
	get_node("/root/ScreenShakeController").request(COLLAPSE_SHAKE, COLLAPSE_SHAKE_SECONDS)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for index: int in bridge_spans.size():
		var span := bridge_spans[index]
		# Spans fall towards each other: the west one tips clockwise, the east one back.
		var tilt := collapse_tilt * (-1.0 if index == 0 else 1.0)
		tween.tween_property(
			span, "position:y", span.position.y - collapse_drop_meters, collapse_seconds
		)
		tween.tween_property(span, "rotation:z", tilt, collapse_seconds)
	tween.chain().tween_callback(
		func() -> void:
			for span: Node3D in bridge_spans:
				span.hide()
	)
