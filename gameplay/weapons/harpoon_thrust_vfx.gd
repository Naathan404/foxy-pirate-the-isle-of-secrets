extends Node3D
## Gold lance and rectangular startup telegraph; art and combat remain separate.

var _reach: float = 1.0
var _striking: bool = false

@onready var _guide: MeshInstance3D = $Guide
@onready var _lance: MeshInstance3D = $Lance
@onready var _tip: MeshInstance3D = $Tip
@onready var _particles: GPUParticles3D = $Sparks


func _ready() -> void:
	_guide.hide()
	_lance.hide()
	_tip.hide()


func prepare(reach: float, width: float, skill: bool) -> void:
	_reach = reach
	var ground_height: float = 0.04
	if skill:
		var origin := global_position + Vector3.UP * 0.4
		var query := PhysicsRayQueryParameters3D.create(
			origin, origin + Vector3.DOWN * 3.0, CombatLayers.WORLD
		)
		var ground := get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty():
			ground_height = float(ground.position.y) - global_position.y + 0.025
	var mesh := _guide.mesh.duplicate() as QuadMesh
	mesh.size = Vector2(maxf(0.4, width), reach)
	_guide.mesh = mesh
	_guide.position = Vector3(0.0, ground_height, -reach * 0.5)
	_guide.visible = skill


func strike(reach: float) -> void:
	_striking = true
	_reach = reach
	_guide.hide()
	_lance.show()
	_tip.show()
	var mesh := _lance.mesh.duplicate() as QuadMesh
	mesh.size = Vector2(0.35, reach + 0.4)
	_lance.mesh = mesh
	_lance.position = Vector3(0.0, 0.8, -reach * 0.5)
	_tip.position = Vector3(0.0, 0.8, -reach)
	_particles.emitting = true
	set_progress(0.0)


func set_progress(progress: float) -> void:
	if not _striking:
		return
	var opacity: float = 1.0 - progress * 0.6
	(_lance.material_override as ShaderMaterial).set_shader_parameter("opacity", opacity)
	_tip.scale = Vector3.ONE * lerpf(0.7, 1.1, sin(progress * PI))
	_particles.position = Vector3(0.0, 0.8, -_reach * 0.75)


func finish() -> void:
	_striking = false
	_guide.hide()
	_lance.hide()
	_tip.hide()
	_particles.emitting = false
