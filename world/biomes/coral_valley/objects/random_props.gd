extends Node3D

const PROP_SCENES: Array[PackedScene] = [
	preload("res://world/biomes/coral_valley/objects/shell.tscn"),
	preload("res://world/biomes/coral_valley/objects/stone.tscn"),
	preload("res://world/biomes/coral_valley/objects/octopus.tscn"),
]

const CORAL_SCENES: Array[PackedScene] = [
	preload("res://world/biomes/coral_valley/objects/beach_coral_orange.tscn"),
	preload("res://world/biomes/coral_valley/objects/beach_coral_pink.tscn"),
	preload("res://world/biomes/coral_valley/objects/beach_coral_turquoise.tscn"),
]

@export var spawn_positions: PackedVector3Array
@export var fixed_spawn_count := 0
@export var prop_scenes: Array[PackedScene] = PROP_SCENES.duplicate()
@export var include_coral: bool = false
@export_range(3, 64, 1) var max_spawn_count := 6


func _ready() -> void:
	var scenes := prop_scenes.filter(func(scene: PackedScene) -> bool: return scene != null)
	if include_coral:
		scenes.append_array(CORAL_SCENES)
	if scenes.is_empty():
		return
	var positions := Array(spawn_positions)
	positions.shuffle()
	var count := fixed_spawn_count if fixed_spawn_count > 0 else randi_range(3, max_spawn_count)
	for index in mini(count, positions.size()):
		var prop := scenes.pick_random().instantiate() as Node3D
		prop.position = positions[index]
		add_child(prop, true)
