extends SceneTree

const PICKUP := preload("res://gameplay/inventory/item_pickup.tscn")
const MATERIAL := preload("res://data/items/consumables/wooden_arrow.tres")
var failures := 0

class TestPlayer:
	extends Player
	func _ready() -> void:
		pass
	func _exit_tree() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func is_gameplay_input_blocked() -> bool:
		return false

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run_tests() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var player := TestPlayer.new()
	var visual := PlayerVisual.new()
	visual.name = "Visual"
	visual.process_mode = Node.PROCESS_MODE_DISABLED
	var animator := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(&"idle_down", idle)
	animator.add_animation_library(&"", library)
	visual.add_child(animator)
	visual.animation_player = animator
	player.add_child(visual)
	var fsm := Fsm.new()
	fsm.name = "FSM"
	player.add_child(fsm)
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	var registry := CharmRegistry.new()
	player.add_child(registry)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2, 10)
	player.add_child(camera)
	holder.add_child(player)
	player.charm_registry = registry
	player.camera = camera
	await process_frame
	for slot in inventory.slots:
		slot.item = MATERIAL
		slot.quantity = MATERIAL.max_stack
	var dir := DirAccess.open("res://data/items/charms")
	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var item := load("res://data/items/charms/" + file) as BaseItem
		check(item != null and item.charm != null and item.icon != null, "Charm item data is complete")
		if item == null or item.charm == null:
			continue
		check(registry.register_definition(item.charm), "Charm definition registers")
		var pickup := PICKUP.instantiate() as ItemPickup
		pickup.item = item
		holder.add_child(pickup)
		check(pickup._can_attract(player), "Charm is collectible with full inventory")
		pickup._on_attraction_started(player)
		var presentation = root.get_child(root.get_child_count() - 1)
		var high: Vector2 = presentation._get_high_target(Vector2(410, 380), Vector2(1280, 720))
		check(is_equal_approx(high.x, 410.0) and high.y < 380.0, "Charm floats directly above the player")
		check(presentation._name_label.text == item.charm.display_name, "Editable UI displays the Charm name")
		check(presentation._surface.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Energy uses additive blending")
		check(presentation._icon_surface.material == null, "Charm icon retains normal blending")
		check(paused and not registry.is_owned(item.charm.charm_id), "Presentation pauses before granting")
		check(animator.assigned_animation == &"idle_down" and animator.process_mode == Node.PROCESS_MODE_ALWAYS, "Idle down runs while paused")
		if count == 0:
			var previous_time := animator.current_animation_position
			await create_timer(0.1, true).timeout
			check(animator.current_animation_position > previous_time, "Idle animation advances while the world is paused")
		presentation._process(2.72)
		check(presentation.phase == 1 and not registry.is_owned(item.charm.charm_id), "Presentation waits for confirmation")
		check(camera.fov < 75.0, "Camera zooms during presentation")
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		presentation._unhandled_input(key)
		check(presentation.phase == 1, "Enter does not confirm")
		key.keycode = KEY_SPACE
		presentation._unhandled_input(key)
		presentation._process(1.6)
		check(registry.is_owned(item.charm.charm_id), "Charm is granted at absorption")
		presentation._process(2.0)
		check(not paused, "World resumes after presentation")
		check(is_equal_approx(camera.fov, 75.0), "Camera zoom is restored")
		check(animator.process_mode == Node.PROCESS_MODE_INHERIT, "Animation process mode is restored")
		check(inventory.count_item(StringName(item.item_id)) == 0, "Charm uses no inventory slot")
		count += 1
	check(count == 12, "All playable Charm items are covered")
	var duplicate := PICKUP.instantiate() as ItemPickup
	duplicate.item = load("res://data/items/charms/arrow_rain.tres")
	holder.add_child(duplicate)
	check(not duplicate._can_attract(player), "Owned Charm does not trigger another presentation")
	player.charm_registry = null
	var invalid := PICKUP.instantiate() as ItemPickup
	invalid.item = duplicate.item
	holder.add_child(invalid)
	check(not invalid._can_attract(player), "Missing registry leaves pickup in the world")
	player.charm_registry = CharmRegistry.new()
	check(not invalid._can_attract(player), "Unregistered Charm leaves pickup in the world")
	player.charm_registry.free()
	player.charm_registry = registry
	registry.set_owned(&"arrow_rain", false)
	var cancelled := PICKUP.instantiate() as ItemPickup
	cancelled.item = load("res://data/items/charms/arrow_rain.tres")
	holder.add_child(cancelled)
	cancelled._on_attraction_started(player)
	var interrupted = root.get_child(root.get_child_count() - 1)
	player.charm_registry = null
	interrupted.phase = 2
	interrupted._process(2.0)
	check(not paused and cancelled.sprite.visible and not cancelled._collecting, "Failure restores the world and pickup")
	check(is_equal_approx(camera.fov, 75.0), "Failure restores camera")
	player.charm_registry = registry
	holder.queue_free()
	await process_frame
	await process_frame
	print("Charm pickup tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)



