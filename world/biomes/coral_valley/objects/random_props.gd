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


func _ready() -> void:
	var positions := Array(spawn_positions)
	positions.shuffle()
	for index in mini(randi_range(3, 6), positions.size()):
		var prop := PROP_SCENES.pick_random().instantiate() as Node3D
		prop.position = positions[index]
		add_child(prop, true)
