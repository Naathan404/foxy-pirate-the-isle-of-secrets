extends PlayerState

@export_range(0.0, 5.0, 0.1) var reload_delay: float = 1.0

var _reload_requested: bool = false


# vào death thì terminal luôn
func _init() -> void:
	is_terminal = true


func _enter() -> void:
	player.dead = true
	player.dash_buffer_remaining = 0.0
	player.attack_requested = false
	player.cancel_attack()
	player.set_horizontal_velocity(Vector3.ZERO)
	_reload_requested = false
	timer = reload_delay
	if is_instance_valid(player.visual):
		var action := "death" if player.visual.has_directional_animation("death") else "hit"
		player.play_directional_animation(action, true)
		timer = maxf(timer, player.visual.get_current_animation_duration())


func _update(delta: float) -> void:
	player.set_horizontal_velocity(Vector3.ZERO)
	if _reload_requested:
		return
	timer = maxf(0.0, timer - delta)
	if timer <= 0.0:
		_reload_requested = true
		get_node("/root/GameManager").reload_current_scene()
