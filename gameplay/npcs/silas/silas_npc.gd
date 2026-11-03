class_name SilasNpc
extends BaseNpc

## A mobile merchant with a Hub-authored set of safe hideouts.

enum DialogueIntent { NONE, OPEN_FIRST_SHOP, OPEN_RETURNING_SHOP, DEPART }

@export_group("Silas Merchant")
@export var data: SilasNpcData
@export var catalog: MerchantCatalog
@export var shop_panel_path: NodePath

@export_group("Silas Hideouts")
@export var hideout_group: StringName = &"silas_hideouts"
@export_range(0.0, 100.0, 0.5, "suffix:m") var minimum_hideout_distance := 12.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var burrow_duration := 0.35
@export_range(0.1, 5.0, 0.05, "suffix:m") var burrow_depth := 1.0

var _shop_panel: SilasShopPanel
var _dialogue_intent := DialogueIntent.NONE
var _active_interactor: Player
var _wander_anchor := Vector3.ZERO
var _hidden_player: Player
var _hidden_destination := Vector3.ZERO
var _burrow_finished := false
var _burrow_tween: Tween
var _sprite_rest_position := Vector3.ZERO
var _is_hidden := false

@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var interaction_collision: CollisionShape3D = $InteractionArea/CollisionShape3D
@onready var sprite: Sprite3D = $Visual/Sprite3D


func _ready() -> void:
	if data == null or catalog == null or not catalog.validate().is_empty():
		push_error("SilasNpc: valid data and merchant catalog are required")
		set_physics_process(false)
		return
	super()
	_shop_panel = get_node_or_null(shop_panel_path) as SilasShopPanel
	if _shop_panel == null:
		push_error("SilasNpc: shop panel is missing")
		return
	_wander_anchor = global_position
	_sprite_rest_position = sprite.position
	_shop_panel.shop_closed.connect(_on_shop_closed)
	dialogue_finished.connect(_on_dialogue_finished)


func get_npc_data() -> NpcData:
	return data


func get_silas_data() -> SilasNpcData:
	return data


func get_wander_anchor() -> Vector3:
	return _wander_anchor


func should_apply_gravity() -> bool:
	return not _is_hidden


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
	if _shop_panel == null or _shop_panel.visible or is_talking or _is_hidden:
		return
	interaction_requested.emit(interactor)
	_active_interactor = interactor
	var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
	var first_meeting := progress == null or not progress.has_met_silas()
	_dialogue_intent = (
		DialogueIntent.OPEN_FIRST_SHOP if first_meeting else DialogueIntent.OPEN_RETURNING_SHOP
	)
	var timeline := data.dialogue_timeline if first_meeting else data.greeting_timeline
	if not _start_dialogue(interactor, timeline):
		_handle_unavailable_dialogue(interactor)


func _on_dialogue_finished(interactor: Player) -> void:
	var intent := _dialogue_intent
	_dialogue_intent = DialogueIntent.NONE
	match intent:
		DialogueIntent.OPEN_FIRST_SHOP:
			var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
			if progress != null:
				progress.mark_met_silas()
			_open_shop.call_deferred(interactor)
		DialogueIntent.OPEN_RETURNING_SHOP:
			_open_shop.call_deferred(interactor)
		DialogueIntent.DEPART:
			begin_departure(interactor)


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
		begin_departure(interactor)


func _open_shop(interactor: Player) -> void:
	if _shop_panel == null or _shop_panel.visible or _is_hidden:
		return
	_active_interactor = interactor
	interaction_area.set_interaction_enabled(false)
	if not _shop_panel.open_for(interactor, catalog):
		interaction_area.set_interaction_enabled(true)


func _on_shop_closed() -> void:
	if not is_instance_valid(_active_interactor) or _active_interactor.dead:
		interaction_area.set_interaction_enabled(true)
		return
	interaction_area.set_interaction_enabled(false)
	_dialogue_intent = DialogueIntent.DEPART
	if not _start_dialogue(_active_interactor, data.farewell_timeline):
		_handle_unavailable_dialogue(_active_interactor)


func begin_departure(interactor: Player) -> void:
	var destination := _choose_hideout(interactor)
	if destination == null:
		push_warning("SilasNpc: no safe hideout is far enough from the player")
		interaction_area.set_interaction_enabled(true)
		return
	_hidden_player = interactor
	_hidden_destination = destination.global_position
	_wander_anchor = _hidden_destination
	var hidden_state := fsm.states.get("hidden") as FsmState
	if hidden_state == null:
		push_error("SilasNpc: hidden state is missing")
		interaction_area.set_interaction_enabled(true)
		return
	fsm.change_state(hidden_state)


func enter_hidden_state() -> void:
	stop_movement()
	_is_hidden = true
	interaction_area.set_interaction_enabled(false)
	body_collision.set_deferred("disabled", true)
	interaction_collision.set_deferred("disabled", true)
	_burrow_finished = false
	_kill_burrow_tween()
	_sprite_rest_position = sprite.position
	_burrow_tween = create_tween().set_parallel()
	_burrow_tween.tween_property(
		sprite, "position:y", _sprite_rest_position.y - burrow_depth, burrow_duration
	)
	_burrow_tween.tween_property(sprite, "modulate:a", 0.0, burrow_duration)
	_burrow_tween.chain().tween_callback(_finish_burrow)


func update_hidden_state() -> void:
	if not _burrow_finished:
		return
	if not is_instance_valid(_hidden_player) or _hidden_player.dead:
		_emerge_from_hidden()
		return
	if _hidden_player.global_position.distance_to(global_position) >= minimum_hideout_distance:
		_emerge_from_hidden()


func _finish_burrow() -> void:
	global_position = _hidden_destination
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	sprite.hide()
	sprite.position = _sprite_rest_position
	sprite.modulate.a = 1.0
	_burrow_finished = true


func _emerge_from_hidden() -> void:
	if not _burrow_finished:
		return
	_burrow_finished = false
	sprite.position = _sprite_rest_position - Vector3.UP * burrow_depth
	sprite.modulate.a = 0.0
	sprite.show()
	_kill_burrow_tween()
	_burrow_tween = create_tween().set_parallel()
	_burrow_tween.tween_property(sprite, "position:y", _sprite_rest_position.y, burrow_duration)
	_burrow_tween.tween_property(sprite, "modulate:a", 1.0, burrow_duration)
	_burrow_tween.chain().tween_callback(_finish_emerge)


func _finish_emerge() -> void:
	body_collision.set_deferred("disabled", false)
	interaction_collision.set_deferred("disabled", false)
	interaction_area.set_interaction_enabled(true)
	_hidden_player = null
	_is_hidden = false
	var wander_state := fsm.states.get("wander") as FsmState
	if wander_state != null:
		fsm.change_state(wander_state)


func _choose_hideout(interactor: Player) -> Marker3D:
	var candidates: Array[Marker3D] = []
	var scene := get_tree().current_scene
	for node: Node in get_tree().get_nodes_in_group(hideout_group):
		var marker := node as Marker3D
		if marker == null or marker.get_tree().current_scene != scene:
			continue
		if (
			marker.global_position.distance_to(interactor.global_position)
			>= minimum_hideout_distance
		):
			candidates.append(marker)
	if candidates.is_empty():
		return null
	return candidates.pick_random()


func _kill_burrow_tween() -> void:
	if _burrow_tween != null and _burrow_tween.is_valid():
		_burrow_tween.kill()
	_burrow_tween = null


func _exit_tree() -> void:
	_kill_burrow_tween()
	super()
