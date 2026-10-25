class_name EquipmentControl
extends Control
## Hiển thị ô Charm và cooldown thật từ runtime; không quản lý trang bị hay tài nguyên

var _manager: CharmSocketManager
var _slots: Dictionary[int, TextureRect] = {}
var _icons: Dictionary[int, TextureRect] = {}
var _cooldowns: Dictionary[int, TextureProgressBar] = {}
var _cooldown_labels: Dictionary[int, Label] = {}

@onready var q_socket: TextureRect = $Q_socket
@onready var e_socket: TextureRect = $E_socket
@onready var space_socket: TextureRect = $SPACE_socket
@onready var potion_socket: TextureRect = $Potion_socket
@onready var q_icon: TextureRect = $Q_socket/Q_icon
@onready var e_icon: TextureRect = $E_socket/E_icon
@onready var space_icon: TextureRect = $SPACE_socket/SPACE_icon


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
