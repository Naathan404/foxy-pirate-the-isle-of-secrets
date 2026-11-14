extends Node3D

const PROP_SCENES: Array[PackedScene] = [
	preload("res://world/biomes/coral_valley/objects/shell.tscn"),
	preload("res://world/biomes/coral_valley/objects/stone.tscn"),
	preload("res://world/biomes/coral_valley/objects/octopus.tscn"),
	preload("res://world/biomes/coral_valley/objects/beach_coral_orange.tscn"),
	preload("res://world/biomes/coral_valley/objects/beach_coral_pink.tscn"),
	preload("res://world/biomes/coral_valley/objects/beach_coral_turquoise.tscn"),
]

@export var spawn_positions: PackedVector3Array
@export var fixed_spawn_count := 0


func _ready() -> void:
	var positions := Array(spawn_positions)
	positions.shuffle()
	var count := fixed_spawn_count if fixed_spawn_count > 0 else randi_range(3, 6)
	for index in mini(count, positions.size()):
		var prop := PROP_SCENES.pick_random().instantiate() as Node3D
		prop.position = positions[index]
		add_child(prop, true)
