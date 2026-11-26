class_name SaveContentCatalog
extends RefCounted
## Resolves the stable IDs written in a save back to shared definition resources.
## Items and forges have no project-wide registry, so their data folders are scanned once.

const ITEM_DIRECTORY := "res://data/items"
const FORGE_DIRECTORY := "res://data/weapon/forges"
const RESOURCE_EXTENSION := "tres"
## Item IDs that were renamed, so older saves keep their items.
const RENAMED_ITEM_IDS: Dictionary[String, String] = {"starfish_core": "hermit_shell"}

static var _items: Dictionary[String, BaseItem] = {}
static var _forges: Dictionary[StringName, WeaponForge] = {}
static var _scanned: bool = false


static func find_item(item_id: String) -> BaseItem:
	_ensure_scanned()
	return _items.get(RENAMED_ITEM_IDS.get(item_id, item_id)) as BaseItem


static func find_forge(forge_id: StringName) -> WeaponForge:
	_ensure_scanned()
	return _forges.get(forge_id) as WeaponForge


static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for resource: Resource in _load_resources(ITEM_DIRECTORY):
		var item := resource as BaseItem
		if item == null or item.item_id.is_empty():
			continue
		if _items.has(item.item_id):
			push_warning("SaveContentCatalog: duplicate item ID '%s'" % item.item_id)
			continue
		_items[item.item_id] = item
	for resource: Resource in _load_resources(FORGE_DIRECTORY):
		var forge := resource as WeaponForge
		if forge == null or forge.forge_id.is_empty() or _forges.has(forge.forge_id):
			continue
		_forges[forge.forge_id] = forge


## ResourceLoader.list_directory also sees remapped resources in exported builds.
static func _load_resources(directory: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for entry: String in ResourceLoader.list_directory(directory):
		var entry_path := directory.path_join(entry)
		if entry.ends_with("/"):
			result.append_array(_load_resources(entry_path.trim_suffix("/")))
		elif entry.get_extension() == RESOURCE_EXTENSION:
			var resource := ResourceLoader.load(entry_path)
			if resource != null:
				result.append(resource)
	return result
