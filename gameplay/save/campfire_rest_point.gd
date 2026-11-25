class_name CampfireRestPoint
extends Node3D
## Rest interaction of a campfire. Interacting opens a menu with REST, REST and SAVE and
## QUIT. In a room whose `safe_room` flag is on, resting refills HP and SP, makes this the
## respawn point and resets the visited rooms (enemies and breakables return, layouts
## reshuffle); REST and SAVE also writes the save afterwards. Elsewhere the campfire
## explains that it cannot be used and changes nothing. Entering a room never saves.

## Emitted once the rest fade has finished, before the menu closes or shows a save result.
signal rested(player: Player)
signal save_finished(error: Error)

@export var choice_message: String = "Rest by the fire to restore HP and stamina."
@export var unsafe_message: String = "This fire is too exposed. You cannot rest or save here."
@export var saved_message: String = "Game saved."

var _resting_player: Player
var _saved_requested := false
var _save_error: Error = OK

@onready var _interaction: NpcInteractionArea = $InteractionArea
@onready var _spawn: Marker3D = $Spawn
@onready var _menu: RestMenu = $RestMenu


func _ready() -> void:
	_interaction.interaction_requested.connect(_on_interaction_requested)
	_menu.rest_requested.connect(choose_rest.bind(false))
	_menu.rest_and_save_requested.connect(choose_rest.bind(true))
	_menu.close_requested.connect(close_menu)


func _exit_tree() -> void:
	if _menu.is_open() or _menu.is_fading():
		_menu.close()
		# No-op while GameManager is mid-transition: it resumes the tree itself.
		get_node("/root/GameManager").exit_rest_menu()


## The nearest room that owns this campfire, or null outside a room.
func get_room() -> BaseRoom:
	return BaseRoom.find_room(self)


## Stable reference used by saves and respawns: room scene plus path from the room root.
func get_location() -> Dictionary:
	var room := get_room()
	if room == null:
		return {}
	return {"scene": room.scene_file_path, "rest_point": String(room.get_path_to(self))}


## The room's `safe_room` flag is the only source of the save permission.
func is_save_allowed() -> bool:
	var room := get_room()
	return room != null and room.safe_room


## Where a loaded game places Foxy: beside the fire, clear of its collision.
func get_spawn_position() -> Vector3:
	return _spawn.global_position


func is_menu_open() -> bool:
	return _menu.is_open()


## True while the rest fade is running.
func is_resting() -> bool:
	return _menu.is_fading()


## Same path as pressing the interact key next to the fire: opens the choice menu.
func rest(player: Player) -> bool:
	if _menu.is_open() or _menu.is_fading() or not _can_player_interact(player):
		return false
	if not get_node("/root/GameManager").enter_rest_menu():
		return false
	_interaction.set_interaction_enabled(false)
	_resting_player = player
	if not is_save_allowed():
		_menu.open_unavailable(unsafe_message)
		return true
	_menu.open_choices(choice_message, _describe_slot())
	return true


## Picks REST (`save` false) or REST and SAVE (`save` true) from the open menu.
func choose_rest(save: bool) -> bool:
	if not _menu.are_rest_choices_available():
		return false
	# The rest itself happens while the screen is black.
	_menu.play_rest_fade(
		_restore_while_dark.bind(_resting_player, save), _on_rest_finished.bind(_resting_player)
	)
	return true


func close_menu() -> void:
	if not _menu.is_open():
		return
	_menu.close()
	_resting_player = null
	_interaction.set_interaction_enabled(true)
	get_node("/root/GameManager").exit_rest_menu()


func _restore_while_dark(player: Player, save: bool) -> void:
	get_node("/root/GameManager").room_states.begin_new_cycle(get_location())
	if is_instance_valid(player):
		player.hp.set_current_hp(player.hp.get_max_hp())
		player.stamina.set_current_sp(player.stamina.get_max_sp())
	_save_error = _write_save() if save else OK
	_saved_requested = save


func _on_rest_finished(player: Player) -> void:
	rested.emit(player)
	if not _saved_requested:
		close_menu()
		return
	var message := saved_message
	if _save_error != OK:
		message = "Save failed (%s). Your previous save is unchanged." % error_string(_save_error)
	_menu.show_save_result(message, _describe_slot())
	save_finished.emit(_save_error)


# Saves the state after the refill, so the file holds the restored HP and SP.
func _write_save() -> Error:
	return get_node("/root/GameManager").save_game(self)


func _can_player_interact(player: Player) -> bool:
	return (
		is_instance_valid(player)
		and not player.dead
		and not player.is_gameplay_input_blocked()
		and not player.is_charm_casting()
	)


func _describe_slot() -> String:
	return get_node("/root/GameManager").save_slot.read().describe_for_overwrite()


func _on_interaction_requested(interactor: Player) -> void:
	rest(interactor)
