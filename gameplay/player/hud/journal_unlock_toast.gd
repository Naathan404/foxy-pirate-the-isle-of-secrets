class_name JournalUnlockToast
extends Control
## Small "new knowledge unlocked" card for Journey entries, in a screen corner. Several
## discoveries made together take turns. It only presents; NoteProgress owns what is unlocked.

const CREATURE_ICON: Texture2D = preload("res://assets/ui/HUD_Fox/Journey/Creature_Icon.png")
const ELITE_ICON: Texture2D = preload("res://assets/ui/HUD_Fox/Journey/Elite_Icon.png")
const BOSS_ICON: Texture2D = preload("res://assets/ui/HUD_Fox/Journey/Boss_Icon.png")
const NOTE_ICON: Texture2D = preload("res://assets/sprites/items/Monster_Notes.png")
const DIARY_ICON: Texture2D = preload("res://assets/sprites/items/Boss_Diary.png")
const CHIME: AudioStream = preload("res://assets/audio/ui/blueprint_reveal.wav")
## Portraits at most this wide are pixel art.
const PIXEL_ART_MAX_PIXELS := 300
const CREATURE_CAPTION := "Creature added to your Journal"
const ELITE_CAPTION := "Elite creature added to your Journal"
const BOSS_CAPTION := "Boss lore added to your Journal"
const TITLE_FORMAT := "%s unlocked"

@export_group("Timing")
@export_range(0.05, 1.0, 0.01, "suffix:s") var enter_seconds: float = 0.35
@export_range(0.5, 8.0, 0.1, "suffix:s") var hold_seconds: float = 3.2
## Shorter hold while more discoveries wait their turn.
@export_range(0.5, 8.0, 0.1, "suffix:s") var queued_hold_seconds: float = 1.9
@export_range(0.05, 1.0, 0.01, "suffix:s") var exit_seconds: float = 0.35

@export_group("Motion")
@export_range(0.0, 400.0, 1.0, "suffix:px") var slide_pixels: float = 90.0
@export_range(1.0, 2.0, 0.01) var portrait_pop_scale: float = 1.25
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var chime_volume_db: float = -9.0

var _queue: Array[MonsterNote] = []
var _tween: Tween
var _rest_x: float = 0.0

@onready var _banner: Control = $Banner
@onready var _portrait: TextureRect = %Portrait
@onready var _elite_badge: Control = %EliteBadge
@onready var _title: Label = %Title
@onready var _caption: Label = %Caption
@onready var _kind_icon: TextureRect = %KindIcon
@onready var _sparkles: Control = %Sparkles


func _ready() -> void:
	_rest_x = _banner.position.x
	_banner.hide()
	var progress := get_node_or_null("/root/NoteProgress")
	if progress != null:
		progress.discovered.connect(enqueue)


func enqueue(note: MonsterNote) -> void:
	if note == null:
		return
	_queue.append(note)
	# Deferred, so discoveries made in the same frame know they have to share the time.
	if _queue.size() == 1 and (_tween == null or not _tween.is_valid()):
		_show_next.call_deferred()


func _show_next() -> void:
	if _queue.is_empty():
		_banner.hide()
		_tween = null
		return
	_present(_queue.pop_front())
	_animate()
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(CHIME, chime_volume_db)


func _present(note: MonsterNote) -> void:
	var boss := note.layout == MonsterNote.Layout.BOSS
	var art := note.portrait
	if art == null and note.pickup_item != null:
		art = note.pickup_item.icon
	if art == null:
		art = DIARY_ICON if boss else NOTE_ICON
	_portrait.texture = art
	_portrait.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if art.get_width() > PIXEL_ART_MAX_PIXELS
		else CanvasItem.TEXTURE_FILTER_NEAREST
	)
	_title.text = TITLE_FORMAT % note.display_name
	_elite_badge.visible = note.is_elite and not boss
	if boss:
		_caption.text = BOSS_CAPTION
		_kind_icon.texture = BOSS_ICON
	elif note.is_elite:
		_caption.text = ELITE_CAPTION
		_kind_icon.texture = ELITE_ICON
	else:
		_caption.text = CREATURE_CAPTION
		_kind_icon.texture = CREATURE_ICON


## Runs on real time, so a hitstop on the killing blow does not stall the banner.
func _animate() -> void:
	_banner.show()
	_banner.modulate.a = 0.0
	_banner.position.x = _rest_x + slide_pixels
	_portrait.pivot_offset = _portrait.size * 0.5
	_portrait.scale = Vector2.ONE * portrait_pop_scale
	_sparkles.modulate.a = 0.0
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(_banner, "modulate:a", 1.0, enter_seconds)
	(
		_tween
		. parallel()
		. tween_property(_banner, "position:x", _rest_x, enter_seconds)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. parallel()
		. tween_property(_portrait, "scale", Vector2.ONE, enter_seconds * 1.4)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.parallel().tween_property(_sparkles, "modulate:a", 1.0, enter_seconds)
	_tween.tween_interval(hold_seconds if _queue.is_empty() else queued_hold_seconds)
	_tween.tween_property(_banner, "modulate:a", 0.0, exit_seconds)
	(
		_tween
		. parallel()
		. tween_property(_banner, "position:x", _rest_x + slide_pixels, exit_seconds)
		. set_ease(Tween.EASE_IN)
	)
	_tween.tween_callback(_show_next)
