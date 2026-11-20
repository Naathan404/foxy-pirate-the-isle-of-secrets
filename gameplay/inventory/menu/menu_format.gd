class_name InventoryMenuFormat
extends RefCounted
## Text helpers shared by the inventory menu pages.

const MAX_DECIMALS_FORMAT := "%.2f"
const UNBOUND_TEXT := "?"
const MOUSE_BUTTON_NAMES := {
	MOUSE_BUTTON_LEFT: "LMB",
	MOUSE_BUTTON_RIGHT: "RMB",
	MOUSE_BUTTON_MIDDLE: "MMB",
}


## Up to two decimals without trailing zeros: 1.50 -> "1.5", 2.00 -> "2".
static func number(value: float) -> String:
	return (MAX_DECIMALS_FORMAT % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")


static func signed(value: float) -> String:
	return ("+" if value >= 0.0 else "") + number(value)


## Short label of the first key or mouse button bound to an Input Map action.
static func action_key(action: StringName) -> String:
	if not InputMap.has_action(action):
		return UNBOUND_TEXT
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if code != KEY_NONE:
				return OS.get_keycode_string(code)
		elif event is InputEventMouseButton:
			var button := (event as InputEventMouseButton).button_index
			return MOUSE_BUTTON_NAMES.get(button, "Mouse %d" % button)
	return UNBOUND_TEXT


## "wooden_arrow" -> "Wooden Arrow" for IDs that have no display resource at hand.
static func humanize_id(id: String) -> String:
	return id.replace("_", " ").capitalize()
