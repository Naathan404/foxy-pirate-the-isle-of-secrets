class_name EquipmentControl
extends Control
## Hiển thị ô Charm và cooldown thật từ runtime; không quản lý trang bị hay tài nguyên

var _manager: CharmSocketManager
var _slots: Dictionary[int, TextureRect] = {}
var _icons: Dictionary[int, TextureRect] = {}
var _cooldowns: Dictionary[int, TextureProgressBar] = {}
var _cooldown_labels: Dictionary[int, Label] = {}
var _potion_tween: Tween
var _potion_rest_scale: Vector2

@onready var q_socket: TextureRect = $Q_socket
@onready var e_socket: TextureRect = $E_socket
@onready var space_socket: TextureRect = $SPACE_socket
@onready var potion_socket: TextureRect = $Potion_socket
@onready var q_icon: TextureRect = $Q_socket/Q_icon
@onready var e_icon: TextureRect = $E_socket/E_icon
@onready var space_icon: TextureRect = $SPACE_socket/SPACE_icon
@onready var potion_icon: TextureRect = $Potion_socket/Potion_icon
@onready var potion_quantity: Label = $Potion_socket/Potion_count


func _ready() -> void:
	_slots = {
		CharmConstants.SocketId.Q: q_socket,
		CharmConstants.SocketId.E: e_socket,
		CharmConstants.SocketId.SPACE: space_socket,
	}
	_icons = {
		CharmConstants.SocketId.Q: q_icon,
		CharmConstants.SocketId.E: e_icon,
		CharmConstants.SocketId.SPACE: space_icon,
	}
	for socket_id: int in _slots:
		# Giữ ảnh trong khung icon hiện tại, không để ảnh lớn làm giãn layout.
		_icons[socket_id].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icons[socket_id].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var slot := _slots[socket_id]
		_cooldowns[socket_id] = slot.get_node("Cooldown") as TextureProgressBar
		_cooldown_labels[socket_id] = slot.get_node("CooldownLabel") as Label

		_cooldowns[socket_id].texture_progress = slot.texture

	_potion_rest_scale = potion_icon.scale

	set_process(false)
	refresh()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		refresh()


# HUD gọi sau khi các node của Player đã ready để có loadout và registry hợp lệ
func bind_manager(manager: CharmSocketManager) -> void:
	_manager = manager
	set_process(is_instance_valid(_manager))
	refresh()


func refresh() -> void:
	var manager_valid := is_instance_valid(_manager)
	potion_socket.show()
	for socket_id: int in _slots:
		var unlocked := manager_valid and _manager.is_socket_unlocked(socket_id)
		_slots[socket_id].visible = unlocked
		var runtime: CharmRuntime
		if unlocked and is_instance_valid(_manager.registry):
			runtime = _manager.registry.get_equipped(socket_id)
		_update_icon(socket_id, runtime)
		_update_cooldown(socket_id, runtime)
	if not manager_valid:
		set_process(false)


func _update_icon(socket_id: int, runtime: CharmRuntime) -> void:
	var sprite: Texture2D
	if runtime != null and runtime.definition != null:
		sprite = runtime.definition.sprite
	var icon := _icons[socket_id]
	if icon.texture != sprite:
		icon.texture = sprite
	icon.visible = sprite != null


func _update_cooldown(socket_id: int, runtime: CharmRuntime) -> void:
	var remaining := 0.0
	var duration := 0.0
	if runtime != null and runtime.definition != null and runtime.definition.is_active():
		remaining = maxf(0.0, runtime.cooldown_remaining)
		duration = maxf(0.0, runtime.definition.cooldown_seconds)
	var cooling_down := remaining > 0.0 and duration > 0.0
	var overlay := _cooldowns[socket_id]
	var label := _cooldown_labels[socket_id]
	overlay.visible = cooling_down
	label.visible = cooling_down
	overlay.value = clampf(remaining / duration, 0.0, 1.0) if cooling_down else 0.0
	label.text = str(ceili(remaining)) if cooling_down else ""


func set_potion_icon(potion: Potion) -> void:
	potion_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	potion_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if potion == null:
		potion_icon.texture = null
		potion_icon.hide()
		return
	
	potion_icon.texture = potion.icon
	potion_icon.show()


func set_potion_quantity(amount: int) -> void:
	potion_quantity.text = str(amount)
	potion_quantity.visible = potion_icon.visible
	potion_icon.modulate = Color.WHITE if amount > 0 else Color.GRAY


func feedback_potion_used() -> void:
	if not is_instance_valid(potion_icon):
		return

	if _potion_tween != null and _potion_tween.is_valid():
		_potion_tween.kill()

	potion_icon.pivot_offset = potion_icon.size * 0.5
	potion_icon.scale = _potion_rest_scale

	_potion_tween = create_tween()
	_potion_tween.tween_property(
		potion_icon, "scale", _potion_rest_scale * 1.2, 0.08
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_potion_tween.tween_property(
		potion_icon, "scale", _potion_rest_scale, 0.16
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
