class_name BossRewardChest
extends TreasureChest

signal reward_pickup_spawned(index: int, pickup: ItemPickup)

const SHOCKWAVE_DURATION := 0.35
const SHOCKWAVE_STRENGTH := 0.007
const SHOCKWAVE_COLOR := Color("ffe3a0")
const SHOCKWAVE_RADIUS_PIXELS := 110.0

@export var rewards: Array[BaseItem] = []
@export var reward_notes: Array[MonsterNote] = []


func _ready() -> void:
	super()
	destroyed.connect(_drop_rewards)


func _drop_rewards() -> void:
	get_node("/root/ShockwaveController").request_world(
		global_position + Vector3.UP,
		SHOCKWAVE_DURATION,
		SHOCKWAVE_STRENGTH,
		SHOCKWAVE_COLOR,
		SHOCKWAVE_RADIUS_PIXELS
	)
	for index in rewards.size():
		if rewards[index] == null:
			continue
		_spawn_reward_pickup(rewards[index], null, index)
	for index in reward_notes.size():
		var note := reward_notes[index]
		if note == null or note.note_id.is_empty():
			continue
		_spawn_reward_pickup(null, note, rewards.size() + index)


func _spawn_reward_pickup(item: BaseItem, note: MonsterNote, index: int) -> void:
	var pickup := pickup_scene.instantiate() as ItemPickup
	pickup.item = item
	pickup.note = note
	get_parent().add_child(pickup)
	pickup.global_position = global_position
	var total := rewards.size() + reward_notes.size()
	var angle := TAU * index / maxf(1.0, float(total))
	reward_pickup_spawned.emit(index, pickup)
	pickup.play_drop_animation(Vector3(cos(angle), 0.0, sin(angle)))
