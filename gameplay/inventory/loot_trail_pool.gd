class_name LootTrailPool
extends Node
## One bounded pool per world scene; idle effects hold no pickup references or processing.

const TRAIL_SCENE: PackedScene = preload("res://gameplay/inventory/loot_trail.tscn")

@export_range(0, 128, 1) var prewarm_count: int = 64
@export_range(1, 256, 1) var max_trails: int = 128
@export_range(1, 16, 1) var create_per_frame: int = 4

var _available: Array[LootTrail] = []
var _in_use: Array[LootTrail] = []
var _created: int = 0
var _target_count: int = 0


static func for_scene(requester: Node) -> LootTrailPool:
	var scene := requester.get_tree().current_scene
	if not is_instance_valid(scene) or scene.is_queued_for_deletion():
		return null
	var existing := scene.get_node_or_null("LootTrailPool")
	if existing != null:
		return existing as LootTrailPool
	var pool := LootTrailPool.new()
	pool.name = "LootTrailPool"
	scene.add_child(pool)
	return pool


func _ready() -> void:
	_target_count = mini(prewarm_count, max_trails)
	set_process(_target_count > 0)


func _process(_delta: float) -> void:
	for index in mini(create_per_frame, _target_count - _created):
		_available.append(_create_trail())
	set_process(_created < _target_count)


func acquire(source: Node3D, color: Color, width: float) -> LootTrail:
	if not is_instance_valid(source):
		return null
	var trail: LootTrail
	if not _available.is_empty():
		trail = _available.pop_back()
	else:
		if _created < max_trails:
			_target_count = mini(max_trails, _created + create_per_frame)
			set_process(true)
		# Grow on later frames, never allocate a ribbon in a burst's activation path.
		return null
	_in_use.append(trail)
	trail.start(source, color, width)
	return trail


func _create_trail() -> LootTrail:
	var trail := TRAIL_SCENE.instantiate() as LootTrail
	add_child(trail)
	trail.finished.connect(_release)
	_created += 1
	return trail


func _release(trail: LootTrail) -> void:
	if not _in_use.has(trail):
		return
	_in_use.erase(trail)
	trail.reset()
	_available.append(trail)
