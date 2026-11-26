class_name TidePearlGate
extends ExitSeal
## The Pearl Gate: a shrine beside a sealed exit with one socket per pearl. Its prompt shows how
## many pearls Foxy carries; with enough of them, interacting sets the pearls into the
## sockets one by one, takes them from the inventory and opens the exit for good.

const SOCKET_POP_SCALE := 1.6
const REFUSE_SHAKE_PIXELS := 2.0
const REFUSE_SHAKE_SECONDS := 0.15
const OPEN_SHAKE_PIXELS := 6.0
const OPEN_SHAKE_SECONDS := 0.4

@export var pearl_item: BaseItem
@export_range(1, 9, 1) var pearls_required: int = 3
@export var interaction: NpcInteractionArea
## One node per pearl; each is hidden until its pearl is set.
@export var socket_pearls: Array[Node3D] = []
@export_range(0.05, 2.0, 0.05, "suffix:s") var socket_fill_seconds: float = 0.4

var _placing: bool = false


func _ready() -> void:
	super()
	if pearl_item == null or interaction == null or socket_pearls.size() != pearls_required:
		push_error("TidePearlGate: assign the pearl item, interaction and one socket per pearl.")
		return
	var open_now := is_open()
	for socket in socket_pearls:
		socket.visible = open_now
	interaction.set_interaction_enabled(not open_now)
	interaction.body_entered.connect(_on_body_entered)
	interaction.interaction_requested.connect(_on_interaction_requested)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_refresh_prompt(body as Player)


func _refresh_prompt(player: Player) -> void:
	var carried := mini(_count_pearls(player), pearls_required)
	if carried >= pearls_required:
		interaction.set_prompt_text("Place the Tide Pearls")
	else:
		interaction.set_prompt_text("Tide Pearls %d/%d" % [carried, pearls_required])


func _on_interaction_requested(player: Player) -> void:
	if _placing or is_open():
		return
	if _count_pearls(player) < pearls_required:
		get_node("/root/ScreenShakeController").request(REFUSE_SHAKE_PIXELS, REFUSE_SHAKE_SECONDS)
		_refresh_prompt(player)
		return
	var inventory := player.get_node("Inventory") as Inventory
	if inventory.remove_item(StringName(pearl_item.item_id), pearls_required) < pearls_required:
		return
	_placing = true
	interaction.set_interaction_enabled(false)
	_place_pearls()


func _place_pearls() -> void:
	var tween := create_tween()
	for socket in socket_pearls:
		var rest_scale := socket.scale
		tween.tween_callback(socket.show)
		tween.tween_property(
			socket, "scale", rest_scale * SOCKET_POP_SCALE, socket_fill_seconds * 0.4
		)
		tween.tween_property(socket, "scale", rest_scale, socket_fill_seconds * 0.6)
	tween.tween_callback(
		get_node("/root/ScreenShakeController").request.bind(OPEN_SHAKE_PIXELS, OPEN_SHAKE_SECONDS)
	)
	tween.tween_callback(open)


func _count_pearls(player: Player) -> int:
	var inventory := player.get_node_or_null("Inventory") as Inventory
	return inventory.count_item(StringName(pearl_item.item_id)) if inventory != null else 0
