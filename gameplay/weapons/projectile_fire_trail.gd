class_name ProjectileFireTrail
extends RefCounted
## One ribbon trail (a `assets/vfx/fire_trails` scene) following a projectile. The trail lives
## beside the projectile, not under it, so it can fade out after the projectile is freed.
##
## Call `follow()` every frame with the point the flame should start from, and `release()` when
## the projectile stops or is freed: the ribbons stop recording and the whole trail is freed
## once the longest one has faded. (A ribbon's own autodestruct frees only its holder node.)

const FREE_MARGIN_SECONDS := 0.1

var _root: Node3D


## Adds `scene` under `parent` at `at`. The ribbons' width and lifetime are multiplied by the
## scales; the scene's own looping sound is dropped, since projectiles play their own sounds.
func _init(
	scene: PackedScene, parent: Node, at: Vector3, width_scale: float, time_scale: float
) -> void:
	_root = scene.instantiate() as Node3D
	for player in _root.find_children("*", "AudioStreamPlayer3D", true, false):
		player.free()
	for ribbon in _ribbons():
		ribbon.set("width", float(ribbon.get("width")) * width_scale)
		ribbon.set("time", float(ribbon.get("time")) * time_scale)
	parent.add_child(_root)
	_root.global_position = at
	_root.reset_physics_interpolation()


func is_active() -> bool:
	return is_instance_valid(_root)


func follow(at: Vector3) -> void:
	if is_instance_valid(_root):
		_root.global_position = at


func release(at: Vector3) -> void:
	if not is_instance_valid(_root):
		return
	_root.global_position = at
	var fade_seconds := 0.0
	for ribbon in _ribbons():
		ribbon.set("emitting", false)
		fade_seconds = maxf(fade_seconds, float(ribbon.get("time")))
	# A scene-tree timer outlives the projectile, which is usually freed right after.
	_root.get_tree().create_timer(fade_seconds + FREE_MARGIN_SECONDS).timeout.connect(
		_root.queue_free
	)
	_root = null


func _ribbons() -> Array[Node]:
	var ribbons: Array[Node] = []
	for node in _root.find_children("*", "MeshInstance3D", true, false):
		if "emitting" in node and "autodestruct" in node:
			ribbons.append(node)
	return ribbons
