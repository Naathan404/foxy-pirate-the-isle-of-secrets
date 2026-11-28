class_name ItemPickup
extends Area3D

const NOTE_ITEM: BaseItem = preload("res://data/items/quest/note.tres")
const BOSS_DIARY_ITEM: BaseItem = preload("res://data/items/quest/boss_diary.tres")
const CHARM_UNLOCK := preload("res://gameplay/charms/progression/charm_unlock.tscn")
const BLUEPRINT_UNLOCK_PATH := "res://gameplay/weapons/blueprints/blueprint_unlock.tscn"
const SHOWCASE_SOUND: AudioStream = preload("res://assets/audio/ui/charm_reveal.wav")
const SHOWCASE_SOUND_DB := -10.0
const CHARM_HIGHLIGHT := Color("ff4d6d")
const UNIQUE_HIGHLIGHT := Color("ffc23d")

@export var item: BaseItem
## A note pickup unlocks this entry instead of taking an inventory slot.
@export var note: MonsterNote
@export_range(1, 999, 1) var quantity: int = 1

@export_group("Idle Animation")
@export var idle_animation_enabled: bool = true
@export_range(0.0, 0.3, 0.01) var pulse_amount: float = 0.08
@export_range(0.0, 1.0, 0.01) var float_height: float = 0.2
@export_range(0.0, 1.0, 0.01) var ground_clearance: float = 0.08
@export_range(0.0, 1.0, 0.01) var bob_height: float = 0.35
@export_range(0.2, 5.0, 0.1) var cycle_duration: float = 1.2
@export_range(0.2, 5.0, 0.1) var scale_cycle_duration: float = 0.6

@export_group("Drop Animation")
@export_range(0.1, 3.0, 0.05) var drop_height: float = 0.9
@export_range(0.05, 1.0, 0.01) var rise_duration: float = 0.18
@export_range(0.05, 1.0, 0.01) var fall_duration: float = 0.28

@export_group("Showcase Drop")
## Higher, slower and farther than ordinary loot, so a unique reward lands clear of the coins.
@export_range(0.5, 5.0, 0.05, "suffix:m") var showcase_height: float = 2.3
@export_range(0.2, 2.0, 0.05, "suffix:s") var showcase_flight_seconds: float = 0.95
@export_range(1.0, 6.0, 0.05, "suffix:m") var showcase_distance: float = 3.3
## Stays on show this long after landing before Foxy can pull it in.
@export_range(0.0, 3.0, 0.05, "suffix:s") var showcase_hold_seconds: float = 0.9
@export_range(1.0, 2.0, 0.01) var showcase_scale: float = 1.25
@export_range(0.01, 0.5, 0.01) var showcase_trail_width: float = 0.3

var _idle_tween: Tween
var _drop_tween: Tween
var _rest_scale: Vector3
var _rest_position: Vector3
var _can_be_picked_up: bool = true
var _collecting: bool = false
var _showcasing: bool = false
var _highlight: RewardHighlight

@onready var sprite: Sprite3D = $Sprite3D
@onready var _scatter: PickupScatter = $Scatter
@onready var _attraction: PlayerAttraction = $Attraction


func _ready() -> void:
	if note != null:
		item = note.pickup_item
		if item == null:
			item = BOSS_DIARY_ITEM if note.layout == MonsterNote.Layout.BOSS else NOTE_ITEM
	if item != null:
		sprite.texture = item.icon
	_rest_scale = sprite.scale
	_rest_position = sprite.position
	# Sprite có tâm ở giữa ảnh: cần nâng thêm nửa chiều cao để đáy không lún.
	if sprite.texture != null:
		var frame_height: float = sprite.texture.get_height() / float(maxi(1, sprite.vframes))
		var half_height: float = frame_height * sprite.pixel_size * absf(_rest_scale.y) * 0.5
		_rest_position.y += half_height * maxf(1.15, 1.0 + pulse_amount)
	_rest_position.y += ground_clearance
	if idle_animation_enabled:
		_rest_position.y += float_height
	_scatter.landed.connect(_on_scatter_landed)
	_attraction.configure(_can_attract)
	_attraction.attraction_started.connect(_on_attraction_started)
	_attraction.attraction_cancelled.connect(_on_attraction_cancelled)
	_attraction.arrived.connect(_collect)
	_attraction.completed.connect(queue_free)
	_start_idle_animation()
	_attraction.set_enabled(true)


func _start_idle_animation() -> void:
	sprite.scale = _rest_scale
	sprite.position = _rest_position
	if not idle_animation_enabled:
		return

	# tween floating item & scale
	var half_cycle: float = maxf(0.1, cycle_duration / 2.0)
	var half_scale_cycle: float = maxf(0.1, scale_cycle_duration / 2.0)
	_idle_tween = create_tween().set_loops()
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(
		sprite, "scale", _rest_scale * (1.0 + pulse_amount), half_scale_cycle
	)
	_idle_tween.parallel().tween_property(
		sprite, "position:y", _rest_position.y + bob_height, half_cycle
	)
	_idle_tween.tween_property(sprite, "scale", _rest_scale, half_scale_cycle)
	_idle_tween.parallel().tween_property(sprite, "position:y", _rest_position.y, half_cycle)


## One-of-a-kind rewards that should never get lost in a pile of loot.
func is_special_reward() -> bool:
	if note != null or item == null:
		return false
	return (
		item.charm != null
		or item.weapon_blueprint != null
		or item.type == GlobalConstants.ItemType.QUEST
	)


## Waits out of sight for `delay_seconds`, then makes its own entrance toward `direction`.
func play_showcase_drop(direction: Vector3, delay_seconds: float) -> void:
	_stop_motion()
	hide()
	_drop_tween = create_tween()
	_drop_tween.tween_interval(maxf(0.01, delay_seconds))
	_drop_tween.tween_callback(_launch_showcase.bind(direction))


## Marks a special reward that is already lying on the ground.
func show_highlight() -> void:
	# Self-lit, so it stays readable in dark rooms.
	sprite.shaded = false
	if _highlight == null:
		var tint := CHARM_HIGHLIGHT if item.charm != null else UNIQUE_HIGHLIGHT
		_highlight = RewardHighlight.attach(self, tint)
	_highlight.burst()


func _launch_showcase(direction: Vector3) -> void:
	show()
	sprite.shaded = false
	if not _showcasing:
		_showcasing = true
		_rest_scale *= showcase_scale
	_scatter.distance_min = showcase_distance
	_scatter.distance_max = showcase_distance
	_scatter.height_variation = 0.0
	_scatter.duration_variation = 0.0
	_scatter.trail_width = showcase_trail_width
	_scatter.trail_color = (CHARM_HIGHLIGHT if item.charm != null else UNIQUE_HIGHLIGHT)
	_stop_motion()
	sprite.position = _rest_position
	sprite.scale = _rest_scale
	_scatter.launch(showcase_height, showcase_flight_seconds, direction)


func _stop_motion() -> void:
	_attraction.reset()
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_can_be_picked_up = false


## Called after placement; the shared scatter component moves both visual and pickup area.
func play_drop_animation(direction: Vector3 = Vector3.ZERO) -> void:
	_stop_motion()
	sprite.position = _rest_position
	sprite.scale = _rest_scale
	_scatter.launch(drop_height, rise_duration + fall_duration, direction)


func _on_scatter_landed() -> void:
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_drop_tween = create_tween()
	# Ép nhẹ khi chạm đất, rồi trả lại hình dáng trước khi lơ lửng.
	_drop_tween.tween_property(sprite, "scale", _rest_scale * Vector3(1.16, 0.78, 1.0), 0.06)
	_drop_tween.tween_property(sprite, "scale", _rest_scale, 0.12)
	if _showcasing:
		show_highlight()
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null:
			audio.play_sfx_3d(SHOWCASE_SOUND, global_position, SHOWCASE_SOUND_DB)
		_drop_tween.tween_callback(_start_idle_animation)
		_drop_tween.tween_interval(showcase_hold_seconds)
		_drop_tween.tween_callback(_enable_pickup)
		return
	_drop_tween.tween_callback(_finish_drop_animation)


func _finish_drop_animation() -> void:
	_start_idle_animation()
	_enable_pickup()


func _enable_pickup() -> void:
	_drop_tween = null
	_can_be_picked_up = true
	_attraction.set_enabled(true)


func _on_body_entered(body: Node3D) -> void:
	_attraction.try_attract(body)


func _can_attract(target: Node3D) -> bool:
	if get_tree().paused:
		return false
	if not _can_be_picked_up or _collecting or is_queued_for_deletion():
		return false
	if item == null or quantity <= 0 or not target is Player:
		return false
	var player := target as Player
	if player.dead or player.is_gameplay_input_blocked():
		return false
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return false
	if note != null:
		return not note.note_id.is_empty()
	if item.charm != null:
		var registry := player.charm_registry
		if not is_instance_valid(registry):
			return false
		var definition := registry.get_definition(item.charm.charm_id)
		if registry.is_owned(item.charm.charm_id):
			call_deferred("queue_free")
			return false
		return definition != null and definition.is_playable() and definition.effect_scene != null
	if item.weapon_blueprint != null:
		var weapons := player.weapon_controller
		var weapon_id := item.weapon_blueprint.weapon_id
		return is_instance_valid(weapons) and weapons.has_weapon_definition(weapon_id)
	# A generic note without an entry cannot grant anything and must not enter inventory.
	if (
		item.opens_note
		or item.item_id == NOTE_ITEM.item_id
		or item.item_id == BOSS_DIARY_ITEM.item_id
	):
		return false
	return inventory.get_available_space(item) > 0


func _on_attraction_started(target: Node3D) -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	sprite.position = _rest_position
	sprite.scale = _rest_scale
	if _highlight != null:
		_highlight.hide()
	if item != null and item.charm != null:
		_attraction.reset()
		_collecting = true
		var presentation := CHARM_UNLOCK.instantiate()
		get_tree().root.add_child(presentation)
		presentation.begin(self, target as Player)
	elif item != null and item.weapon_blueprint != null:
		var player := target as Player
		if player.weapon_controller.is_blueprint_unlocked(item.weapon_blueprint.weapon_id):
			return
		_attraction.reset()
		_collecting = true
		# Load on demand: the presentation references ItemPickup in its public API.
		var presentation := (load(BLUEPRINT_UNLOCK_PATH) as PackedScene).instantiate()
		get_tree().root.add_child(presentation)
		presentation.begin(self, player)


## The presentation owns the reward transaction; this only releases the reserved pickup.
## A consumed pickup is removed; otherwise it reappears and can be collected again.
func finish_reward_presentation(consumed: bool) -> void:
	if consumed:
		queue_free()
		return
	sprite.show()
	if _highlight != null:
		_highlight.show()
	_collecting = false
	_attraction.set_enabled(true)
	_start_idle_animation()


## Kept for existing callers; Blueprint and Charm reveals share one release path.
func finish_blueprint_presentation(consumed: bool) -> void:
	finish_reward_presentation(consumed)


func _on_attraction_cancelled() -> void:
	_collecting = false
	if _highlight != null:
		_highlight.show()
	_start_idle_animation()


func _collect(target: Node3D) -> void:
	if not _can_attract(target):
		_attraction.retry()
		return
	var inventory := target.get_node_or_null("Inventory") as Inventory
	# Inventory signals may re-enter pickup code; reserve the transaction first.
	_collecting = true
	if note != null:
		get_node("/root/NoteProgress").discover(note)
		quantity = 0
		inventory.notify_item_picked_up(item, 1)
		_can_be_picked_up = false
		_attraction.complete()
		return
	if item.charm != null:
		# Charm pickups use the presentation started before attraction moves them.
		_collecting = false
		_attraction.retry()
		return
	if item.weapon_blueprint != null:
		var player := target as Player
		if not player.weapon_controller.set_blueprint_unlocked(
			item.weapon_blueprint.weapon_id, true
		):
			_collecting = false
			_attraction.retry()
			return
		quantity = 0
		inventory.notify_item_picked_up(item, 1)
		_can_be_picked_up = false
		_attraction.complete()
		return
	var requested_quantity := quantity
	quantity = inventory.add_item(item, quantity)
	var accepted_quantity := requested_quantity - quantity
	inventory.notify_item_picked_up(item, accepted_quantity)
	if quantity > 0:
		_collecting = false
		_attraction.retry()
		return
	_can_be_picked_up = false
	_attraction.complete()
