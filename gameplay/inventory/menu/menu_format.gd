class_name InventoryMenuFormat
extends RefCounted
## Text helpers shared by the inventory menu pages.

const MAX_DECIMALS_FORMAT := "%.2f"
const UNBOUND_TEXT := "?"
const THOUSANDS_GROUP := 3
const THOUSANDS_SEPARATOR := ","
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


## Whole amounts such as gold with thousands separators: 1234567 -> "1,234,567".
static func grouped(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > THOUSANDS_GROUP:
		result = THOUSANDS_SEPARATOR + digits.right(THOUSANDS_GROUP) + result
		digits = digits.left(digits.length() - THOUSANDS_GROUP)
	return ("-" if value < 0 else "") + digits + result


## Shrinks `label`'s font, never below `minimum_size`, until its text fits `max_width` pixels.
## Used for values that are usually short but may grow, such as a large gold balance.
static func fit_font_size(
	label: Label, max_width: float, preferred_size: int, minimum_size: int
) -> void:
	var font := label.get_theme_font("font")
	var size := preferred_size
	while (
		size > minimum_size
		and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width
	):
		size -= 1
	label.add_theme_font_size_override("font_size", size)


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
