class_name PropSlot
extends Node3D
## A hand-placed spot that shows one prop from `pool`, chosen anew each world cycle (every
## campfire rest or death) and kept the same between room visits within a cycle.
## Use it for decor and small breakables only; trees and large rocks that shape the paths
## stay as fixed props. Place the slot so the whole jitter circle is clear of paths,
## exits, water edges and the campfire spawn.
##
## Loot belongs to the slot, not to the picked prop: whichever prop appears, it drops the
## slot's item (or nothing), so a room's rewards do not swing with the visuals.

const FLIP_CHANCE := 0.5

@export var pool: PropPool
## Random offset on the ground plane, in metres from the slot.
@export_range(0.0, 3.0, 0.05, "suffix:m") var jitter_radius_meters: float = 0.0
## Relative size change, e.g. 0.1 picks a scale between 90% and 110% of the prop's own.
@export_range(0.0, 0.5, 0.01) var scale_variance: float = 0.0
## Mirror the prop's sprite half of the time.
@export var random_flip: bool = true

@export_group("Loot")
@export var drop_item: BaseItem
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.0
@export_range(1, 99, 1) var drop_quantity: int = 1

## The prop placed this cycle, or null when the slot stayed empty.
var prop: Node3D


func _ready() -> void:
	if pool == null:
		push_warning("PropSlot '%s' has no pool" % name)
		return
	var random := BaseRoom.create_random(self)
	var scene := pool.pick(random)
	# Draw every value even for an empty pick, so one slot's result never shifts another.
	var angle := random.randf() * TAU
	var distance := sqrt(random.randf()) * jitter_radius_meters
	var size_factor := 1.0 + random.randf_range(-scale_variance, scale_variance)
	var flipped := random_flip and random.randf() < FLIP_CHANCE
	if scene == null:
		return
	prop = scene.instantiate() as Node3D
	if prop == null:
		push_warning("PropSlot '%s': pool scenes must have a Node3D root" % name)
		return
	prop.position = Vector3(cos(angle), 0.0, sin(angle)) * distance
	prop.scale *= size_factor
	if flipped:
		var sprite := prop.find_child("Sprite3D", true, false) as Sprite3D
		if sprite != null:
			sprite.flip_h = not sprite.flip_h
	if prop is DestructibleProp:
		var breakable := prop as DestructibleProp
		breakable.drop_item = drop_item
		breakable.drop_chance = drop_chance if drop_item != null else 0.0
		breakable.drop_quantity = drop_quantity
	add_child(prop, true)
