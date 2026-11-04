class_name SilasNpc
extends BaseNpc

## A stationary merchant who opens for dialogue and closes after the shop farewell.

enum DialogueIntent { NONE, OPEN_FIRST_SHOP, OPEN_RETURNING_SHOP, CLOSE }
enum PresentationState { CLOSED, OPENING, OPEN, CLOSING }

@export_group("Silas Merchant")
@export var data: SilasNpcData
@export var catalog: MerchantCatalog
@export var shop_panel_path: NodePath

var _shop_panel: SilasShopPanel
var _dialogue_intent := DialogueIntent.NONE
var _presentation_state := PresentationState.CLOSED
var _active_interactor: Player
var _opening_player_was_blocked := false
var _pending_timeline := ""
var _stock_random := RandomNumberGenerator.new()
@onready var sprite: AnimatedSprite3D = $Visual/AnimatedSprite3D


func _ready() -> void:
	if data == null or catalog == null:
		push_error("SilasNpc: NPC data or merchant catalog is missing")
		set_physics_process(false)
		return
	var catalog_errors := catalog.validate()
	if not catalog_errors.is_empty():
		push_error("SilasNpc: invalid merchant catalog:\n%s" % "\n".join(catalog_errors))
		set_physics_process(false)
		return
	_stock_random.randomize()
	super()
	_shop_panel = get_node_or_null(shop_panel_path) as SilasShopPanel
	if _shop_panel == null:
		push_error("SilasNpc: shop panel is missing")
		return
	for animation: StringName in [&"idle_close", &"open", &"idle_open", &"close"]:
		if not sprite.sprite_frames.has_animation(animation):
			push_error("SilasNpc: missing sprite animation: %s" % animation)
			return
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.play(&"idle_close")
	_shop_panel.shop_closed.connect(_on_shop_closed)
	_shop_panel.stock_reroll_requested.connect(reroll_shop_stock)
	dialogue_finished.connect(_on_dialogue_finished)


func get_npc_data() -> NpcData:
	return data


func _focus_dialogue_camera(interactor: Player) -> void:
	# The greeting already focused the camera. Farewell must not focus it again
	# while the greeting's restore tween may still be running.
	if _dialogue_intent == DialogueIntent.CLOSE:
		return
	super(interactor)


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if action != &"idle" and action != &"walk":
		return false
	if not is_instance_valid(visual.animation_player):
		return false
	if visual.animation_player.assigned_animation == action and not restart:
		return true
	visual.animation_player.play(action)
	return true


func _on_interaction_requested(interactor: Player) -> void:
	if (
		_shop_panel == null
		or _shop_panel.visible
		or is_talking
		or _presentation_state != PresentationState.CLOSED
	):
		return
	interaction_requested.emit(interactor)
	_active_interactor = interactor
	var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
	var first_meeting := progress == null or not progress.has_met_silas()
	_dialogue_intent = (
		DialogueIntent.OPEN_FIRST_SHOP if first_meeting else DialogueIntent.OPEN_RETURNING_SHOP
	)
	_pending_timeline = data.dialogue_timeline if first_meeting else data.greeting_timeline
	_opening_player_was_blocked = interactor.blocked
	interactor.blocked = true
	_hold_player_idle(interactor)
	interaction_area.set_interaction_enabled(false)
	_presentation_state = PresentationState.OPENING
	sprite.play(&"open")


func _on_sprite_animation_finished() -> void:
	match _presentation_state:
		PresentationState.OPENING:
			_finish_opening()
		PresentationState.CLOSING:
			_finish_closing()


func _finish_opening() -> void:
	_presentation_state = PresentationState.OPEN
	sprite.play(&"idle_open")
	var interactor := _active_interactor
	_restore_opening_player_control()
	if not is_instance_valid(interactor) or interactor.dead:
		_begin_close()
		return
	var timeline := _pending_timeline
	_pending_timeline = ""
	if not _start_dialogue(interactor, timeline):
		_handle_unavailable_dialogue(interactor)


func _restore_opening_player_control() -> void:
	if is_instance_valid(_active_interactor):
		_active_interactor.blocked = _opening_player_was_blocked


func _on_dialogue_finished(interactor: Player) -> void:
	var intent := _dialogue_intent
	_dialogue_intent = DialogueIntent.NONE
	match intent:
		DialogueIntent.OPEN_FIRST_SHOP:
			interaction_area.set_interaction_enabled(false)
			var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
			if progress != null:
				progress.mark_met_silas()
			_open_shop.call_deferred(interactor)
		DialogueIntent.OPEN_RETURNING_SHOP:
			interaction_area.set_interaction_enabled(false)
			_open_shop.call_deferred(interactor)
		DialogueIntent.CLOSE:
			_begin_close()


func _handle_unavailable_dialogue(interactor: Player) -> void:
	var intent := _dialogue_intent
	_dialogue_intent = DialogueIntent.NONE
	if intent == DialogueIntent.OPEN_FIRST_SHOP:
		var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
		if progress != null:
			progress.mark_met_silas()
		_open_shop(interactor)
	elif intent == DialogueIntent.OPEN_RETURNING_SHOP:
		_open_shop(interactor)
	else:
		_begin_close()


func _open_shop(interactor: Player) -> void:
	if _shop_panel == null or _shop_panel.visible:
		return
	_active_interactor = interactor
	interaction_area.set_interaction_enabled(false)
	var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
	var stock := (
		progress.get_shop_stock(catalog) if progress != null else catalog.roll_buy_stock(_stock_random)
	)
	if not _shop_panel.open_for(interactor, stock):
		_begin_close()


func reroll_shop_stock() -> void:
	var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
	if progress == null:
		return
	var stock := progress.reroll_shop_stock(catalog)
	if _shop_panel != null and _shop_panel.visible and stock != null:
		_shop_panel.update_stock(stock)


func _on_shop_closed() -> void:
	if not is_instance_valid(_active_interactor) or _active_interactor.dead:
		_begin_close()
		return
	interaction_area.set_interaction_enabled(false)
	_dialogue_intent = DialogueIntent.CLOSE
	_hold_player_idle(_active_interactor)
	if not _start_dialogue(_active_interactor, data.farewell_timeline):
		_handle_unavailable_dialogue(_active_interactor)


func _begin_close() -> void:
	_presentation_state = PresentationState.CLOSING
	interaction_area.set_interaction_enabled(false)
	sprite.play(&"close")


func _finish_closing() -> void:
	_presentation_state = PresentationState.CLOSED
	sprite.play(&"idle_close")
	_active_interactor = null
	interaction_area.set_interaction_enabled(true)


func _hold_player_idle(interactor: Player) -> void:
	interactor.clear_gameplay_input()
	interactor.set_horizontal_velocity(Vector3.ZERO)
	if is_instance_valid(interactor.visual):
		interactor.visual.reset_animation_speed()
	interactor.play_directional_animation("idle")


func _exit_tree() -> void:
	if _presentation_state == PresentationState.OPENING:
		_restore_opening_player_control()
	super()
