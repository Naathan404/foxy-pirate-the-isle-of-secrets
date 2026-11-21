class_name InventoryCatalogSlot
extends Button
## Grid cell shared by the Weapon, Charms and Journey pages.
##
## Selection uses the picked frame, equipped/boss state a corner badge and locked state a lock
## glyph, so no state is communicated by color alone.

const FILLED_FRAME: Texture2D = preload("res://assets/ui/HUD_Fox/Weapons/Unpick_Slot.png")
const SILHOUETTE_MATERIAL: ShaderMaterial = preload(
	"res://gameplay/inventory/menu/silhouette_material.tres"
)
const EMPTY_FRAME: Texture2D = preload("res://assets/ui/HUD_Fox/Weapons/NotUnlock_Slot.png")

@export_range(0.0, 1.0, 0.01) var hover_selection_alpha: float = 0.45
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.07
## Pixel-art portraits (bestiary sprites) use nearest filtering; painted icons stay smooth.
@export var icon_texture_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_PARENT_NODE

var _selected: bool = false
var _hovered: bool = false

@onready var _visual: Control = %Visual
@onready var _frame: TextureRect = %Frame
@onready var _icon: TextureRect = %Icon
@onready var _lock: TextureRect = %Lock
@onready var _badge: TextureRect = %Badge
@onready var _selection: TextureRect = %Selection


func _ready() -> void:
	_icon.texture_filter = icon_texture_filter
	InventoryHoverFeedback.attach(self, _visual, hover_scale)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	visibility_changed.connect(_on_visibility_changed)
	_apply()


## Shows one entry. `filled` picks the framed cell; empty cells keep the star placeholder.
func present(
	entry_icon: Texture2D, filled: bool, locked: bool = false, badge: Texture2D = null
) -> void:
	disabled = false
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.texture = FILLED_FRAME if filled else EMPTY_FRAME
	_icon.texture = entry_icon
	# Locked entries show only their shape, never the artwork.
	_icon.material = SILHOUETTE_MATERIAL if locked else null
	_lock.visible = locked
	_badge.texture = badge
	_badge.visible = badge != null


## A non-interactive cell used to pad grids up to whole rows.
func present_placeholder() -> void:
	present(null, false)
	disabled = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = ""
	set_selected(false)


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	_apply()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered and not disabled
	_apply()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_hovered = false
		_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_selection.visible = _selected or _hovered
	_selection.modulate.a = 1.0 if _selected else hover_selection_alpha
