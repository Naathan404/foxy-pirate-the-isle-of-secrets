extends SceneTree
## Checks every prop of a Coral Valley room against the art rules and prints PASS/FAIL:
## collision by kind (rules 11-12), palm height (rule 8), base pivot for tall props (rule 13),
## the prop budget (rule 20). Exit code 1 if anything fails.
##
## godot --headless --path . --script <this> -- res://world/biomes/coral_valley/map/room_XX.tscn

const PASS_THROUGH := ["coral", "seaweed"]
const BLOCKING := ["palm", "stone", "wood_log", "shell", "campfire"]
const PROP_FOLDER := "/coral_valley/objects/"
const PALM_MIN_METERS := 7.0
const PALM_MAX_METERS := 9.0
const SEAWEED_METERS := 4.7
## Props this tall must pivot at their base (rule 13). Today only palms are trees.
const TALL_PROP_METERS := 5.0
const PROP_BUDGET := 30
## A base-pivoted sprite sits on the ground and its offset lifts the image by most of its half
## height; a centre-pivoted one sits about half its height above the ground.
const PIVOT_TOLERANCE_METERS := 0.3

var _failures := 0


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file(path)
	await create_timer(1.0).timeout
	var points := 0
	var tallest_other := 0.0
	var palm_heights: Array[float] = []
	for prop in _room_props(current_scene):
		var file := String(prop.scene_file_path).get_file()
		var sprite := prop.get_node_or_null("Visual/Sprite3D") as Sprite3D
		if sprite == null or sprite.texture == null:
			continue
		var height := (
			sprite.texture.get_height()
			* sprite.pixel_size
			* sprite.global_transform.basis.get_scale().y
		)
		var is_palm := file.contains("palm")
		if not file.contains("campfire"):
			points += 2 if is_palm else 1
		if is_palm:
			palm_heights.append(height)
		elif not file.contains("seaweed") and not file.contains("campfire"):
			tallest_other = maxf(tallest_other, height)
		_check_collision(prop, file)
		if is_palm:
			_check(
				height >= PALM_MIN_METERS and height <= PALM_MAX_METERS,
				(
					"%s palm height %.2f m within %.0f-%.0f m"
					% [prop.name, height, PALM_MIN_METERS, PALM_MAX_METERS]
				)
			)
		if height >= TALL_PROP_METERS and is_palm:
			_check_pivot(prop, sprite)
	_check(points <= PROP_BUDGET, "prop budget %d / %d points" % [points, PROP_BUDGET])
	for palm_height in palm_heights:
		_check(
			palm_height >= SEAWEED_METERS * 1.5 and palm_height > tallest_other,
			"palms are the tallest props (%.2f m)" % palm_height
		)
	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_collision(prop: Node, file: String) -> void:
	var shape := prop.get_node_or_null("MovementBody/CollisionShape3D") as CollisionShape3D
	var body := prop.get_node_or_null("MovementBody") as CollisionObject3D
	var blocks := (
		shape != null and not shape.disabled and body != null and body.collision_layer != 0
	)
	for kind in PASS_THROUGH:
		if file.contains(kind):
			_check(not blocks, "%s (%s) lets Foxy walk through" % [prop.name, file])
			return
	for kind in BLOCKING:
		if file.contains(kind):
			_check(blocks, "%s (%s) blocks Foxy" % [prop.name, file])
			return


func _check_pivot(prop: Node, sprite: Sprite3D) -> void:
	var lift := sprite.offset.y * sprite.pixel_size
	var half := sprite.texture.get_height() * sprite.pixel_size * 0.5
	var base_pivot := absf(sprite.position.y) <= PIVOT_TOLERANCE_METERS and lift > half * 0.5
	_check(
		base_pivot,
		(
			"%s pivots at its base (offset.y %.0f px, sprite y %.2f)"
			% [prop.name, sprite.offset.y, sprite.position.y]
		)
	)
	var upright := bool(prop.get("swingable")) and bool(prop.get("upright_depth"))
	_check(upright, "%s uses swingable + upright_depth" % prop.name)
	var shape := prop.get_node_or_null("MovementBody/CollisionShape3D") as Node3D
	if shape != null:
		_check(
			absf(shape.position.x) <= PIVOT_TOLERANCE_METERS,
			"%s blocker sits under the trunk (x %.2f)" % [prop.name, shape.position.x]
		)


func _check(ok: bool, text: String) -> void:
	if ok:
		print("PASS  ", text)
	else:
		_fail(text)


func _fail(text: String) -> void:
	_failures += 1
	print("FAIL  ", text)


## Every Coral Valley prop placed in the room, wherever it sits (Scenery, Exits or elsewhere).
## The harbor boats come with the base scene's exits and are not room props.
func _room_props(room: Node) -> Array[Node]:
	var props: Array[Node] = []
	for node in room.find_children("*", "", true, false):
		var file := String(node.scene_file_path)
		if file.contains(PROP_FOLDER) and not file.contains("harbor_boat"):
			props.append(node)
	return props
