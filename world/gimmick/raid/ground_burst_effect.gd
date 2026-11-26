class_name GroundBurstEffect
extends Node3D
## Telegraphs an enemy rising out of the ground: pebbles hop while a crack opens in jolts and
## stays open until the spawner calls `erupt()` (dirt and a shock ring, as the enemy appears)
## or `close()` (the spawn moved elsewhere). Elites get a larger, glowing crack. An eruption
## therefore always means an enemy came out.

const CRACK_START_SCALE := 0.3
const CRACK_MAX_ALPHA := 0.9
## The crack opens in this many jolts rather than one smooth growth.
const CRACK_JOLT_COUNT := 3
## Share of each jolt spent snapping open; the rest is a still pause.
const CRACK_JOLT_SNAP_RATIO := 0.35
const CRACK_FADE_SECONDS := 0.35
const RING_START_SCALE := 0.4
const RING_END_SCALE := 2.4
const RING_SECONDS := 0.4
const RING_START_ALPHA := 0.8
const ELITE_DIRT_AMOUNT := 48
const ELITE_PEBBLE_AMOUNT := 20
const ELITE_CRACK_COLOR := Color(0.95, 0.32, 0.12)
## Any range works; it only varies the crack pattern between spawn points.
const CRACK_SEED_RANGE := 100.0

@export_range(1.0, 2.0, 0.05) var elite_scale: float = 1.4

var _crack_material: ShaderMaterial
var _ring_material: StandardMaterial3D
var _tween: Tween
var _finished: bool = false

@onready var _crack: MeshInstance3D = $Crack
@onready var _ring: MeshInstance3D = $ShockRing
@onready var _pebbles: GPUParticles3D = $Pebbles
@onready var _dirt: GPUParticles3D = $Dirt


## Opens the crack over `telegraph_seconds`, then keeps it open with pebbles hopping.
func play(is_elite: bool, telegraph_seconds: float) -> void:
	# Each effect owns its materials because several spawn points telegraph at once.
	_crack_material = _crack.material_override.duplicate() as ShaderMaterial
	_ring_material = _ring.material_override.duplicate() as StandardMaterial3D
	_crack.material_override = _crack_material
	_ring.material_override = _ring_material
	_crack_material.set_shader_parameter(&"seed", randf() * CRACK_SEED_RANGE)
	if is_elite:
		scale *= elite_scale
		_dirt.amount = ELITE_DIRT_AMOUNT
		_pebbles.amount = ELITE_PEBBLE_AMOUNT
		_crack_material.set_shader_parameter(&"crack_color", ELITE_CRACK_COLOR)
		_ring_material.albedo_color = ELITE_CRACK_COLOR
	_crack_material.set_shader_parameter(&"opacity", 0.0)
	_crack.scale = Vector3.ONE * CRACK_START_SCALE
	_ring.visible = false
	_pebbles.emitting = true

	_tween = create_tween()
	var jolt_seconds := telegraph_seconds / CRACK_JOLT_COUNT
	for jolt in CRACK_JOLT_COUNT:
		var progress := float(jolt + 1) / CRACK_JOLT_COUNT
		var crack_scale := lerpf(CRACK_START_SCALE, 1.0, progress)
		var snap_seconds := jolt_seconds * CRACK_JOLT_SNAP_RATIO
		var snap := _tween.tween_property(_crack, "scale", Vector3.ONE * crack_scale, snap_seconds)
		snap.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(
			_crack_material, ^"shader_parameter/opacity", CRACK_MAX_ALPHA * progress, snap_seconds
		)
		_tween.tween_interval(jolt_seconds - snap_seconds)


## The enemy is coming out: dirt and a shock ring, then the effect removes itself.
func erupt() -> void:
	if not _begin_finish():
		return
	_dirt.restart()
	_dirt.emitting = true
	_ring.visible = true
	_ring.scale = Vector3.ONE * RING_START_SCALE
	_ring_material.albedo_color.a = RING_START_ALPHA
	var spread := _tween.tween_property(_ring, "scale", Vector3.ONE * RING_END_SCALE, RING_SECONDS)
	spread.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_ring_material, "albedo_color:a", 0.0, RING_SECONDS)
	_tween.tween_property(_crack_material, ^"shader_parameter/opacity", 0.0, CRACK_FADE_SECONDS)
	_tween.chain().tween_interval(_dirt.lifetime)
	_tween.chain().tween_callback(queue_free)


## Nothing comes out here after all: the crack fades without an eruption.
func close() -> void:
	if not _begin_finish():
		return
	_tween.tween_property(_crack_material, ^"shader_parameter/opacity", 0.0, CRACK_FADE_SECONDS)
	_tween.chain().tween_callback(queue_free)


func _begin_finish() -> bool:
	if _finished:
		return false
	_finished = true
	_pebbles.emitting = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel()
	return true
