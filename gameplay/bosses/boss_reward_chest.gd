class_name BossRewardChest
extends TreasureChest

signal reward_pickup_spawned(index: int, pickup: ItemPickup)

const SHOCKWAVE_DURATION := 0.35
const SHOCKWAVE_STRENGTH := 0.007
const SHOCKWAVE_COLOR := Color("ffe3a0")
const SHOCKWAVE_RADIUS_PIXELS := 110.0

@export var rewards: Array[BaseItem] = []


func _ready() -> void:
	super()
	destroyed.connect(_drop_rewards)


func _drop_rewards() -> void:
	get_node("/root/ShockwaveController").request_world(
		global_position + Vector3.UP,
		SHOCKWAVE_DURATION, SHOCKWAVE_STRENGTH, SHOCKWAVE_COLOR, SHOCKWAVE_RADIUS_PIXELS
	)
	for index in rewards.size():
		if rewards[index] == null:
			continue
		var pickup := pickup_scene.instantiate() as ItemPickup
		pickup.item = rewards[index]
		get_parent().add_child(pickup)
		pickup.global_position = global_position
		var angle := TAU * index / maxf(1.0, float(rewards.size()))
		reward_pickup_spawned.emit(index, pickup)
		pickup.play_drop_animation(Vector3(cos(angle), 0.0, sin(angle)))


## Restore the opened appearance without replaying rewards or camera effects.
func restore_opened() -> void:
	_destroyed = true
	_health.set_current_hp(0.0)
	_hurtbox.enabled = false
	_hurtbox.set_deferred("monitorable", false)
	if visual_root is Sprite3D and depleted_texture != null:
		(visual_root as Sprite3D).texture = depleted_texture
