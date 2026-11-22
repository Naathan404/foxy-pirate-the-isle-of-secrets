@tool
class_name HubLandmarkPlaceholder
extends Node3D
## Marks where a planned Hub structure stands until its art and gameplay system exist.
## Visual only (with optional blocking collision); it never offers an interaction, so the
## player cannot mistake it for a working building.

const LABEL_GAP_METERS := 0.6
const BODY_ALPHA := 0.7

@export var title: String = "Landmark":
	set(value):
		title = value
		_apply()
## Short state shown under the title, e.g. why the structure is not usable yet.
@export_multiline var status_note: String = "":
	set(value):
		status_note = value
		_apply()
@export var footprint_meters: Vector2 = Vector2(2.0, 2.0):
	set(value):
		footprint_meters = value
		_apply()
@export_range(0.05, 12.0, 0.05, "suffix:m") var height_meters: float = 2.0:
	set(value):
		height_meters = value
		_apply()
@export var tint: Color = Color(0.82, 0.7, 0.48):
	set(value):
		tint = value
		_apply()
@export var blocks_movement: bool = true:
	set(value):
		blocks_movement = value
		_apply()

@onready var _body_mesh: MeshInstance3D = $Body
@onready var _label: Label3D = $Label3D
@onready var _collision: CollisionShape3D = $StaticBody3D/CollisionShape3D


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	var box := BoxMesh.new()
	box.size = Vector3(footprint_meters.x, height_meters, footprint_meters.y)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint, BODY_ALPHA)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	box.material = material
	_body_mesh.mesh = box
	_body_mesh.position.y = height_meters * 0.5

	_label.text = title if status_note.is_empty() else "%s\n%s" % [title, status_note]
	_label.position.y = height_meters + LABEL_GAP_METERS

	var shape := BoxShape3D.new()
	shape.size = box.size
	_collision.shape = shape
	_collision.position.y = height_meters * 0.5
	_collision.disabled = not blocks_movement
