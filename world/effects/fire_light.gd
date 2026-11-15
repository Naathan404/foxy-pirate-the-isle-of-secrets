@tool
extends OmniLight3D
## Smooth, non-periodic fire flicker; reusable for torches and braziers.
@export_range(0.0, 8.0) var base_energy: float = 2.2
@export_range(0.0, 0.9) var flicker_amount: float = 0.22
@export_range(0.1, 8.0) var flicker_speed: float = 2.5
@export var warm_color := Color(1.0, 0.48, 0.16)
@export var hot_color := Color(1.0, 0.69, 0.3)
@export var preview_in_editor: bool = true
var _noise := FastNoiseLite.new()
var _elapsed := 0.0

func _ready() -> void:
    _noise.seed = get_instance_id() % 2147483647
    _noise.frequency = 1.0

func _process(delta: float) -> void:
    if Engine.is_editor_hint() and not preview_in_editor:
        light_energy = base_energy
        light_color = warm_color
        return
    _elapsed += delta * flicker_speed
    var flicker := clampf(_noise.get_noise_1d(_elapsed), -1.0, 1.0)
    light_energy = base_energy * (1.0 + flicker * flicker_amount)
    light_color = warm_color.lerp(hot_color, (flicker + 1.0) * 0.5)
