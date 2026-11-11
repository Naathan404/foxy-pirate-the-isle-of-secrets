@tool
class_name PlatformLever
extends StaticBody3D

## Place this lever anywhere in a level. Drag MovingPlatform nodes from the
## Scene tree into Target Platforms. Built-in docks can use their parent
## platform when this list is empty.

enum DestinationMode { START, END, TOGGLE }

@export_group("Platform Targets")
@export var target_platforms: Array[MovingPlatform] = []:
	set(value):
		target_platforms = value
		update_configuration_warnings()
@export var destination_mode: DestinationMode = DestinationMode.START
@export_storage var use_parent_platform_when_unassigned := false
@export_group("Scene Preview")
@export var show_target_links_in_editor := true

var _link_mesh: ImmediateMesh
var _link_preview: MeshInstance3D
var _preview_elapsed := 0.0

@onready var hurtbox: HurtBox = $Lever/HurtBox
@onready var _lever_sprite: AnimatedSprite3D = $Lever/AnimatedSprite3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_preview()
		return
	set_process(false)
	hurtbox.actor = self
	hurtbox.team = CombatTeams.ENEMY
	hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	_lever_sprite.animation_finished.connect(_on_lever_animation_finished)
	_lever_sprite.play(&"idle")


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_preview_elapsed += delta
	if _preview_elapsed < 0.2:
		return
	_preview_elapsed = 0.0
	_update_editor_preview()


func _setup_editor_preview() -> void:
	_link_mesh = ImmediateMesh.new()
	_link_preview = MeshInstance3D.new()
	_link_preview.name = "TargetLinksPreview"
	_link_preview.mesh = _link_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	_link_preview.material_override = material
	add_child(_link_preview, false, Node.INTERNAL_MODE_BACK)
	_update_editor_preview()


func _update_editor_preview() -> void:
	if _link_mesh == null:
		return
	_link_mesh.clear_surfaces()
	if not show_target_links_in_editor or target_platforms.is_empty():
		return
	var endpoints: Array[Vector3] = []
	for moving_platform in _get_targets():
		if moving_platform.is_inside_tree():
			endpoints.append(to_local(moving_platform.global_position))
	if endpoints.is_empty():
		return
	_link_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for endpoint in endpoints:
		_link_mesh.surface_set_color(Color(1.0, 0.7, 0.15, 0.85))
		_link_mesh.surface_add_vertex(Vector3.ZERO)
		_link_mesh.surface_add_vertex(endpoint)
	_link_mesh.surface_end()


func receive_damage(damage: DamageContext) -> float:
	if damage == null or damage.source_team != CombatTeams.PLAYER or damage.amount_hp <= 0.0:
		return 0.0
	var platforms := _get_targets()
	if platforms.is_empty():
		return 0.0
	for moving_platform in platforms:
		match destination_mode:
			DestinationMode.START:
				moving_platform.request_destination(false)
			DestinationMode.END:
				moving_platform.request_destination(true)
			DestinationMode.TOGGLE:
				moving_platform.request_destination(not moving_platform.is_targeting_end())
	_lever_sprite.stop()
	_lever_sprite.play(&"active")
	return damage.amount_hp


func _get_targets() -> Array[MovingPlatform]:
	var targets: Array[MovingPlatform] = []
	if target_platforms.is_empty() and use_parent_platform_when_unassigned:
		var parent_platform := get_parent() as MovingPlatform
		if parent_platform != null:
			targets.append(parent_platform)
	else:
		for platform in target_platforms:
			if is_instance_valid(platform) and platform not in targets:
				targets.append(platform)
	return targets


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_platforms.is_empty() and not use_parent_platform_when_unassigned:
		warnings.append(
			"Drag MovingPlatform nodes from the Scene tree into Target Platforms in the Inspector."
		)
	for platform in target_platforms:
		if platform == null:
			warnings.append("Target Platforms contains an empty slot.")
			break
	return warnings


func _on_lever_animation_finished() -> void:
	if _lever_sprite.animation == &"active":
		_lever_sprite.play(&"idle")
