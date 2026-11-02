class_name GoldPickupPool
extends Node
## Scene-local coin storage. Creation and activation have separate per-frame budgets.

const COIN_SCENE: PackedScene = preload("res://gameplay/economy/gold_pickup.tscn")
const SPREAD_ANGLE: float = 2.39996323

@export_range(0, 256, 1) var prewarm_count: int = 64
@export_range(1, 1024, 1) var max_pickups: int = 256
@export_range(1, 16, 1) var create_per_frame: int = 4
@export_range(1, 32, 1) var activate_per_frame: int = 8

var _available: Array[GoldPickup] = []
var _active: Array[GoldPickup] = []
var _pending: Array[Dictionary] = []
var _created: int = 0


static func for_scene(requester: Node) -> GoldPickupPool:
	var scene := requester.get_tree().current_scene
	if not is_instance_valid(scene) or scene.is_queued_for_deletion():
		return null
	var existing := scene.get_node_or_null("GoldPickupPool")
	if existing != null:
		return existing as GoldPickupPool
	var pool := GoldPickupPool.new()
	pool.name = "GoldPickupPool"
	scene.add_child(pool)
	return pool


func _ready() -> void:
	set_process(prewarm_count > 0)


func spawn_gold(at: Vector3, total: int, direction: Vector3) -> void:
	if total <= 0:
		return
	# Store one request per reward, rather than allocating a request for every coin.
	_pending.append(
		{"at": at, "remaining": total, "index": 0, "angle": atan2(direction.z, direction.x)}
	)
	set_process(true)


func _process(_delta: float) -> void:
	var warm_target := mini(prewarm_count, max_pickups)
	var needs_growth := _created < warm_target
	needs_growth = (
		needs_growth or (not _pending.is_empty() and _available.size() < activate_per_frame)
	)
	if needs_growth:
		for index in mini(create_per_frame, max_pickups - _created):
			_create_coin()
	_activate_pending()
	var can_progress := (
		not _pending.is_empty() and (not _available.is_empty() or _created < max_pickups)
	)
	# A saturated pool waits for a coin to return; queued Gold is never discarded.
	set_process(_created < warm_target or can_progress)


func _create_coin() -> void:
	var pickup := COIN_SCENE.instantiate() as GoldPickup
	pickup.pooled = true
	add_child(pickup)
	pickup.recycle_requested.connect(_release)
	_available.append(pickup)
	_created += 1


func _activate_pending() -> void:
	for index in activate_per_frame:
		if _available.is_empty() or _pending.is_empty():
			return
		var request: Dictionary = _pending.front()
		var angle: float = request.angle + request.index * SPREAD_ANGLE
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var pickup: GoldPickup = _available.pop_back()
		_active.append(pickup)
		pickup.activate(request.at, direction)
		request.remaining -= 1
		request.index += 1
		if request.remaining == 0:
			_pending.pop_front()


func _release(pickup: GoldPickup) -> void:
	if not _active.has(pickup):
		return
	_active.erase(pickup)
	pickup.park()
	_available.append(pickup)
	if not _pending.is_empty():
		set_process(true)
