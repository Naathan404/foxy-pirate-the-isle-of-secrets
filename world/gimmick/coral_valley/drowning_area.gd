class_name DrowningArea
extends Area3D
## The water volume follows the surface; visual shader waves do not affect drowning.

@export var water: Node3D
@export var volume: CollisionShape3D
@export var drown_point_path: NodePath = ^"DrownPoint"
@export var enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(_delta: float) -> void:
	if not enabled or not is_instance_valid(water) or not is_instance_valid(volume):
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player == null or player.dead:
			continue
		var point := player.get_node_or_null(drown_point_path) as Marker3D
		if point == null or water.global_position.y <= point.global_position.y:
			continue
		# Overlap lists can lag behind teleports or a moving water surface by one tick.
		if not _contains_point(point.global_position):
			continue
		# Environmental death bypasses combat armor and dash invulnerability.
		# Use HealthComponent so the HUD and existing death/reload flow stay in sync.
		if is_instance_valid(player.hp) and player.hp.is_alive():
			player.hp.take_damage(player.hp.current_hp)
		else:
			player.die()


func _contains_point(world_position: Vector3) -> bool:
	var box := volume.shape as BoxShape3D
	if box == null or volume.disabled:
		return false
	var point := volume.to_local(world_position).abs()
	var half_size := box.size * 0.5
	return point.x <= half_size.x and point.y <= half_size.y and point.z <= half_size.z
