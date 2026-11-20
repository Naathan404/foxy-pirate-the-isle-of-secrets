class_name EliteCoralRevive
extends EnemyState

enum Phase { CURL, DORMANT, REASSEMBLE }

@export_range(0.1, 4.0, 0.05, "suffix:s") var curl_duration: float = 0.75
@export_range(0.2, 15.0, 0.05, "suffix:s") var dormant_duration: float = 4.2
@export_range(0.1, 4.0, 0.05, "suffix:s") var reassemble_duration: float = 0.75

var _phase: Phase = Phase.CURL


func _enter() -> void:
	var skeleton := enemy as EliteCoralSkeleton
	if skeleton == null:
		request_state(&"guard")
		return
	skeleton.set_reviving(true)
	skeleton._set_horizontal_velocity(Vector3.ZERO)
	_phase = Phase.CURL
	timer = maxf(0.05, curl_duration)
	skeleton.play_directional_animation(&"bone_curl", true)
	skeleton._spawn_vfx(&"smoke", skeleton.global_position + Vector3.UP * 0.6)


func _exit() -> void:
	var skeleton := enemy as EliteCoralSkeleton
	if skeleton != null:
		skeleton.set_reviving(false)


func _update(delta: float) -> void:
	var skeleton := enemy as EliteCoralSkeleton
	if skeleton == null:
		return
	skeleton._set_horizontal_velocity(Vector3.ZERO)
	if not update_timer(delta):
		return
	match _phase:
		Phase.CURL:
			_phase = Phase.DORMANT
			timer = maxf(0.1, dormant_duration)
			skeleton.play_directional_animation(&"bone_dormant", true)
		Phase.DORMANT:
			_phase = Phase.REASSEMBLE
			timer = maxf(0.05, reassemble_duration)
			skeleton.play_directional_animation(&"bone_revive", true)
			skeleton._spawn_vfx(&"alert", skeleton.global_position + Vector3.UP * 1.4)
			skeleton._spawn_vfx(&"smoke", skeleton.global_position + Vector3.UP * 0.5)
		Phase.REASSEMBLE:
			skeleton.complete_revive()
			if skeleton.has_target():
				request_state(&"chase")
			elif skeleton.roam_when_guarding:
				request_state(&"guard")
			else:
				request_state(&"return")
