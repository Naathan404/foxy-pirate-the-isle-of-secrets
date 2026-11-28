class_name ArrowRainTelegraph
extends Node3D
## Landing zone of an Arrow Rain volley: a ring of sun rays that fills while the arrows are in
## the air and erupts the moment the last one lands, with a heavy shake, a golden flash and a
## refraction wave. Damage stays with the arrows themselves.

@export var radius: float = 2.0
## Time from the first release to the last arrow landing.
@export var lifetime: float = 1.7
@export var ring_color: Color = Color(1.0, 0.72, 0.3)

var _zone: CharmBlastVfx


func _ready() -> void:
	_zone = CharmBlastVfx.plant(
		get_parent(), global_position, CharmBlastVfx.Kind.GOLD, radius, lifetime, ring_color
	)
	get_tree().create_timer(lifetime, false).timeout.connect(_erupt, CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	# Cancelled before the volley ended (death, unequip): fade the zone, no eruption.
	if is_instance_valid(_zone):
		_zone.dismiss()
	_zone = null


func _erupt() -> void:
	if is_instance_valid(_zone):
		_zone.detonate()
	_zone = null
	CharmFeel.shake(self, 7.0, 0.2)
	CharmFeel.flash(self, ring_color, 0.1, 0.14)
	CharmFeel.shockwave(self, global_position + Vector3.UP * 0.4, ring_color, 210.0)
	CharmFeel.sound(self, CharmFeel.IMPACT_SOUND, global_position, -2.0, 0.8)
	queue_free()
