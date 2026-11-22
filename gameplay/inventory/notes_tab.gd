extends Control
## Journey page: a read-only bestiary of MonsterNote entries. Entries and their default unlock
## state are edited in the Inspector; runtime unlocks live in the NoteProgress autoload.

enum Filter { ALL, CREATURES, BOSSES }

const SLOT_SCENE: PackedScene = preload("res://gameplay/inventory/menu/catalog_slot.tscn")
const BOSS_BADGE: Texture2D = preload("res://assets/ui/HUD_Fox/Journey/Boss_Icon.png")
## Item art for notes/diaries without a portrait, matching the pickup that unlocks them.
const NOTE_ICON: Texture2D = preload("res://assets/sprites/items/Monster_Notes.png")
const DIARY_ICON: Texture2D = preload("res://assets/sprites/items/Boss_Diary.png")
const GRID_COLUMNS := 5
const MIN_VISIBLE_ROWS := 4
const LOCKED_NAME := "???"
const FILTER_NAMES := {
	Filter.ALL: "entries",
	Filter.CREATURES: "creature entries",
	Filter.BOSSES: "boss entries",
}

@export var notes: Array[MonsterNote] = []
@export_range(12, 40, 1) var section_heading_size: int = 25
@export_range(12, 30, 1) var section_body_size: int = 17

var _filter: Filter = Filter.ALL
var _entries: Array[MonsterNote] = []
var _selected_id: StringName = &""
var _slots: Array[InventoryCatalogSlot] = []
var _dirty: bool = true

@onready var _grid: GridContainer = %Grid
@onready var _counter_label: Label = %CounterLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _portrait: TextureRect = %Portrait
@onready var _entry_name: Label = %EntryName
@onready var _entry_kind: Label = %EntryKind
@onready var _details_scroll: ScrollContainer = %DetailsScroll
@onready var _sections: VBoxContainer = %Sections
@onready var _footer: Label = %Footer
@onready var _filter_chips: Dictionary[Filter, InventoryFilterChip] = {
	Filter.ALL: %FilterAll,
	Filter.CREATURES: %FilterCreatures,
	Filter.BOSSES: %FilterBosses,
}


func _ready() -> void:
	for filter: Filter in _filter_chips:
		_filter_chips[filter].pressed.connect(_set_filter.bind(filter))
	visibility_changed.connect(_on_visibility_changed)
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


func refresh() -> void:
	_dirty = false
	if not is_node_ready():
		return
	_rebuild_entries()
	var selected := _find_entry(_selected_id)
	if selected == null and not _entries.is_empty():
		selected = _first_unlocked_entry()
		_selected_id = selected.note_id if selected != null else _entries[0].note_id
	_refresh_grid()
	_render_detail(_find_entry(_selected_id))


## Entrance animation played by the menu when this page appears.
func play_intro() -> void:
	InventoryMenuFx.stagger_in(_slots)
	InventoryMenuFx.pop(_portrait, InventoryMenuFx.ICON_POP_FROM_SCALE)


func focus_default() -> void:
	var index := _index_of(_selected_id)
	var target: Control = _slots[index] if index >= 0 else _filter_chips[_filter]
	target.grab_focus.call_deferred()


func _on_note_progress_changed(_note_id: StringName) -> void:
	if is_visible_in_tree():
		refresh()
	else:
		_dirty = true


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and _dirty:
		refresh()


func _set_filter(filter: Filter) -> void:
	var changed := filter != _filter
	_filter = filter
	refresh()
	if changed:
		InventoryMenuFx.stagger_in(_slots)


## Keeps the authored catalog order; entries without an ID are skipped as before.
func _rebuild_entries() -> void:
	_entries.clear()
	var found: int = 0
	var total: int = 0
	for note in notes:
		if note == null or note.note_id.is_empty():
			continue
		total += 1
		found += 1 if is_note_unlocked(note) else 0
		if _matches(note):
			_entries.append(note)
	_counter_label.text = "%d/%d" % [found, total]
	for filter: Filter in _filter_chips:
		_filter_chips[filter].set_active(filter == _filter)


func _matches(note: MonsterNote) -> bool:
	match _filter:
		Filter.CREATURES:
			return note.layout == MonsterNote.Layout.MONSTER
		Filter.BOSSES:
			return note.layout == MonsterNote.Layout.BOSS
	return true


func _refresh_grid() -> void:
	var rows: int = maxi(MIN_VISIBLE_ROWS, ceili(float(_entries.size()) / GRID_COLUMNS))
	var cell_count: int = rows * GRID_COLUMNS
	while _slots.size() < cell_count:
		var slot := SLOT_SCENE.instantiate() as InventoryCatalogSlot
		slot.icon_texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_grid.add_child(slot)
		slot.pressed.connect(_select_index.bind(_slots.size()))
		_slots.append(slot)
	for index in range(_slots.size()):
		var slot := _slots[index]
		slot.visible = index < cell_count
		if index >= _entries.size():
			slot.present_placeholder()
			continue
		var note := _entries[index]
		var unlocked := is_note_unlocked(note)
		var boss := note.layout == MonsterNote.Layout.BOSS
		slot.present(
			_portrait_of(note) if unlocked else null,
			unlocked,
			not unlocked,
			BOSS_BADGE if boss else null
		)
		slot.set_selected(note.note_id == _selected_id)
		slot.tooltip_text = (
			note.display_name if unlocked else "Undiscovered %s" % ("boss" if boss else "creature")
		)
	_empty_label.visible = _entries.is_empty()
	_empty_label.text = "No %s in this journey yet." % FILTER_NAMES[_filter]


func _select_index(index: int) -> void:
	if index < _entries.size():
		var changed := _entries[index].note_id != _selected_id
		_selected_id = _entries[index].note_id
		refresh()
		if changed:
			InventoryMenuFx.pop(_portrait, InventoryMenuFx.ICON_POP_FROM_SCALE)


func _render_detail(note: MonsterNote) -> void:
	_clear_sections()
	_details_scroll.scroll_vertical = 0
	_portrait.texture = null
	if note == null:
		_entry_name.text = "Journey"
		_entry_kind.text = ""
		_add_body("Creatures and bosses you learn about are recorded here.")
		_footer.text = ""
		return

	var boss := note.layout == MonsterNote.Layout.BOSS
	if not is_note_unlocked(note):
		# Locked entries never reveal their name, portrait or text.
		_entry_name.text = LOCKED_NAME
		_entry_kind.text = "Undiscovered boss" if boss else "Undiscovered creature"
		_add_body("Find this entry's %s to fill in this page." % ("boss diary" if boss else "note"))
		_footer.text = ""
		return

	_portrait.texture = _portrait_of(note)
	_entry_name.text = note.display_name
	_entry_name.tooltip_text = note.display_name
	_entry_kind.text = "Boss encounter" if boss else "Creature record"
	if note.enemy_data != null:
		_add_stats_line(note.enemy_data)
	if boss:
		_add_section("The Encounter", note.description)
		_add_section("The Story", note.story)
		_add_section("Battle Notes", note.behavior)
		_add_section("Pirate's Strategy", note.strategy)
	else:
		_add_section("Description", note.description)
		_add_section("Behavior", note.behavior)
		_add_section("Field Tip", note.strategy)
	_footer.text = "Entry %d of %d" % [_index_of(note.note_id) + 1, _entries.size()]


func _add_stats_line(data: EnemyData) -> void:
	var label := _add_body(
		(
			"Health  %s     Attack  %s"
			% [
				InventoryMenuFormat.number(data.max_hp),
				InventoryMenuFormat.number(data.attack_damage)
			]
		)
	)
	label.theme_type_variation = &"MutedLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _add_section(title: String, body: String) -> void:
	if body.strip_edges().is_empty():
		return
	var heading := Label.new()
	heading.text = title
	heading.theme_type_variation = &"HeadingLabel"
	heading.add_theme_font_size_override("font_size", section_heading_size)
	_sections.add_child(heading)
	_add_body(body.strip_edges())


func _add_body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BodyLabel"
	label.add_theme_font_size_override("font_size", section_body_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sections.add_child(label)
	return label


func _clear_sections() -> void:
	_entry_name.tooltip_text = ""
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()


func _portrait_of(note: MonsterNote) -> Texture2D:
	if note.portrait != null:
		return note.portrait
	if note.pickup_item != null and note.pickup_item.icon != null:
		return note.pickup_item.icon
	return DIARY_ICON if note.layout == MonsterNote.Layout.BOSS else NOTE_ICON


func _first_unlocked_entry() -> MonsterNote:
	for note in _entries:
		if is_note_unlocked(note):
			return note
	return null


func _find_entry(note_id: StringName) -> MonsterNote:
	var index := _index_of(note_id)
	return _entries[index] if index >= 0 else null


func _index_of(note_id: StringName) -> int:
	for index in range(_entries.size()):
		if _entries[index].note_id == note_id:
			return index
	return -1
