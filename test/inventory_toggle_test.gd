extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	root.add_child(player)
	await process_frame
	await process_frame
	var ui: InventoryUI = player.inventory_ui
	_check(ui != null, "Player references its inventory UI")
	_check(not ui.is_open() and not ui.visible, "Inventory starts closed and hidden")
	var mouse_mode_before: Input.MouseMode = Input.mouse_mode
	_press_key(KEY_TAB)
	_check(ui.is_open() and ui.visible, "Tab opens inventory")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Cursor is visible while open")
	_check(not paused, "Opening inventory keeps world running")
	_check(player.is_gameplay_input_blocked(), "Inventory blocks player input")

	player.move_direction = Vector3.RIGHT
	player.attack_requested = true
	player.dash_buffer_remaining = 1.0
	Input.action_press(&"right")
	player._read_input()
	Input.action_release(&"right")
	_check(player.move_direction == Vector3.ZERO, "Opening inventory clears movement input")
	_check(not player.attack_requested and player.dash_buffer_remaining == 0.0, "Clear pending attacks and dash")
	player.request_attack()
	player.request_dash()
	_check(not player.attack_requested and player.dash_buffer_remaining == 0.0, "Reject new combat requests while open")

	var previous_y: float = player.position.y
	player.velocity.y = -1.0
	player._physics_process(0.016)
	_check(player.position.y < previous_y, "Player physics continues while inventory is open")
	_press_key(KEY_TAB, true)
	_check(ui.is_open(), "Held key echo does not toggle repeatedly")
	ui.material_button.grab_focus()
	_press_key(KEY_TAB)
	_check(not ui.is_open() and not ui.visible, "Tab closes even with a focused UI button")
	_check(Input.mouse_mode == mouse_mode_before, "Closing restores previous cursor mode")
	_check(not player.is_gameplay_input_blocked(), "Closing restores player input")

	_press_key(KEY_TAB)
	ui._select_tab(2)
	_press_key(KEY_ESCAPE)
	_check(not ui.is_open() and not ui.visible, "Escape closes inventory from another tab")
	_press_key(KEY_ESCAPE)
	_check(not ui.is_open(), "Escape does not open a closed inventory")
	ui.open_inventory()
	_check(ui.tabs.current_tab == 2, "Reopening preserves selected tab")
	ui.open_inventory()
	ui.close_inventory()
	ui.close_inventory()
	_check(not ui.is_open() and Input.mouse_mode == mouse_mode_before, "Repeated open/close calls are safe")

	Input.action_press(&"right")
	player._read_input()
	Input.action_release(&"right")
	_check(not player.move_direction.is_zero_approx(), "Movement input works after closing")
	ui.open_inventory()
	player.die()
	_check(not ui.is_open(), "Player death closes inventory")
	_press_key(KEY_TAB)
	_check(not ui.is_open(), "Dead player cannot reopen inventory")
	player.free()
	_check(Input.mouse_mode == mouse_mode_before, "Scene teardown leaves cursor restored")
	if _failures == 0:
		print("Inventory toggle checks passed")
	quit(0 if _failures == 0 else 1)


func _press_key(key: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	release.echo = false
	root.push_input(release)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
