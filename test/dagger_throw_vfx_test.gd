extends SceneTree

const DAGGER_PATH: String = "res://gameplay/weapons/attack scenes/dagger_throw.tscn"

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(DAGGER_PATH) as PackedScene
	var world := Node3D.new()
	root.add_child(world)
	var actor := Node3D.new()
	world.add_child(actor)
	var dagger = scene.instantiate()
	world.add_child(dagger)
	var context := AttackContext.new()
	context.actor = actor
	context.direction = Vector3.RIGHT
	context.range_units = 4.0
	dagger.context = context
	var effect = dagger.get_node("ThrowVFX")
	# Keep fade assertions independent of the scene's art tuning.
	effect.trail_lifetime = 0.19
	effect.ghost_lifetime = 0.14
	_check(not effect.is_processing(), "No VFX before release")
	dagger.activate()
	dagger.set_physics_process(false)
	effect.set_process(false)
	_check(effect.get_parent() == world, "VFX detached into projectile world")
	_check(effect._flying and effect._aura.visible, "Release starts blade halo")
	_check(effect._bursts[0].visible, "Release burst appears")
	var count: int = effect.get_child_count()
	for index in 10:
		dagger.position.x += 0.15
		effect._process(0.016)
	_check(effect._ribbon_mesh.get_surface_count() == 1, "Ribbon follows flight samples")
	var stamped: Vector3 = effect._ghosts[0].global_position
	dagger.position.x += 1.0
	_check(effect._ghosts[0].global_position == stamped, "Echo remains in world space")
	paused = true
	_check(not effect.can_process(), "VFX respects inventory pause")
	paused = false
	dagger._begin_return()
	_check(effect._returning and dagger.returning, "Recall switches VFX palette")
	_check(effect._color() == effect.return_color, "Recall uses cyan color")
	for index in 30:
		effect.impact(dagger.global_position)
	_check(effect.get_child_count() == count, "Multi-hit bursts reuse fixed pool")
	_check(dagger.speed == 12.0 and dagger.return_speed == 16.0, "Flight speeds preserved")
	_check(dagger.max_distance == 4.0, "Attack range preserved")
	effect.finish(true)
	dagger.free()
	_check(not effect._flying and not effect._aura.visible, "Catch stops continuous effects")
	effect._process(0.3)
	_check(effect._points.is_empty(), "Detached trail fades after catch")
	for ghost: Sprite3D in effect._ghosts:
		_check(not ghost.visible, "Detached echoes fade after catch")
	effect._process(0.2)
	_check(effect.is_queued_for_deletion(), "Detached VFX cleans itself up")
	effect.free()
	# External projectile deletion must also drain the trail and clean up.
	var cancelled = scene.instantiate()
	world.add_child(cancelled)
	cancelled.context = context
	var orphan = cancelled.get_node("ThrowVFX")
	cancelled.activate()
	orphan.set_process(false)
	cancelled.free()
	orphan._process(0.1)
	_check(not orphan._flying, "Deleted source stops VFX safely")
	orphan._process(0.5)
	_check(orphan.is_queued_for_deletion(), "Deleted source leaves no orphan VFX")
	orphan.free()
	world.free()
	if _failures == 0:
		print("Dagger VFX release, ribbon, recall, pooling and cleanup checks passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
