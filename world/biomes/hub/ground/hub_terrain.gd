@tool
class_name HubTerrain
extends Node3D
## Hub ground made of axis-aligned rectangles in this node's X/Z metres (Rect2 position is
## the -X/-Z corner). Grass and stone each render as one ragged-edged surface over the union
## of their rectangles, and every rectangle is walkable floor with its top at this node's Y.
## Place it under a BaseRoom's `Environment` with a name starting with "BaseGround" so the
## room builds edge walls from these floors. Keep the node unrotated and unscaled.

## Matches MAX_RECTS in hub_terrain.gdshader.
const MAX_RECTS_PER_SURFACE := 32
const FLOOR_THICKNESS_METERS := 1.0
## Lifts stone above grass so the overlapping surfaces never z-fight.
const STONE_LIFT_METERS := 0.012
const BODY_NAME := "StaticBody3D"

@export var grass_material: ShaderMaterial:
	set(value):
		grass_material = value
		_queue_rebuild()
@export var stone_material: ShaderMaterial:
	set(value):
		stone_material = value
		_queue_rebuild()
@export var grass_rects: Array[Rect2] = []:
	set(value):
		grass_rects = value
		_queue_rebuild()
@export var stone_rects: Array[Rect2] = []:
	set(value):
		stone_rects = value
		_queue_rebuild()

var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


## Every rectangle of both surfaces, in this node's local X/Z.
func get_floor_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.append_array(grass_rects)
	rects.append_array(stone_rects)
	return rects


## Whether a point (local X/Z) lies on walkable ground.
func has_floor_at(local_point: Vector2) -> bool:
	for rect: Rect2 in get_floor_rects():
		if rect.has_point(local_point):
			return true
	return false


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		# Generated nodes have no owner, so they are never saved with the scene.
		if child.owner == null:
			remove_child(child)
			child.queue_free()
	var no_underlay: Array[Rect2] = []
	_add_surface("GrassSurface", grass_rects, grass_material, 0.0, no_underlay)
	# Grass may overgrow stone only where the stone lies on grass, never on bridges.
	_add_surface("StoneSurface", stone_rects, stone_material, STONE_LIFT_METERS, grass_rects)
	_add_floor_body()


func _add_surface(
	surface_name: String,
	rects: Array[Rect2],
	material: ShaderMaterial,
	lift: float,
	underlay: Array[Rect2]
) -> void:
	if rects.is_empty() or material == null:
		return
	if rects.size() > MAX_RECTS_PER_SURFACE:
		push_warning(
			(
				"HubTerrain %s: only the first %d rectangles are drawn."
				% [surface_name, MAX_RECTS_PER_SURFACE]
			)
		)
	var fringe := float(material.get_shader_parameter("fringe_meters"))
	var bounds := rects[0]
	for rect: Rect2 in rects:
		bounds = bounds.merge(rect)
	bounds = bounds.grow(fringe)
	var center := bounds.get_center()

	var shader_rects := _to_shader_rects(rects, center)
	var underlay_rects := _to_shader_rects(underlay, center)
	var surface_material := material.duplicate() as ShaderMaterial
	surface_material.set_shader_parameter("rects", shader_rects)
	surface_material.set_shader_parameter("rect_count", shader_rects.size())
	surface_material.set_shader_parameter("underlay_rects", underlay_rects)
	surface_material.set_shader_parameter("underlay_count", underlay_rects.size())

	var plane := PlaneMesh.new()
	plane.size = bounds.size
	var surface := MeshInstance3D.new()
	surface.name = surface_name
	surface.mesh = plane
	surface.material_override = surface_material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.position = Vector3(center.x, lift, center.y)
	add_child(surface)


## Rectangles as (centre.x, centre.z, half width, half depth) relative to `origin`.
func _to_shader_rects(rects: Array[Rect2], origin: Vector2) -> Array[Vector4]:
	var shader_rects: Array[Vector4] = []
	for rect: Rect2 in rects.slice(0, MAX_RECTS_PER_SURFACE):
		var local_center := rect.get_center() - origin
		shader_rects.append(
			Vector4(local_center.x, local_center.y, rect.size.x * 0.5, rect.size.y * 0.5)
		)
	return shader_rects


func _add_floor_body() -> void:
	var body := StaticBody3D.new()
	body.name = BODY_NAME
	add_child(body)
	for rect: Rect2 in get_floor_rects():
		var box := BoxShape3D.new()
		box.size = Vector3(rect.size.x, FLOOR_THICKNESS_METERS, rect.size.y)
		var shape := CollisionShape3D.new()
		shape.shape = box
		var center := rect.get_center()
		shape.position = Vector3(center.x, -FLOOR_THICKNESS_METERS * 0.5, center.y)
		body.add_child(shape)
