class_name TrialAltar
extends Node3D
## The shrine at the end of a Coral Valley trial. It holds one Tide Pearl, taken by walking
## into the altar, and optionally a Charm laid in front of it.
##
## Bound to a raid, the altar stays underground until the raid is cleared and then rises.
## Otherwise reaching it is the trial (the far islet of a grapple chain, the pearl islet of a
## puzzle). The pearl is remembered through `pearl_flag` for the run. The Charm is not a
## one-off drop: until Foxy owns it, it is laid out again on every visit, so leaving the room
## never loses it.

const ITEM_PICKUP: PackedScene = preload("res://gameplay/inventory/item_pickup.tscn")
const RISE_DEPTH_METERS := 2.5
const RISE_SHAKE_PIXELS := 5.0
const TAKE_SHAKE_PIXELS := 3.0
const SHAKE_SECONDS := 0.25
## Where the Charm lies, in front of the altar towards the camera.
const CHARM_OFFSET := Vector3(0.0, 0.0, 1.6)

## Story flag set when the pearl is taken, e.g. `coral_valley_pearl_courage`.
@export var pearl_flag: StringName = &""
@export var pearl_item: BaseItem
## Optional Charm reward, e.g. the Tide Grapple.
@export var charm_item: BaseItem
## Optional: the altar rises only once this raid is cleared.
@export var raid: RaidLockdown
@export_range(0.1, 3.0, 0.05, "suffix:s") var rise_seconds: float = 1.2
@export_range(0.1, 2.0, 0.05, "suffix:s") var take_seconds: float = 0.5
@export_range(0.0, 1.0, 0.01) var spent_light_ratio: float = 0.25

var _charm_pickup: ItemPickup

@onready var _visual: Node3D = $Visual
@onready var _pearl: Node3D = $Visual/Pearl
@onready var _light: OmniLight3D = $Visual/Light
@onready var _take_area: Area3D = $TakeArea
@onready var _light_energy: float = _light.light_energy


func _ready() -> void:
	if pearl_flag.is_empty() or pearl_item == null:
		push_error("TrialAltar: assign a pearl flag and the pearl item.")
		return
	_take_area.body_entered.connect(_on_body_entered)
	if raid != null and not raid.is_cleared():
		_set_active(false)
		raid.raid_cleared.connect(_rise, CONNECT_ONE_SHOT)
		return
	_set_active(true)


func is_pearl_taken() -> bool:
	return get_node("/root/GameManager").has_story_flag(pearl_flag)


func _set_active(active: bool) -> void:
	visible = active
	# A disabled body leaves the physics space, so a sunken altar blocks nothing.
	_visual.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_take_area.set_deferred("monitoring", active)
	if not active:
		return
	_pearl.visible = not is_pearl_taken()
	_light.light_energy = _light_energy * (spent_light_ratio if is_pearl_taken() else 1.0)
	_lay_out_charm.call_deferred()


func _rise() -> void:
	_set_active(true)
	_visual.position.y = -RISE_DEPTH_METERS
	var rise := create_tween().tween_property(_visual, "position:y", 0.0, rise_seconds)
	rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_node("/root/ScreenShakeController").request(RISE_SHAKE_PIXELS, rise_seconds)


func _lay_out_charm() -> void:
	if charm_item == null or charm_item.charm == null or is_instance_valid(_charm_pickup):
		return
	var player := get_node("/root/GameManager").player as Player
	if (
		is_instance_valid(player)
		and is_instance_valid(player.charm_registry)
		and player.charm_registry.is_owned(charm_item.charm.charm_id)
	):
		return
	_charm_pickup = ITEM_PICKUP.instantiate() as ItemPickup
	_charm_pickup.item = charm_item
	get_parent().add_child(_charm_pickup)
	_charm_pickup.global_position = to_global(CHARM_OFFSET)
	_charm_pickup.play_drop_animation(Vector3.BACK)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player or is_pearl_taken():
		return
	var player := body as Player
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory == null or inventory.add_item(pearl_item, 1) > 0:
		return
	get_node("/root/GameManager").set_story_flag(pearl_flag)
	inventory.notify_item_picked_up(pearl_item, 1)
	get_node("/root/ScreenShakeController").request(TAKE_SHAKE_PIXELS, SHAKE_SECONDS)
	var tween := create_tween().set_parallel()
	tween.tween_property(_pearl, "global_position", player.global_position, take_seconds)
	tween.tween_property(_pearl, "scale", Vector3.ZERO, take_seconds)
	tween.tween_property(_light, "light_energy", _light_energy * spent_light_ratio, take_seconds)
	tween.chain().tween_callback(_pearl.hide)
