class_name Potion
extends BaseItem

enum Kind { HEALTH, STAMINA, DUAL_ESSENCE }
enum Size { SMALL, LARGE }

@export var potion_kind: Kind = Kind.HEALTH
@export var potion_size: Size = Size.LARGE
