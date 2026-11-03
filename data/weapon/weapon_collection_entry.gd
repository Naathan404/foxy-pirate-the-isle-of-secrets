class_name WeaponCollectionEntry
extends Resource
## Player progression, never stored on a shared WeaponData definition.

@export var definition: WeaponData
## Crafting permission only. Unlocking a blueprint does not grant an item.
@export var blueprint_unlocked: bool = false:
	set(value):
		if blueprint_unlocked == value:
			return
		blueprint_unlocked = value
		emit_changed()
## A separate flag: loot can be owned even without its crafting blueprint.
@export var owned: bool = false:
	set(value):
		if owned == value:
			return
		owned = value
		emit_changed()
## Forge for the instance granted when ownership is enabled.
@export var forge: WeaponForge
