extends Node
## Room-owned ambience; the player continues to own water and low-health feedback.
@export var replace_player_ambient: bool = true

func _ready() -> void:
    call_deferred("_configure_player_ambient")

func _configure_player_ambient() -> void:
    if not replace_player_ambient:
        return
    var player := get_parent().get_node_or_null("Foxy")
    if player == null:
        return
    var atmosphere := player.get_node_or_null("Effects/EnvironmentAtmosphere")
    if atmosphere != null:
        atmosphere.ambient_enabled = false
        atmosphere._refresh_settings()
    var motes := player.get_node_or_null("Effects/AmbientMotes") as GPUParticles3D
    if motes != null:
        motes.emitting = false
        motes.visible = false
