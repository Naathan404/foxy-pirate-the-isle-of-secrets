extends DestructibleProp

@onready var _hull_shape: CollisionShape3D = $HurtBox/CollisionShape3D


func _ready() -> void:
	super._ready()
	visibility_changed.connect(_sync_hull_collision)
	destroyed.connect(_sync_hull_collision)
	_sync_hull_collision()


func _sync_hull_collision() -> void:
	_hull_shape.set_deferred("disabled", not is_visible_in_tree() or _destroyed)
