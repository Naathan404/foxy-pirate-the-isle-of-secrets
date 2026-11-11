extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://gameplay/player/foxy.tscn") as PackedScene
	var player := scene.instantiate() as Player
	root.add_child(player)
	var run_state := player.fsm.states.get("run") as FsmState
	player.move_direction = Vector3.RIGHT
	player.fsm.change_state(run_state)
	player.fsm._update(0.0)
	assert(player.fsm.current_state == run_state)
	player.velocity = Vector3(3.0, 0.0, 2.0)
	player.blocked = true
	player.hold_for_dialogue()
	assert(player.fsm.current_state == player.fsm.states.get("idle"))
	assert(player.move_direction == Vector3.ZERO)
	assert(player.velocity.x == 0.0 and player.velocity.z == 0.0)
	var assigned := String(player.visual.animation_player.assigned_animation)
	assert(assigned.begins_with("idle_"), "Dialogue should show idle immediately")
	player.queue_free()
	await process_frame
	print("player_dialogue_pose_test: PASS")
	quit()
