class_name BarrelMuzzleInk
extends Node3D
## Ink spat from a Barrel's mouth on each volley: droplets thrown along the shot and a puff of
## ink mist. A zero direction sprays all around (the elite's radial volley). Removes itself.

## Spread of the droplets when there is no shot direction.
const ALL_AROUND_SPREAD_DEGREES := 180.0

@onready var _droplets: GPUParticles3D = $Droplets
@onready var _mist: GPUParticles3D = $Mist


## `size` scales the whole burst, so a bigger barrel spits a bigger cloud.
func play(direction: Vector3, size: float) -> void:
	scale = Vector3.ONE * size
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		var material := _droplets.process_material.duplicate() as ParticleProcessMaterial
		material.spread = ALL_AROUND_SPREAD_DEGREES
		_droplets.process_material = material
	else:
		# Particles are emitted along local -Z; only yaw, so gravity still points down.
		basis = Basis.looking_at(horizontal.normalized()).scaled(scale)
	_droplets.emitting = true
	_mist.emitting = true
	var lifetime := maxf(_droplets.lifetime, _mist.lifetime)
	create_tween().tween_callback(queue_free).set_delay(lifetime)
