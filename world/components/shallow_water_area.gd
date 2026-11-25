class_name ShallowWaterArea
extends Area3D
## Shallow channels Foxy can wade through. Slows him while he stands in any of the area's shapes.
##
## Uses Player.environment_move_speed_multiplier, the same hook FlatTide uses for flooded ground,
## so a room should not combine this area with a FlatTide controller.

@export_range(0.1, 1.0, 0.05) var move_speed_multiplier: float = 0.75

var _players: Array[Player] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatLayers.PLAYER_BODY
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	for player: Player in _players:
		if is_instance_valid(player):
			player.environment_move_speed_multiplier = 1.0
	_players.clear()


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or _players.has(player):
		return
	_players.append(player)
	player.environment_move_speed_multiplier = move_speed_multiplier


func _on_body_exited(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	_players.erase(player)
	if is_instance_valid(player):
		player.environment_move_speed_multiplier = 1.0
