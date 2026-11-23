extends SceneTree
## Prints what a Coral Valley room looks like to the art rules: the ground sprite's world rect
## (for bake_ground.py), visual vs collision floor heights, and every prop's height,
## scale and blocking. Read-only.
##
## godot --headless --path . --script <this> -- res://world/biomes/coral_valley/map/room_XX.tscn

const RAY_TOP := 20.0
const RAY_BOTTOM := -20.0
const PROP_FOLDER := "/coral_valley/objects/"
const MAX_RAY_HITS := 12


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file(path)
	await create_timer(1.0).timeout
	var room := current_scene as Node3D
	var foxy := room.get_node_or_null("Foxy") as CollisionObject3D

	print("== ", path)
	var ground := room.get_node_or_null("Environment/BaseGround/Sprite3D") as Sprite3D
	if ground != null:
		var box := ground.global_transform * ground.get_aabb()
		print(
			(
				"ground_rect (x0, z0, width, depth): [%.5f, %.5f, %.5f, %.5f]"
				% [box.position.x, box.position.z, box.size.x, box.size.z]
			)
		)
		var floor_y := _floor_at(room, foxy, box.get_center().x, box.get_center().z)
		print(
			(
				"ground sprite y %.3f, floor under centre %.3f, lift visuals by %.3f m"
				% [box.position.y, floor_y, floor_y - box.position.y]
			)
		)
	for exit_name in ["LeftPath", "RightPath", "UpPath", "DownPath"]:
		var exit := room.get_node_or_null("Exits/" + exit_name) as Node3D
		if exit == null or not exit.visible:
			continue
		var sprite := exit.get_node_or_null("Sprite3D") as Sprite3D
		var box := sprite.global_transform * sprite.get_aabb()
		var c := box.get_center()
		var floor_y := _floor_at(room, foxy, c.x, c.z)
		print(
			(
				"%s sprite y %.3f, floor %.3f, lift by %.3f m"
				% [exit_name, box.position.y, floor_y, floor_y - box.position.y]
			)
		)

	var points := 0
	for prop in _room_props(room):
		var sprite := prop.get_node_or_null("Visual/Sprite3D") as Sprite3D
		if sprite == null or sprite.texture == null:
			continue
		var height := (
			sprite.texture.get_height()
			* sprite.pixel_size
			* sprite.global_transform.basis.get_scale().y
		)
		var is_palm := String(prop.scene_file_path).contains("palm")
		if not String(prop.scene_file_path).contains("campfire"):
			points += 2 if is_palm else 1
		var shape := prop.get_node_or_null("MovementBody/CollisionShape3D") as CollisionShape3D
		var body := prop.get_node_or_null("MovementBody") as CollisionObject3D
		var blocks := shape != null and not shape.disabled and body.collision_layer != 0
		print(
			(
				"%-26s %-22s scale %.2f  height %.2f m  blocks %s  pos (%.1f, %.1f)"
				% [
					prop.name,
					String(prop.scene_file_path).get_file(),
					(prop as Node3D).scale.x,
					height,
					blocks,
					(prop as Node3D).global_position.x,
					(prop as Node3D).global_position.z
				]
			)
		)
	print("prop budget: %d / 30 points (palms count 2)" % points)
	quit()


## Floor height at (x, z): skips props and characters until the ray meets room floor
## (Environment) or an exit pier (Exits).
func _floor_at(room: Node3D, foxy: CollisionObject3D, x: float, z: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, RAY_TOP, z), Vector3(x, RAY_BOTTOM, z)
	)
	var excluded: Array[RID] = []
	if foxy != null:
		excluded.append(foxy.get_rid())
	for i in MAX_RAY_HITS:
		query.exclude = excluded
		var hit := room.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return NAN
		var collider := hit.collider as Node
		var path := String(room.get_path_to(collider))
		if path.begins_with("Environment") or path.begins_with("Exits"):
			return hit.position.y
		excluded.append(hit.rid)
	return NAN


## Every Coral Valley prop placed in the room, wherever it sits (Scenery, Exits or elsewhere).
## The harbor boats come with the base scene's exits and are not room props.
func _room_props(room: Node) -> Array[Node]:
	var props: Array[Node] = []
	for node in room.find_children("*", "", true, false):
		var file := String(node.scene_file_path)
		if file.contains(PROP_FOLDER) and not file.contains("harbor_boat"):
			props.append(node)
	return props
