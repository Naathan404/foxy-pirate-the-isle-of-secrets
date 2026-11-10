extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://gameplay/player/foxy.tscn") as PackedScene
	assert(player_scene != null)
	var player := player_scene.instantiate()
	assert(player.get_node("Effects/LowHealthVignette") is LowHealthVignette)
	player.free()
	var health := HealthComponent.new()
	root.add_child(health)
	var effect := LowHealthVignette.new()
	effect.health = health
	effect.fade_in_seconds = 0.05
	effect.fade_out_seconds = 0.05
	root.add_child(effect)
	var overlay := effect._overlay as ColorRect
	assert(not overlay.visible)
	health.init(100.0)
	health.take_damage(69.0)
	assert(not overlay.visible, "31% HP must not show the warning")
	health.take_damage(1.0)
	assert(overlay.visible, "30% HP must show the warning")
	effect._transition.custom_step(0.08)
	effect._process(0.08)
	var first_strength: float = effect._material.get_shader_parameter("strength")
	assert(first_strength > 0.0)
	effect._process(effect.breath_cycle_seconds * 0.5)
	assert(effect._material.get_shader_parameter("strength") > first_strength, "Warning should pulse")
	health.heal(1.0)
	assert(overlay.visible, "Warning should fade rather than vanish immediately")
	effect._transition.custom_step(0.08)
	assert(not overlay.visible, "Warning should disappear above 30% HP")
	health.take_damage(1.0)
	assert(overlay.visible, "Warning should return when HP drops to 30% again")
	effect.queue_free()
	health.queue_free()
	print("low_health_vignette_test: PASS")
	quit()
