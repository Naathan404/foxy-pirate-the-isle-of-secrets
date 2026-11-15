extends Control
## Bestiary pages in the inventory book. Entries and their defaults are edited in Inspector.

const TITLE_FONT: Font = preload("res://assets/fonts/BlackCrest-gwPyY.otf")
const BODY_FONT: Font = preload("res://assets/fonts/unifont-17.0.03.otf")
const INK := Color(0.24, 0.12, 0.10)
const MUTED := Color(0.40, 0.25, 0.19)

@export var notes: Array[MonsterNote] = []

var _rows: VBoxContainer
var _detail: VBoxContainer
var _selected_id: StringName


func _ready() -> void:
	_build_layout()
	get_node("/root/NoteProgress").changed.connect(_on_note_progress_changed)
	refresh()


## Changes and saves a note state without modifying the authored resource.
func set_note_unlocked(note_id: StringName, unlocked: bool) -> bool:
	for note in notes:
		if note != null and note.note_id == note_id:
			return get_node("/root/NoteProgress").set_unlocked(note_id, unlocked)
	return false


func is_note_unlocked(note: MonsterNote) -> bool:
	return get_node("/root/NoteProgress").is_unlocked(note)


func _on_note_progress_changed(_note_id: StringName) -> void:
	refresh()


func refresh() -> void:
	if not is_instance_valid(_rows):
		return
	_clear(_rows)
	var selected: MonsterNote
	for note in notes:
		if note == null or note.note_id.is_empty():
			continue
		var unlocked := is_note_unlocked(note)
		var row := Button.new()
		row.text = ("  " + note.display_name) if unlocked else "  ???   ·   LOCKED"
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 44)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.disabled = not unlocked
		row.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
		row.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
		)
		row.add_theme_font_override("font", BODY_FONT)
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override("font_color", INK)
		row.add_theme_color_override("font_hover_color", INK)
		row.add_theme_color_override("font_pressed_color", INK)
		row.add_theme_color_override("font_disabled_color", Color(0.77, 0.69, 0.61, 0.8))
		row.add_theme_stylebox_override("normal", _row_style(Color(0.55, 0.32, 0.22, 0.16)))
		row.add_theme_stylebox_override("hover", _row_style(Color(0.66, 0.37, 0.20, 0.30)))
		row.add_theme_stylebox_override("pressed", _row_style(Color(0.62, 0.32, 0.17, 0.40)))
		row.add_theme_stylebox_override("disabled", _row_style(Color(0.12, 0.09, 0.09, 0.76)))
		if unlocked:
			row.pressed.connect(_select.bind(note))
		if unlocked and note.note_id == _selected_id:
			selected = note
			row.add_theme_stylebox_override("normal", _row_style(Color(0.62, 0.32, 0.17, 0.35)))
		_rows.add_child(row)
	if selected == null:
		_selected_id = &""
	_render_detail(selected)


func _select(note: MonsterNote) -> void:
	if not is_note_unlocked(note):
		return
	_selected_id = note.note_id
	refresh()


func _build_layout() -> void:
	# Match the printable areas of the existing 1100 x 650 inventory book.
	var left := Control.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left.anchor_right = 0.5
	left.offset_left = 108
	left.offset_right = -52
	left.offset_top = 55
	left.offset_bottom = -100
	add_child(left)
	var right := Control.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right.anchor_left = 0.5
	right.offset_left = 50
	right.offset_right = -96
	right.offset_top = 55
	right.offset_bottom = -100
	add_child(right)

	var left_column := _column(left)
	_add_label(left_column, "Field Notes", 38, TITLE_FONT, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(
		left_column, "CREATURES OF THE ISLE", 12, BODY_FONT, HORIZONTAL_ALIGNMENT_CENTER, MUTED
	)
	_add_divider(left_column)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(list_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_rows)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 7)
	detail_scroll.add_child(_detail)


func _render_detail(note: MonsterNote) -> void:
	_clear(_detail)
	if note == null:
		_add_label(_detail, "The Bestiary", 38, TITLE_FONT, HORIZONTAL_ALIGNMENT_CENTER)
		_add_divider(_detail)
		_add_spacer(_detail, 110)
		_add_label(
			_detail,
			"Select an unlocked note to read about the creatures of the isle.",
			17,
			BODY_FONT,
			HORIZONTAL_ALIGNMENT_CENTER,
			MUTED
		)
		return
	var boss := note.layout == MonsterNote.Layout.BOSS
	_add_label(
		_detail,
		"BOSS ENCOUNTER" if boss else "CREATURE RECORD",
		12,
		BODY_FONT,
		HORIZONTAL_ALIGNMENT_CENTER,
		MUTED
	)
	_add_label(
		_detail, note.display_name, 36 if boss else 32, TITLE_FONT, HORIZONTAL_ALIGNMENT_CENTER
	)
	_add_divider(_detail)
	if boss:
		_add_portrait(_detail, note.portrait, Vector2(0, 160))
		_add_stats(_detail, note, HORIZONTAL_ALIGNMENT_CENTER)
		_section("THE ENCOUNTER", note.description)
		_section("BATTLE NOTES", note.behavior)
		_section("PIRATE'S STRATEGY", note.strategy)
	else:
		var summary := HBoxContainer.new()
		summary.add_theme_constant_override("separation", 14)
		_detail.add_child(summary)
		_add_portrait(summary, note.portrait, Vector2(120, 115))
		var facts := VBoxContainer.new()
		facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		facts.add_theme_constant_override("separation", 7)
		summary.add_child(facts)
		_add_label(facts, "FIELD PROFILE", 13, BODY_FONT, HORIZONTAL_ALIGNMENT_LEFT, MUTED)
		_add_stats(facts, note, HORIZONTAL_ALIGNMENT_LEFT)
		_add_label(facts, note.description, 16, BODY_FONT)
		_add_divider(_detail)
		_section("BEHAVIOR", note.behavior)
		_section("FIELD TIP", note.strategy)


func _add_portrait(parent: Node, texture: Texture2D, minimum: Vector2) -> void:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = minimum
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = texture
	parent.add_child(portrait)


func _add_stats(parent: Node, note: MonsterNote, alignment: HorizontalAlignment) -> void:
	if note.enemy_data != null:
		_add_label(
			parent,
			(
				"HEALTH  %s    ATTACK  %s"
				% [str(note.enemy_data.max_hp), str(note.enemy_data.attack_damage)]
			),
			13,
			BODY_FONT,
			alignment,
			MUTED
		)


func _section(title: String, body: String) -> void:
	if body.strip_edges().is_empty():
		return
	_add_label(_detail, title, 13, BODY_FONT, HORIZONTAL_ALIGNMENT_LEFT, MUTED)
	_add_label(_detail, body, 16, BODY_FONT)


func _column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 7)
	parent.add_child(column)
	return column


func _add_label(
	parent: Node,
	text: String,
	font_size: int,
	font: Font,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	color: Color = INK
) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _add_divider(parent: Node) -> void:
	var divider := HSeparator.new()
	parent.add_child(divider)


func _add_spacer(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)


func _row_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	return style


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
