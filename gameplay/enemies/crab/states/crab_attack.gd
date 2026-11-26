class_name CrabAttack
extends EnemyState
## A crab's claw pinch: standing beside Foxy, it raises the claw towards Foxy, slams it down
## and holds still a moment. Damage, shake and the cracked ground land on the frame the claw
## meets the ground.

@export_range(0.0, 2.0, 0.01, "suffix:s") var impact_delay: float = 0.7
@export_range(0.05, 1.0, 0.01, "suffix:s") var active_duration: float = 0.15
## How long the crab stays down after the hit, so the pinch can be punished.
@export_range(0.0, 2.0, 0.01, "suffix:s") var recovery_duration: float = 0.5
@export var impact_scene: PackedScene = preload("res://gameplay/enemies/crab/crab_slam_impact.tscn")
## Bone of the artwork where the claw meets the ground.
@export var impact_bone: String = "fx_impact"
## Sideways distance to the hit when the artwork has no such bone (sprite sheet).
@export_range(0.0, 4.0, 0.05, "suffix:m") var fallback_reach_meters: float = 1.0
@export_range(0.2, 2.0, 0.05) var impact_scale: float = 0.6

@export_group("Impact Feel")
@export_range(0.0, 14.0, 0.5, "suffix:px") var shake_pixels: float = 6.0
@export_range(0.0, 0.3, 0.01, "suffix:s") var shake_seconds: float = 0.18
@export_group("")

var _elapsed: float = 0.0
var _side: float = 1.0
var _has_impacted: bool = false


func _enter() -> void:
	if not enemy.has_target():
		request_state(&"patrol")
		return
	_side = -1.0 if enemy.target.global_position.x < enemy.global_position.x else 1.0
	enemy.face_direction(Vector3(_side, 0.0, 0.0))
	enemy._refresh_direction_checks()
	enemy.stop_movement()
	_elapsed = 0.0
	_has_impacted = false
	enemy.play_directional_animation(&"claw", true)


func _exit() -> void:
	enemy.end_active_attack()


func _update(delta: float) -> void:
	enemy.stop_movement(delta)
	_elapsed += maxf(0.0, delta)
	if not _has_impacted and _elapsed >= impact_delay:
		_impact()
	if _elapsed >= impact_delay + active_duration:
		enemy.end_active_attack()
	if _elapsed >= impact_delay + active_duration + recovery_duration:
		var patrol := get_node_or_null("../Patrol") as CrabPatrol
		if patrol != null:
			patrol.start_attack_cooldown()
		request_state(&"patrol")


func _impact() -> void:
	_has_impacted = true
	enemy.begin_active_attack(0, &"crab_pinch")
	enemy.get_node("/root/ScreenShakeController").request(shake_pixels, shake_seconds)
	var fallback := Vector3(_side * fallback_reach_meters, 0.0, 0.0)
	var effect := CrabSlamImpact.spawn_at_claw(impact_scene, enemy, impact_bone, fallback)
	if effect != null:
		effect.scale = Vector3.ONE * impact_scale
