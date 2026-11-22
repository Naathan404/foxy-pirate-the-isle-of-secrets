class_name InventoryCharmSocketButton
extends Button
## One of the Q / SPACE / E charm sockets. The target socket gets a marker and the word "Target";
## locked sockets show a lock glyph and the word "Locked".

@export_range(0.0, 1.0, 0.01) var locked_alpha: float = 0.4
@export_range(1.0, 1.2, 0.01) var target_scale: float = 1.06
@export_range(0.05, 0.3, 0.01, "suffix:s") var feedback_seconds: float = 0.12
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.05

var _tween: Tween

@onready var _visual: Control = %Visual
@onready var _frame: TextureRect = %Frame
@onready var _icon: TextureRect = %SocketIcon
@onready var _lock: TextureRect = %SocketLock
@onready var _marker: TextureRect = %TargetMarker
@onready var _key_label: Label = %KeyLabel


func _ready() -> void:
	InventoryHoverFeedback.attach(self, null, hover_scale)
	resized.connect(_update_pivot)
	_update_pivot()


func present(
	key: String, charm_icon: Texture2D, unlocked: bool, is_target: bool, animate: bool = true
) -> void:
	_icon.texture = charm_icon if unlocked else null
	_lock.visible = not unlocked
	_frame.modulate.a = 1.0 if unlocked else locked_alpha
	_marker.visible = is_target
	var state := "Target" if is_target else ("Locked" if not unlocked else "")
	_key_label.text = key if state.is_empty() else "%s  ·  %s" % [key, state]
	var target := Vector2.ONE * (target_scale if is_target else 1.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or not is_visible_in_tree():
		_visual.scale = target
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "scale", target, feedback_seconds)


## Celebrates a successful equip/unequip on this socket.
func play_change_feedback() -> void:
	InventoryMenuFx.pop(_icon, InventoryMenuFx.BADGE_POP_FROM_SCALE)
	InventoryMenuFx.burst(self)


func _update_pivot() -> void:
	_visual.pivot_offset = size * InventoryMenuFx.CENTER_RATIO
