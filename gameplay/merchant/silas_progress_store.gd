class_name SilasProgressStore
extends Node

## Narrow persistence for the merchant while the project has no game-wide save system.
const DEFAULT_SAVE_PATH := "user://silas_progress.save"
const SAVE_VERSION := 1

@export var save_path := DEFAULT_SAVE_PATH

var _met_silas := false
var _bow_purchased := false
var _shop_stock: MerchantCatalog
var _stock_source: MerchantCatalog
var _stock_random := RandomNumberGenerator.new()
var _stock_random_ready := false


func _ready() -> void:
	load_progress()


func has_met_silas() -> bool:
	return _met_silas


func has_bow_purchase() -> bool:
	return _bow_purchased


func get_shop_stock(source: MerchantCatalog) -> MerchantCatalog:
	if _shop_stock == null or _stock_source != source:
		return reroll_shop_stock(source)
	return _shop_stock


func reroll_shop_stock(source: MerchantCatalog) -> MerchantCatalog:
	if source == null or not source.validate().is_empty():
		return null
	if not _stock_random_ready:
		_stock_random.randomize()
		_stock_random_ready = true
	var previous := _shop_stock if _stock_source == source else null
	_shop_stock = source.roll_buy_stock(_stock_random, previous)
	_stock_source = source
	return _shop_stock


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
