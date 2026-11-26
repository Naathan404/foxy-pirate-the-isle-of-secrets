class_name CrabSlamImpact
extends Node3D
## Where an elite crab's claw hits the ground: the ground cracks open at once, a shock ring and
## a low dust wave run outwards, dirt and rock chunks fly up. The crack lingers a moment so the
## hit spot stays readable, then fades and the effect removes itself.

const CRACK_START_SCALE := 0.35
const CRACK_OPEN_SECONDS := 0.08
const CRACK_MAX_ALPHA := 0.95
const RING_START_SCALE := 0.3
const RING_SECONDS := 0.35
const RING_START_ALPHA := 0.9
## Any range works; it only varies the crack pattern between slams.
const CRACK_SEED_RANGE := 100.0
const GROUND_PROBE_UP_METERS := 2.0
const GROUND_PROBE_DOWN_METERS := 4.0
## Keeps the decal just above the ground so it does not flicker into it.
const GROUND_LIFT_METERS := 0.04

@export_range(1.0, 4.0, 0.05) var ring_end_scale: float = 2.2
@export_range(0.0, 5.0, 0.05, "suffix:s") var crack_hold_seconds: float = 1.1
@export_range(0.05, 3.0, 0.05, "suffix:s") var crack_fade_seconds: float = 0.6

@onready var _crack: MeshInstance3D = $Crack
@onready var _ring: MeshInstance3D = $ShockRing
@onready var _bursts: Array[GPUParticles3D] = [$Dirt, $Rocks, $DustWave]


## Places `scene` on the ground under `owner_enemy` moved by `offset`, in the enemy's room.
static func spawn_at_ground(
	scene: PackedScene, owner_enemy: Node3D, offset: Vector3
) -> CrabSlamImpact:
	var parent := owner_enemy.get_parent()
	if scene == null or parent == null:
		return null
	var effect := scene.instantiate() as CrabSlamImpact
	parent.add_child(effect)
	var spot := owner_enemy.global_position + offset
	var query := PhysicsRayQueryParameters3D.create(
		spot + Vector3.UP * GROUND_PROBE_UP_METERS,
		spot + Vector3.DOWN * GROUND_PROBE_DOWN_METERS,
		CombatLayers.WORLD
	)
	var hit := owner_enemy.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spot = hit.position
	effect.global_position = spot + Vector3.UP * GROUND_LIFT_METERS
	return effect


## Cracks the ground where `crab`'s claw lands: beside the crab at the artwork's
## `impact_bone`, which follows any change to the crab's size, or at `fallback_offset` when
## the artwork has no such bone (sprite sheet).
static func spawn_at_claw(
	scene: PackedScene, crab: EnemyBase, impact_bone: String, fallback_offset: Vector3
) -> CrabSlamImpact:
	return spawn_at_ground(scene, crab, get_claw_offset(crab, impact_bone, fallback_offset))


## Shared by the damage hitbox and the ground effect so both land under the same claw.
static func get_claw_offset(
	crab: EnemyBase, impact_bone: String, fallback_offset: Vector3
) -> Vector3:
	var offset := fallback_offset
	var point: Variant = crab.visual.get_bone_position(impact_bone)
	if point is Vector3:
		# The artwork is drawn facing the camera: only its sideways offset lies on the ground.
		offset = Vector3((point as Vector3).x - crab.global_position.x, 0.0, 0.0)
	return offset


func _ready() -> void:
	# Each slam owns its materials because the crack fades while another may open.
	var crack_material := _crack.material_override.duplicate() as ShaderMaterial
	var ring_material := _ring.material_override.duplicate() as StandardMaterial3D
	_crack.material_override = crack_material
	_ring.material_override = ring_material
	crack_material.set_shader_parameter(&"seed", randf() * CRACK_SEED_RANGE)
	_crack.scale = Vector3.ONE * CRACK_START_SCALE
	_ring.scale = Vector3.ONE * RING_START_SCALE
	ring_material.albedo_color.a = RING_START_ALPHA
	for burst in _bursts:
		burst.restart()
		burst.emitting = true

	var tween := create_tween().set_parallel()
	var open := tween.tween_property(_crack, "scale", Vector3.ONE, CRACK_OPEN_SECONDS)
	open.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		crack_material, ^"shader_parameter/opacity", CRACK_MAX_ALPHA, CRACK_OPEN_SECONDS
	)
	var spread := tween.tween_property(_ring, "scale", Vector3.ONE * ring_end_scale, RING_SECONDS)
	spread.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_material, "albedo_color:a", 0.0, RING_SECONDS)
	tween.chain().tween_interval(crack_hold_seconds)
	tween.chain().tween_property(
		crack_material, ^"shader_parameter/opacity", 0.0, crack_fade_seconds
	)
	tween.chain().tween_callback(queue_free)
