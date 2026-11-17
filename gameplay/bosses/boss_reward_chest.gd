class_name BossRewardChest
extends TreasureChest

signal reward_pickup_spawned(index: int, pickup: ItemPickup)

@export var rewards: Array[BaseItem] = []


func _ready() -> void:
	super()
	destroyed.connect(_drop_rewards)


func _drop_rewards() -> void:
	get_node("/root/ShockwaveController").request_world(
		global_position + Vector3.UP, 0.45, 0.016, Color("ffe3a0")
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
