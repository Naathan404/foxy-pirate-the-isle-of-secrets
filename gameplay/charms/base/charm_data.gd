class_name CharmData
extends Resource
## Cấu hình bất biến của một Charm.

@export var charm_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Ảnh hiển thị trong ô Charm; có thể để trống khi chưa có asset
@export var sprite: Texture2D
@export_enum("Active:0", "Passive:1") var charm_type: int = CharmConstants.CharmType.PASSIVE
@export var effect_scene: PackedScene
@export var resource_cost: float = 0.0
@export var cooldown_seconds: float = 0.0
@export_range(0.0, 1.0, 0.01) var proc_chance: float = 1.0
@export var acquisition_source: StringName = &"shop"
@export_enum("Playable:0", "Prototype:1", "Disabled:2")
var content_status: int = CharmConstants.ContentStatus.PLAYABLE
## -1 means that the drop chance is intentionally unset (prototype/pending balance).
@export_range(-1.0, 1.0, 0.01) var drop_chance: float = 0.0
@export var tags: Array[StringName] = []
@export var effect_params: Dictionary = {}


func is_active() -> bool:
	return charm_type == CharmConstants.CharmType.ACTIVE


func is_passive() -> bool:
	return charm_type == CharmConstants.CharmType.PASSIVE


func is_playable() -> bool:
	return content_status == CharmConstants.ContentStatus.PLAYABLE


func is_prototype() -> bool:
	return content_status == CharmConstants.ContentStatus.PROTOTYPE


func get_param_float(param_id: StringName, fallback: float = 0.0) -> float:
	var value: Variant = effect_params.get(param_id, fallback)
	return float(value) if value is float or value is int else fallback


func get_param_int(param_id: StringName, fallback: int = 0) -> int:
	var value: Variant = effect_params.get(param_id, fallback)
	return int(value) if value is float or value is int else fallback


func get_param_string(param_id: StringName, fallback: String = "") -> String:
	var value: Variant = effect_params.get(param_id, fallback)
	return String(value) if value is String or value is StringName else fallback


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if charm_id.is_empty():
		errors.append("charm_id must not be empty")
	if display_name.strip_edges().is_empty():
		errors.append("display_name must not be empty")
	if resource_cost < 0.0:
		errors.append("resource_cost must be non-negative")
	if cooldown_seconds < 0.0:
		errors.append("cooldown_seconds must be non-negative")
	if proc_chance < CharmConstants.MIN_PROC_CHANCE:
		errors.append("proc_chance must be at least 0.0")
	if proc_chance > CharmConstants.MAX_PROC_CHANCE:
		errors.append("proc_chance must be at most 1.0")
	if (
		drop_chance < CharmConstants.UNSET_DROP_CHANCE
		or drop_chance > CharmConstants.MAX_PROC_CHANCE
	):
		errors.append("drop_chance must be -1.0 (unset) or between 0.0 and 1.0")
	if is_playable() and is_equal_approx(drop_chance, CharmConstants.UNSET_DROP_CHANCE):
		errors.append("playable charms must define drop_chance")
	if is_prototype() and not is_equal_approx(drop_chance, CharmConstants.UNSET_DROP_CHANCE):
		errors.append("prototype charms must leave drop_chance unset")
	if is_active() and effect_scene == null:
		errors.append("active charms must define an effect_scene")
	if is_passive() and (resource_cost > 0.0 or cooldown_seconds > 0.0):
		errors.append("passive charms must not define activation cost or cooldown")
	return errors
