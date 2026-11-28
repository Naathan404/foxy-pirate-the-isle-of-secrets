class_name CharmFeel
extends RefCounted
## Shared feedback for charm casts and hits: hitstop, screen shake, a colour flash over the
## screen, a refraction shockwave and sound. Each call quietly does nothing when its autoload or
## the player's flash layer is missing (headless tests, bare scenes), so charms never check.
##
## Strength guide: light hits (pellets, single arrows) shake 2-3 px and stop only their target;
## heavy hits (finishers, lunges) shake 6-8 px, stop the world briefly and flash; big area
## blasts add a shockwave.

const HIT_SOUND: AudioStream = preload("res://assets/audio/combat/dagger_hit.wav")
const IMPACT_SOUND: AudioStream = preload("res://assets/audio/combat/bow_impact.wav")
const RELEASE_SOUND: AudioStream = preload("res://assets/audio/combat/bow_release.wav")
const WHOOSH_SOUND: AudioStream = preload("res://assets/audio/combat/dagger_throw.wav")
const TICK_SOUND: AudioStream = preload("res://assets/audio/combat/bow_charge_tick.wav")


static func shake(node: Node, pixels: float, seconds: float) -> void:
	var controller := _autoload(node, &"ScreenShakeController")
	if controller != null:
		controller.request(pixels, seconds)


## Freezes the whole game for a moment; pass the hit target so props can soften it.
static func hitstop(node: Node, seconds: float, target: Node = null) -> void:
	var controller := _autoload(node, &"HitstopController")
	if controller != null:
		controller.request(seconds, target)


## Freezes only `source` and `target` (their animation), the rest of the game keeps going.
static func local_hitstop(node: Node, source: Node3D, target: Node3D, seconds: float) -> void:
	var controller := _autoload(node, &"HitstopController")
	if controller != null:
		controller.request_local(source, target, seconds)


static func flash(
	node: Node, color: Color, opacity: float, seconds: float = 0.14, priority: int = 1
) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var layer := node.get_tree().get_first_node_in_group(&"combat_screen_flash")
	if layer != null:
		layer.call("flash", color, opacity, seconds, priority)


## A ring of refraction spreading from a world point; `radius_pixels` 0 covers the screen.
static func shockwave(
	node: Node,
	at: Vector3,
	color: Color,
	radius_pixels: float,
	strength: float = 0.014,
	seconds: float = 0.45
) -> void:
	var controller := _autoload(node, &"ShockwaveController")
	if controller != null:
		controller.request_world(at, seconds, strength, color, radius_pixels)


static func sound(
	node: Node, stream: AudioStream, at: Vector3, volume_db: float = -6.0, pitch: float = 1.0
) -> void:
	var manager := _autoload(node, &"AudioManager")
	if manager != null:
		manager.play_sfx_3d(stream, at, volume_db, pitch)


static func _autoload(node: Node, autoload_name: StringName) -> Node:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	return node.get_node_or_null(NodePath("/root/" + String(autoload_name)))
