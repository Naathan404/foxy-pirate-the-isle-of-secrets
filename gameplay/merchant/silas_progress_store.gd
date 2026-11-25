class_name SilasProgressStore
extends Node

## Merchant progress. Its own file keeps the latest state between launches; the game save
## slot is the authority on New Game (reset) and Continue (restore), so a loaded game never
## keeps a purchase made after that save.
const DEFAULT_SAVE_PATH := "user://silas_progress.save"
const SAVE_VERSION := 1

@export var save_path := DEFAULT_SAVE_PATH
@export_group("Restock")
## Play time (menus and loading excluded) after which the stock changes; each wait is drawn
## at random between the two values and never shown to the player.
@export_range(30.0, 3600.0, 5.0, "suffix:s") var restock_min_seconds := 360.0
@export_range(30.0, 3600.0, 5.0, "suffix:s") var restock_max_seconds := 720.0

var _met_silas := false
var _bow_purchased := false
var _shop_stock: MerchantCatalog
var _stock_source: MerchantCatalog
var _stock_random := RandomNumberGenerator.new()
var _stock_random_ready := false
## Set by a restock trigger; the stock is only redrawn on the next visit, when it can be seen.
var _stock_stale := false
var _restock_schedule := SilasRestockSchedule.new(restock_min_seconds, restock_max_seconds)


func _ready() -> void:
	# Apply the Inspector values; nothing has been recorded yet.
	_restock_schedule = SilasRestockSchedule.new(restock_min_seconds, restock_max_seconds)
	load_progress()


func _process(delta: float) -> void:
	# The tree is paused during menus and scene transitions, so only real play time counts.
	if _restock_schedule.advance(delta, _get_stock_random()):
		_stock_stale = true


func has_met_silas() -> bool:
	return _met_silas


func has_bow_purchase() -> bool:
	return _bow_purchased


## Returns the session stock, drawing a new one first if none exists yet or a restock trigger
## fired. `excluded_offer_ids` only matters when a new stock is drawn.
func get_shop_stock(
	source: MerchantCatalog, excluded_offer_ids: Array[StringName] = []
) -> MerchantCatalog:
	if _shop_stock == null or _stock_source != source or _stock_stale:
		return reroll_shop_stock(source, excluded_offer_ids)
	return _shop_stock


func reroll_shop_stock(
	source: MerchantCatalog, excluded_offer_ids: Array[StringName] = []
) -> MerchantCatalog:
	if source == null or not source.validate().is_empty():
		return null
	var previous := _shop_stock if _stock_source == source else null
	_shop_stock = source.roll_buy_stock(_get_stock_random(), previous, excluded_offer_ids)
	_stock_source = source
	_stock_stale = false
	return _shop_stock


## Silas restocks the first time Foxy reaches each area of the run.
func note_area_entered(area_id: StringName) -> void:
	if _restock_schedule.note_area_entered(area_id):
		_stock_stale = true


func mark_met_silas() -> bool:
	if _met_silas:
		return true
	_met_silas = true
	return save_progress()


func mark_bow_purchased() -> bool:
	if _bow_purchased:
		return true
	_bow_purchased = true
	return save_progress()


func get_save_data() -> Dictionary:
	return {"met_silas": _met_silas, "bow_purchased": _bow_purchased}


## Expects data already checked by GameSaveSnapshot. Stock is rerolled on the next visit.
func apply_save_data(saved: Dictionary) -> bool:
	_met_silas = bool(saved.get("met_silas", false))
	_bow_purchased = bool(saved.get("bow_purchased", false))
	_clear_shop_stock()
	return save_progress()


func reset_progress() -> bool:
	return apply_save_data({})


func load_progress() -> bool:
	_met_silas = false
	_bow_purchased = false
	if not FileAccess.file_exists(save_path):
		return true
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("SilasProgressStore: unable to read progress save")
		return false
	var values: Dictionary = file.get_var(false)
	if values.is_empty():
		push_warning("SilasProgressStore: invalid progress save")
		return false
	_met_silas = bool(values.get(&"met_silas", false))
	_bow_purchased = bool(values.get(&"bow_purchased", false))
	return true


func save_progress() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SilasProgressStore: unable to write progress save")
		return false
	file.store_var(
		{
			&"version": SAVE_VERSION,
			&"met_silas": _met_silas,
			&"bow_purchased": _bow_purchased,
		},
		false
	)
	return true


func _clear_shop_stock() -> void:
	_shop_stock = null
	_stock_source = null
	_stock_stale = false
	_restock_schedule.reset()


func _get_stock_random() -> RandomNumberGenerator:
	if not _stock_random_ready:
		_stock_random.randomize()
		_stock_random_ready = true
	return _stock_random
