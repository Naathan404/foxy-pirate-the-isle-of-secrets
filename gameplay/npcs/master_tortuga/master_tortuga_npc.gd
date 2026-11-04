class_name MasterTortugaNpc
extends BaseNpc

const TALKING_SHEET: Texture2D = preload(
	"res://assets/sprites/npcs/master_tortuga/Master_Tortuga_Talking.png"
)

@export var data: NpcData

@onready var sprite: AnimatedSprite3D = $Visual/AnimatedSprite3D
@onready var forge_panel: TortugaPanel = $TortugaPanel


func _ready() -> void:
	if data == null or forge_panel == null:
		push_error("MasterTortugaNpc: NPC data and forge panel are required")
		set_physics_process(false)
		return
	super()
	_install_talking_animation()
	dialogue_started.connect(_on_dialogue_started)
	dialogue_finished.connect(_on_dialogue_finished)
	forge_panel.panel_closed.connect(_on_panel_closed)
	sprite.play(&"idle")


func get_npc_data() -> NpcData:
	return data


func play_directional_animation(action: StringName, _restart: bool = false) -> bool:
	return action == &"idle" or action == &"walk"


func _on_dialogue_started(_interactor: Player) -> void:
	sprite.play(&"talking")


func _on_dialogue_finished(interactor: Player) -> void:
	sprite.play(&"idle")
	interaction_area.set_interaction_enabled(false)
	_open_panel.call_deferred(interactor)


func _open_panel(interactor: Player) -> void:
	if not is_instance_valid(interactor) or interactor.dead or not forge_panel.open_for(interactor):
		interaction_area.set_interaction_enabled(true)


func _on_panel_closed() -> void:
	interaction_area.set_interaction_enabled(true)


func _install_talking_animation() -> void:
	var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
	if not frames.has_animation(&"talking"):
		frames.add_animation(&"talking")
		frames.set_animation_speed(&"talking", 10.0)
		frames.set_animation_loop(&"talking", true)
		for index in 8:
			var frame := AtlasTexture.new()
			frame.atlas = TALKING_SHEET
			frame.region = Rect2((index % 4) * 443, floori(float(index) / 4.0) * 443, 443, 443)
			frames.add_frame(&"talking", frame)
	sprite.sprite_frames = frames


func _exit_tree() -> void:
	if is_instance_valid(forge_panel) and forge_panel.visible:
		forge_panel.close_panel(true)
	super()
